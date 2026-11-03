import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/notifications/notification_port.dart';
import 'package:nine_fuse/features/game/domain/campaign_chapter.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/presentation/screens/level_select_screen.dart';
import 'package:nine_fuse/features/game/presentation/widgets/chapter_chest.dart';
import 'package:nine_fuse/features/game/presentation/widgets/daily_spin_dialog.dart';
import 'package:nine_fuse/features/game/providers/campaign_records.dart';
import 'package:nine_fuse/features/game/providers/endless_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import 'package:nine_fuse/features/game/providers/wallet.dart';
import '../../../support/localized.dart';

class _FakeNotificationPort implements NotificationPort {
  @override
  Future<void> scheduleDailySpinReminder(DateTime at) async {}

  @override
  Future<void> scheduleInactivityReminder(DateTime at) async {}

  @override
  Future<void> cancelAll() async {}
}

/// O baú de fim de capítulo: nó na trilha, três estados e crédito único.
void main() {
  group('chestStateFor', () {
    final chapter1 = chapterOf(1); // fases 1-6

    test('capítulo não concluído é trancado', () {
      expect(
        chestStateFor(chapter1, progress: 5, claimedChests: const {}),
        ChestState.locked,
      );
    });

    test('capítulo concluído e não pago é pronto', () {
      expect(
        chestStateFor(chapter1, progress: 6, claimedChests: const {}),
        ChestState.ready,
      );
    });

    test('capítulo já pago é aberto', () {
      expect(
        chestStateFor(chapter1, progress: 40, claimedChests: const {1}),
        ChestState.opened,
      );
    });

    // A poda de `CampaignRecords` apaga o detalhe das fases antigas; o baú lê
    // o progresso, então um capítulo podado continua contando como concluído.
    test('capítulo antigo conta como concluído pelo progresso', () {
      expect(
        chestStateFor(chapterOf(25), progress: 400, claimedChests: const {}),
        ChestState.ready,
      );
    });

    test('todo capítulo tem baú, inclusive depois do 20', () {
      expect(chapterHasChest(chapterOf(1)), isTrue);
      final last = chapterOf(190);
      expect(last.number, kChapterChestPayableCount);
      expect(chapterHasChest(last), isTrue);
      expect(chapterHasChest(chapterOf(last.lastLevel + 1)), isTrue);
      expect(chapterHasChest(chapterOf(5000)), isTrue);
    });
  });

  group('baú na trilha', () {
    late InMemoryGameStorage storage;

    Future<void> pumpMap(
      WidgetTester tester, {
      required int progress,
      Set<int>? claimed,
    }) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      storage = InMemoryGameStorage(
        campaignProgress: progress,
        claimedChests: claimed,
        lastSpinTimestamp: DateTime.now(),
      );
      final container = ProviderContainer(
        overrides: [
          endlessProvider.overrideWith(
            (ref) => EndlessNotifier(random: Random(1), storage: storage),
          ),
          campaignProgressProvider.overrideWith(
            (ref) => CampaignProgress(storage: storage),
          ),
          campaignRecordsProvider.overrideWith(
            (ref) => CampaignRecords(storage: storage),
          ),
          endlessHighScoreProvider.overrideWith(
            (ref) => EndlessHighScore(storage: storage),
          ),
          walletProvider.overrideWith(
            (ref) => WalletNotifier(storage: storage),
          ),
          notificationPortProvider.overrideWithValue(_FakeNotificationPort()),
          dailySpinStorageProvider.overrideWithValue(storage),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedApp(home: const LevelSelectScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    ChestState stateOf(WidgetTester tester, int chapter) => tester
        .widget<ChapterChestNode>(
          find.byWidgetPredicate(
            (w) => w is ChapterChestNode && w.chapter == chapter,
          ),
        )
        .state;

    Future<void> tapChest(WidgetTester tester, int chapter) async {
      await tester.ensureVisible(find.byKey(chestNodeKey(chapter)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(chestNodeKey(chapter)));
      await tester.pumpAndSettle();
    }

    testWidgets('trancado: mostra a dica e não paga', (tester) async {
      await pumpMap(tester, progress: 3);

      expect(stateOf(tester, 1), ChestState.locked);
      await tapChest(tester, 1);

      expect(find.byKey(chestLockedPopupKey), findsOneWidget);
      expect(find.byKey(chestRewardPopupKey), findsNothing);
      expect(storage.coins, 0);
    });

    testWidgets('pronto: paga uma vez só e vira aberto', (tester) async {
      await pumpMap(tester, progress: 6);

      expect(stateOf(tester, 1), ChestState.ready);
      // O capítulo 2 (fases 7-10) ainda não foi concluído.
      expect(stateOf(tester, 2), ChestState.locked);

      await tapChest(tester, 1);
      expect(find.byKey(chestRewardPopupKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(chestRewardPopupKey),
          matching: find.text('+$kChapterChestReward'),
        ),
        findsWidgets,
      );
      expect(storage.coins, kChapterChestReward);
      expect(storage.claimedChests, contains(1));

      await tester.tap(find.byKey(chestCollectButtonKey));
      await tester.pumpAndSettle();
      expect(find.byKey(chestRewardPopupKey), findsNothing);
      expect(stateOf(tester, 1), ChestState.opened);

      // Segundo toque: nada sobe e nada é pago.
      await tapChest(tester, 1);
      expect(find.byKey(chestRewardPopupKey), findsNothing);
      expect(storage.coins, kChapterChestReward);
    });

    testWidgets('depois do capítulo 20: baú menor na trilha, paga 50', (
      tester,
    ) async {
      // Fase 210 vencida: o capítulo 21 (fases 191-200) está concluído e
      // dentro da janela do mapa.
      await pumpMap(tester, progress: 210);
      const chapter = kChapterChestPayableCount + 1;

      expect(stateOf(tester, chapter), ChestState.ready);
      await tapChest(tester, chapter);
      expect(
        find.descendant(
          of: find.byKey(chestRewardPopupKey),
          matching: find.text('+$kLateChapterChestReward'),
        ),
        findsWidgets,
      );
      expect(storage.coins, kLateChapterChestReward);
      expect(storage.claimedChests, contains(chapter));
    });

    testWidgets('já aberto vem do disco', (tester) async {
      await pumpMap(tester, progress: 10, claimed: {1});

      expect(stateOf(tester, 1), ChestState.opened);
      expect(stateOf(tester, 2), ChestState.ready);
    });
  });
}
