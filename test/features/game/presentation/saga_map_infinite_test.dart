import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/level_catalog.dart';
import 'package:nine_fuse/features/game/presentation/screens/level_select_screen.dart';
import 'package:nine_fuse/features/game/presentation/widgets/saga_map.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

void main() {
  Widget host(List<GameLevel> levels, int progress) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SagaMapWidget(
              levels: levels,
              progress: progress,
              starsOf: (_) => 0,
              onTapLevel: (_) {},
            ),
          ),
        ),
      );

  testWidgets('o mapa não anuncia mais capítulo em breve', (tester) async {
    await tester.pumpWidget(host(
      [for (int n = 1; n <= 18; n++) levelAt(n)],
      10,
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Em Breve'), findsNothing);
    expect(find.textContaining('Coming Soon'), findsNothing);
  });

  // O nome promete "pins", não "pins projetados": a asserção original só
  // confirmava a existência da chave `levelCardKey`, que um `_FuturePin` (nó
  // projetado, sem chave, sem número e sem semântica de botão) jamais
  // satisfaria — mas não distinguia isso explicitamente. Aqui o teste checa
  // o conteúdo **dentro** do card com a chave da fase: a fase 11 (a próxima a
  // jogar, com progresso 10) traz o convite "JOGAR", e a 18 (bem à frente)
  // traz cadeado — os dois estados que só um pin de verdade tem.
  testWidgets('fases geradas além da fase 10 aparecem como pins de verdade, '
      'não como nós projetados', (tester) async {
    await tester.pumpWidget(host(
      [for (int n = 1; n <= 18; n++) levelAt(n)],
      10,
    ));
    await tester.pumpAndSettle();

    // O rótulo de "jogar" é `Positioned` **irmão** do card no `Stack` do pin
    // (âncora fixa à borda do círculo, não ao tamanho do card) — por isso a
    // busca é pela tela toda, e não `descendant` da chave. E aceita as duas
    // traduções: o ambiente de teste resolve o locale do sistema, que varia
    // com a máquina que roda a suíte.
    expect(find.byKey(levelCardKey(11)), findsOneWidget);
    expect(
      find.text('JOGAR').evaluate().isNotEmpty ||
          find.text('PLAY').evaluate().isNotEmpty,
      isTrue,
      reason: 'fase 11 é a próxima a jogar com progresso 10',
    );

    expect(find.byKey(levelCardKey(18)), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(levelCardKey(18)),
        matching: find.byIcon(Icons.lock_outline),
      ),
      findsOneWidget,
      reason: 'fase 18 ainda não foi vencida (progresso é 10)',
    );
  });

  testWidgets(
      'a tela do mapa abre sem quebrar e sem anunciar fim de conteúdo com '
      'progresso zero', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LevelSelectScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    // Com progresso zero a janela ainda tem de alcançar as dez artesanais.
    expect(find.byKey(levelCardKey(10)), findsOneWidget);
    expect(find.textContaining('Em Breve'), findsNothing);
    expect(find.textContaining('Coming Soon'), findsNothing);
  });
}
