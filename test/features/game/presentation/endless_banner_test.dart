import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/endless_progression.dart';
import 'package:nine_fuse/features/game/presentation/widgets/endless_banner.dart';
import 'package:nine_fuse/features/game/providers/endless_state.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';
import '../../../support/localized.dart';

void main() {
  const progression = EndlessProgression();

  Future<void> pumpBanner(WidgetTester tester, EndlessState state) =>
      tester.pumpWidget(
        MaterialApp(
          locale: kTestLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EndlessBanner(
              state: state,
              highScore: 0,
              progression: progression,
            ),
          ),
        ),
      );

  double bandProgress(WidgetTester tester) => tester
      .widget<LinearProgressIndicator>(find.byKey(endlessBandProgressKey))
      .value!;

  group('maior bloco', () {
    testWidgets('o rótulo diz de que "maior" se trata', (tester) async {
      // "Maior" sozinho podia ser pontuação, faixa ou combo.
      await pumpBanner(tester, EndlessState(board: Board.empty()));

      expect(find.text('Maior Bloco'), findsOneWidget);
    });

    testWidgets('mostra a peça, não só o número', (tester) async {
      await pumpBanner(
        tester,
        EndlessState(board: Board.empty(), highestDigit: 6),
      );

      // Duas camadas de texto: traço embaixo, preenchimento branco em cima. É
      // a mesma técnica do número da peça — sem o contorno, o `9` dourado
      // ficaria ilegível neste selo.
      final digit = find.descendant(
        of: find.byKey(endlessBiggestKey),
        matching: find.text('6'),
      );
      expect(digit, findsNWidgets(2));

      final texts = tester.widgetList<Text>(digit);
      expect(
        texts.where((t) => t.style?.foreground?.style == PaintingStyle.stroke),
        hasLength(1),
      );
      expect(texts.where((t) => t.style?.color == Colors.white), hasLength(1));
    });

    testWidgets('antes da primeira fusão não inventa um zero', (tester) async {
      // Nenhuma fusão devolve zero — a menor peça que ela cria é um 1. Um "0"
      // aqui seria lido como "meu maior bloco é um 0", que nunca é verdade.
      await pumpBanner(tester, EndlessState(board: Board.empty()));

      expect(
        find.descendant(
          of: find.byKey(endlessBiggestKey),
          matching: find.text('—'),
        ),
        findsOneWidget,
      );
    });
  });

  group('evolução da faixa', () {
    testWidgets('o alvo da próxima faixa aparece como selo', (tester) async {
      await pumpBanner(tester, EndlessState(board: Board.empty()));

      final promotion = progression.promotionDigitFor(0);
      expect(find.text('Próxima faixa: crie um'), findsOneWidget);
      expect(
        find.text('$promotion'),
        findsOneWidget,
        reason: 'o dígito que promove precisa vir destacado no selo',
      );
    });

    testWidgets('a barra mede a distância até o dígito que promove', (
      tester,
    ) async {
      final spawnMax = progression.spawnMaxFor(0);

      // Nada fundido acima da faixa: nenhum avanço.
      await pumpBanner(tester, EndlessState(board: Board.empty()));
      expect(bandProgress(tester), 0);

      // Um dígito acima do teto da faixa é meio caminho; o seguinte promove.
      await pumpBanner(
        tester,
        EndlessState(board: Board.empty(), highestDigit: spawnMax + 1),
      );
      expect(bandProgress(tester), 0.5);
    });

    testWidgets('no último degrau some a barra e sobra o aviso', (
      tester,
    ) async {
      await pumpBanner(
        tester,
        EndlessState(board: Board.empty(), step: EndlessProgression.lastStep),
      );

      expect(find.byKey(endlessBandProgressKey), findsNothing);
      expect(find.text('Faixa máxima alcançada'), findsOneWidget);
    });
  });
}
