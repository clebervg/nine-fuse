import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/notifications/notification_port.dart';
import 'package:nine_fuse/core/notifications/notification_service.dart';

class FakeNotificationPort implements NotificationPort {
  DateTime? dailySpinAt;
  DateTime? inactivityAt;
  int cancelCalls = 0;

  @override
  Future<void> scheduleDailySpinReminder(DateTime at) async {
    dailySpinAt = at;
  }

  @override
  Future<void> scheduleInactivityReminder(DateTime at) async {
    inactivityAt = at;
  }

  @override
  Future<void> cancelAll() async {
    cancelCalls++;
  }
}

void main() {
  final fixedNow = DateTime.utc(2026, 9, 11, 12, 0, 0);

  test('onDailySpinCompleted agenda o lembrete para +24h', () async {
    final port = FakeNotificationPort();
    final service = NotificationService(port: port, now: () => fixedNow);

    await service.onDailySpinCompleted();

    expect(port.dailySpinAt, fixedNow.add(const Duration(hours: 24)));
  });

  test('onAppOpened agenda o lembrete de inatividade para +72h', () async {
    final port = FakeNotificationPort();
    final service = NotificationService(port: port, now: () => fixedNow);

    await service.onAppOpened();

    expect(port.inactivityAt, fixedNow.add(const Duration(hours: 72)));
  });

  test('onAppOpened chamado de novo empurra o lembrete para frente', () async {
    final port = FakeNotificationPort();
    var current = fixedNow;
    final service = NotificationService(port: port, now: () => current);

    await service.onAppOpened();
    expect(port.inactivityAt, fixedNow.add(const Duration(hours: 72)));

    current = fixedNow.add(const Duration(hours: 10));
    await service.onAppOpened();
    expect(port.inactivityAt, current.add(const Duration(hours: 72)));
  });
}
