import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Tipografia do jogo.
///
/// Todas as fontes vêm **empacotadas** em `assets/fonts/`, não baixadas em
/// runtime. Uma fonte que depende de rede cai em silêncio no padrão do sistema
/// quando o aparelho está offline, e o jogo muda de cara sem aviso —
/// inaceitável quando a fonte é parte da identidade visual.
///
/// Três papéis, da direção "Observatório Real":
/// - [title]: Lilita One — títulos, nome da fase e botões grandes;
/// - [number]: Baloo 2 — números do HUD (a mesma família dos números
///   desenhados nos tiles, então placar e peça falam a mesma língua);
/// - [display]: Nunito — texto corrido e descrições.
class AppFonts {
  const AppFonts._();

  /// Família do texto corrido. Arredondada e geométrica.
  static const String display = 'Nunito';

  /// Família dos títulos e botões grandes. Só tem um peso: o desenho já é
  /// pesado, e pedir `w900` faria o Flutter sintetizar um negrito borrado.
  static const String title = 'LilitaOne';

  /// Família dos números (pontos, jogadas, moedas, timers). Pesos 700 e 800.
  static const String number = 'Baloo2';

  /// Registra a licença OFL de cada fonte empacotada.
  ///
  /// A OFL exige que a licença acompanhe a redistribuição. Sem isto ela não
  /// aparece na tela "Licenças" do app, e estaríamos distribuindo a fonte fora
  /// dos termos.
  static void registerLicense() {
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks(const [
        'Nunito',
      ], await rootBundle.loadString('assets/fonts/OFL.txt'));
      yield LicenseEntryWithLineBreaks(const [
        'Lilita One',
      ], await rootBundle.loadString('assets/fonts/OFL-LilitaOne.txt'));
      yield LicenseEntryWithLineBreaks(const [
        'Baloo 2',
      ], await rootBundle.loadString('assets/fonts/OFL-Baloo2.txt'));
    });
  }
}
