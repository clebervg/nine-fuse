import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/ads/ad_providers.dart';
import 'package:nine_fuse/core/ads/consent_service.dart';
import 'package:nine_fuse/features/game/domain/game_settings.dart';
import 'package:nine_fuse/features/game/presentation/screens/settings_screen.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import 'package:nine_fuse/features/game/providers/settings.dart';
import 'package:nine_fuse/main.dart';

import '../../../support/localized.dart';

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

void main() {
  late InMemoryGameStorage storage;
  late _Consent consent;

  Future<void> pumpSettings(
    WidgetTester tester, {
    bool consentRequired = false,
    GameSettings saved = const GameSettings(),
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    storage = InMemoryGameStorage(settings: saved);
    consent = _Consent(optionsRequired: consentRequired);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => SettingsNotifier(storage: storage),
          ),
          consentServiceProvider.overrideWithValue(
            ConsentService(consent: consent, tracking: _Tracking()),
          ),
        ],
        child: localizedApp(home: const SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool switchValue(WidgetTester tester, Key row) => tester
      .widget<Switch>(
        find.descendant(of: find.byKey(row), matching: find.byType(Switch)),
      )
      .value;

  testWidgets('mostra o que estava salvo', (tester) async {
    await pumpSettings(
      tester,
      saved: const GameSettings(musicOn: false, vibrationOn: false),
    );

    expect(switchValue(tester, settingsSoundKey), isTrue);
    expect(switchValue(tester, settingsMusicKey), isFalse);
    expect(switchValue(tester, settingsVibrationKey), isFalse);
  });

  testWidgets('cada interruptor grava no disco na hora', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.byKey(settingsMusicKey));
    await tester.tap(find.byKey(settingsVibrationKey));
    await tester.pumpAndSettle();

    expect(storage.settings.musicOn, isFalse);
    expect(storage.settings.vibrationOn, isFalse);
    expect(storage.settings.soundOn, isTrue);
  });

  testWidgets('o volume só aparece com o som ligado', (tester) async {
    await pumpSettings(tester);
    expect(find.byKey(settingsVolumeKey), findsOneWidget);

    await tester.tap(find.byKey(settingsSoundKey));
    await tester.pumpAndSettle();

    expect(storage.settings.soundOn, isFalse);
    expect(find.byKey(settingsVolumeKey), findsNothing);
  });

  testWidgets('escolher o idioma grava a escolha', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.byKey(settingsLanguageKey(AppLanguage.en)));
    await tester.pumpAndSettle();

    expect(storage.settings.language, AppLanguage.en);
  });

  testWidgets('fora do EEE não há item de consentimento', (tester) async {
    await pumpSettings(tester);
    expect(find.byKey(settingsConsentKey), findsNothing);
  });

  testWidgets('onde a lei exige, o item reabre o formulário do UMP', (
    tester,
  ) async {
    await pumpSettings(tester, consentRequired: true);
    expect(find.byKey(settingsConsentKey), findsOneWidget);

    await tester.tap(find.byKey(settingsConsentKey));
    await tester.pump();
    expect(consent.reopened, 1);
  });

  testWidgets('créditos e licenças abrem', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.byKey(settingsCreditsKey));
    await tester.pumpAndSettle();
    expect(find.textContaining('Open Font License'), findsOneWidget);
    await tester.tap(find.text('FECHAR'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(settingsLicensesKey));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });

  group('MaterialApp.locale', () {
    Future<Locale?> appLocale(WidgetTester tester, AppLanguage language) async {
      final storage = InMemoryGameStorage(
        settings: GameSettings(language: language),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(
              (ref) => SettingsNotifier(storage: storage),
            ),
          ],
          child: const NineFuseApp(),
        ),
      );
      // Um quadro para a leitura do disco chegar, outro para o app reagir.
      await tester.pump();
      await tester.pump();
      return tester.widget<MaterialApp>(find.byType(MaterialApp)).locale;
    }

    testWidgets('idioma escolhido vira o locale do app', (tester) async {
      expect(await appLocale(tester, AppLanguage.en), const Locale('en'));
    });

    testWidgets('"do aparelho" deixa o locale nulo', (tester) async {
      expect(await appLocale(tester, AppLanguage.system), isNull);
    });

    testWidgets('trocar o idioma troca o texto na hora', (tester) async {
      final storage = InMemoryGameStorage();
      final notifier = SettingsNotifier(storage: storage);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [settingsProvider.overrideWith((ref) => notifier)],
          child: Consumer(
            builder: (context, ref, _) {
              final code = ref.watch(
                settingsProvider.select((s) => s.language.code),
              );
              return localizedApp(
                locale: Locale(code ?? 'pt'),
                home: const SettingsScreen(),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('AJUSTES'), findsOneWidget);

      await tester.tap(find.byKey(settingsLanguageKey(AppLanguage.en)));
      await tester.pumpAndSettle();
      expect(find.text('SETTINGS'), findsOneWidget);
    });
  });
}
