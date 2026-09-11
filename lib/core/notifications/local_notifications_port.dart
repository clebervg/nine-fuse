import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:nine_fuse/core/notifications/notification_port.dart';

/// Fala com o plugin de verdade.
///
/// Sem teste automatizado, de propósito: exercitar isto mediria o SDK
/// (`flutter_local_notifications`), não a lógica do jogo — a mesma régua já
/// aplicada a `AdMobRewardedPort`. `NotificationService` é quem carrega toda a
/// lógica testável.
class LocalNotificationsPort implements NotificationPort {
  LocalNotificationsPort() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  /// ID fixo por tipo de lembrete: agendar de novo **substitui**, nunca
  /// acumula uma segunda notificação do mesmo tipo pendente.
  static const int _dailySpinNotificationId = 1;
  static const int _inactivityNotificationId = 2;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();

    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  @override
  Future<void> scheduleDailySpinReminder(DateTime at) async {
    await _ensureInitialized();
    await _plugin.zonedSchedule(
      _dailySpinNotificationId,
      'A roleta diária está pronta!',
      'Volte para girar e ganhar sua recompensa de hoje.',
      tz.TZDateTime.from(at, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_spin',
          'Roleta Diária',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  Future<void> scheduleInactivityReminder(DateTime at) async {
    await _ensureInitialized();
    await _plugin.zonedSchedule(
      _inactivityNotificationId,
      'Sentimos sua falta!',
      'Seus números estão esperando por você no NineFuse.',
      tz.TZDateTime.from(at, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'inactivity',
          'Lembrete de Inatividade',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  Future<void> cancelAll() async {
    await _ensureInitialized();
    await _plugin.cancelAll();
  }
}
