import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/core/juice_timings.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/providers/game_state.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';

/// Orquestra o estado da fase. Toda a regra de Match-3 e fusão vive no
/// [MatchEngine]; aqui só decidimos o que fazer com o resultado.
class GameNotifier extends StateNotifier<GameState> {
  GameNotifier({Random? random, Future<void> Function(Duration)? delay})
    : _random = random ?? Random(),
      _delay = delay ?? _realDelay,
      super(GameState.initial());

  static Future<void> _realDelay(Duration d) => Future<void>.delayed(d);

  final Random _random;

  /// Espera entre os quadros da encenação. Injetável para os testes rodarem
  /// sem gastar tempo real — e para não dependerem de `pumpAndSettle` em
  /// lógica que não é de widget.
  final Future<void> Function(Duration) _delay;

  /// O motor é criado por fase, porque a janela de spawn muda de fase para
  /// fase. Fica nulo até a primeira fase começar.
  MatchEngine? _engine;

  /// Exposto para os testes poderem perguntar ao motor quais trocas formam
  /// combinação, em vez de depender do sorteio.
  @visibleForTesting
  MatchEngine? get engine => _engine;

  /// Começa a fase [level] com um tabuleiro novo.
  void startLevel(GameLevel level) {
    _engine = MatchEngine(
      random: _random,
      spawnMin: level.spawnMin,
      spawnMax: level.spawnMax,
    );

    final board = _engine!.generateBoard();

    state = GameState(
      board: board,
      level: level,
      status: GameStatus.playing,
      hint: _engine!.findHint(board),
      // Cada partida tem o seu número. Sem ele, recomeçar a fase atual sem
      // tê-la perdido é indistinguível de nada ter mudado, e a UI não teria
      // como saber que precisa reabrir o cartão de início.
      runId: state.runId + 1,
    );
  }

  /// Recomeça a fase atual.
  void restartLevel() => startLevel(state.level);

  /// Substitui o tabuleiro por um montado à mão.
  ///
  /// Só para teste: é o que permite exercitar uma jogada específica — criar o
  /// dígito máximo, por exemplo — sem depender de o sorteio colaborar.
  @visibleForTesting
  void debugSetBoard(Board board) {
    final hint = _engine?.findHint(board);
    state = state.copyWith(board: board, hint: hint, clearHint: hint == null);
  }

  /// Vai para a fase seguinte, ou repete a última se a campanha acabou.
  void nextLevel() {
    final index = kCampaign.indexWhere((l) => l.number == state.level.number);
    final next = index >= 0 && index + 1 < kCampaign.length
        ? kCampaign[index + 1]
        : state.level;
    startLevel(next);
  }

  /// Tap consecutivo: o primeiro toque seleciona, o segundo em peça adjacente
  /// tenta a troca. Tocar longe move a seleção.
  void selectTile(Position position) {
    if (state.status != GameStatus.playing || state.isResolving) return;
    if (state.board.getTileAt(position) == null) return;

    final selected = state.selectedTile;

    if (selected == null) {
      _select(position);
      return;
    }

    if (selected.position == position) {
      deselectTile();
      return;
    }

    if (selected.position.isAdjacentTo(position)) {
      swapTiles(selected.position, position);
    } else {
      _select(position);
    }
  }

  void _select(Position position) {
    final tile = state.board.getTileAt(position);
    if (tile == null) return;

    state = state.copyWith(
      selectedTile: tile.copyWith(isSelected: true),
      clearRejectedSwap: true,
    );
  }

  void deselectTile() {
    state = state.copyWith(clearSelectedTile: true, clearRejectedSwap: true);
  }

