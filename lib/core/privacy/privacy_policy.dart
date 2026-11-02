import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// URL pública da política de privacidade, injetada no build:
/// `--dart-define=PRIVACY_POLICY_URL=https://...`.
///
/// Não fica no código porque o endereço só existe depois de hospedar a página
/// (ver o README). Vazio = o link não aparece, em vez de abrir uma página
/// quebrada; mas a Play Store exige o link no app, então um release sem essa
/// variável não é publicável.
const String kPrivacyPolicyUrl = String.fromEnvironment('PRIVACY_POLICY_URL');

/// Abre a política no navegador. Devolve `false` se não houver URL ou se o
/// aparelho não conseguir abri-la.
Future<bool> openPrivacyPolicy({String url = kPrivacyPolicyUrl}) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return false;
  try {
    // Navegador externo: a política é uma página web comum, e o usuário deve
    // poder lê-la, compartilhá-la e voltar ao jogo.
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (error) {
    debugPrint('Não abriu a política de privacidade: $error');
    return false;
  }
}
