/// Como o jogo agenda lembretes locais, sem amarrar o resto do código ao
/// plugin nativo.
///
/// A interface existe pela mesma razão de `RewardedAdPort`: testar a
/// orquestração (quando agendar o quê) não deve exigir canal de plataforma. A
/// implementação real (`LocalNotificationsPort`) não tem teste — testá-la
/// mediria o plugin, não o jogo.
abstract interface class NotificationPort {
  /// Lembrete de que a roleta diária está disponível de novo.
  Future<void> scheduleDailySpinReminder(DateTime at);

  /// Lembrete de inatividade: o jogador não abriu o app há um tempo.
  Future<void> scheduleInactivityReminder(DateTime at);

  /// Cancela todos os lembretes agendados.
  Future<void> cancelAll();
}