  /// Troca duas peças adjacentes.
  ///
  /// A troca só vale se formar combinação: caso contrário as peças voltam e o
  /// movimento não é contado, senão o limite de movimentos não puniria erro.
  void swapTiles(Position a, Position b) {
    final engine = _engine;
    if (engine == null || state.status != GameStatus.playing) return;
    // Jogar por cima da animação embaralharia o que o jogador está vendo com
    // o que já aconteceu.
    if (state.isResolving) return;

    switch (engine.tryMove(state.board, a, b)) {
      case MoveImpossible():
        return;

      case MoveRejected(:final from, :final to):
        state = state.copyWith(
          clearSelectedTile: true,
          rejectedSwap: (from, to),
        );

      case MoveResolved(:final resolution):
        if (JuiceTimings.instantResolution) {
          _finishMove(engine, resolution, extraScore: resolution.score);
        } else {
          _playResolution(engine, resolution);
        }
    }
  }

  /// Encena a jogada passo a passo e só então aplica o desfecho.
  ///
  /// Cada cascata aparece em dois quadros: o da fusão (peças absorvidas ainda
  /// visíveis, encolhendo) e o do assentamento (queda e reposição). Sem isso a
  /// jogada inteira seria um salto do começo ao fim, e não haveria como
  /// mostrar combo, pontuação no lugar certo, nem a fusão acontecendo.
  Future<void> _playResolution(
    MatchEngine engine,
    Resolution resolution,
  ) async {
    state = state.copyWith(
      isResolving: true,
      clearSelectedTile: true,
      clearRejectedSwap: true,
    );

    var runningScore = state.score;

    for (final step in resolution.steps) {
      if (!mounted) return;

      // Quadro da fusão: o placar já sobe aqui, junto com a pontuação
      // flutuante que a UI desenha no ponto da fusão.
      runningScore += step.score;

      // O clímax do jogo merece ser sentido, não só visto. Fica na encenação e
      // não em `_finishMove` porque o momento importa: a batida tem de coincidir
      // com o clarão, e não com o fim da cascata inteira.
      if (step.explosionCentres.isNotEmpty) {
        _explosionFeedback();
      }

      state = state.copyWith(
        board: step.boardAfterFusion,
        score: runningScore,
        activeStep: step,
        comboCount: step.cascade,
        // Uma vez ligado, nunca desliga: a comemoração é da **primeira** fusão
        // máxima da partida.
        apexCelebrated:
            state.apexCelebrated || step.explosionCentres.isNotEmpty,
        bigFusionTileIds: {
          for (final fusion in step.fusions)
            if (fusion.isBig) fusion.tileId,
        },
      );
      await _delay(JuiceTimings.fusion);
      if (!mounted) return;

      // Quadro do assentamento: as peças caem e o topo é reposto.
      state = state.copyWith(board: step.boardAfterSettle);
      await _delay(JuiceTimings.settle);
    }

    if (!mounted) return;
    // A pontuação já subiu quadro a quadro durante a encenação.
    _finishMove(engine, resolution, extraScore: 0);
  }

  /// Batida forte da explosão do dígito máximo.
  ///
  /// Injetável porque é a única coisa aqui que fala com a plataforma: nos
  /// testes vira um contador, e a suíte não depende de canal nativo.
  @visibleForTesting
  static void Function() explosionFeedback = HapticFeedback.heavyImpact;

  void _explosionFeedback() => explosionFeedback();

  /// Aplica o desfecho da jogada: objetivo, movimento, dica e situação da fase.
  ///
  /// [extraScore] é a pontuação que ainda não foi contabilizada. Na encenação
  /// ela sobe a cada cascata e aqui vale zero; na resolução instantânea vem
  /// tudo de uma vez.
  void _finishMove(
    MatchEngine engine,
    Resolution resolution, {
    required int extraScore,
  }) {
    final progress =
        state.objectiveProgress +
        resolution.countProduced(state.level.objective.digit);
    final moves = state.moves + 1;

    // Cada dígito máximo criado devolve movimentos. É o que faz a explosão ser
    // uma conquista de fase, e não só um efeito bonito: sem isso o jogador que
    // gasta jogadas montando o 9 é punido por ter feito a jogada mais difícil.
    final bonusMoves =
        state.bonusMoves + resolution.explosions * kExplosionBonusMoves;

    // Uma varredura só serve às duas perguntas: existe jogada (senão a fase
    // acabou) e qual é ela (para a dica).
    final hint = engine.findHint(resolution.board);

    final outcome = _outcomeAfterMove(
      progress: progress,
      moves: moves,
      // O saldo já contando o bônus deste movimento: um 9 criado na última
      // jogada precisa salvar a fase, não chegar tarde demais.
      movesAvailable: state.level.moveLimit + bonusMoves,
      hasMove: hint != null,
    );

    state = state.copyWith(
      board: resolution.board,
      score: state.score + extraScore,
      moves: moves,
      bonusMoves: bonusMoves,
      objectiveProgress: progress,
      status: outcome.status,
      lossReason: outcome.loss,
      clearLossReason: outcome.loss == null,
      hint: hint,
      clearHint: hint == null,
      bigFusionTileIds: resolution.bigFusionTileIds,
      clearActiveStep: true,
      comboCount: 0,
      isResolving: false,
      clearSelectedTile: true,
      clearRejectedSwap: true,
      // Na resolução instantânea não há encenação para ligar o sinal, e sem
      // isto a comemoração só existiria no caminho animado.
      apexCelebrated: state.apexCelebrated || resolution.explosions > 0,
    );
  }

