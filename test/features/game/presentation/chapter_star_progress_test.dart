import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/campaign_chapter.dart';
import 'package:nine_fuse/features/game/presentation/widgets/chapter_star_progress.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';
import '../../../support/localized.dart';

void main() {
  // O capítulo 1 tem 6 fases, logo 18 estrelas em jogo.
  final chapter = kChapters.first;

  Future<void> pumpBar(
    WidgetTester tester, {
    required int starsInChapter,
    required int starsGained,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: kTestLocale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: ChapterStarProgress(
                chapter: chapter,
                starsInChapter: starsInChapter,
                starsGained: starsGained,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A fração que a barra desenha neste instante.
  double fillFactor(WidgetTester tester) => tester
      .widget<FractionallySizedBox>(find.byKey(chapterStarFillKey))
      .widthFactor!;

  testWidgets('mostra o capítulo e o par estrelas/total', (tester) async {
    await pumpBar(tester, starsInChapter: 12, starsGained: 3);
    await tester.pumpAndSettle();

    expect(find.text('Capítulo 1: Fusões Primárias'), findsOneWidget);
    expect(find.text('12/18'), findsOneWidget);
  });

  testWidgets('parte do total anterior e chega no novo', (tester) async {
    await pumpBar(tester, starsInChapter: 12, starsGained: 3);

    // Primeiro quadro: ainda no que o jogador tinha antes desta fase (9/18).
    expect(fillFactor(tester), closeTo(9 / 18, 0.001));

    // A animação é finita, então `pumpAndSettle` termina — e o fato de
    // terminar é parte do que este teste garante: animação em repetição
    // derrubaria a suíte inteira.
    await tester.pumpAndSettle();

    expect(fillFactor(tester), closeTo(12 / 18, 0.001));
  });

  testWidgets('sem ganho, a barra nasce parada no total', (tester) async {
    await pumpBar(tester, starsInChapter: 12, starsGained: 0);

    expect(fillFactor(tester), closeTo(12 / 18, 0.001));

    await tester.pumpAndSettle();

    expect(fillFactor(tester), closeTo(12 / 18, 0.001));
  });

  testWidgets('o capítulo cheio enche a barra', (tester) async {
    await pumpBar(tester, starsInChapter: 18, starsGained: 3);
    await tester.pumpAndSettle();

    expect(fillFactor(tester), closeTo(1, 0.001));
    expect(find.text('18/18'), findsOneWidget);
  });

  // "12/18" lido em voz alta não diz de que é a fração. O rótulo diz — e
  // `excludeSemantics` impede o leitor de anunciar a frase e depois o número
  // solto, defeito já corrigido no cabeçalho do mapa.
  testWidgets('anuncia a fração por extenso, uma vez só', (tester) async {
    await pumpBar(tester, starsInChapter: 12, starsGained: 3);
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel(
        '12 de 18 estrelas no Capítulo 1: Fusões Primárias.',
      ),
      findsOneWidget,
    );
  });
}
