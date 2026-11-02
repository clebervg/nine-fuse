import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/notifications/notification_port.dart';
import 'package:nine_fuse/core/widgets/coins_header_badge.dart';
import 'package:nine_fuse/features/game/domain/level_record.dart';
import 'package:nine_fuse/features/game/presentation/screens/game_screen.dart';
import 'package:nine_fuse/features/game/presentation/screens/home_screen.dart';
import 'package:nine_fuse/features/game/presentation/screens/level_select_screen.dart';
import 'package:nine_fuse/features/game/presentation/screens/settings_screen.dart';
import 'package:nine_fuse/features/game/presentation/screens/shop_screen.dart';
import 'package:nine_fuse/features/game/presentation/widgets/daily_spin_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/level_start_dialog.dart';
import 'package:nine_fuse/features/game/providers/campaign_records.dart';
import 'package:nine_fuse/features/game/providers/endless_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import 'package:nine_fuse/features/game/providers/wallet.dart';

import '../../../support/localized.dart';

/// Porta de notificações que conta as aberturas do app, sem plugin real.
class _FakeNotificationPort implements NotificationPort {
  int inactivityScheduled = 0;

  @override
  Future<void> scheduleDailySpinReminder(DateTime at) async {}

  @override
  Future<void> scheduleInactivityReminder(DateTime at) async =>
      inactivityScheduled++;

  @override
  Future<void> cancelAll() async {}
}

void main() {
  late InMemoryGameStorage storage;
  late _FakeNotificationPort notifications;

  Future<void> pumpHome(
    WidgetTester tester, {
    bool spinEligible = false,
    int progress = 0,
    Map<int, LevelRecord>? records,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    storage = InMemoryGameStorage(
      campaignProgress: progress,
      levelRecords: records,
      // Já girou "agora": só o teste da roleta quer vê-la abrir sozinha.
      lastSpinTimestamp: spinEligible ? null : DateTime.now(),
    );
    notifications = _FakeNotificationPort();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationPortProvider.overrideWithValue(notifications),
          dailySpinStorageProvider.overrideWithValue(storage),
          walletProvider.overrideWith(
            (ref) => WalletNotifier(storage: storage),
          ),
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
        ],
        child: localizedApp(home: const HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('JOGAR abre a fase da vez, por cima do mapa', (tester) async {
    await pumpHome(tester, progress: 2);

    await tester.tap(find.byKey(homePlayKey));
    await tester.pumpAndSettle();

    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.byKey(levelStartKey), findsOneWidget);
    expect(find.text('Fase 3'), findsWidgets);
    // O mapa fica por baixo: é para ele que o "voltar às fases" do fim de
    // partida leva.
    expect(find.byType(LevelSelectScreen, skipOffstage: false), findsOneWidget);
  });

  testWidgets('a engrenagem do topo abre as Configurações', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byKey(homeSettingsKey));
    await tester.pumpAndSettle();

    expect(find.byKey(settingsScreenKey), findsOneWidget);
    // A política de privacidade, que era o botão do canto, mora lá dentro.
    expect(find.byKey(settingsPrivacyPolicyKey), findsOneWidget);
  });

  testWidgets('a pílula mostra capítulo e fase, e abre o mapa sem jogar', (
    tester,
  ) async {
    await pumpHome(tester, progress: 2);

    expect(find.text('CAPÍTULO 1 · FASE 3'), findsOneWidget);

    await tester.tap(find.byKey(homeMapKey));
    await tester.pumpAndSettle();

    expect(find.byType(LevelSelectScreen), findsOneWidget);
    expect(find.byType(GameScreen), findsNothing);
  });

  testWidgets('a pílula de estrelas soma a campanha inteira', (tester) async {
    await pumpHome(
      tester,
      progress: 2,
      records: {
        1: const LevelRecord(stars: 3, bestScore: 100),
        2: const LevelRecord(stars: 2, bestScore: 80),
      },
    );

    expect(
      find.descendant(of: find.byKey(homeStarsKey), matching: find.text('5')),
      findsOneWidget,
    );
  });

  testWidgets('LOJA abre a Loja', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byKey(homeShopKey));
    await tester.pumpAndSettle();

    expect(find.byType(ShopScreen), findsOneWidget);
  });

  testWidgets('o + da pílula de moedas abre a Loja, e não a caixa', (
    tester,
  ) async {
    await pumpHome(tester);

    await tester.tap(find.byKey(coinsHeaderAddKey));
    await tester.pumpAndSettle();

    expect(find.byType(ShopScreen), findsOneWidget);
    expect(find.byKey(coinStoreKey), findsNothing);
  });

  testWidgets(
    'elegível, a roleta abre sozinha e o botão ROLETA ganha o selo vermelho',
    (tester) async {
      await pumpHome(tester, spinEligible: true);

      expect(find.byKey(dailySpinKey), findsOneWidget);
      expect(find.byKey(homeSpinBadgeKey), findsOneWidget);
    },
  );

  testWidgets('sem giro grátis, nada abre sozinho, mas ROLETA abre a roleta', (
    tester,
  ) async {
    await pumpHome(tester);

    expect(find.byKey(dailySpinKey), findsNothing);
    expect(find.byKey(homeSpinBadgeKey), findsNothing);

    await tester.tap(find.byKey(homeSpinKey));
    await tester.pumpAndSettle();

    expect(find.byKey(dailySpinKey), findsOneWidget);
  });

  testWidgets('avisa ao serviço de notificações que o app abriu', (
    tester,
  ) async {
    await pumpHome(tester);

    expect(notifications.inactivityScheduled, 1);
  });
}
