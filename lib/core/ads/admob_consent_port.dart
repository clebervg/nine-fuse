import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:nine_fuse/core/ads/consent_service.dart';

/// A ponte com o UMP do `google_mobile_ads`. Fina e **sem teste**, pela mesma
/// razão do `AdMobRewardedPort`: testá-la mediria o SDK, não o jogo.
class UmpConsentPort implements ConsentPort {
  const UmpConsentPort();

  @override
  Future<bool> gather() async {
    final info = ConsentInformation.instance;

    // Atualiza o estado. Falha de rede aqui não é fatal: o SDK guarda o último
    // consentimento, e `canRequestAds` abaixo reflete isso.
    final updated = Completer<void>();
    info.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => updated.complete(),
      (error) {
        debugPrint('UMP: falha ao atualizar o consentimento: ${error.message}');
        updated.complete();
      },
    );
    await updated.future;

    // Mostra o formulário só se a lei exigir e o usuário ainda não escolheu.
    final shown = Completer<void>();
    ConsentForm.loadAndShowConsentFormIfRequired((error) {
      if (error != null) debugPrint('UMP: formulário: ${error.message}');
      shown.complete();
    });
    await shown.future;

    return info.canRequestAds();
  }

  @override
  Future<bool> privacyOptionsRequired() async {
    final status = await ConsentInformation.instance
        .getPrivacyOptionsRequirementStatus();
    return status == PrivacyOptionsRequirementStatus.required;
  }

  @override
  Future<void> showPrivacyOptions() {
    final done = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((error) {
      if (error != null) debugPrint('UMP: opções: ${error.message}');
      done.complete();
    });
    return done.future;
  }
}

/// A ponte com o ATT. Só o iOS tem o diálogo; no resto devolve `true`.
class AttTrackingPort implements TrackingPort {
  const AttTrackingPort();

  @override
  Future<bool> requestAuthorization() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return true;

    var status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status == TrackingStatus.notDetermined) {
      status = await AppTrackingTransparency.requestTrackingAuthorization();
    }
    // `notSupported` (iOS < 14) não tem o que recusar.
    return status == TrackingStatus.authorized ||
        status == TrackingStatus.notSupported;
  }
}
