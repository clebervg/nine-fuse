import 'dart:io';

import 'package:flutter/foundation.dart' show kReleaseMode;

/// Identificadores do AdMob.
///
/// **As unidades de produção não moram no código: entram no build por
/// `--dart-define`** (uma por funil, ver o README). Android e iOS são builds
/// separados, então o mesmo nome de variável serve às duas plataformas.
///
/// Sem a variável, o comportamento depende do modo:
/// - **debug/profile** → ID de teste oficial do Google. É o que deve rodar em
///   desenvolvimento: pedir inventário real de um build de debug conta como
///   tráfego inválido e arrisca a conta antes de o jogo chegar à loja.
/// - **release** → string vazia, e a carga do anúncio falha de forma limpa
///   ("sem estoque"). Um release NUNCA cai em ID de teste em silêncio, mas
///   também não mostra anúncio: esquecer um `--dart-define` custa receita,
///   não quebra o app. Por isso `tool/check_admob_ids.sh` existe.
///
/// O App ID (um por plataforma) não passa por aqui: o SDK o lê do manifesto
/// (`manifestPlaceholders` em `app/build.gradle.kts`) e do `Info.plist`.
abstract final class AdIds {
  /// App ID de teste, o mesmo que está na configuração nativa das plataformas.
  ///
  /// Fica aqui só para documentar o par: o SDK o lê do manifesto, não daqui.
  static const String androidTestApp = 'ca-app-pub-3940256099942544~3347511713';
  static const String iosTestApp = 'ca-app-pub-3940256099942544~1458002511';

  static const String _androidTestRewarded =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _iosTestRewarded =
      'ca-app-pub-3940256099942544/1712485313';
  static const String _androidTestInterstitial =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _iosTestInterstitial =
      'ca-app-pub-3940256099942544/4411468910';

  // `const` + `fromEnvironment`: o valor é fixado na compilação, não há como
  // trocá-lo em runtime. O padrão vazio significa "não injetado".
  static const String _hammer = String.fromEnvironment('ADMOB_HAMMER_REWARDED');
  static const String _moves = String.fromEnvironment('ADMOB_MOVES_REWARDED');
  static const String _coins = String.fromEnvironment('ADMOB_COINS_REWARDED');
  static const String _spin = String.fromEnvironment('ADMOB_SPIN_REWARDED');
  static const String _bomb = String.fromEnvironment('ADMOB_BOMB_REWARDED');
  static const String _brush = String.fromEnvironment('ADMOB_BRUSH_REWARDED');
  static const String _interstitial = String.fromEnvironment(
    'ADMOB_INTERSTITIAL',
  );

  /// Unidade do anúncio que paga o Martelo de Fusão.
  ///
  /// Uma unidade por funil, mesmo que no teste todas apontem para o mesmo ID:
  /// é por unidade que a rede reporta receita, e uma só impediria de saber
  /// qual funil paga.
  static String get hammerRewarded => _resolve(_hammer);

  /// Unidade do anúncio que paga o reforço de saldo (gatilho pre-churn).
  static String get movesRewarded => _resolve(_moves);

  /// Unidade do anúncio que paga **moedas** dentro do modal de compra.
  static String get coinsRewarded => _resolve(_coins);

  /// Unidade do anúncio que paga o giro extra da roleta diária.
  static String get spinRewarded => _resolve(_spin);

  /// Unidade do anúncio que paga a Bomba.
  static String get bombRewarded => _resolve(_bomb);

  /// Unidade do anúncio que paga o Pincel.
  static String get brushRewarded => _resolve(_brush);

  /// Unidade do intersticial (pós-vitória / saída para o mapa).
  ///
  /// O formato é outro (não premiado), então o ID de teste também: pedir um
  /// intersticial numa unidade de premiado falha na rede.
  static String get interstitial => _resolve(
    _interstitial,
    android: _androidTestInterstitial,
    ios: _iosTestInterstitial,
  );

  /// O ID injetado vence em qualquer modo; sem ele, teste fora de release e
  /// vazio em release (ver a documentação da classe).
  static String _resolve(
    String injected, {
    String android = _androidTestRewarded,
    String ios = _iosTestRewarded,
  }) {
    if (injected.isNotEmpty) return injected;
    return kReleaseMode ? '' : _testFor(android: android, ios: ios);
  }

  /// Fora de Android e iOS não há SDK de anúncio, e a string vazia é o que faz
  /// a carga falhar de forma limpa em vez de estourar no canal de plataforma.
  static String _testFor({required String android, required String ios}) {
    if (Platform.isAndroid) return android;
    if (Platform.isIOS) return ios;
    return '';
  }
}
