import 'dart:io';

/// Identificadores do AdMob.
///
/// **Todos são os IDs de teste oficiais do Google.** São eles que devem rodar
/// em desenvolvimento: pedir inventário real de um build de debug conta como
/// tráfego inválido e é o caminho mais rápido para a conta ser suspensa antes
/// mesmo de o jogo estar na loja.
///
/// Trocar pelos IDs de produção é a última coisa a fazer antes de publicar, e
/// são **quatro** lugares — os dois daqui, o `applicationId` do
/// `AndroidManifest.xml` e o `GADApplicationIdentifier` do `Info.plist`. Um
/// esquecido não quebra o build: o anúncio simplesmente não vem.
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

  /// Unidade do anúncio que paga o Martelo de Fusão.
  ///
  /// Separada da do reforço de saldo mesmo apontando hoje para o mesmo ID de
  /// teste: é por unidade que a rede reporta receita, e uma só impediria de
  /// saber qual dos dois funis paga.
  static String get hammerRewarded => _rewarded;

  /// Unidade do anúncio que paga o reforço de saldo (gatilho pre-churn).
  static String get movesRewarded => _rewarded;

  /// Fora de Android e iOS não há SDK de anúncio, e a string vazia é o que faz
  /// a carga falhar de forma limpa em vez de estourar no canal de plataforma.
  static String get _rewarded {
    if (Platform.isAndroid) return _androidTestRewarded;
    if (Platform.isIOS) return _iosTestRewarded;
    return '';
  }
}
