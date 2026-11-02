import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';
import 'package:nine_fuse/features/game/domain/tutorial.dart';

/// Monta um tabuleiro a partir de uma matriz de valores.
Board boardFromValues(List<List<int>> values) {
  var board = Board.empty();
  for (int row = 0; row < Board.boardSize; row++) {
    for (int col = 0; col < Board.boardSize; col++) {
      final position = Position(row: row, col: col);
      board = board.updateTile(
        position,
        Tile(id: 'r${row}c$col', value: values[row][col], position: position),
      );
    }
  }
  return board;
}

/// Tabuleiro sem combinação em que a troca (0,2)↔(1,2) completa `0,0,0` na
/// linha 0, e a troca (5,2)↔(6,2) completa `3,3,3` na linha 5.
List<List<int>> get _twoMoves => [
  [0, 0, 1, 2, 1, 2, 1, 2],
  [2, 2, 0, 1, 2, 1, 2, 1],
  [1, 2, 1, 2, 1, 2, 1, 2],
  [2, 1, 2, 1, 2, 1, 2, 1],
  [1, 2, 1, 2, 1, 2, 1, 2],
  [3, 3, 2, 1, 2, 1, 2, 1],
  [1, 1, 3, 2, 1, 2, 1, 2],
  [2, 1, 2, 1, 2, 1, 2, 1],
];

void main() {
  group('idleTutorialStep', () {
    TutorialStep? next({
      int level = 1,
      int moves = 0,
      Set<TutorialStep> seen = const {},
      int boosters = 0,
      Set<ObstacleType> covered = const {},
    }) => idleTutorialStep(
      levelNumber: level,
      movesMade: moves,
      pending: (step) => !seen.contains(step),
      boosterStock: boosters,
      coveredOnBoard: covered,
    );

    test('fase 1 sem jogada: a mão da primeira troca', () {
      expect(next(), TutorialStep.firstSwap);
    });

    test('fase 1: o objetivo só depois da fusão', () {
      expect(next(moves: 1), isNull);
      expect(
        next(moves: 1, seen: {TutorialStep.firstSwap, TutorialStep.fusion}),
        TutorialStep.objective,
      );
    });

    test('fase 2: o medalhão de jogadas', () {
      expect(next(level: 2), TutorialStep.movesMedallion);
      expect(next(level: 2, seen: {TutorialStep.movesMedallion}), isNull);
    });

    test('fase 3 aponta o dock mesmo vazio; depois, só com estoque', () {
      expect(next(level: 3), TutorialStep.boosterDock);
      expect(next(level: 4), isNull);
      expect(next(level: 4, boosters: 1), TutorialStep.boosterDock);
      expect(
        next(level: 4, boosters: 1, seen: {TutorialStep.boosterDock}),
        isNull,
      );
    });

    test('cada cobertura estreia na primeira vez que aparece', () {
      expect(
        next(level: 8, covered: {ObstacleType.ice}),
        TutorialStep.obstacleIce,
      );
      expect(
        next(
          level: 9,
          covered: {ObstacleType.ice, ObstacleType.glass},
          seen: {TutorialStep.obstacleIce, TutorialStep.boosterDock},
        ),
        TutorialStep.obstacleGlass,
      );
      expect(
        next(
          level: 10,
          covered: {ObstacleType.stone},
          seen: {TutorialStep.obstacleStone, TutorialStep.boosterDock},
        ),
        isNull,
      );
    });

    test('a estreia de cobertura vem antes do dock', () {
      expect(
        next(level: 8, boosters: 2, covered: {ObstacleType.ice}),
        TutorialStep.obstacleIce,
      );
    });
  });

  group('describeSwapFusion', () {
    final engine = MatchEngine(random: Random(1));
    final board = boardFromValues(_twoMoves);

    test('conta as peças e os valores da fusão de verdade', () {
      final fusion = describeSwapFusion(
        engine,
        board,
        const Position(row: 6, col: 2),
        const Position(row: 5, col: 2),
      )!;
      expect(fusion.count, 3);
      expect(fusion.from, 3);
      expect(fusion.to, 4);
      expect(fusion.anchor, const Position(row: 5, col: 2));
    });

    test('a ponta da combinação é a que tem a peça nova', () {
      // Na ordem inversa o trio passa pela primeira ponta, não pela segunda.
      final fusion = describeSwapFusion(
        engine,
        board,
        const Position(row: 5, col: 2),
        const Position(row: 6, col: 2),
      )!;
      expect(fusion.anchor, const Position(row: 5, col: 2));
    });

    test('troca sem combinação devolve nulo', () {
      const a = Position(row: 7, col: 0);
      const b = Position(row: 7, col: 1);
      expect(engine.swapCreatesMatch(board, a, b), isFalse);
      expect(describeSwapFusion(engine, board, a, b), isNull);
    });
  });

  group('tutorialSwap', () {
    test('orienta o par para a fusão nascer na segunda ponta', () {
      final engine = MatchEngine(random: Random(1));
      final board = boardFromValues(_twoMoves);
      final (a, b) = tutorialSwap(engine, board)!;

      expect(a.isAdjacentTo(b), isTrue);
      expect(describeSwapFusion(engine, board, a, b)!.anchor, b);
    });

    test('evita a troca que venceria a fase na hora', () {
      final engine = MatchEngine(random: Random(1));
      final board = boardFromValues(_twoMoves);

      final (a, b) = tutorialSwap(engine, board, avoidResult: 1)!;
      expect(describeSwapFusion(engine, board, a, b)!.to, isNot(1));
      final (c, d) = tutorialSwap(engine, board, avoidResult: 4)!;
      expect(describeSwapFusion(engine, board, c, d)!.to, isNot(4));
    });

    test('em tabuleiros sorteados, a jogada sugerida é sempre válida', () {
      for (var seed = 0; seed < 60; seed++) {
        final engine = MatchEngine(random: Random(seed));
        final board = engine.generateBoard();
        final swap = tutorialSwap(engine, board, avoidResult: 4);

        expect(swap, isNotNull, reason: 'seed $seed');
        final (a, b) = swap!;
        expect(a.isAdjacentTo(b), isTrue, reason: 'seed $seed');
        expect(
          engine.swapCreatesMatch(board, a, b),
          isTrue,
          reason: 'seed $seed',
        );
        // A mão termina o gesto onde a peça evoluída nasce.
        expect(
          describeSwapFusion(engine, board, a, b)!.anchor,
          b,
          reason: 'seed $seed',
        );
      }
    });

    test('tabuleiro travado: nenhuma sugestão', () {
      final engine = MatchEngine(random: Random(1));
      final stuck = boardFromValues([
        for (var row = 0; row < 8; row++)
          [for (var col = 0; col < 8; col++) (row * 2 + col) % 4],
      ]);
      expect(engine.hasValidMoves(stuck), isFalse);
      expect(tutorialSwap(engine, stuck), isNull);
    });
  });

  test('cada cobertura tem um passo, e "nenhuma" não tem', () {
    expect(obstacleTutorialStep(ObstacleType.ice), TutorialStep.obstacleIce);
    expect(
      obstacleTutorialStep(ObstacleType.glass),
      TutorialStep.obstacleGlass,
    );
    expect(
      obstacleTutorialStep(ObstacleType.stone),
      TutorialStep.obstacleStone,
    );
    expect(obstacleTutorialStep(ObstacleType.none), isNull);
  });
}
