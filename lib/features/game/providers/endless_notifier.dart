import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/core/juice_timings.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/endless_progression.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/providers/endless_state.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import 'package:nine_fuse/features/game/providers/hammer_booster.dart';

/// Modo Endless: sem objetivo e sem limite de movimentos. A corrida dura até o
/// tabuleiro não ter mais nenhuma troca que forme combinação.
///
/// A janela de sorteio **sobe** conforme o jogador domina cada faixa. Isso não
/// é enfeite: com a janela fixa em 0-3 a simulação mostrou que toda partida
/// morre em ~274 movimentos sem nunca chegar ao dígito máximo. Deslizar a
/// janela dobra a duração e leva ao 9. Ver [EndlessProgression], e
/// `tool/simulate_economy.dart --mode=endless` para os números.
class EndlessNotifier extends StateNotifier<EndlessState>
    with HammerBooster<EndlessState> {
  EndlessNotifier({
    Random? random,
    GameStorage? storage,
    Future<void> Function(Duration)? delay,
    this.progression = const EndlessProgression(),
  }) : _random = random ?? Random(),
       _delay = delay ?? ((d) => Future<void>.delayed(d)),
       _storage = storage ?? const PrefsGameStorage(),
       super(EndlessState.initial());

  final Random _random;
  final GameStorage _storage;

  /// Espera entre os quadros da encenação, injetável para os testes.
  final Future<void> Function(Duration) _delay;
  final EndlessProgression progression;

  MatchEngine? _engine;

  @visibleForTesting
  MatchEngine? get engine => _engine;

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

  /// A corrida travada não aceita golpe: o cartão de fim já está na tela e o
  /// placar já foi gravado, então um golpe ali reabriria uma partida encerrada.
  @override
  bool get acceptsHammer =>
      state.status == EndlessStatus.playing && !state.isResolving;

  @override
  void onHammerTargetingStarted() {
    state = state.copyWith(clearSelectedTile: true, clearRejectedSwap: true);
  }

  /// O golpe **não conta como movimento**, mesmo aqui, onde não há limite deles:
  /// `moves` é o que o cartão de fim de corrida relata, e um golpe comprado não
  /// é uma jogada do jogador.
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

  int _highScore = 0;

  /// Recorde conhecido. Zero até [start] carregar o valor salvo.
  int get highScore => _highScore;

  /// Começa uma corrida nova.
  ///
  /// Ler o recorde não pode impedir de jogar: se o armazenamento falhar,
  /// começamos com recorde zero em vez de deixar o jogador preso na espera.
  Future<void> start() async {
    try {
      _highScore = await _storage.readHighScore();
    } catch (error, stack) {
      _highScore = 0;
      debugPrint('Falha ao ler o recorde do Endless: $error\n$stack');
    }

    final engine = MatchEngine(random: _random);
    _applyWindow(engine, EndlessProgression.firstStep);
    _engine = engine;

    final board = engine.generateBoard(
      obstacles: progression.obstaclesFor(EndlessProgression.firstStep),
    );

    state = EndlessState(
      board: board,
      status: EndlessStatus.playing,
      hint: engine.findHint(board),
      // O estoque atravessa a corrida nova; a mira e o estilhaço ficam com a
      // que acabou.
      hammer: state.hammer.inventoryOnly,
    );

    // A campanha pode ter gastado um martelo enquanto esta tela estava viva: o
    // estoque é o mesmo, e quem chegou por último ao disco manda.
    await refreshHammers();
  }

  void _applyWindow(MatchEngine engine, int step) {
    engine.setSpawnWindow(
      min: progression.spawnMinFor(step),
      max: progression.spawnMaxFor(step),
    );
  }

  /// Substitui o tabuleiro por um montado à mão.
  ///
  /// Só para teste: é o que permite exercitar uma jogada específica — criar o
  /// dígito máximo, por exemplo — sem depender de o sorteio colaborar.
  @visibleForTesting
  void debugSetBoard(Board board) {
    final hint = _engine?.findHint(board);
    state = state.copyWith(board: board, hint: hint, clearHint: hint == null);
  }

  /// Tap consecutivo, igual à campanha.
  void selectTile(Position position) {
    if (state.status != EndlessStatus.playing || state.isResolving) return;
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

  void swapTiles(Position a, Position b) {
    final engine = _engine;
    if (engine == null || state.status != EndlessStatus.playing) return;
    if (state.isResolving) return;

    switch (engine.tryMove(state.board, a, b)) {
      case MoveImpossible():
        return;

      case MoveRejected(:final from, :final to):
        state = state.copyWith(
          clearSelectedTile: true,
          rejectedSwap: (from, to),
        );

      case MoveSuperNineActivated(:final board, :final convertedFrom):
        _applySuperNineActivation(engine, board, convertedFrom);

      case MoveResolved(:final resolution):
        if (JuiceTimings.instantResolution) {
          _finishMove(engine, resolution, extraScore: resolution.score);
        } else {
          _playResolution(engine, resolution);
        }
    }
  }

  /// Aplica o desfecho da ativação do Super 9, espelhando
  /// `GameNotifier._applySuperNineActivation`: consome 1 movimento, decai as
  /// peças especiais do turno e conta como evento de clímax para o tranco de
  /// tela. Não há objetivo nem limite de movimentos no Endless — o único
  /// desfecho possível além de continuar jogando é o tabuleiro travar.
  void _applySuperNineActivation(
    MatchEngine engine,
    Board board,
    int convertedFrom,
  ) {
    final decayed = engine.decaySpecials(board);
    final hint = engine.findHint(decayed);
    final stuck = hint == null;

    state = state.copyWith(
      board: decayed,
      moves: state.moves + 1,
      clearSelectedTile: true,
      clearRejectedSwap: true,
      hint: hint,
      clearHint: stuck,
      explosions: state.explosions + 1,
      status: stuck ? EndlessStatus.stuck : EndlessStatus.playing,
      isRecord: stuck && state.score > _highScore,
      // Ativar o Super 9 sempre produz um 9 — mesma régua de
      // `GameNotifier._applySuperNineActivation`.
      apexCelebrated: state.apexCelebrated || convertedFrom + 1 == kMaxDigit,
    );

    if (stuck) _saveIfRecord(state.score);
  }

  /// Encena a jogada quadro a quadro. Ver `GameNotifier._playResolution`: a
  /// mecânica é a mesma, muda só o que se faz no fim.
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

      runningScore += step.score;

      // O clímax do jogo merece ser sentido, não só visto — e no Endless ele é
      // ainda mais raro que na campanha. Fica na encenação e não em
      // `_finishMove` porque a batida tem de coincidir com o clarão. O Bloco 9
      // aprimorado (o que cria o dígito máximo) ainda merece a mesma ênfase.
      if (step.fusions.any((f) => f.value == kMaxDigit)) explosionFeedback();

      state = state.copyWith(
        board: step.boardAfterFusion,
        score: runningScore,
        activeStep: step,
        comboCount: step.cascade,
        bigFusionTileIds: {
          for (final fusion in step.fusions)
            if (fusion.isBig) fusion.tileId,
        },
      );
      await _delay(JuiceTimings.fusion);
      if (!mounted) return;

      state = state.copyWith(board: step.boardAfterSettle);
      await _delay(JuiceTimings.settle);
    }

    if (!mounted) return;
    _finishMove(engine, resolution, extraScore: 0, countsAsMove: countsAsMove);
  }

  /// Batida forte da explosão do dígito máximo.
  ///
  /// Injetável porque é a única coisa aqui que fala com a plataforma: nos
  /// testes vira um contador, e a suíte não depende de canal nativo.
  @visibleForTesting
  static void Function() explosionFeedback = HapticFeedback.heavyImpact;

  void _finishMove(
    MatchEngine engine,
    Resolution resolution, {
    required int extraScore,
    bool countsAsMove = true,
  }) {
    // A janela sobe no máximo um degrau por movimento, mesmo que uma cascata
    // produza vários dígitos altos de uma vez.
    final step = progression.advance(
      step: state.step,
      produced: resolution.producedDigits,
    );
    // O degrau novo cobra o espaço junto com a janela: quem provou que domina
    // a faixa recebe o tabuleiro mais apertado. `placeObstacles` só cobre o
    // que não trava a partida, então isto nunca fabrica um fim de corrida.
    var board = resolution.board;
    if (step != state.step) {
      _applyWindow(engine, step);
      board = engine.placeObstacles(board, progression.obstaclesFor(step));
    }

    // O decaimento das peças especiais só roda em jogada que **conta** como
    // turno do jogador — o golpe de martelo não decai, mesma régua de
    // `GameNotifier._finishMove`. E peça nascida NESTA jogada fica de fora do
    // decaimento (mesma correção de `GameNotifier._finishMove`): sem isso um
    // Super 9 recém-formado perderia 1 dos seus 3 turnos de vida antes de o
    // jogador sequer poder usá-lo.
    if (countsAsMove) {
      board = engine.decaySpecials(
        board,
        newbornIds: resolution.newbornSpecialTileIds,
      );
    }

    final score = state.score + extraScore;

    // Uma varredura só serve às duas perguntas: ainda dá para jogar e qual é
    // a jogada.
    final hint = engine.findHint(board);
    final stuck = hint == null;

    state = state.copyWith(
      board: board,
      score: score,
      moves: state.moves + (countsAsMove ? 1 : 0),
      step: step,
      highestDigit: max(state.highestDigit, resolution.highestProduced),
      status: stuck ? EndlessStatus.stuck : EndlessStatus.playing,
      isRecord: stuck && score > _highScore,
      hint: hint,
      clearHint: stuck,
      bigFusionTileIds: resolution.bigFusionTileIds,
      clearActiveStep: true,
      comboCount: 0,
      isResolving: false,
      clearSelectedTile: true,
      clearRejectedSwap: true,
      // O clímax (Bloco 9/Super 9) é o que `apexCelebrated` celebra agora:
      // primeira vez que o dígito máximo nasce nesta corrida.
      apexCelebrated:
          state.apexCelebrated || resolution.producedDigits.contains(kMaxDigit),
    );

    if (stuck) _saveIfRecord(score);
  }

  Future<void> _saveIfRecord(int score) async {
    if (score <= _highScore) return;
    _highScore = score;

    // Perder o recorde no disco é ruim, mas travar o fim de partida por causa
    // disso é pior.
    try {
      await _storage.writeHighScore(score);
    } catch (error, stack) {
      debugPrint('Falha ao gravar o recorde do Endless: $error\n$stack');
    }
  }
}