  /// Como a fase fica depois deste movimento, e por quê.
  ///
  /// As duas causas de derrota são independentes e são apuradas separadamente:
  /// **saldo de movimentos** é regra de fase, **tabuleiro travado** é estado do
  /// tabuleiro. Um nunca substitui o outro — devolver só o status obrigaria a
  /// UI a deduzir o motivo pelo saldo, que foi a origem da mensagem confusa.
  ///
  /// A vitória é conferida antes das derrotas: cumprir o objetivo no último
  /// movimento disponível vale como vitória, não como movimentos esgotados.
  ({GameStatus status, LossReason? loss}) _outcomeAfterMove({
    required int progress,
    required int moves,
    required int movesAvailable,
    required bool hasMove,
  }) {
    if (progress >= state.level.objective.count) {
      return (status: GameStatus.won, loss: null);
    }
    if (moves >= movesAvailable) {
      return (status: GameStatus.lost, loss: LossReason.moveLimitReached);
    }
    if (!hasMove) {
      return (status: GameStatus.lost, loss: LossReason.boardStuck);
    }
    return (status: GameStatus.playing, loss: null);
  }
}

/// Provider do GameNotifier
final gameProvider = StateNotifierProvider<GameNotifier, GameState>(
  (ref) => GameNotifier(),
);

/// Número da fase mais alta já concluída. As fases seguintes ficam bloqueadas.
///
/// O valor é carregado do armazenamento na criação e gravado a cada fase
/// concluída, para que fechar o app não custe a campanha.
class CampaignProgress extends StateNotifier<int> {
  CampaignProgress({GameStorage? storage})
    : _storage = storage ?? const PrefsGameStorage(),
      super(0) {
    _load();
  }

  final GameStorage _storage;

  /// A leitura é assíncrona, então a tela aparece com zero e se atualiza quando
  /// o valor chega. Falha de leitura vale como "nada salvo": perder o avanço é
  /// ruim, mas travar o menu é pior.
  Future<void> _load() async {
    try {
      final saved = await _storage.readCampaignProgress();
      // Nunca regride. Se o jogador concluiu uma fase antes da leitura chegar,
      // o valor em memória é o mais recente.
      if (mounted && saved > state) state = saved;
    } catch (error, stack) {
      debugPrint('Falha ao ler o progresso da campanha: $error\n$stack');
    }
  }

  void complete(int levelNumber) {
    if (levelNumber <= state) return;
    state = levelNumber;
    _persist(levelNumber);
  }

  bool isUnlocked(GameLevel level) => level.number <= state + 1;

  void reset() {
    state = 0;
    _persist(0);
  }

  Future<void> _persist(int levelNumber) async {
    try {
      await _storage.writeCampaignProgress(levelNumber);
    } catch (error, stack) {
      debugPrint('Falha ao gravar o progresso da campanha: $error\n$stack');
    }
  }
}

final campaignProgressProvider = StateNotifierProvider<CampaignProgress, int>(
  (ref) => CampaignProgress(),
);
