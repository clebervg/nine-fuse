import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Tipografia do jogo.
///
/// A Nunito vem **empacotada** em `assets/fonts/`, não baixada em runtime. Uma
/// fonte que depende de rede cai em silêncio no padrão do sistema quando o
/// aparelho está offline, e o jogo muda de cara sem aviso — inaceitável quando
/// a fonte é parte da identidade visual.
class AppFonts {
  const AppFonts._();

  /// Família dos números e dos títulos. Arredondada e geométrica: os dígitos
  /// ficam distintos entre si, que é o que importa num jogo de números.
  static const String display = 'Nunito';

  /// Registra a licença OFL da fonte empacotada.
  ///
  /// A OFL exige que a licença acompanhe a redistribuição. Sem isto ela não
  /// aparece na tela "Licenças" do app, e estaríamos distribuindo a fonte fora
  /// dos termos.
  static void registerLicense() {
    LicenseRegistry.addLicense(() async* {
      final license = await rootBundle.loadString('assets/fonts/OFL.txt');
      yield LicenseEntryWithLineBreaks(const ['Nunito'], license);
    });
  }
}
