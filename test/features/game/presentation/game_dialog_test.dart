import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/features/game/presentation/widgets/game_dialog.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';
import '../../../support/localized.dart';

void main() {
  const cardKey = Key('dialog_card');

  Future<void> pumpDialog(WidgetTester tester, {String title = 'VITÓRIA!'}) =>
      tester.pumpWidget(
        MaterialApp(
          locale: kTestLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: GameDialog(
                cardKey: cardKey,
                title: title,
                accent: AppColors.digit2,
                child: const Text('conteúdo'),
              ),
            ),
          ),
        ),
      );

  group('caixa de mensagem do jogo', () {
    testWidgets('o título fica pregado acima da borda do cartão', (
      tester,
    ) async {
      // É o que separa um selo de prêmio de uma primeira linha em negrito. Se
      // o título voltar para dentro da caixa, o modal volta a ler como diálogo
      // de sistema — que foi exatamente o diagnóstico que motivou esta caixa.
      await pumpDialog(tester);

      final card = tester.getRect(find.byKey(cardKey));
      final selo = tester.getRect(find.byKey(gameDialogTitleKey));

      expect(
        selo.top,
        lessThan(card.top),
        reason: 'o selo deveria projetar-se para fora do cartão',
      );
      // E ainda assim invadi-lo: um selo solto no ar não pertence à caixa.
      expect(selo.bottom, greaterThan(card.top));
    });

    testWidgets('o cartão assina com a cor da ocasião', (tester) async {
      await pumpDialog(tester);

      final decoration =
          tester.widget<Container>(find.byKey(cardKey)).decoration!
              as BoxDecoration;

      expect(decoration.border, isNotNull);
      expect(
        decoration.boxShadow,
        isNotEmpty,
        reason: 'sem halo o cartão some contra o fundo escuro',
      );
    });

    testWidgets('um título longo não estoura a largura do cartão', (
      tester,
    ) async {
      // "MOVIMENTOS ESGOTADOS" é o título real mais longo da campanha, e a
      // fonte de teste mede cada glifo como um `em` inteiro — o pior caso.
      await pumpDialog(tester, title: 'MOVIMENTOS ESGOTADOS');
      expect(tester.takeException(), isNull);
    });
  });

  group('botão 3D', () {
    testWidgets('afunda ao ser pressionado e volta ao soltar', (tester) async {
      var taps = 0;

      await tester.pumpWidget(
        MaterialApp(
          locale: kTestLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: GameButton(
                label: 'JOGAR',
                color: AppColors.digit2,
                onPressed: () => taps++,
              ),
            ),
          ),
        ),
      );

      final repouso = tester.getTopLeft(find.text('JOGAR'));

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('JOGAR')),
      );
      await tester.pumpAndSettle();
      final pressionado = tester.getTopLeft(find.text('JOGAR'));

      expect(
        pressionado.dy,
        greaterThan(repouso.dy),
        reason: 'a compressão é o que dá vontade física de clicar',
      );

      await gesture.up();
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(find.text('JOGAR')).dy, repouso.dy);
      expect(taps, 1);
    });

    testWidgets('continua sendo um botão para quem lê a tela', (tester) async {
      // Deixou de ser `ElevatedButton` para poder afundar; isso não pode custar
      // a semântica de botão.
      await tester.pumpWidget(
        MaterialApp(
          locale: kTestLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: GameButton(
              label: 'CONTINUAR',
              color: AppColors.digit1,
              onPressed: () {},
            ),
          ),
        ),
      );

      final semantics = tester
          .widgetList<Semantics>(
            find.ancestor(
              of: find.text('CONTINUAR'),
              matching: find.byType(Semantics),
            ),
          )
          .where((s) => s.properties.button ?? false);

      expect(
        semantics,
        isNotEmpty,
        reason: 'o botão precisa se anunciar como botão',
      );
      // O rótulo vem do `Text`, uma vez só: duplicá-lo no `Semantics` faria o
      // leitor de tela anunciar "CONTINUAR CONTINUAR".
      expect(
        tester.getSemantics(find.text('CONTINUAR')).label.trim(),
        'CONTINUAR',
      );
    });
  });
}
