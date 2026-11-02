import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/ads/consent_service.dart';

class _FakeConsent implements ConsentPort {
  _FakeConsent({
    this.canRequest = true,
    this.fail = false,
    this.options = false,
  });

  final bool canRequest;
  final bool fail;
  final bool options;
  int gathers = 0;
  int optionsShown = 0;

  @override
  Future<bool> gather() async {
    gathers++;
    if (fail) throw StateError('plugin ausente');
    return canRequest;
  }

  @override
  Future<bool> privacyOptionsRequired() async => options;

  @override
  Future<void> showPrivacyOptions() async => optionsShown++;
}

class _FakeTracking implements TrackingPort {
  _FakeTracking(this.granted, this.log);

  final bool granted;
  final List<String> log;

  @override
  Future<bool> requestAuthorization() async {
    log.add('att');
    return granted;
  }
}

void main() {
  test('com consentimento e ATT concedido, anúncios personalizados', () async {
    final service = ConsentService(
      consent: _FakeConsent(),
      tracking: _FakeTracking(true, []),
    );
    final result = await service.ensure();
    expect(result.canRequestAds, isTrue);
    expect(result.personalized, isTrue);
  });

  test('ATT recusado ainda permite anúncio, mas não personalizado', () async {
    final service = ConsentService(
      consent: _FakeConsent(),
      tracking: _FakeTracking(false, []),
    );
    final result = await service.ensure();
    expect(result.canRequestAds, isTrue);
    expect(result.personalized, isFalse);
  });

  test(
    'sem consentimento regional, nada de anúncio e o ATT nem é pedido',
    () async {
      final log = <String>[];
      final service = ConsentService(
        consent: _FakeConsent(canRequest: false),
        tracking: _FakeTracking(true, log),
      );
      final result = await service.ensure();
      expect(result.canRequestAds, isFalse);
      expect(log, isEmpty, reason: 'ATT só depois do consentimento resolvido');
    },
  );

  test('o ATT vem depois do UMP', () async {
    final log = <String>[];
    final consent = _FakeConsent();
    final service = ConsentService(
      consent: consent,
      tracking: _FakeTracking(true, log),
    );
    await service.ensure();
    expect(consent.gathers, 1);
    expect(log, ['att']);
  });

  test('o fluxo roda uma vez, mesmo com vários funis pedindo junto', () async {
    final consent = _FakeConsent();
    final service = ConsentService(
      consent: consent,
      tracking: _FakeTracking(true, []),
    );
    await Future.wait([service.ensure(), service.ensure(), service.ensure()]);
    expect(consent.gathers, 1);
  });

  test('plugin que estoura vira "sem anúncio", não exceção', () async {
    final service = ConsentService(
      consent: _FakeConsent(fail: true),
      tracking: _FakeTracking(true, []),
    );
    final result = await service.ensure();
    expect(result.canRequestAds, isFalse);
  });

  test('opções de privacidade: exigência e reabertura', () async {
    final consent = _FakeConsent(options: true);
    final service = ConsentService(
      consent: consent,
      tracking: _FakeTracking(true, []),
    );
    expect(await service.privacyOptionsRequired(), isTrue);
    await service.showPrivacyOptions();
    expect(consent.optionsShown, 1);
  });
}
