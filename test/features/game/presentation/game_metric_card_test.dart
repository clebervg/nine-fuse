import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
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
            accent: AppColors.digit3,
            value: '7',
            urgent: urgent,
            pulseSeed: pulseSeed,
          ),
        ),
      ),
    ),
  );

  /// A caixa de fora, que é onde mora o aro em degradê.
  ///
  /// `first` e não `single`: a pílula passou a ser duas caixas encaixadas — a
  /// de fora desenha o contorno e a base projetada, a de dentro o fundo. Pedir
  /// "o único `Container`" quebraria a cada camada nova de material.
  BoxDecoration decorationOf(WidgetTester tester) =>
      tester
              .widgetList<Container>(
                find.descendant(
                  of: find.byKey(const Key('metric')),
                  matching: find.byType(Container),
                ),
              )
              .first
              .decoration!
          as BoxDecoration;

  testWidgets('a pílula mostra rótulo e valor', (tester) async {
    await pumpCard(tester);

    expect(find.text('JOGADAS'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.byIcon(Icons.bolt), findsOneWidget);
  });

  testWidgets('em alerta o aro fica vermelho e ganha neon', (tester) async {
    await pumpCard(tester, urgent: false);
    final calmo = decorationOf(tester);

    await pumpCard(tester, urgent: true);
    final alerta = decorationOf(tester);

    // O aro é um degradê desenhado como caixa por fora, e não um `Border`:
    // `BoxBorder` só aceita cor chapada, e o contorno claro em cima descendo
    // para escuro embaixo é o que dá volume à pílula. A asserção segue medindo
    // a mesma coisa — a cor com que o aro começa.
    expect(
      (alerta.gradient! as LinearGradient).colors.first.toARGB32(),
      AppColors.digit0.toARGB32(),
    );
    expect(
      alerta.boxShadow!.length,
      greaterThan(calmo.boxShadow!.length),
      reason: 'o neon vermelho só existe na urgência',
    );
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
