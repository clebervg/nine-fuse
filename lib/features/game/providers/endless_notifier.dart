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

/// Modo Endless: sem objetivo e sem limite de movimentos. A corrida dura até o
/// tabuleiro não ter mais nenhuma troca que forme combinação.
///
/// A janela de sorteio **sobe** conforme o jogador domina cada faixa. Isso não
/// é enfeite: com a janela fixa em 0-3 a simulação mostrou que toda partida
/// morre em ~274 movimentos sem nunca chegar ao dígito máximo. Deslizar a
/// janela dobra a duração e leva ao 9. Ver [EndlessProgression], e
/// `tool/simulate_economy.dart --mode=endless` para os números.
class EndlessNotifier extends StateNotifier<EndlessState> {
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
    );
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

      case MoveResolved(:final resolution):
        if (JuiceTimings.instantResolution) {
          _finishMove(engine, resolution, extraScore: resolution.score);
        } else {
          _playResolution(engine, resolution);
        }
    }
  }

  /// Encena a jogada quadro a quadro. Ver `GameNotifier._playResolution`: a
  /// mecânica é a mesma, muda só o que se faz no fim.
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

      runningScore += step.score;

      // O clímax do jogo merece ser sentido, não só visto — e no Endless ele é
      // ainda mais raro que na campanha. Fica na encenação e não em
      // `_finishMove` porque a batida tem de coincidir com o clarão.
      if (step.explosionCentres.isNotEmpty) explosionFeedback();

      state = state.copyWith(
        board: step.boardAfterFusion,
        score: runningScore,
        activeStep: step,
        comboCount: step.cascade,
        bigFusionTileIds: {
          for (final fusion in step.fusions)
            if (fusion.isBig) fusion.tileId,
        },
        // Uma vez ligado, nunca desliga: a comemoração é da **primeira** fusão
        // máxima da partida.
        apexCelebrated:
            state.apexCelebrated || step.explosionCentres.isNotEmpty,
      );
      await _delay(JuiceTimings.fusion);
      if (!mounted) return;

      state = state.copyWith(board: step.boardAfterSettle);
      await _delay(JuiceTimings.settle);
    }

    if (!mounted) return;
    _finishMove(engine, resolution, extraScore: 0);
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

    final score = state.score + extraScore;

    // Uma varredura só serve às duas perguntas: ainda dá para jogar e qual é
    // a jogada.
    final hint = engine.findHint(board);
    final stuck = hint == null;

    state = state.copyWith(
      board: board,
      score: score,
      moves: state.moves + 1,
      step: step,
      highestDigit: max(state.highestDigit, resolution.highestProduced),
      explosions: state.explosions + resolution.explosions,
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
      // Na resolução instantânea não há encenação para ligar o sinal.
      apexCelebrated: state.apexCelebrated || resolution.explosions > 0,
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
