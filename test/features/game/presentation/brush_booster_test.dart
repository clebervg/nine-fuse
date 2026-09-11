import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';
import 'package:nine_fuse/features/game/presentation/screens/game_screen.dart';
import 'package:nine_fuse/features/game/presentation/widgets/board_grid_widget.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_button.dart';
import 'package:nine_fuse/features/game/presentation/widgets/level_start_dialog.dart';
import 'package:nine_fuse/features/game/providers/brush_booster.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import '../../../support/localized.dart';

/// O Pincel: mesma máquina de mira do Martelo/Bomba (célula única), soma 1 ao
/// valor da peça tocada em vez de destruir — sem funil de aquisição.
void main() {
  late GameNotifier notifier;
  late InMemoryGameStorage storage;

  const roomy = GameLevel(
    number: 44,
    objective: Objective(digit: 8, count: 9),
    moveLimit: 500,
  );

  const target = Position(row: 1, col: 1);

  /// Tabuleiro estável com um `3` solitário na mira, fora da janela de
  /// sorteio, para nenhuma reposição fabricar o mesmo valor por acidente.
  Board stableBoard({ObstacleType? cover, int targetValue = 3}) {
    var board = Board.empty();
    for (int row = 0; row < Board.boardSize; row++) {
      for (int col = 0; col < Board.boardSize; col++) {
        final position = Position(row: row, col: col);
        board = board.updateTile(
          position,
          Tile(
            id: 'r${row}c$col',
            value: position == target ? targetValue : (row + col) % 3,
            position: position,
          ),
        );
      }
    }
    if (cover != null) {
      board = board.updateTile(
        target,
        board.getTileAt(target)!.withObstacle(cover),
      );
    }
    return board;
  }

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
    notifier = GameNotifier(random: Random(42), storage: storage);
  });

  tearDown(() {
    BrushBooster.targetingFeedback = realTargeting;
    BrushBooster.rejectionFeedback = realRejection;
    BrushBooster.paintFeedback = realPaint;
  });

  Future<void> pumpGame(
    WidgetTester tester, {
    int brushes = 1,
    ObstacleType? cover,
    int targetValue = 3,
  }) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [gameProvider.overrideWith((ref) => notifier)],
        child: localizedApp(home: const GameScreen(level: roomy)),
      ),
    );
    await tester.pumpAndSettle();
    if (find.byKey(startLevelKey).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(startLevelKey));
      await tester.pumpAndSettle();
    }

    if (brushes > 0) notifier.grantBrush(count: brushes);
    notifier.debugSetBoard(stableBoard(cover: cover, targetValue: targetValue));
    await tester.pumpAndSettle();
  }

  Future<void> tapTarget(WidgetTester tester) async {
    await tester.tap(find.byKey(tileKey(target)));
    await tester.pumpAndSettle();
  }

  group('botão do pincel', () {
    testWidgets('mostra o estoque no HUD', (tester) async {
      await pumpGame(tester, brushes: 3);

      expect(find.byKey(brushButtonKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(brushBadgeKey),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('vira X vermelho ao entrar em mira', (tester) async {
      await pumpGame(tester);

      await tester.tap(find.byKey(brushButtonKey));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(brushButtonKey),
          matching: find.byIcon(Icons.close_rounded),
        ),
        findsOneWidget,
      );
    });

    testWidgets('o próprio botão cancela a mira', (tester) async {
      await pumpGame(tester);

      await tester.tap(find.byKey(brushButtonKey));
      await tester.pumpAndSettle();
      expect(notifier.state.isBrushTargeting, isTrue);

      await tester.tap(find.byKey(brushButtonKey));
      await tester.pumpAndSettle();
      expect(notifier.state.isBrushTargeting, isFalse);
    });

    testWidgets('sem estoque, o toque recusa e não entra em mira', (
      tester,
    ) async {
      await pumpGame(tester, brushes: 0);

      await tester.tap(find.byKey(brushButtonKey));
      await tester.pumpAndSettle();

      expect(notifier.state.isBrushTargeting, isFalse);
    });
  });

  group('mira e pintura', () {
    testWidgets('o toque soma 1 ao valor da peça', (tester) async {
      await pumpGame(tester);
      await tester.tap(find.byKey(brushButtonKey));
      await tester.pumpAndSettle();

      await tapTarget(tester);

      expect(notifier.state.board.getTileAt(target)?.value, 4);
      expect(notifier.state.brushCount, 0);
      expect(notifier.state.moves, 0, reason: 'pintar não gasta movimento');
    });

    testWidgets('em mira, tocar a peça não a seleciona para troca', (
      tester,
    ) async {
      await pumpGame(tester);
      await tester.tap(find.byKey(brushButtonKey));
      await tester.pumpAndSettle();

      await tapTarget(tester);

      expect(notifier.state.selectedTile, isNull);
    });

    testWidgets('sobre cobertura, recusa e não cobra — o Pincel não afeta obstáculo', (
      tester,
    ) async {
      await pumpGame(tester, cover: ObstacleType.ice);
      await tester.tap(find.byKey(brushButtonKey));
      await tester.pumpAndSettle();

      await tapTarget(tester);

      expect(notifier.state.board.getTileAt(target)?.value, 3);
      expect(notifier.state.board.countObstacles(ObstacleType.ice), 1);
      expect(notifier.state.brushCount, 1, reason: 'recusa não cobra');
    });

    testWidgets('sobre o dígito máximo, recusa — não há "+1" a dar', (
      tester,
    ) async {
      await pumpGame(tester, targetValue: kMaxDigit);
      await tester.tap(find.byKey(brushButtonKey));
      await tester.pumpAndSettle();

      await tapTarget(tester);

      expect(notifier.state.board.getTileAt(target)?.value, kMaxDigit);
      expect(notifier.state.brushCount, 1, reason: 'recusa não cobra');
    });

    testWidgets('fora da mira, tocar a peça volta a selecionar', (
      tester,
    ) async {
      await pumpGame(tester);

      await tapTarget(tester);

      expect(notifier.state.selectedTile?.position, target);
      expect(notifier.state.brushCount, 1, reason: 'nada foi cobrado');
    });
  });

  group('persistência', () {
    testWidgets('o saldo gasto é gravado', (tester) async {
      await pumpGame(tester, brushes: 2);
      await tester.tap(find.byKey(brushButtonKey));
      await tester.pumpAndSettle();

      await tapTarget(tester);
      await tester.pumpAndSettle();

      expect(storage.brushCount, 1);
    });
  });
}