/// Provider do modo Endless.
final endlessProvider = StateNotifierProvider<EndlessNotifier, EndlessState>((
  ref,
) {
  return EndlessNotifier();
});

/// O Endless abre depois da fase 5, como recomendaram os especialistas: até ali
/// a campanha já ensinou fusão, cadeia e gestão de espaço.
const int kEndlessUnlockLevel = 5;

/// O Modo Recorde está liberado para quem chegou até [campaignProgress] na
/// campanha?
///
/// Função pura, e não um getter espalhado por cada tela que precisa saber:
/// hoje só `level_select_screen.dart` e o novo convite de migração
/// (`game_screen.dart`) fazem essa pergunta, mas as duas têm de concordar —
/// duas cópias da mesma comparação divergiriam no primeiro ajuste do
/// desbloqueio.
bool endlessIsUnlocked(int campaignProgress) =>
    campaignProgress >= kEndlessUnlockLevel;

/// O recorde do Endless, lido sem começar uma partida.
///
/// Existe porque o destaque do Endless no mapa precisa mostrar o recorde, e o
/// [EndlessNotifier] só carrega o dele ao iniciar uma sessão — pedir o recorde
/// ao notifier obrigaria a criar uma partida para desenhar um banner.
class EndlessHighScore extends StateNotifier<int> {
  EndlessHighScore({GameStorage? storage})
    : _storage = storage ?? const PrefsGameStorage(),
      super(0) {
    refresh();
  }

  final GameStorage _storage;

  /// Relê do disco. Chamado ao voltar do Endless para o mapa: a sessão que
  /// acabou pode ter batido o recorde, e quem gravou foi o outro notifier.
  Future<void> refresh() async {
    try {
      final saved = await _storage.readHighScore();
      // Nunca regride: se a sessão recém-terminada já atualizou o valor em
      // memória, uma leitura atrasada não pode desfazê-lo.
      if (mounted && saved > state) state = saved;
    } catch (error, stack) {
      debugPrint('Falha ao ler o recorde do Endless: $error\n$stack');
    }
  }
}

final endlessHighScoreProvider = StateNotifierProvider<EndlessHighScore, int>(
  (ref) => EndlessHighScore(),
);
