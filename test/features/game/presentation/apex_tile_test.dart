import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/endless_progression.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';
import 'package:nine_fuse/features/game/presentation/widgets/endless_banner.dart';
import 'package:nine_fuse/features/game/presentation/widgets/tile_widget.dart';
import 'package:nine_fuse/features/game/providers/endless_state.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';
import '../../../support/localized.dart';

/// Todas as `BoxDecoration` presentes na árvore.
Iterable<BoxDecoration> decorations(WidgetTester tester) => tester
    .widgetList<Container>(find.byType(Container))
    .map((c) => c.decoration)
    .whereType<BoxDecoration>();

void main() {
  Widget hostTile(int value) => MaterialApp(
    locale: kTestLocale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 60,
          height: 60,
          child: TileWidget(
            tile: Tile(
              id: 't',
              value: value,
              position: const Position(row: 0, col: 0),
            ),
            side: 60,
          ),
        ),
      ),
    ),
  );

  group('identidade da peça ápice', () {
    testWidgets('o dígito máximo usa o degradê dourado, não a cor da paleta', (
      tester,
    ) async {
      // Um bloco chapado e branco era o que fazia a peça mais rara do jogo
      // parecer a mais apagada.
      await tester.pumpWidget(hostTile(kMaxDigit));
      await tester.pumpAndSettle();

      final gradient = decorations(tester)
          .map((d) => d.gradient)
          .whereType<LinearGradient>()
          .firstWhere((g) => g.colors.contains(AppColors.digit9));

      expect(gradient.colors, contains(AppColors.digit9Deep));
    });

    testWidgets('a peça ápice brilha em neon dourado', (tester) async {
      await tester.pumpWidget(hostTile(kMaxDigit));
      await tester.pumpAndSettle();

      final shadows = decorations(
        tester,
      ).expand((d) => d.boxShadow ?? const <BoxShadow>[]);

      expect(
        shadows.where(
          (s) =>
              s.color.toARGB32() ==
              AppColors.digit9.withValues(alpha: 0.85).toARGB32(),
        ),
        isNotEmpty,
        reason: 'o ápice perdeu o halo dourado',
      );
    });

    testWidgets('só o ápice espalha o halo para fora da célula', (
      tester,
    ) async {
      // `BoxShadow` com `spreadRadius` positivo desenha fora da caixa e invade
      // as vizinhas. É um preço que só o clímax do jogo paga.
      await tester.pumpWidget(hostTile(4));
      await tester.pumpAndSettle();

      for (final shadow in decorations(
        tester,
      ).expand((d) => d.boxShadow ?? const [])) {
        expect(shadow.spreadRadius, lessThanOrEqualTo(0.0));
      }
    });

    testWidgets('o número do ápice tem contorno mais grosso', (tester) async {
      // O dourado é a cor mais clara da paleta: o branco chega a ele em 1,4:1
      // e quem sustenta a leitura é o traço.
      double strokeOf(int digit) => tester
          .widgetList<Text>(find.text('$digit'))
          .firstWhere((t) => t.style?.foreground?.style == PaintingStyle.stroke)
          .style!
          .foreground!
          .strokeWidth;

      await tester.pumpWidget(hostTile(4));
      await tester.pumpAndSettle();
      final comum = strokeOf(4);

      await tester.pumpWidget(hostTile(kMaxDigit));
      await tester.pumpAndSettle();

      expect(strokeOf(kMaxDigit), greaterThan(comum));
    });
  });

  group('maior bloco no HUD do Endless', () {
    Future<void> pumpBanner(WidgetTester tester, int digit) =>
        tester.pumpWidget(
          MaterialApp(
            locale: kTestLocale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: EndlessBanner(
                state: EndlessState(board: Board.empty(), highestDigit: digit),
                highScore: 0,
                progression: const EndlessProgression(),
              ),
            ),
          ),
        );

    testWidgets('o selo do ápice nunca fica apagado', (tester) async {
      await pumpBanner(tester, kMaxDigit);
      await tester.pumpAndSettle();

      // Pela chave do selo, e não pelo primeiro `Container` sob a pílula: a
      // moldura da métrica também é um `Container` com decoração própria, e
      // depender da ordem da árvore faria o teste falhar a cada mudança de
      // layout sem que o fato medido mudasse.
      final decoration =
          tester
                  .widget<Container>(find.byKey(endlessBiggestTileKey))
                  .decoration!
              as BoxDecoration;

      expect(decoration.gradient, AppColors.apexGradient);
      expect(decoration.boxShadow, isNotEmpty);
    });

    testWidgets('a chegada do ápice anima o selo', (tester) async {
      await pumpBanner(tester, kMaxDigit - 1);
      await tester.pumpAndSettle();

      // A chave amarrada ao dígito é o que faz o `Tween` renascer — e é o que
      // dispara a animação sem estado nem controlador.
      await pumpBanner(tester, kMaxDigit);
      await tester.pump(const Duration(milliseconds: 450));

      final scale = tester
          .widgetList<Transform>(
            find.descendant(
              of: find.byKey(endlessBiggestKey),
              matching: find.byType(Transform),
            ),
          )
          .map((t) => t.transform.getMaxScaleOnAxis())
          .reduce((a, b) => a > b ? a : b);

      expect(scale, greaterThan(1.05), reason: 'o selo não pulsou');

      // A animação é finita: em repetição, `pumpAndSettle` nunca terminaria e
      // derrubaria a suíte de widget inteira.
      await tester.pumpAndSettle();
    });
  });
}
