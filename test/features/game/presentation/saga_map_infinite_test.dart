import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/level_catalog.dart';
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

  testWidgets('mostra pins além da última fase artesanal', (tester) async {
    await tester.pumpWidget(host(
      [for (int n = 1; n <= 18; n++) levelAt(n)],
      10,
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(levelCardKey(11)), findsOneWidget);
    expect(find.byKey(levelCardKey(18)), findsOneWidget);
  });
}
