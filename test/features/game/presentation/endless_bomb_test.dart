import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';
import 'package:nine_fuse/features/game/presentation/screens/endless_screen.dart';
import 'package:nine_fuse/features/game/presentation/widgets/board_grid_widget.dart';
import 'package:nine_fuse/features/game/presentation/widgets/bomb_offer_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_button.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_targeting_layer.dart';
import 'package:nine_fuse/features/game/providers/bomb_booster.dart';
import 'package:nine_fuse/features/game/providers/endless_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import '../../../support/localized.dart';

/// A Bomba no Modo Recorde: mesma máquina do Martelo (`endless_hammer_test.dart`),
/// área 3x3 em vez de célula única. Este arquivo cobre só o funil de
/// conversão ligado ao Endless — a mira em si já é testada em
/// `bomb_booster_test.dart` (campanha) e o mixin é o mesmo dos dois modos.
void main() {
  late EndlessNotifier notifier;
  late InMemoryGameStorage storage;

  // Centro da área: mesma linha alta do teste de Martelo do Endless, com
  // folga de uma célula em volta para o 3x3 inteiro caber no tabuleiro.
  const target = Position(row: 2, col: 2);

  late void Function() realTargeting;
  late void Function() realRejection;
  late void Function() realStrike;

  setUp(() {
    realTargeting = BombBooster.targetingFeedback;
    realRejection = BombBooster.rejectionFeedback;
    realStrike = BombBooster.strikeFeedback;
    BombBooster.targetingFeedback = () {};
    BombBooster.rejectionFeedback = () {};
    BombBooster.strikeFeedback = () {};
    storage = InMemoryGameStorage();
    notifier = EndlessNotifier(random: Random(7), storage: storage);
  });

  tearDown(() {
    BombBooster.targetingFeedback = realTargeting;
    BombBooster.rejectionFeedback = realRejection;
    BombBooster.strikeFeedback = realStrike;
  });

  /// Tabuleiro estável com um `7` na área 3x3 alvo, fora da janela de
  /// sorteio, para nenhuma reposição fabricar o mesmo valor por acidente.
  Board stableBoard() {
    var board = Board.empty();
    for (int row = 0; row < Board.boardSize; row++) {
      for (int col = 0; col < Board.boardSize; col++) {
        final position = Position(row: row, col: col);
        final inBlastZone =
            (row - target.row).abs() <= 1 && (col - target.col).abs() <= 1;
        board = board.updateTile(
          position,
          Tile(
            id: 'r${row}c$col',
            value: inBlastZone ? 7 : (row + col) % 3,
            position: position,
          ),
        );
      }
    }
    return board;
  }

  Future<void> pumpEndless(
    WidgetTester tester, {
    int bombs = 0,
    Future<bool> Function()? ad,
  }) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          endlessProvider.overrideWith((ref) => notifier),
          if (ad != null) bombAdProvider.overrideWithValue(ad),
        ],
        child: localizedApp(home: const EndlessScreen()),
      ),
    );
    // O tabuleiro nasce depois de uma leitura assíncrona; `pumpAndSettle` não
    // serve porque o indicador de carregamento anima sem parar.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    if (bombs > 0) notifier.grantBomb(count: bombs);
    notifier.debugSetBoard(stableBoard());
    await tester.pump();
  }

  Future<void> tapTarget(WidgetTester tester) async {
    await tester.tap(find.byKey(tileKey(target)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('funil de conversão', () {
    testWidgets('sem estoque, mirar abre o convite com o alvo guardado', (
      tester,
    ) async {
      await pumpEndless(tester, bombs: 0);
      await tester.tap(find.byKey(endlessBombButtonKey));
      await tester.pump();

      await tapTarget(tester);

      expect(find.byKey(bombOfferKey), findsOneWidget);
      expect(notifier.state.pendingBombTarget, target);
      expect(
        notifier.state.board.getAllTiles().where((t) => t.value == 7),
        isNotEmpty,
      );
    });

    testWidgets('assistir ao anúncio explode o alvo já destacado', (
      tester,
    ) async {
      await pumpEndless(tester, bombs: 0, ad: () async => true);
      await tester.tap(find.byKey(endlessBombButtonKey));
      await tester.pump();
      await tapTarget(tester);

      await tester.tap(find.byKey(bombOfferWatchKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        notifier.state.board.getAllTiles().where((t) => t.value == 7),
        isEmpty,
      );
      expect(find.byKey(bombOfferKey), findsNothing);
      expect(notifier.state.moves, 0);
    });

    testWidgets('com o convite aberto, a mira sai de cena', (tester) async {
      await pumpEndless(tester, bombs: 0);
      await tester.tap(find.byKey(endlessBombButtonKey));
      await tester.pump();
      await tapTarget(tester);

      expect(find.byKey(bombOfferKey), findsOneWidget);
      expect(find.byKey(hammerScrimKey), findsNothing);
      expect(find.byKey(hammerAimKey), findsNothing);
      expect(notifier.state.pendingBombTarget, target);
    });
  });
}
