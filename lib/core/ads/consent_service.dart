import 'package:flutter/foundation.dart';

/// Porta do formulário de consentimento (UMP, do Google).
///
/// Mesma régua do `AdMobRewardedPort`: a ponte com o SDK é fina e sem teste, e
/// toda a decisão vive no [ConsentService], testável em Dart puro.
abstract interface class ConsentPort {
  /// Atualiza o estado do consentimento e, se a lei exigir (EEE, Reino Unido…),
  /// mostra o formulário. Devolve se o app **já pode pedir anúncios**.
  Future<bool> gather();

  /// Se o usuário tem de poder reabrir a escolha (obrigatório no EEE).
  Future<bool> privacyOptionsRequired();

  /// Reabre o formulário de opções de privacidade.
  Future<void> showPrivacyOptions();
}

/// Porta do ATT (App Tracking Transparency, só iOS 14.5+).
abstract interface class TrackingPort {
  /// Pede a autorização de rastreamento. Devolve `true` se concedida.
  /// Onde não existe ATT (Android, iOS antigo), devolve `true`: não há
  /// o que recusar, e o consentimento regional já vem do [ConsentPort].
  Future<bool> requestAuthorization();
}

/// O que os anúncios podem fazer depois do consentimento.
@immutable
class ConsentResult {
  const ConsentResult({
    required this.canRequestAds,
    required this.personalized,
  });

  /// Sem isto, nenhum anúncio pode ser pedido.
  final bool canRequestAds;

  /// `false` pede só anúncios não personalizados (`nonPersonalizedAds`).
  final bool personalized;

  /// Estado seguro quando algo falha: nada de anúncio.
  static const denied = ConsentResult(
    canRequestAds: false,
    personalized: false,
  );
}

/// Decide quando o app pode falar com a rede de anúncios.
///
/// A ordem é a que a Apple e o Google pedem: primeiro o consentimento regional
/// (UMP), depois o ATT no iOS. O resultado é calculado **uma vez** e
/// compartilhado — vários funis pedem anúncio ao mesmo tempo no início da fase,
/// e abrir o formulário duas vezes seria pior que não abri-lo.
class ConsentService {
  ConsentService({required this.consent, required this.tracking});

  final ConsentPort consent;
  final TrackingPort tracking;

  Future<ConsentResult>? _result;

  /// Roda o fluxo na primeira chamada; as seguintes reaproveitam o resultado.
  Future<ConsentResult> ensure() => _result ??= _run();

  Future<ConsentResult> _run() async {
    try {
      final canRequest = await consent.gather();
      if (!canRequest) return ConsentResult.denied;

      // O ATT só é pedido com o consentimento regional resolvido. Recusar o
      // ATT não bloqueia anúncio: só tira a personalização.
      final tracked = await tracking.requestAuthorization();
      return ConsentResult(canRequestAds: true, personalized: tracked);
    } catch (error, stack) {
      // Sem plugin nativo (hot restart, desktop) ou erro do SDK: o jogo segue
      // sem anúncio, que é o caso que o `RewardedAdService` já trata.
      debugPrint('Consentimento indisponível: $error\n$stack');
      return ConsentResult.denied;
    }
  }

  Future<bool> privacyOptionsRequired() async {
    try {
      return await consent.privacyOptionsRequired();
    } catch (_) {
      return false;
    }
  }

  Future<void> showPrivacyOptions() async {
    try {
      await consent.showPrivacyOptions();
    } catch (error) {
      debugPrint('Opções de privacidade indisponíveis: $error');
    }
  }
}
