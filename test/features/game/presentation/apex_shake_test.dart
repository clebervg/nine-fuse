import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';

/// Monta um tabuleiro 8x8 a partir de uma matriz de valores.
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

/// A uma troca de fundir três peças de [value], em **L**.
Board _boardWithTrio(int value) {
  final grid = [
    for (int row = 0; row < Board.boardSize; row++)
      [for (int col = 0; col < Board.boardSize; col++) (row + col) % 3],
  ];
  grid[4][2] = value;
  grid[4][4] = value;
  grid[3][3] = value;
  return _boardFromValues(grid);
}

void _playTrio(void Function(Position, Position) swap) =>
    swap(const Position(row: 3, col: 3), const Position(row: 4, col: 3));

void main() {
  GameNotifier notifierAt(Board board) {
    final notifier = GameNotifier(
      random: Random(7),
      storage: InMemoryGameStorage(),
    );
    notifier.startLevel(
      GameLevel(
        number: 95,
        objective: Objective(digit: kMaxDigit, count: 9),
        moveLimit: 20,
      ),
    );
    notifier.debugSetBoard(board);
    return notifier;
  }

  group('contador de explosões na campanha', () {
    test('uma partida nova não tem explosão nenhuma', () {
      expect(notifierAt(_boardWithTrio(3)).state.explosions, 0);
    });

    // O Bloco 9 (o 9 criado por uma combinação comum de 3-4 peças) deixou de
    // contar como evento de clímax: ele só limpa bloqueador ao redor, sem o
    // peso visual que justificava o tranco. `explosions` fica reservado para
    // o próximo evento de clímax — a ativação do Super 9 —, que ainda não
    // liga este sinal nesta task (é polimento de apresentação, fora do
    // escopo desta integração; ver nota no game_notifier.dart).
    test('criar o dígito máximo (Bloco 9) não conta mais explosão', () {
      final notifier = notifierAt(_boardWithTrio(kMaxDigit - 1));
      _playTrio(notifier.swapTiles);

      expect(notifier.state.explosions, 0);
    });

    test('uma jogada comum não conta explosão', () {
      final notifier = notifierAt(_boardWithTrio(5));
      _playTrio(notifier.swapTiles);

      expect(notifier.state.explosions, 0);
    });
  });

  group('sinal de tranco do tabuleiro', () {
    // O `StrikeShake` só sacode quando o serial **cresce**. Golpe de martelo e
    // ativação do Super 9 são os dois motivos do tranco hoje; o Bloco 9
    // comum não é mais um deles (ver comentário acima).
    test('criar o dígito máximo (Bloco 9) não mexe mais no sinal', () {
      final notifier = notifierAt(_boardWithTrio(kMaxDigit - 1));
      final before = notifier.state.shakeSerial;

      _playTrio(notifier.swapTiles);

      expect(notifier.state.shakeSerial, before);
    });

    test('uma jogada comum não mexe no sinal', () {
      final notifier = notifierAt(_boardWithTrio(5));
      final before = notifier.state.shakeSerial;

      _playTrio(notifier.swapTiles);

      expect(notifier.state.shakeSerial, before);
    });
  });
}
