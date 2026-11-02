import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:nine_fuse/core/ads/consent_service.dart';
import 'package:nine_fuse/core/ads/interstitial_ad_service.dart';

/// A ponte do intersticial com o SDK do AdMob.
///
/// Mesma régua do `AdMobRewardedPort`: fina e **sem teste**. Toda a decisão
/// (quando pode exibir, quando repor) vive no [InterstitialAdService].
class AdMobInterstitialPort implements InterstitialAdPort {
  const AdMobInterstitialPort({required this.consent});

  /// Nenhum anúncio é pedido antes de o consentimento (UMP/ATT) resolver.
  final ConsentService consent;

  @override
  Future<InterstitialAdHandle?> load(String unitId) async {
    // Unidade vazia: release sem `--dart-define`, ou plataforma sem SDK.
    if (unitId.isEmpty) return null;

    final permission = await consent.ensure();
    if (!permission.canRequestAds) return null;

    final completer = Completer<InterstitialAdHandle?>();

    // `await` obrigatório pelo mesmo bug já vivido no premiado: sem ele, um
    // canal nativo ausente vira erro assíncrono solto e o `Completer` nunca
    // completa.
    try {
      await InterstitialAd.load(
        adUnitId: unitId,
        request: AdRequest(nonPersonalizedAds: !permission.personalized),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) => completer.complete(_AdMobInterstitial(ad)),
          onAdFailedToLoad: (_) => completer.complete(null),
        ),
      );
    } catch (error, stack) {
      debugPrint('SDK de anúncio indisponível para $unitId: $error\n$stack');
      return null;
    }

    return completer.future;
  }
}

class _AdMobInterstitial implements InterstitialAdHandle {
  _AdMobInterstitial(this._ad);

  final InterstitialAd _ad;

  @override
  Future<void> show() {
    final completer = Completer<void>();
    // Só o fechamento (ou a falha) encerra a espera: completar antes deixaria
    // a navegação seguir com o anúncio ainda por cima da tela.
    _ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) {
        if (!completer.isCompleted) completer.complete();
      },
      onAdFailedToShowFullScreenContent: (_, _) {
        if (!completer.isCompleted) completer.complete();
      },
    );
    _ad.show();
    return completer.future;
  }

  @override
  void dispose() => _ad.dispose();
}
