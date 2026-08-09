import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/juice_timings.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_state.dart';

/// A encenação quadro a quadro da jogada.
///
/// O resto da suíte resolve a jogada de uma vez (ver
/// `test/flutter_test_config.dart`), porque verifica regra de jogo. Aqui é o
/// contrário: o que interessa é justamente a passagem pelos quadros.
void main() {
  late GameNotifier notifier;

  /// Espera de mentira: avança os quadros sem gastar tempo real.
  Future<void> instant(Duration _) => Future<void>.value();

  const roomy = GameLevel(
    number: 99,
    objective: Objective(digit: 8, count: 99),
    moveLimit: 500,
  );

  setUp(() {
    JuiceTimings.instantResolution = false;
    notifier = GameNotifier(random: Random(42), delay: instant);
    notifier.startLevel(roomy);
  });

  tearDown(() => JuiceTimings.instantResolution = true);

  (Position, Position)? findValidSwap() {
    final engine = notifier.engine!;
    final board = notifier.state.board;
    for (final (a, b) in engine.candidateSwaps(board)) {
      if (engine.swapCreatesMatch(board, a, b)) return (a, b);
    }
    return null;
  }

  /// Roda a jogada até o fim, deixando os `await` internos completarem.
  Future<void> playMove() async {
    final pair = findValidSwap()!;
    notifier.swapTiles(pair.$1, pair.$2);
    // Cada quadro cede o controle uma vez; um punhado de voltas na fila de
    // microtarefas cobre folgadamente as cascatas de uma jogada.
    for (int i = 0; i < 200; i++) {
      await Future<void>.value();
    }
  }

  group('trava de entrada', () {
    test('a jogada marca o estado como em encenação', () {
      final pair = findValidSwap()!;
      notifier.swapTiles(pair.$1, pair.$2);

      expect(notifier.state.isResolving, isTrue);
    });

    test('não aceita outra jogada durante a encenação', () async {
      final pair = findValidSwap()!;
      notifier.swapTiles(pair.$1, pair.$2);
      expect(notifier.state.isResolving, isTrue);

      // Jogar por cima da animação embaralharia o que o jogador vê com o que
      // já aconteceu.
      final during = notifier.state;
      notifier.swapTiles(Position(row: 0, col: 0), Position(row: 0, col: 1));
      expect(notifier.state, during);

      await playMove();
    });

    test('não aceita seleção durante a encenação', () async {
      final pair = findValidSwap()!;
      notifier.swapTiles(pair.$1, pair.$2);

      notifier.selectTile(Position(row: 5, col: 5));
      expect(notifier.state.selectedTile, isNull);

      await playMove();
    });

    test('a trava é liberada ao final', () async {
      await playMove();

      expect(notifier.state.isResolving, isFalse);
      expect(notifier.state.activeStep, isNull);
      expect(notifier.state.comboCount, 0);
    });
  });

  group('quadros da cascata', () {
    test('o passo ativo fica exposto durante a encenação', () {
      final pair = findValidSwap()!;
      notifier.swapTiles(pair.$1, pair.$2);

      final step = notifier.state.activeStep;
      expect(step, isNotNull);
      expect(step!.fusions, isNotEmpty);
      expect(notifier.state.comboCount, 1);
    });

    test('o primeiro quadro mostra o tabuleiro antes da queda', () {
      final pair = findValidSwap()!;
      notifier.swapTiles(pair.$1, pair.$2);

      // As casas liberadas pela fusão ainda estão vazias: é o quadro em que a
      // UI encolhe as peças absorvidas.
      expect(notifier.state.board.isFull, isFalse);
      expect(notifier.state.board, notifier.state.activeStep!.boardAfterFusion);
    });

    test('o tabuleiro termina cheio e o movimento é contado', () async {
      await playMove();

      expect(notifier.state.board.isFull, isTrue);
      expect(notifier.state.moves, 1);
      expect(notifier.state.status, GameStatus.playing);
    });

    test('a pontuação sobe já no primeiro quadro', () {
      expect(notifier.state.score, 0);

      final pair = findValidSwap()!;
      notifier.swapTiles(pair.$1, pair.$2);

      // Subir só no fim faria o número saltar depois de a animação acabar.
      expect(notifier.state.score, greaterThan(0));
    });

    test('a pontuação final bate com a soma dos passos encenados', () async {
      // Observa os passos conforme aparecem. Chamar `resolve` à parte para
      // prever o resultado não serve: a reposição consome o sorteio do motor,
      // e a jogada real acabaria com outro tabuleiro.
      final seen = <int, int>{};
      notifier.addListener((state) {
        final step = state.activeStep;
        if (step != null) seen[step.cascade] = step.score;
      });

      await playMove();

      expect(seen, isNotEmpty);
      expect(
        notifier.state.score,
        seen.values.fold<int>(0, (total, s) => total + s),
      );
    });
  });

  group('troca recusada', () {
    test('não entra em encenação', () {
      final engine = notifier.engine!;
      final board = notifier.state.board;
      final pair = engine
          .candidateSwaps(board)
          .firstWhere((s) => !engine.swapCreatesMatch(board, s.$1, s.$2));

      notifier.swapTiles(pair.$1, pair.$2);

      expect(notifier.state.isResolving, isFalse);
      expect(notifier.state.activeStep, isNull);
      expect(notifier.state.rejectedSwap, isNotNull);
    });
  });
}
