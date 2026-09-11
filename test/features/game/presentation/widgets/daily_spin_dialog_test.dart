import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/notifications/notification_port.dart';
import 'package:nine_fuse/features/game/presentation/widgets/daily_spin_dialog.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
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

    expect(find.byKey(dailySpinSpinButtonKey), findsNothing);
  });
}
