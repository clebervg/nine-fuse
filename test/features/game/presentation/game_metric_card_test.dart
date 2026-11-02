import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/theme/nf_tokens.dart';
import 'package:nine_fuse/features/game/presentation/widgets/game_metric_card.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';
import '../../../support/localized.dart';

void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    bool urgent = false,
    Object? pulseSeed,
  }) => tester.pumpWidget(
    MaterialApp(
      locale: kTestLocale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: GameMetricCard(
            key: const Key('metric'),
            label: 'JOGADAS',
            icon: Icons.bolt,
            accent: AppColors.uiGold,
            value: '7',
            urgent: urgent,
            pulseSeed: pulseSeed,
          ),
        ),
      ),
    ),
  );

  /// A caixa da pílula, onde mora a borda.
  BoxDecoration decorationOf(WidgetTester tester) =>
      tester
              .widget<Container>(
                find.descendant(
                  of: find.byKey(const Key('metric')),
                  matching: find.byType(Container),
                ),
              )
              .decoration!
          as BoxDecoration;

  testWidgets('a pílula mostra rótulo e valor', (tester) async {
    await pumpCard(tester);

    expect(find.text('JOGADAS'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.byIcon(Icons.bolt), findsOneWidget);
  });

  testWidgets('em alerta a borda fica vermelha e só ela ganha neon', (
    tester,
  ) async {
    await pumpCard(tester, urgent: false);
    final calmo = decorationOf(tester);

    await pumpCard(tester, urgent: true);
    final alerta = decorationOf(tester);

    // Fora do alerta a borda é neutra (a cor fica no ícone); no alerta ela
    // vira `NfColors.alert`. Compara ignorando o alfa (a borda neutra é branco
    // com transparência).
    Color opaque(Color c) => c.withValues(alpha: 1);

    expect(
      opaque((calmo.border! as Border).top.color).toARGB32(),
      isNot(opaque(NfColors.alert).toARGB32()),
    );
    expect(
      opaque((alerta.border! as Border).top.color).toARGB32(),
      opaque(NfColors.alert).toARGB32(),
    );

    // Neon só na urgência: brilho aceso o tempo todo vira papel de parede.
    expect(calmo.boxShadow ?? const [], isEmpty);
    expect(alerta.boxShadow, isNotEmpty);
  });

  testWidgets('a batida da pílula termina sozinha', (tester) async {
    // O ponto do teste não é o tamanho do salto e sim que ele **acaba**: uma
    // animação em repetição faria `pumpAndSettle` rodar para sempre e
    // derrubaria toda a suíte de widget, não só este teste.
    await pumpCard(tester, urgent: true, pulseSeed: 3);
    await tester.pumpAndSettle();

    expect(find.text('7'), findsOneWidget);
  });
}
