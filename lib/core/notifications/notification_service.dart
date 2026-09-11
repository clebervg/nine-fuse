import 'package:nine_fuse/core/notifications/notification_port.dart';

/// Sabe **quando** agendar cada lembrete; a porta sabe **como**.
///
/// `now` é injetável para o teste não depender do relógio real — mesmo
/// padrão de qualquer serviço deste projeto que precisa de tempo
/// determinístico.
class NotificationService {
  NotificationService({required this._port, this._now = DateTime.now});

  final NotificationPort _port;
  final DateTime Function() _now;

  /// Chamado ao terminar um giro da roleta diária: o próximo giro libera em
  /// 24h, e é isso que o lembrete anuncia.
  Future<void> onDailySpinCompleted() =>
      _port.scheduleDailySpinReminder(_now().add(const Duration(hours: 24)));

  /// Chamado toda vez que o app abre: reagenda o lembrete de inatividade
  /// para 72h a partir de agora, empurrando qualquer agendamento anterior.
  /// Abrir o app é o próprio sinal de que o jogador está ativo — a
  /// notificação só dispara se ele realmente ficar 72h sem voltar.
  Future<void> onAppOpened() =>
      _port.scheduleInactivityReminder(_now().add(const Duration(hours: 72)));
}
