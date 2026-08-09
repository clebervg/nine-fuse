import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';

void main() {
  group('Position', () {
    test('isAdjacentTo aceita apenas vizinhos ortogonais', () {
      const origin = Position(row: 4, col: 4);

      expect(origin.isAdjacentTo(Position(row: 4, col: 5)), isTrue);
      expect(origin.isAdjacentTo(Position(row: 4, col: 3)), isTrue);
      expect(origin.isAdjacentTo(Position(row: 5, col: 4)), isTrue);
      expect(origin.isAdjacentTo(Position(row: 3, col: 4)), isTrue);

      // Diagonal não é adjacência neste jogo.
      expect(origin.isAdjacentTo(Position(row: 5, col: 5)), isFalse);
      expect(origin.isAdjacentTo(Position(row: 4, col: 6)), isFalse);
      expect(origin.isAdjacentTo(origin), isFalse);
    });

    test('distanceTo usa distância de Manhattan', () {
      expect(Position(row: 0, col: 0).distanceTo(Position(row: 3, col: 4)), 7);
    });

    test('copyWith não altera a instância original', () {
      const original = Position(row: 0, col: 0);
      final moved = original.copyWith(row: 1);

      expect(original.row, 0);
      expect(moved, Position(row: 1, col: 0));
    });

    test('igualdade é por valor', () {
      expect(Position(row: 2, col: 3), Position(row: 2, col: 3));
      expect(
        Position(row: 2, col: 3).hashCode,
        Position(row: 2, col: 3).hashCode,
      );
    });
  });

  group('Tile', () {
    const anywhere = Position(row: 0, col: 0);

    test('evolve incrementa o valor sem mutar o original', () {
      const tile = Tile(id: 'a', value: 3, position: anywhere);
      final evolved = tile.evolve();

      expect(tile.value, 3);
      expect(evolved.value, 4);
    });

    test('evolve não passa de 9', () {
      const tile = Tile(id: 'a', value: 9, position: anywhere);

      expect(tile.evolve().value, 9);
    });

    test('moveTo troca a posição preservando id e valor', () {
      const tile = Tile(id: 'a', value: 5, position: anywhere);
      const target = Position(row: 1, col: 1);

      final moved = tile.moveTo(target);

      expect(tile.position, anywhere);
      expect(moved.position, target);
      expect(moved.id, 'a');
      expect(moved.value, 5);
    });
  });

  group('Board', () {
    test('empty cria 8x8 sem nenhuma peça', () {
      final board = Board.empty();

      expect(board.isEmpty, isTrue);
      expect(board.isFull, isFalse);
      expect(board.tileCount, 0);
      expect(board.getEmptyPositions(), hasLength(64));
    });

    test('updateTile devolve um novo board sem mutar o anterior', () {
      final board = Board.empty();
      const position = Position(row: 0, col: 0);
      const tile = Tile(id: 'a', value: 5, position: position);

      final updated = board.updateTile(position, tile);

      expect(board.getTileAt(position), isNull);
      expect(updated.getTileAt(position), tile);
    });

    test('isValidPosition rejeita coordenadas fora da matriz', () {
      final board = Board.empty();

      expect(board.isValidPosition(Position(row: 0, col: 0)), isTrue);
      expect(board.isValidPosition(Position(row: 7, col: 7)), isTrue);
      expect(board.isValidPosition(Position(row: -1, col: 0)), isFalse);
      expect(board.isValidPosition(Position(row: 8, col: 0)), isFalse);
      expect(board.isValidPosition(Position(row: 0, col: 8)), isFalse);
    });

    test('getTileAt fora da matriz devolve null em vez de estourar', () {
      expect(Board.empty().getTileAt(Position(row: 99, col: 99)), isNull);
    });
  });
}
