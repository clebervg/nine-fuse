import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/presentation/widgets/saga_map.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';
import '../../../support/localized.dart';

/// O pulso do pin da fase atual fica desligado na suíte inteira
/// (`test/flutter_test_config.dart`), senão `pumpAndSettle` nunca termina.
///
/// O efeito colateral é que **nenhum** teste via a aura no tamanho em que ela
/// de fato aparece no aparelho: com o pulso parado ela fica no menor diâmetro,
/// e foi assim que um estouro de layout que só existe no meio do pulso passou
/// pela suíte inteira e apareceu no console de quem estava jogando.
///
/// Este arquivo liga o pulso de propósito e avança o relógio à mão, sem
/// `pumpAndSettle`.
void main() {
  setUp(() => debugDisableMapPulse = false);
  tearDown(() => debugDisableMapPulse = true);

  Future<void> pumpMap(WidgetTester tester) async {
    tester.view.physicalSize = const Size(750, 1334);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        locale: kTestLocale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SagaMapWidget(
            levels: kCampaign,
            progress: 3,
            starsOf: (_) => 2,
            onTapLevel: (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets('a aura da fase atual não estoura a caixa do pin no auge', (
    tester,
  ) async {
    await pumpMap(tester);

    // Um ciclo inteiro, em passos: o estouro só aparece perto do pico, então
    // amostrar apenas o começo e o fim não veria nada.
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.takeException(),
        isNull,
        reason: 'estourou a ${i * 100}ms do pulso',
      );
    }

    // Desmonta com o controlador ainda rodando, senão sobra ticker vivo.
    await tester.pumpWidget(const SizedBox());
  });
}
