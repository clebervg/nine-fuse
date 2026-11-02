import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/notifications/notification_port.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/presentation/widgets/daily_spin_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/game_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/prize_wheel.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import 'package:nine_fuse/features/game/providers/wallet.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

class FakeNotificationPort implements NotificationPort {
  DateTime? dailySpinAt;

  @override
  Future<void> scheduleDailySpinReminder(DateTime at) async {
    dailySpinAt = at;
  }

  @override
  Future<void> scheduleInactivityReminder(DateTime at) async {}

  @override
  Future<void> cancelAll() async {}
}

Widget _wrap(Widget child, List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  ),
);

void main() {
  testWidgets('girar credita a fatia sorteada em moedas e grava o timestamp', (
    tester,
  ) async {
    final storage = InMemoryGameStorage(coins: 5);
    final fakePort = FakeNotificationPort();
    final fixedNow = DateTime.utc(2026, 9, 11, 12, 0, 0);
    // Índice 0 de `kSpinWheelPrizes` é `SpinPrize(SpinPrizeType.coins, 10)`.
    const forcedIndex = 0;

    await tester.pumpWidget(
      _wrap(const DailySpinDialog(), [
        dailySpinStorageProvider.overrideWithValue(storage),
        notificationPortProvider.overrideWithValue(fakePort),
        dailySpinClockProvider.overrideWithValue(() => fixedNow),
        dailySpinPrizeIndexProvider.overrideWithValue(() => forcedIndex),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(dailySpinSpinButtonKey));
    await tester.pumpAndSettle();

    expect(storage.coins, 15);
    expect(storage.lastSpinTimestamp, fixedNow);
    expect(fakePort.dailySpinAt, fixedNow.add(const Duration(hours: 24)));
  });

  testWidgets('girar credita a fatia sorteada em martelo, sem tocar moeda', (
    tester,
  ) async {
    final storage = InMemoryGameStorage(coins: 5, hammerCount: 2);
    final fakePort = FakeNotificationPort();
    final fixedNow = DateTime.utc(2026, 9, 11, 12, 0, 0);
    // Índice 1 de `kSpinWheelPrizes` é `SpinPrize(SpinPrizeType.hammer, 1)`.
    const forcedIndex = 1;

    await tester.pumpWidget(
      _wrap(const DailySpinDialog(), [
        dailySpinStorageProvider.overrideWithValue(storage),
        notificationPortProvider.overrideWithValue(fakePort),
        dailySpinClockProvider.overrideWithValue(() => fixedNow),
        dailySpinPrizeIndexProvider.overrideWithValue(() => forcedIndex),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(dailySpinSpinButtonKey));
    await tester.pumpAndSettle();

    expect(storage.hammerCount, 3);
    expect(storage.coins, 5);
    expect(storage.lastSpinTimestamp, fixedNow);
  });

  testWidgets('martelo sorteado com estoque cheio vira moeda', (tester) async {
    final storage = InMemoryGameStorage(
      coins: 5,
      hammerCount: kMaxBoosterStock,
    );
    final fixedNow = DateTime.utc(2026, 9, 11, 12, 0, 0);
    // Índice 1 de `kSpinWheelPrizes` é `SpinPrize(SpinPrizeType.hammer, 1)`.
    const forcedIndex = 1;

    await tester.pumpWidget(
      _wrap(const DailySpinDialog(), [
        dailySpinStorageProvider.overrideWithValue(storage),
        notificationPortProvider.overrideWithValue(FakeNotificationPort()),
        dailySpinClockProvider.overrideWithValue(() => fixedNow),
        dailySpinPrizeIndexProvider.overrideWithValue(() => forcedIndex),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(dailySpinSpinButtonKey));
    await tester.pumpAndSettle();

    expect(storage.hammerCount, kMaxBoosterStock);
    expect(storage.coins, 5 + kCoinsPerOverflowBooster);
  });

  testWidgets('não elegível mostra a contagem de espera e não gira', (
    tester,
  ) async {
    final fixedNow = DateTime.utc(2026, 9, 11, 12, 0, 0);
    final storage = InMemoryGameStorage(
      coins: 5,
      lastSpinTimestamp: fixedNow.subtract(const Duration(hours: 1)),
    );
    final fakePort = FakeNotificationPort();

    await tester.pumpWidget(
      _wrap(const DailySpinDialog(), [
        dailySpinStorageProvider.overrideWithValue(storage),
        notificationPortProvider.overrideWithValue(fakePort),
        dailySpinClockProvider.overrideWithValue(() => fixedNow),
      ]),
    );
    await tester.pumpAndSettle();

    // O botão continua no lugar (o layout não pula), mas desativado, e a
    // linha de espera conta o que falta das 24h a partir do último giro.
    expect(find.byKey(dailySpinSpinButtonKey), findsOneWidget);
    expect(find.byKey(dailySpinCountdownKey), findsOneWidget);
    expect(find.text('23:00:00'), findsOneWidget);

    await tester.tap(find.byKey(dailySpinSpinButtonKey));
    await tester.tap(find.byKey(prizeWheelHubKey));
    await tester.pumpAndSettle();

    expect(storage.coins, 5);
    expect(
      storage.lastSpinTimestamp,
      fixedNow.subtract(const Duration(hours: 1)),
    );
    expect(find.byKey(dailySpinPrizePopupKey), findsNothing);
  });

  testWidgets('o popup anuncia o prêmio e o booster que virou moeda', (
    tester,
  ) async {
    final storage = InMemoryGameStorage(
      coins: 5,
      hammerCount: kMaxBoosterStock,
    );
    final fixedNow = DateTime.utc(2026, 9, 11, 12, 0, 0);

    await tester.pumpWidget(
      _wrap(const DailySpinDialog(), [
        dailySpinStorageProvider.overrideWithValue(storage),
        notificationPortProvider.overrideWithValue(FakeNotificationPort()),
        dailySpinClockProvider.overrideWithValue(() => fixedNow),
        // Índice 1 de `kSpinWheelPrizes` é `SpinPrize(SpinPrizeType.hammer, 1)`.
        dailySpinPrizeIndexProvider.overrideWithValue(() => 1),
        // A carteira relê o mesmo disco em memória; a padrão iria ao
        // `SharedPreferences` real e o popup esperaria por ele.
        walletProvider.overrideWith((ref) => WalletNotifier(storage: storage)),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(dailySpinSpinButtonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(dailySpinPrizePopupKey), findsOneWidget);
    expect(
      find.text('Stock full: +$kCoinsPerOverflowBooster coins'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(dailySpinCollectButtonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(dailySpinPrizePopupKey), findsNothing);
    // Depois do giro grátis sobra o giro extra por vídeo.
    expect(find.byKey(dailySpinWatchAgainButtonKey), findsOneWidget);
  });

  testWidgets('tocar no cubo central também gira', (tester) async {
    final storage = InMemoryGameStorage(coins: 5);
    final fixedNow = DateTime.utc(2026, 9, 11, 12, 0, 0);

    await tester.pumpWidget(
      _wrap(const DailySpinDialog(), [
        dailySpinStorageProvider.overrideWithValue(storage),
        notificationPortProvider.overrideWithValue(FakeNotificationPort()),
        dailySpinClockProvider.overrideWithValue(() => fixedNow),
        dailySpinPrizeIndexProvider.overrideWithValue(() => 0),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(prizeWheelHubKey));
    await tester.pump(const Duration(milliseconds: 500));

    // No meio do giro o botão já está desativado, e novos toques (no cubo ou
    // no botão) não giram de novo nem creditam duas vezes.
    final button = tester.widget<GameButton>(
      find.byKey(dailySpinSpinButtonKey),
    );
    expect(button.onPressed, isNull);
    await tester.tap(find.byKey(prizeWheelHubKey));
    await tester.tap(find.byKey(dailySpinSpinButtonKey));
    await tester.pumpAndSettle();

    expect(storage.coins, 15);
    expect(storage.lastSpinTimestamp, fixedNow);
  });

  testWidgets('o giro extra por vídeo credita de novo sem gravar timestamp', (
    tester,
  ) async {
    final storage = InMemoryGameStorage(coins: 5);
    var now = DateTime.utc(2026, 9, 11, 12, 0, 0);
    final firstSpin = now;

    await tester.pumpWidget(
      _wrap(const DailySpinDialog(), [
        dailySpinStorageProvider.overrideWithValue(storage),
        notificationPortProvider.overrideWithValue(FakeNotificationPort()),
        dailySpinClockProvider.overrideWithValue(() => now),
        dailySpinPrizeIndexProvider.overrideWithValue(() => 0),
        walletProvider.overrideWith((ref) => WalletNotifier(storage: storage)),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(dailySpinSpinButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(dailySpinCollectButtonKey));
    await tester.pumpAndSettle();

    now = now.add(const Duration(minutes: 5));
    await tester.tap(find.byKey(dailySpinWatchAgainButtonKey));
    await tester.pumpAndSettle();

    expect(storage.coins, 25);
    expect(storage.lastSpinTimestamp, firstSpin);
    await tester.tap(find.byKey(dailySpinCollectButtonKey));
    await tester.pumpAndSettle();
    expect(find.byKey(dailySpinWatchAgainButtonKey), findsNothing);
  });
}
