import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/juice_timings.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/nova_event.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';
import 'package:nine_fuse/features/game/presentation/screens/game_screen.dart';
import 'package:nine_fuse/features/game/presentation/widgets/level_start_dialog.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import 'package:nine_fuse/features/game/providers/wallet.dart';
import '../../../support/localized.dart';

/// A ponta que os testes do notifier (`nova_shake_test.dart`) não cobrem: a
/// tela observando `novaCoinsGranted` crescer e creditando a diferença na
/// carteira de verdade — o `GameNotifier` não tem `ref` para fazer isso
/// sozinho.
void main() {
  const target = Position(row: 3, col: 3);
  const neighbour = Position(row: 4, col: 3);

  Board boardWithNineTrio() {
    var board = Board.empty();
    for (int row = 0; row < Board.boardSize; row++) {
      for (int col = 0; col < Board.boardSize; col++) {
        final position = Position(row: row, col: col);
        board = board.updateTile(
          position,
          Tile(
            id: 'r${row}c$col',
            value: (row + col) % 3,
            position: position,
          ),
        );
      }
    }
    for (final pos in [
      const Position(row: 4, col: 2),
      const Position(row: 4, col: 4),
      target,
    ]) {
      board = board.updateTile(
        pos,
        board.getTileAt(pos)!.copyWith(value: kMaxDigit),
      );
    }
    return board;
  }

  late void Function() realFeedback;

  setUp(() {
    JuiceTimings.instantResolution = false;
    realFeedback = GameNotifier.explosionFeedback;
    GameNotifier.explosionFeedback = () {};
  });

  tearDown(() {
    JuiceTimings.instantResolution = true;
    GameNotifier.explosionFeedback = realFeedback;
  });

  testWidgets('a Nova credita a moeda na carteira de verdade, via a tela', (
    tester,
  ) async {
    final storage = InMemoryGameStorage();
    final wallet = WalletNotifier(storage: storage);
    await wallet.refresh();

    final notifier = GameNotifier(
      random: Random(42),
      // Espera de mentira: a jogada avança quadro a quadro sem gastar tempo
      // real de teste.
      delay: (_) => Future<void>.value(),
      storage: storage,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameProvider.overrideWith((ref) => notifier),
          walletProvider.overrideWith((ref) => wallet),
        ],
        child: localizedApp(
          home: const GameScreen(
            level: GameLevel(
              number: 97,
              objective: Objective(digit: kMaxDigit, count: 9),
              moveLimit: 20,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (find.byKey(startLevelKey).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(startLevelKey));
      await tester.pumpAndSettle();
    }

    notifier.debugSetBoard(boardWithNineTrio());
    await tester.pump();

    notifier.swapTiles(target, neighbour);

    // Cede a fila de microtarefas repetidamente até a encenação (hitstop +
    // fusão + assentamento) terminar.
    for (int i = 0; i < 300; i++) {
      await tester.pump();
    }

    expect(wallet.state.coins, kNovaCoinsTier1);
    expect(storage.coins, kNovaCoinsTier1, reason: 'sobrevive à sessão');
  });
}
