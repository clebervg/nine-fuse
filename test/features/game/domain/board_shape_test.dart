import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/board_shape.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';

Position p(int row, int col) => Position(row: row, col: col);

/// Tabuleiro com [voids] fora do formato e o resto preenchido pela base
/// diagonal sem combinação (`(row + col) % 3`), com [overrides] por cima.
Board shapedBoard(
  Set<Position> voids, {
  Map<Position, int> overrides = const {},
}) {
  var board = Board.empty(voids: voids);
  for (int row = 0; row < Board.boardSize; row++) {
    for (int col = 0; col < Board.boardSize; col++) {
      final position = p(row, col);
      if (voids.contains(position)) continue;
      board = board.updateTile(
        position,
        Tile(
          id: 'r${row}c$col',
          value: overrides[position] ?? (row + col) % 3,
          position: position,
        ),
      );
    }
  }
  return board;
}

void main() {
  group('BoardShape', () {
    test('todo formato é simétrico na horizontal e na vertical', () {
      for (final shape in BoardShape.values) {
        for (final cell in shape.voids) {
          expect(
            shape.voids,
            contains(p(cell.row, 7 - cell.col)),
            reason: '$shape',
          );
          expect(
            shape.voids,
            contains(p(7 - cell.row, cell.col)),
            reason: '$shape',
          );
        }
      }
    });

    test('nenhum formato apaga uma coluna inteira nem passa de 40% de vão', () {
      for (final shape in BoardShape.values) {
        for (int col = 0; col < Board.boardSize; col++) {
          final voidRows = shape.voids.where((c) => c.col == col).length;
          expect(
            voidRows,
            lessThan(Board.boardSize),
            reason: '$shape col $col',
          );
        }
        expect(shape.playableCount, greaterThanOrEqualTo(38), reason: '$shape');
      }
    });

    test('full não tem vão', () {
      expect(BoardShape.full.voids, isEmpty);
      expect(BoardShape.full.isShaped, isFalse);
    });
  });

  group('Board com formato', () {
    test('casa fora do formato não aceita peça e não conta como vazia', () {
      final voids = {p(0, 0)};
      final board = Board.empty(
        voids: voids,
      ).updateTile(p(0, 0), Tile(id: 'x', value: 1, position: p(0, 0)));

      expect(board.getTileAt(p(0, 0)), isNull);
      expect(board.isValidPosition(p(0, 0)), isFalse);
      expect(board.getEmptyPositions(), isNot(contains(p(0, 0))));
      expect(board.getEmptyPositions(), hasLength(63));
    });

    test('isFull compara com as casas do formato, não com 64', () {
      final board = shapedBoard(BoardShape.ring.voids);
      expect(board.tileCount, 60);
      expect(board.isFull, isTrue);
    });

    test('dois tabuleiros iguais em formatos diferentes não são iguais', () {
      expect(Board.empty(), isNot(Board.empty(voids: {p(0, 0)})));
    });
  });

  group('MatchEngine com formato', () {
    late MatchEngine engine;
    setUp(() => engine = MatchEngine(random: Random(3)));

    test('generateBoard respeita o formato, enche o resto e tem jogada', () {
      for (final shape in BoardShape.values) {
        for (int seed = 0; seed < 5; seed++) {
          final e = MatchEngine(random: Random(seed));
          final board = e.generateBoard(
            voids: shape.voids,
            obstacles: const ObstacleLayout(ice: 2, glass: 2, stone: 2),
          );
          for (final cell in shape.voids) {
            expect(board.getTileAt(cell), isNull, reason: '$shape seed $seed');
          }
          expect(board.isFull, isTrue, reason: '$shape seed $seed');
          expect(e.detectMatches(board), isEmpty, reason: '$shape seed $seed');
          expect(e.hasValidMoves(board), isTrue, reason: '$shape seed $seed');
        }
      }
    });

    test('a casa fora do formato quebra a sequência como uma parede', () {
      // Linha 3: 5 5 # 5 — com o vão no meio não há trio.
      final board = shapedBoard(
        {p(3, 2), p(3, 5)},
        overrides: {p(3, 0): 5, p(3, 1): 5, p(3, 3): 5},
      );
      expect(engine.detectMatches(board), isEmpty);
    });

    test('a gravidade passa por cima do vão', () {
      // Coluna 2 com vão nas linhas 3 e 4: esvaziar a linha 5 faz a peça da
      // linha 2 cair para a 5, pulando o vão.
      final voids = {p(3, 2), p(4, 2)};
      final full = shapedBoard(voids);
      final above = full.getTileAt(p(2, 2))!;
      final holed = full.updateTile(p(5, 2), null);

      final settled = engine.applyGravity(holed);

      expect(settled.getTileAt(p(5, 2))?.id, above.id);
      expect(settled.getTileAt(p(3, 2)), isNull);
      expect(settled.getTileAt(p(4, 2)), isNull);
      // O buraco subiu para o topo da coluna, não para o vão.
      expect(settled.getTileAt(p(0, 2)), isNull);
      expect(engine.refill(settled).isFull, isTrue);
    });

    test('troca com casa fora do formato é impossível', () {
      final board = shapedBoard({p(0, 0)});
      expect(engine.tryMove(board, p(0, 1), p(0, 0)), isA<MoveImpossible>());
    });

    test('a dica nunca envolve casa fora do formato', () {
      final voids = BoardShape.cross.voids;
      final board = engine.generateBoard(voids: voids);
      for (final (a, b) in engine.candidateSwaps(board)) {
        expect(voids.contains(a) || voids.contains(b), isFalse);
      }
    });

    test('a resolução nunca põe peça no vão', () {
      final voids = BoardShape.pillars.voids;
      for (int seed = 0; seed < 10; seed++) {
        final e = MatchEngine(random: Random(seed));
        var board = e.generateBoard(voids: voids);
        for (int move = 0; move < 15; move++) {
          final hint = e.findHint(board);
          if (hint == null) break;
          final result = e.tryMove(board, hint.$1, hint.$2);
          if (result is! MoveResolved) break;
          board = result.resolution.board;
          for (final cell in voids) {
            expect(board.getTileAt(cell), isNull);
          }
          expect(board.isFull, isTrue);
        }
      }
    });

    test('bomba e martelo no vão são recusados ou ignoram o vão', () {
      final voids = {p(0, 0)};
      final board = shapedBoard(voids);
      expect(engine.smash(board, p(0, 0)), isNull);
      final blast = engine.smashArea(board, p(0, 1));
      expect(blast, isNotNull);
      expect(blast!.board.getTileAt(p(0, 0)), isNull);
      expect(blast.board.isFull, isTrue);
    });
  });
}
