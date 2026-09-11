import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/juice_timings.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/nova_event.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';

/// A Nova (3+ noves já existentes se alinhando) sobe o mesmo sinal de tranco
/// de tela que o Bloco 9/Supernova já usam, com um hitstop antes do pico —
/// mesmo desenho de `apex_shake_test.dart`, mas exercitando a encenação
/// quadro a quadro em vez do atalho `instantResolution`.
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

  /// A uma troca de alinhar três `9`s em L — o mesmo desenho de
  /// `_boardWithTrio` em `apex_shake_test.dart`, só que com o dígito que já
  /// dispara a Nova em vez do Bloco 9.
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

  late GameNotifier notifier;

  setUp(() {
    JuiceTimings.instantResolution = false;
    // Sem binding de plataforma neste teste puro (`test`, não `testWidgets`):
    // o haptic de verdade estouraria por falta de `TestWidgetsFlutterBinding`.
    GameNotifier.explosionFeedback = () {};
    notifier = GameNotifier(random: Random(7), delay: instant, storage: InMemoryGameStorage());
    notifier.startLevel(
      GameLevel(
        number: 96,
        objective: Objective(digit: kMaxDigit, count: 9),
        moveLimit: 20,
      ),
    );
    notifier.debugSetBoard(boardWithNineTrio());
  });

  tearDown(() {
    JuiceTimings.instantResolution = true;
    GameNotifier.explosionFeedback = HapticFeedback.heavyImpact;
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

  test('o hitstop da Nova é aguardado antes do resto da encenação', () async {
    final waited = <Duration>[];
    notifier = GameNotifier(
      random: Random(7),
      delay: (d) {
        waited.add(d);
        return Future<void>.value();
      },
      storage: InMemoryGameStorage(),
    );
    notifier.startLevel(
      GameLevel(
        number: 96,
        objective: Objective(digit: kMaxDigit, count: 9),
        moveLimit: 20,
      ),
    );
    notifier.debugSetBoard(boardWithNineTrio());

    await playTrio();

    // O hitstop da Nova é uma espera própria, distinta da espera de fusão e
    // de assentamento que qualquer cascata já paga — sem ele, a onda de
    // choque e o tranco de tela nasceriam no mesmo quadro da fusão, sem a
    // pausa dramática que o pedido descreve.
    expect(waited, contains(JuiceTimings.novaHitstop));
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
}
