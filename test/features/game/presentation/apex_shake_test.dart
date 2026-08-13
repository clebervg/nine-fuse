import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/presentation/screens/game_screen.dart';
import 'package:nine_fuse/features/game/presentation/widgets/level_start_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/strike_shake.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import '../../../support/localized.dart';

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

    test('criar o dígito máximo conta uma explosão', () {
      final notifier = notifierAt(_boardWithTrio(kMaxDigit - 1));
      _playTrio(notifier.swapTiles);

      expect(notifier.state.explosions, 1);
    });

    test('uma jogada comum não conta explosão', () {
      final notifier = notifierAt(_boardWithTrio(5));
      _playTrio(notifier.swapTiles);

      expect(notifier.state.explosions, 0);
    });

    test('recomeçar a fase zera o contador', () {
      final notifier = notifierAt(_boardWithTrio(kMaxDigit - 1));
      _playTrio(notifier.swapTiles);
      expect(notifier.state.explosions, 1);

      notifier.restartLevel();

      expect(notifier.state.explosions, 0);
    });
  });

  group('sinal de tranco do tabuleiro', () {
    // O `StrikeShake` só sacode quando o serial **cresce**. Golpe de martelo e
    // explosão do dígito máximo são dois motivos para o mesmo tranco, então o
    // sinal precisa somar os dois — e nunca regredir dentro da partida, senão o
    // segundo motivo cancelaria o primeiro em vez de sacudir.
    test('a explosão faz o sinal de tranco crescer', () {
      final notifier = notifierAt(_boardWithTrio(kMaxDigit - 1));
      final before = notifier.state.shakeSerial;

      _playTrio(notifier.swapTiles);

      expect(notifier.state.shakeSerial, greaterThan(before));
    });

    test('uma jogada comum não mexe no sinal', () {
      final notifier = notifierAt(_boardWithTrio(5));
      final before = notifier.state.shakeSerial;

      _playTrio(notifier.swapTiles);

      expect(notifier.state.shakeSerial, before);
    });
  });

  group('a tela sacode o tabuleiro no clímax', () {
    testWidgets('o tranco da campanha escuta o sinal de explosão', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final notifier = GameNotifier(
        random: Random(7),
        storage: InMemoryGameStorage(),
      );
      const level = GameLevel(
        number: 95,
        objective: Objective(digit: kMaxDigit, count: 9),
        moveLimit: 500,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [gameProvider.overrideWith((ref) => notifier)],
          child: localizedApp(home: const GameScreen(level: level)),
        ),
      );
      await tester.pumpAndSettle();
      if (find.byKey(startLevelKey).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(startLevelKey));
        await tester.pumpAndSettle();
      }

      notifier.debugSetBoard(_boardWithTrio(kMaxDigit - 1));
      _playTrio(notifier.swapTiles);
      await tester.pump();

      final shake = tester.widget<StrikeShake>(find.byType(StrikeShake));
      expect(
        shake.serial,
        notifier.state.shakeSerial,
        reason: 'a tela ainda escuta só o martelo, e a explosão não sacode',
      );
      expect(shake.serial, greaterThan(0));

      await tester.pumpAndSettle();
    });
  });
}
