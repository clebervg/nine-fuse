import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/presentation/screens/level_select_screen.dart';
import 'package:nine_fuse/features/game/presentation/screens/splash_screen.dart';
import 'package:nine_fuse/features/game/providers/campaign_records.dart';
import 'package:nine_fuse/features/game/providers/endless_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';

import '../../../support/localized.dart';

void main() {
  testWidgets('chama onSplashComplete ao fim da animação, em vez de navegar',
      (tester) async {
    var completed = false;

    await tester.pumpWidget(
      localizedApp(
        home: SplashScreen(onSplashComplete: () => completed = true),
      ),
    );

    expect(completed, isFalse);

    // `kSplashDuration` exato não fecha o `AnimationController`: o primeiro
    // tick do ticker só ocorre no frame do `pump` seguinte ao `pumpWidget`
    // (o `forward()` roda durante o build, depois da fase de callbacks
    // transientes do frame do `pumpWidget`), então o controller nasce de pé
    // atrás em relação ao relógio falso do teste por um quantum de frame. Um
    // milissegundo de folga é suficiente e determinístico neste binding.
    await tester.pump(kSplashDuration + const Duration(milliseconds: 1));

    expect(completed, isTrue);
    expect(find.byType(LevelSelectScreen), findsNothing);
  });

  testWidgets('navega para LevelSelectScreen ao fim da animação por padrão',
      (tester) async {
    final storage = InMemoryGameStorage();
    final container = ProviderContainer(
      overrides: [
        endlessProvider.overrideWith(
          (ref) => EndlessNotifier(random: Random(1), storage: storage),
        ),
        campaignProgressProvider.overrideWith(
          (ref) => CampaignProgress(storage: storage),
        ),
        campaignRecordsProvider.overrideWith(
          (ref) => CampaignRecords(storage: storage),
        ),
        endlessHighScoreProvider.overrideWith(
          (ref) => EndlessHighScore(storage: storage),
        ),
      ],
    );
    addTearDown(container.dispose);

    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(home: const SplashScreen()),
      ),
    );

    expect(find.byType(LevelSelectScreen), findsNothing);

    await tester.pumpAndSettle();

    expect(find.byType(LevelSelectScreen), findsOneWidget);
  });
}
