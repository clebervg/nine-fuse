import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';
import 'package:nine_fuse/features/game/presentation/screens/endless_screen.dart';
import 'package:nine_fuse/features/game/presentation/widgets/board_grid_widget.dart';
import 'package:nine_fuse/features/game/presentation/widgets/brush_offer_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_button.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_targeting_layer.dart';
import 'package:nine_fuse/features/game/providers/brush_booster.dart';
import 'package:nine_fuse/features/game/providers/endless_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import '../../../support/localized.dart';

/// O Pincel no Modo Recorde: mesma máquina do Martelo/Bomba (célula única).
/// Este arquivo cobre só o funil de conversão ligado ao Endless — a mira em
/// si já é testada em `brush_booster_test.dart` (campanha) e o mixin é o
/// mesmo dos dois modos.
void main() {
  late EndlessNotifier notifier;
  late InMemoryGameStorage storage;

  const target = Position(row: 1, col: 1);

  late void Function() realTargeting;
  late void Function() realRejection;
  late void Function() realPaint;

  setUp(() {
    realTargeting = BrushBooster.targetingFeedback;
    realRejection = BrushBooster.rejectionFeedback;
    realPaint = BrushBooster.paintFeedback;
    BrushBooster.targetingFeedback = () {};
    BrushBooster.rejectionFeedback = () {};
    BrushBooster.paintFeedback = () {};
    storage = InMemoryGameStorage();
    notifier = EndlessNotifier(random: Random(7), storage: storage);
  });

  tearDown(() {
    BrushBooster.targetingFeedback = realTargeting;
    BrushBooster.rejectionFeedback = realRejection;
    BrushBooster.paintFeedback = realPaint;
  });

  /// Tabuleiro estável com um `3` solitário na mira, fora da janela de
  /// sorteio, para nenhuma reposição fabricar o mesmo valor por acidente.
  Board stableBoard() {
    var board = Board.empty();
    for (int row = 0; row < Board.boardSize; row++) {
      for (int col = 0; col < Board.boardSize; col++) {
        final position = Position(row: row, col: col);
        board = board.updateTile(
          position,
          Tile(
            id: 'r${row}c$col',
            value: position == target ? 3 : (row + col) % 3,
            position: position,
          ),
        );
      }
    }
    return board;
  }

  Future<void> pumpEndless(
    WidgetTester tester, {
    int brushes = 0,
    Future<bool> Function()? ad,
  }) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          endlessProvider.overrideWith((ref) => notifier),
          if (ad != null) brushAdProvider.overrideWithValue(ad),
        ],
        child: localizedApp(home: const EndlessScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    if (brushes > 0) notifier.grantBrush(count: brushes);
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
      await pumpEndless(tester, brushes: 0);
      await tester.tap(find.byKey(endlessBrushButtonKey));
      await tester.pump();

      await tapTarget(tester);

      expect(find.byKey(brushOfferKey), findsOneWidget);
      expect(notifier.state.pendingBrushTarget, target);
      expect(notifier.state.board.getTileAt(target)?.value, 3);
    });

    testWidgets('assistir ao anúncio pinta o alvo já destacado', (
      tester,
    ) async {
      await pumpEndless(tester, brushes: 0, ad: () async => true);
      await tester.tap(find.byKey(endlessBrushButtonKey));
      await tester.pump();
      await tapTarget(tester);

      await tester.tap(find.byKey(brushOfferWatchKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(notifier.state.board.getTileAt(target)?.value, 4);
      expect(find.byKey(brushOfferKey), findsNothing);
      expect(notifier.state.moves, 0);
    });

    testWidgets('com o convite aberto, a mira sai de cena', (tester) async {
      await pumpEndless(tester, brushes: 0);
      await tester.tap(find.byKey(endlessBrushButtonKey));
      await tester.pump();
      await tapTarget(tester);

      expect(find.byKey(brushOfferKey), findsOneWidget);
      expect(find.byKey(hammerScrimKey), findsNothing);
      expect(find.byKey(hammerAimKey), findsNothing);
      expect(notifier.state.pendingBrushTarget, target);
    });
  });
}
