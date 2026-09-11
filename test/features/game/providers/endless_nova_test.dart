import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/juice_timings.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/nova_event.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';
import 'package:nine_fuse/features/game/providers/endless_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';

/// A Nova no Endless: mesmo desenho de `nova_shake_test.dart` (campanha), mas
/// exercitando o `EndlessNotifier` — o lado que ganhou o hitstop/tranco
/// dedicado/recompensa junto com a campanha, e nunca tinha teste próprio.
void main() {
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

  /// A uma troca de alinhar três `9`s em L — mesmo tabuleiro de
  /// `nova_shake_test.dart`.
  Board boardWithNineTrio() {
    final grid = [
      for (int row = 0; row < Board.boardSize; row++)
        [for (int col = 0; col < Board.boardSize; col++) (row + col) % 3],
    ];
    grid[4][2] = kMaxDigit;
    grid[4][4] = kMaxDigit;
    grid[3][3] = kMaxDigit;
    return boardFromValues(grid);
  }

  Future<void> instant(Duration _) => Future<void>.value();

  late EndlessNotifier notifier;

  setUp(() async {
    JuiceTimings.instantResolution = false;
    // Sem binding de plataforma neste teste puro (`test`, não `testWidgets`):
    // o haptic de verdade estouraria por falta de `TestWidgetsFlutterBinding`.
    EndlessNotifier.explosionFeedback = () {};
    notifier = EndlessNotifier(
      random: Random(7),
      delay: instant,
      storage: InMemoryGameStorage(),
    );
    await notifier.start();
    notifier.debugSetBoard(boardWithNineTrio());
  });

  tearDown(() {
    JuiceTimings.instantResolution = true;
    EndlessNotifier.explosionFeedback = HapticFeedback.heavyImpact;
  });

  Future<void> playTrio() async {
    notifier.swapTiles(
      const Position(row: 3, col: 3),
      const Position(row: 4, col: 3),
    );
    for (int i = 0; i < 200; i++) {
      await Future<void>.value();
    }
  }

  test('a Nova sobe o contador dedicado de tranco (novaStrikes)', () async {
    final before = notifier.state.novaStrikes;

    await playTrio();

    expect(notifier.state.novaStrikes, greaterThan(before));
  });

  test('a Nova credita moedas (tier 1: 3 peças = kNovaCoinsTier1)', () async {
    final before = notifier.state.novaCoinsGranted;

    await playTrio();

    expect(notifier.state.novaCoinsGranted, before + kNovaCoinsTier1);
  });

  test('a Nova credita +1 booster, Bomba ou Pincel — nunca o Martelo', () async {
    final bombBefore = notifier.state.bombCount;
    final brushBefore = notifier.state.brushCount;
    final hammerBefore = notifier.state.hammerCount;

    await playTrio();

    final bombGained = notifier.state.bombCount - bombBefore;
    final brushGained = notifier.state.brushCount - brushBefore;

    expect(
      bombGained + brushGained,
      1,
      reason: 'exatamente um dos dois boosters ganha +1',
    );
    expect(bombGained, anyOf(0, 1));
    expect(brushGained, anyOf(0, 1));
    expect(notifier.state.hammerCount, hammerBefore, reason: 'nunca o martelo');
  });

  test('o hitstop da Nova é aguardado antes do resto da encenação', () async {
    final waited = <Duration>[];
    notifier = EndlessNotifier(
      random: Random(7),
      delay: (d) {
        waited.add(d);
        return Future<void>.value();
      },
      storage: InMemoryGameStorage(),
    );
    await notifier.start();
    notifier.debugSetBoard(boardWithNineTrio());

    await playTrio();

    // O hitstop da Nova é uma espera própria, distinta da espera de fusão e
    // de assentamento que qualquer cascata já paga — sem ele, a onda de
    // choque e o tranco de tela nasceriam no mesmo quadro da fusão, sem a
    // pausa dramática que o desenho da Nova pede.
    expect(waited, contains(JuiceTimings.novaHitstop));
  });
}
