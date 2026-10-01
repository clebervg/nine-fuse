import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/ads/ad_providers.dart';
import 'package:nine_fuse/core/ads/consent_service.dart';
import 'package:nine_fuse/core/widgets/privacy_dialog.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

class _Consent implements ConsentPort {
  _Consent({required this.optionsRequired});
  final bool optionsRequired;
  int reopened = 0;

  @override
  Future<bool> gather() async => true;
  @override
  Future<bool> privacyOptionsRequired() async => optionsRequired;
  @override
  Future<void> showPrivacyOptions() async => reopened++;
}

class _Tracking implements TrackingPort {
  @override
  Future<bool> requestAuthorization() async => true;
}

Future<_Consent> _open(WidgetTester tester, {required bool required}) async {
  final consent = _Consent(optionsRequired: required);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        consentServiceProvider.overrideWithValue(
          ConsentService(consent: consent, tracking: _Tracking()),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showPrivacyDialog(context),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return consent;
}

void main() {
  testWidgets('fora do EEE não há botão de opções de anúncio', (tester) async {
    await _open(tester, required: false);
    expect(find.byKey(privacyAdOptionsButtonKey), findsNothing);
  });

  testWidgets('no EEE o botão reabre o formulário do UMP', (tester) async {
    final consent = await _open(tester, required: true);
    expect(find.byKey(privacyAdOptionsButtonKey), findsOneWidget);
    await tester.tap(find.byKey(privacyAdOptionsButtonKey));
    await tester.pump();
    expect(consent.reopened, 1);
  });

  testWidgets('sem PRIVACY_POLICY_URL o link da política não aparece', (
    tester,
  ) async {
    // Sem --dart-define a constante é vazia: melhor sem link do que um
    // link que abre uma página quebrada.
    await _open(tester, required: false);
    expect(find.byKey(privacyPolicyButtonKey), findsNothing);
  });
}
