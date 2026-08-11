import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';
import 'package:nine_fuse/features/game/presentation/screens/endless_screen.dart';
import 'package:nine_fuse/features/game/presentation/widgets/board_grid_widget.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_button.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_offer_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_targeting_layer.dart';
import 'package:nine_fuse/features/game/presentation/widgets/juice_overlay.dart';
import 'package:nine_fuse/features/game/providers/endless_notifier.dart';
import 'package:nine_fuse/features/game/providers/endless_state.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import 'package:nine_fuse/features/game/providers/hammer_booster.dart';
import '../../../support/localized.dart';

void main() {
  late EndlessNotifier notifier;
  late InMemoryGameStorage storage;
  late void Function() realTargeting;
  late void Function() realRejection;

  // Linha alta: nesta janela de teste o hit-test só alcança a metade de cima do
  // tabuleiro.
  const target = Position(row: 1, col: 1);

  setUp(() {
    realTargeting = HammerBooster.targetingFeedback;
    realRejection = HammerBooster.rejectionFeedback;
    HammerBooster.targetingFeedback = () {};
    HammerBooster.rejectionFeedback = () {};
    storage = InMemoryGameStorage();
    notifier = EndlessNotifier(random: Random(7), storage: storage);
  });

  tearDown(() {
    HammerBooster.targetingFeedback = realTargeting;
    HammerBooster.rejectionFeedback = realRejection;
  });

  /// Tabuleiro estável com um `7` solitário na mira.
  Board stableBoard({ObstacleType? cover}) {
    var board = Board.empty();
    for (int row = 0; row < Board.boardSize; row++) {
      for (int col = 0; col < Board.boardSize; col++) {
        final position = Position(row: row, col: col);
        board = board.updateTile(
          position,
          Tile(
            id: 'r${row}c$col',
            value: position == target ? 7 : (row + col) % 3,
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

  Future<void> pumpEndless(
    WidgetTester tester, {
    int hammers = 1,
    Future<bool> Function()? ad,
    ObstacleType? cover,
  }) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    storage.hammerCount = hammers;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          endlessProvider.overrideWith((ref) => notifier),
          if (ad != null) hammerAdProvider.overrideWithValue(ad),
        ],
        child: localizedApp(home: const EndlessScreen()),
      ),
    );
    // O tabuleiro nasce depois de uma leitura assíncrona; `pumpAndSettle` não
    // serve porque o indicador de carregamento anima sem parar.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    notifier.debugSetBoard(stableBoard(cover: cover));
    await tester.pump();
  }

  Future<void> tapTarget(WidgetTester tester) async {
    await tester.tap(find.byKey(tileKey(target)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('o botão do martelo aparece no HUD do Modo Recorde', (
    tester,
  ) async {
    await pumpEndless(tester, hammers: 2);

    expect(find.byKey(endlessHammerButtonKey), findsOneWidget);
    expect(notifier.state.hammerCount, 2, reason: 'o estoque é o mesmo');
  });

  testWidgets('mirar e bater oblitera a célula sem contar movimento', (
    tester,
  ) async {
    await pumpEndless(tester, cover: ObstacleType.stone);

    await tester.tap(find.byKey(endlessHammerButtonKey));
    await tester.pump();
    expect(notifier.state.isHammerTargeting, isTrue);

    await tapTarget(tester);

    expect(notifier.state.board.countObstacles(ObstacleType.stone), 0);
    expect(notifier.state.hammerCount, 0);
    expect(notifier.state.moves, 0);
  });

  testWidgets('o botão vira CANCELAR durante a mira', (tester) async {
    await pumpEndless(tester);

    await tester.tap(find.byKey(endlessHammerButtonKey));
    await tester.pump();

    expect(find.text('CANCELAR'), findsOneWidget);
  });

  testWidgets('tocar fora do tabuleiro cancela a mira', (tester) async {
    await pumpEndless(tester);
    await tester.tap(find.byKey(endlessHammerButtonKey));
    await tester.pump();
    expect(find.byKey(hammerScrimKey), findsOneWidget);

    await tester.tapAt(const Offset(100, 1300));
    await tester.pump();

    expect(notifier.state.isHammerTargeting, isFalse);
  });

  testWidgets('o estilhaço sai na cor do dígito destruído', (tester) async {
    await pumpEndless(tester);
    await tester.tap(find.byKey(endlessHammerButtonKey));
    await tester.pump();

    await tapTarget(tester);

    final effect = tester.widget<ShatterEffect>(find.byType(ShatterEffect));
    expect(effect.color, AppColors.getColorByDigit(7));
  });

  testWidgets('sem estoque, mirar abre o convite de aquisição', (tester) async {
    await pumpEndless(tester, hammers: 0, ad: () async => true);
    await tester.tap(find.byKey(endlessHammerButtonKey));
    await tester.pump();

    await tapTarget(tester);
    expect(find.byKey(hammerOfferKey), findsOneWidget);

    await tester.tap(find.byKey(hammerOfferWatchKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      notifier.state.board.getAllTiles().where((t) => t.value == 7),
      isEmpty,
    );
    expect(find.byKey(hammerOfferKey), findsNothing);
  });

  testWidgets('a corrida encerrada não oferece o martelo', (tester) async {
    await pumpEndless(tester);
    // Trava a corrida à mão: um tabuleiro sem nenhuma troca possível.
    notifier.debugSetBoard(stableBoard());
    while (notifier.state.status == EndlessStatus.playing) {
      final engine = notifier.engine!;
      final board = notifier.state.board;
      (Position, Position)? pair;
      for (final (a, b) in engine.candidateSwaps(board)) {
        if (engine.swapCreatesMatch(board, a, b)) {
          pair = (a, b);
          break;
        }
      }
      if (pair == null) break;
      notifier.swapTiles(pair.$1, pair.$2);
    }
    await tester.pump();
    if (!notifier.state.isOver) return;

    expect(find.byKey(endlessHammerButtonKey), findsNothing);
  });
}
