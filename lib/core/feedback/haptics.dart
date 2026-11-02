import 'package:flutter/services.dart';

/// O único caminho do jogo até o motor de vibração e os sons de sistema.
///
/// Existe para o interruptor "Vibração" das Configurações valer em **todo**
/// lugar sem cada tela ler a configuração: as batidas estavam espalhadas por
/// boosters, notifiers, roleta, mapa e botões, e um `if` repetido em cada uma
/// seria esquecido na próxima batida nova. Quem decide é o `main`, que
/// espelha a configuração persistida em [enabled]/[systemSoundsEnabled].
///
/// É estático, e não um provider, porque os ganchos que o usam já são
/// estáticos e injetáveis (`HammerBooster.strikeFeedback`,
/// `GameNotifier.explosionFeedback`...) — os testes continuam dublando os
/// ganchos como sempre, e o padrão aqui é ligado, igual ao jogo antes desta
/// chave existir.
abstract final class Haptics {
  /// Espelho de `GameSettings.vibrationOn`.
  static bool enabled = true;

  /// Espelho de `GameSettings.soundOn` para os sons do **sistema** (clique e
  /// alerta). "Som desligado" que deixasse o clique do mapa tocando seria um
  /// interruptor que mente.
  static bool systemSoundsEnabled = true;

  static void selection() {
    if (enabled) HapticFeedback.selectionClick();
  }

  static void light() {
    if (enabled) HapticFeedback.lightImpact();
  }

  static void medium() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  static void heavy() {
    if (enabled) HapticFeedback.heavyImpact();
  }

  /// Clique curto do próprio sistema.
  static void click() {
    if (systemSoundsEnabled) SystemSound.play(SystemSoundType.click);
  }

  /// Alerta do sistema (mira errada).
  static void alert() {
    if (systemSoundsEnabled) SystemSound.play(SystemSoundType.alert);
  }
}
