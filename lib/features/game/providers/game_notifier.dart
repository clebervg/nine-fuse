import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/core/juice_timings.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/level_catalog.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/providers/game_state.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import 'package:nine_fuse/features/game/providers/hammer_booster.dart';

/// Orquestra o estado da fase. Toda a regra de Match-3 e fusão vive no
/// [MatchEngine]; aqui só decidimos o que fazer com o resultado.
class GameNotifier extends StateNotifier<GameState>
    with HammerBooster<GameState> {
  GameNotifier({
    Random? random,
    Future<void> Function(Duration)? delay,
    GameStorage? storage,
  }) : _random = random ?? Random(),
       _delay = delay ?? _realDelay,
       _storage = storage ?? const PrefsGameStorage(),
       super(GameState.initial()) {
    refreshHammers();
  }

  static Future<void> _realDelay(Duration d) => Future<void>.delayed(d);

  final Random _random;

  /// Onde o inventário de boosters mora entre aberturas do app.
  final GameStorage _storage;

  @override
  GameStorage get hammerStorage => _storage;

  @override
  MatchEngine? get hammerEngine => _engine;

  @override
  Board get hammerBoard => state.board;

  @override
  HammerState get hammer => state.hammer;

  @override
  void writeHammer(HammerState value) => state = state.copyWith(hammer: value);

  /// Mira e golpe pedem a fase em andamento e nenhuma encenação no ar — a mesma
  /// régua de [swapTiles], pelo mesmo motivo: jogar por cima da animação
  /// embaralharia o que o jogador está vendo com o que já aconteceu.
  @override
  bool get acceptsHammer =>
      state.status == GameStatus.playing && !state.isResolving;

  /// Mira e seleção de troca não convivem: uma peça acesa para trocar, enquanto
  /// o dedo vai martelar, diz duas coisas ao mesmo tempo.
  @override
  void onHammerTargetingStarted() {
    state = state.copyWith(clearSelectedTile: true, clearRejectedSwap: true);
  }

  @override
  void playHammerResolution(MatchEngine engine, Resolution resolution) {
    if (JuiceTimings.instantResolution) {
      _finishMove(
        engine,
        resolution,
        extraScore: resolution.score,
        countsAsMove: false,
      );
    } else {
      _playResolution(engine, resolution, countsAsMove: false);
    }
  }

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

    final board = _engine!.generateBoard(obstacles: level.obstacles);

    state = GameState(
      board: board,
      level: level,
      status: GameStatus.playing,
      hint: _engine!.findHint(board),
      // Cada partida tem o seu número. Sem ele, recomeçar a fase atual sem
      // tê-la perdido é indistinguível de nada ter mudado, e a UI não teria
      // como saber que precisa reabrir o cartão de início.
      runId: state.runId + 1,
      boardObstacleGoal: _obstacleGoalFor(level, board),
      // O inventário atravessa a fase nova (é do jogador, não da partida), mas
      // a mira e o estilhaço ficam para trás com a partida que acabou.
      hammer: state.hammer.inventoryOnly,
    );

    // O Endless pode ter gastado um martelo enquanto esta tela estava viva: os
    // dois notifiers compartilham o estoque, e quem chegou por último ao disco
    // manda.
    refreshHammers();
  }

  /// O alvo de um objetivo "limpe todas as coberturas", medido **no tabuleiro
  /// que o jogador recebeu**.
  ///
  /// Não sai de `level.obstacles` porque `placeObstacles` descarta a cobertura
  /// que não acha lugar: pedir as quatro pedras que a fase queria, num tabuleiro
  /// onde só três couberam, seria fabricar uma fase impossível.
  static int? _obstacleGoalFor(GameLevel level, Board board) =>
      level.objective.type == ObjectiveType.clearAllObstacles
      ? board.countObstacles(level.objective.obstacle)
      : null;

  /// Recomeça a fase atual.
  void restartLevel() => startLevel(state.level);

  /// O convite de reforço de saldo subiu na tela.
  ///
  /// Quem marca é a **UI**, e não o notifier: a regra sabe dizer que a fase
  /// está apertada ([GameState.shouldOfferMoves]), mas só a tela sabe se
  /// chegou a mostrar o convite. Marcar aqui, na jogada que cruza o limiar,
  /// gastaria a única oferta da fase mesmo que o modal nunca abrisse — por
  /// exemplo, com o app em segundo plano.
  void markMovesOfferShown() {
    if (state.movesOfferShown) return;
    state = state.copyWith(movesOfferShown: true);
  }

  /// Credita o prêmio do anúncio de reforço de saldo.
  ///
  /// Entra em [GameState.bonusMoves], e não descontando de `moves`, pela mesma
  /// razão do bônus do dígito máximo: `moves` é "quantas jogadas o jogador
  /// fez", e é isso que o cartão de fim de fase relata.
  ///
  /// A fase encerrada recusa. O cartão de desfecho já está no ar, e creditar
  /// movimentos aqui deixaria o jogador com saldo numa fase que acabou — sem
  /// contar que a regra anti-churn não vende nada na tela de derrota.
  void grantBonusMoves([int amount = kPreChurnReward]) {
    if (state.status != GameStatus.playing) return;
    state = state.copyWith(
      bonusMoves: state.bonusMoves + amount,
      // O convite se fecha por ter sido pago, e não só por ter sido mostrado:
      // sem isto ele reabriria assim que o saldo voltasse ao limiar.
      movesOfferShown: true,
    );
  }

  /// Substitui o tabuleiro por um montado à mão.
  ///
  /// Só para teste: é o que permite exercitar uma jogada específica — criar o
  /// dígito máximo, por exemplo — sem depender de o sorteio colaborar.
  @visibleForTesting
  void debugSetBoard(Board board) {
    final hint = _engine?.findHint(board);
    state = state.copyWith(
      board: board,
      hint: hint,
      clearHint: hint == null,
      // O alvo de "limpe todas" vem do tabuleiro, e o tabuleiro acabou de
      // trocar. Sem recalcular, a fase cobraria as coberturas do sorteio que
      // este board substituiu.
      boardObstacleGoal: _obstacleGoalFor(state.level, board),
      clearBoardObstacleGoal: _obstacleGoalFor(state.level, board) == null,
    );
  }

  /// Vai para a fase seguinte. Não há última fase: acima do conteúdo
  /// artesanal, `levelAt` calcula.
  void nextLevel() => startLevel(levelAt(state.level.number + 1));

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
    Resolution resolution, {
    bool countsAsMove = true,
  }) async {
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
        // O tranco do tabuleiro nasce aqui, e não em `_finishMove`, pelo mesmo
        // motivo da batida tátil: a sacudida tem de coincidir com o clarão, e
        // não com o fim da cascata inteira.
        explosions: state.explosions + step.explosionCentres.length,
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
    // A pontuação e o contador de explosões já subiram quadro a quadro durante
    // a encenação.
    _finishMove(
      engine,
      resolution,
      extraScore: 0,
      extraExplosions: 0,
      countsAsMove: countsAsMove,
    );
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
  ///
  /// [countsAsMove] é falso no golpe de martelo: não gastar movimento é
  /// justamente o que o jogador está comprando. O desfecho continua sendo
  /// reavaliado — uma cascata do golpe pode cumprir o objetivo, e a queda pode
  /// travar o tabuleiro.
  /// [extraExplosions] segue a mesma regra de [extraScore]: nulo significa "o
  /// caminho que me chamou ainda não contou", e a resolução instantânea — que
  /// não tem encenação para contar quadro a quadro — cai nesse caso.
  void _finishMove(
    MatchEngine engine,
    Resolution resolution, {
    required int extraScore,
    int? extraExplosions,
    bool countsAsMove = true,
  }) {
    final progress = state.objectiveProgress + _gainedThisMove(resolution);
    final moves = state.moves + (countsAsMove ? 1 : 0);

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
      // O alvo é estável durante a fase: `boardObstacleGoal` foi fixado no
      // sorteio, e os outros objetivos declaram a quantidade. Lê-lo do estado
      // **antes** da atualização é seguro, e evita montar um estado provisório
      // só para poder perguntar se ele já ganhou.
      target: state.objectiveTarget,
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
      explosions:
          state.explosions + (extraExplosions ?? resolution.explosions),
    );
  }

  /// O quanto esta jogada rendeu ao objetivo da fase.
  ///
  /// As metas se medem em unidades diferentes, e a diferença importa: um dígito
  /// só conta se tiver **nascido de fusão**, e uma cobertura só conta se tiver
  /// **quebrado** — trincar o vidro não é progresso, porque não é o que o
  /// jogador vê sumir do tabuleiro.
  int _gainedThisMove(Resolution resolution) {
    final objective = state.level.objective;

    return switch (objective.type) {
      ObjectiveType.reachDigit => resolution.countProduced(objective.digit!),
      ObjectiveType.clearObstacles || ObjectiveType.clearAllObstacles =>
        resolution.countCleared(objective.obstacle),
    };
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
    required int target,
    required int moves,
    required int movesAvailable,
    required bool hasMove,
  }) {
    if (progress >= target) {
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
