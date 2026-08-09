import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';
import 'package:nine_fuse/features/game/presentation/widgets/tile_widget.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';
import '../../../support/localized.dart';

/// Luminância relativa, conforme a WCAG.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  Widget host(int value, {bool selected = false}) => MaterialApp(
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
            isSelected: selected,
          ),
        ),
      ),
    ),
  );

  group('legibilidade do número', () {
    testWidgets('o número é branco em todos os dígitos', (tester) async {
      // Texto preto em umas peças e branco em outras quebra a hierarquia
      // visual: o olho gasta tempo processando a diferença.
      for (int digit = 0; digit <= kMaxDigit; digit++) {
        await tester.pumpWidget(host(digit));
        await tester.pumpAndSettle();

        final fills = tester
            .widgetList<Text>(find.text('$digit'))
            .where((t) => t.style?.color != null);

        expect(fills, isNotEmpty, reason: 'dígito $digit');
        for (final text in fills) {
          expect(text.style!.color, Colors.white, reason: 'dígito $digit');
        }
      }
    });

    testWidgets('todo número tem contorno escuro', (tester) async {
      // É o contorno que sustenta o branco uniforme. Sem ele o amarelo fica em
      // 1,40:1 e o prateado em 1,15:1 — bem abaixo do mínimo de 3:1.
      for (final digit in const [3, 9]) {
        await tester.pumpWidget(host(digit));
        await tester.pumpAndSettle();

        final stroked = tester
            .widgetList<Text>(find.text('$digit'))
            .where((t) => t.style?.foreground?.style == PaintingStyle.stroke);

        expect(stroked, hasLength(1), reason: 'dígito $digit sem contorno');
        expect(
          stroked.first.style!.foreground!.strokeWidth,
          greaterThan(2),
          reason: 'contorno fino demais para sustentar o branco',
        );
      }
    });

    test('todo dígito é legível, pelo branco ou pelo contorno', () {
      // A propriedade que importa não é "o contorno contrasta com tudo" — num
      // fundo escuro ele não contrasta, e nem precisa: ali quem faz a leitura
      // é o preenchimento branco. Basta que **um dos dois** passe.
      //
      // É por isso que o branco pode ser uniforme: no amarelo (branco a
      // 1,40:1) e no prateado (1,15:1) o contorno assume; no índigo e no roxo,
      // o branco.
      // 3:1 é o mínimo da WCAG para **texto grande**, que é o caso: 32px em
      // peso 900, bem acima do limiar de 14pt em negrito. O 4,5:1 vale para
      // texto corrido.
      const minimoTextoGrande = 3.0;

      for (int digit = 0; digit <= kMaxDigit; digit++) {
        final tile = AppColors.getColorByDigit(digit);
        final byFill = _contrast(Colors.white, tile);
        final byOutline = _contrast(kDigitOutline, tile);

        expect(
          math.max(byFill, byOutline),
          greaterThanOrEqualTo(minimoTextoGrande),
          reason:
              'dígito $digit ilegível: branco ${byFill.toStringAsFixed(2)}'
              ':1, contorno ${byOutline.toStringAsFixed(2)}:1',
        );
      }
    });

    test('o contorno separa o número do preenchimento branco', () {
      // Sem isso o glifo se dissolveria na peça clara mesmo tendo contorno.
      expect(_contrast(kDigitOutline, Colors.white), greaterThan(10));
    });

    test('as peças claras dependem mesmo do contorno', () {
      // Fixa o motivo de o contorno existir: se alguém remover, estes dois
      // dígitos passam a ter texto branco praticamente invisível.
      for (final digit in const [3, 9]) {
        expect(
          _contrast(Colors.white, AppColors.getColorByDigit(digit)),
          lessThan(2.0),
          reason: 'dígito $digit deixou de precisar do contorno — reveja',
        );
      }
    });
  });

  group('realce contido na célula', () {
    testWidgets('a seleção não usa sombra externa', (tester) async {
      await tester.pumpWidget(host(4, selected: true));
      await tester.pumpAndSettle();

      final decorated = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>();

      for (final decoration in decorated) {
        for (final shadow in decoration.boxShadow ?? const <BoxShadow>[]) {
          // Halo branco espalhado invadia as células vizinhas e parecia
          // defeito de renderização.
          expect(
            shadow.spreadRadius,
            lessThanOrEqualTo(0.0),
            reason: 'sombra se espalhando para fora da peça',
          );
        }
      }
    });

    testWidgets('a peça selecionada salta acima das vizinhas', (tester) async {
      await tester.pumpWidget(host(4));
      await tester.pumpAndSettle();
      final normal = tester.getSize(find.byType(TileWidget));

      await tester.pumpWidget(host(4, selected: true));
      await tester.pumpAndSettle();

      final scale = tester
          .widget<ScaleTransition>(
            find.descendant(
              of: find.byType(AnimatedScale),
              matching: find.byType(ScaleTransition),
            ),
          )
          .scale
          .value;

      expect(
        scale,
        greaterThan(1.0),
        reason: 'sem o salto, a seleção perde o destaque que o halo dava',
      );
      expect(normal.width, 60);
    });

    testWidgets('a borda de seleção fica dentro da peça', (tester) async {
      await tester.pumpWidget(host(4, selected: true));
      await tester.pumpAndSettle();

      final decoration = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => (d.border?.top.width ?? 0) > 0);

      expect(decoration.border!.top.strokeAlign, BorderSide.strokeAlignInside);
    });
  });
}
