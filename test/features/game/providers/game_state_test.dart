import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_state.dart';

/// Base sem nenhuma combinação: faixas diagonais de período 3 nunca produzem
/// três valores iguais seguidos em linha ou coluna.
List<List<int>> _baseGrid() => [
  for (int row = 0; row < Board.boardSize; row++)
    [for (int col = 0; col < Board.boardSize; col++) (row + col) % 3],
];

Board _boardFromValues(List<List<int>> values) {
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

/// Um tabuleiro em que a troca de [_swapFrom] com [_swapTo] forma a trinca
/// horizontal da linha 3, colunas 1 a 3.
///
/// As coberturas pedidas em [covers] são postas à mão, e não pelo sorteio do
/// motor: o teste precisa saber **exatamente** quais células encostam na fusão.
Board _boardWithCovers(Map<Position, ObstacleType> covers) {
  final grid = _baseGrid();
  grid[3][1] = 5;
  grid[3][3] = 5;
  grid[2][2] = 5;

  var board = _boardFromValues(grid);
  for (final entry in covers.entries) {
    board = board.updateTile(
      entry.key,
      board.getTileAt(entry.key)!.withObstacle(entry.value),
    );
  }
  return board;
}

const _swapFrom = Position(row: 2, col: 2);
const _swapTo = Position(row: 3, col: 2);

void main() {
  late GameNotifier notifier;

  setUp(() => notifier = GameNotifier(random: Random(42)));

  /// Prepara a fase [level] com o tabuleiro montado à mão e faz a única jogada.
  void playTheMove(GameLevel level, Map<Position, ObstacleType> covers) {
    notifier.startLevel(level);
    notifier.debugSetBoard(_boardWithCovers(covers));
    notifier.swapTiles(_swapFrom, _swapTo);
  }

  group('Objective', () {
    test('o construtor padrão continua sendo o objetivo de dígito', () {
      const objective = Objective(digit: 5, count: 2);

      expect(objective.type, ObjectiveType.reachDigit);
      expect(objective.digit, 5);
      expect(objective.count, 2);
      expect(objective.obstacle, ObstacleType.none);
    });

    test('clearObstacles guarda o tipo e a quantidade, sem dígito', () {
      const objective = Objective.clearObstacles(
        obstacle: ObstacleType.stone,
        count: 5,
      );

      expect(objective.type, ObjectiveType.clearObstacles);
      expect(objective.obstacle, ObstacleType.stone);
      expect(objective.count, 5);
      expect(objective.digit, isNull);
    });

    test('clearAllObstacles não declara quantidade: quem sabe é o tabuleiro', () {
      const objective = Objective.clearAllObstacles(ObstacleType.ice);

      expect(objective.type, ObjectiveType.clearAllObstacles);
      expect(objective.obstacle, ObstacleType.ice);
      expect(objective.digit, isNull);
    });
  });

  group('objectiveTarget', () {
    test('no objetivo de dígito é a quantidade declarada pela fase', () {
      notifier.startLevel(
        const GameLevel(
          number: 90,
          objective: Objective(digit: 4, count: 3),
          moveLimit: 50,
        ),
      );

      expect(notifier.state.objectiveTarget, 3);
    });

    test('no clearAllObstacles é o que o tabuleiro realmente trouxe', () {
      notifier.startLevel(
        const GameLevel(
          number: 91,
          objective: Objective.clearAllObstacles(ObstacleType.ice),
          moveLimit: 50,
          obstacles: ObstacleLayout(ice: 3, stone: 1),
        ),
      );

      final ice = notifier.state.board
          .getAllTiles()
          .where((t) => t.obstacle == ObstacleType.ice)
          .length;

      // A pedra não entra na conta: o objetivo é do gelo.
      expect(notifier.state.objectiveTarget, ice);
      expect(notifier.state.objectiveTarget, greaterThan(0));
    });
  });

  group('vitória por limpeza de obstáculos', () {
    test('quebrar a cobertura pedida vence a fase', () {
      playTheMove(
        const GameLevel(
          number: 92,
          objective: Objective.clearObstacles(
            obstacle: ObstacleType.ice,
            count: 1,
          ),
          moveLimit: 50,
        ),
        {const Position(row: 3, col: 0): ObstacleType.ice},
      );

      expect(notifier.state.objectiveProgress, 1);
      expect(notifier.state.status, GameStatus.won);
    });

    test('só conta a cobertura do tipo pedido', () {
      // A pedra encosta na fusão e leva impacto, mas o objetivo é do gelo — e
      // ela nem sequer quebra no primeiro impacto.
      playTheMove(
        const GameLevel(
          number: 93,
          objective: Objective.clearObstacles(
            obstacle: ObstacleType.ice,
            count: 1,
          ),
          moveLimit: 50,
        ),
        {const Position(row: 3, col: 0): ObstacleType.stone},
      );

      expect(notifier.state.objectiveProgress, 0);
      expect(notifier.state.status, GameStatus.playing);
    });

    test('clearAllObstacles espera o último gelo do tabuleiro', () {
      // Um gelo encosta na fusão, o outro fica no canto oposto e sobrevive.
      playTheMove(
        const GameLevel(
          number: 94,
          objective: Objective.clearAllObstacles(ObstacleType.ice),
          moveLimit: 50,
        ),
        {
          const Position(row: 3, col: 0): ObstacleType.ice,
          const Position(row: 7, col: 7): ObstacleType.ice,
        },
      );

      expect(notifier.state.objectiveProgress, 1);
      expect(notifier.state.objectiveTarget, 2);
      expect(notifier.state.status, GameStatus.playing);
    });

    test('clearAllObstacles vence quando o último cede', () {
      // Os dois gelos encostam na trinca da linha 3, um de cada lado.
      playTheMove(
        const GameLevel(
          number: 95,
          objective: Objective.clearAllObstacles(ObstacleType.ice),
          moveLimit: 50,
        ),
        {
          const Position(row: 3, col: 0): ObstacleType.ice,
          const Position(row: 3, col: 4): ObstacleType.ice,
        },
      );

      expect(notifier.state.objectiveProgress, 2);
      expect(notifier.state.status, GameStatus.won);
    });

    test('limpar a última cobertura na jogada final vence, não perde', () {
      // `moveLimit: 1`: o movimento que quebra o gelo é também o que zera o
      // saldo. A vitória tem de vir antes do fim por limite de movimentos.
      playTheMove(
        const GameLevel(
          number: 96,
          objective: Objective.clearAllObstacles(ObstacleType.ice),
          moveLimit: 1,
        ),
        {const Position(row: 3, col: 0): ObstacleType.ice},
      );

      expect(notifier.state.movesLeft, 0);
      expect(notifier.state.status, GameStatus.won);
      expect(notifier.state.lossReason, isNull);
    });

    test('a fração do objetivo acompanha o alvo do tabuleiro', () {
      playTheMove(
        const GameLevel(
          number: 97,
          objective: Objective.clearObstacles(
            obstacle: ObstacleType.ice,
            count: 2,
          ),
          moveLimit: 50,
        ),
        {const Position(row: 3, col: 0): ObstacleType.ice},
      );

      expect(notifier.state.objectiveFraction, 0.5);
      expect(notifier.state.objectiveMet, isFalse);
    });
  });

  group('objetivo de dígito segue intacto', () {
    test('a cobertura quebrada não conta para um objetivo de dígito', () {
      playTheMove(
        const GameLevel(
          number: 98,
          objective: Objective(digit: 9, count: 9),
          moveLimit: 50,
        ),
        {const Position(row: 3, col: 0): ObstacleType.ice},
      );

      expect(notifier.state.objectiveProgress, 0);
      expect(notifier.state.status, GameStatus.playing);
    });
  });
}
