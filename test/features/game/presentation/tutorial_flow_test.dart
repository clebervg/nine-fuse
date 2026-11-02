import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tutorial.dart';
import 'package:nine_fuse/features/game/presentation/l10n_labels.dart';
import 'package:nine_fuse/features/game/presentation/screens/game_screen.dart';
import 'package:nine_fuse/features/game/presentation/widgets/board_grid_widget.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_button.dart';
import 'package:nine_fuse/features/game/presentation/widgets/level_start_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/tutorial_layer.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import 'package:nine_fuse/features/game/providers/tutorial.dart';

import '../../../support/localized.dart';

void main() {
  late GameNotifier notifier;
  late InMemoryGameStorage storage;

  setUp(() {
    storage = InMemoryGameStorage();
  });

  /// Monta a fase [level] com o tutorial ligado sobre [storage] e aperta
  /// JOGAR. Não espera a tela assentar depois: a mão e o relógio dos balões
  /// são animações finitas, e cada teste decide até onde avançar.
  Future<void> pumpLevel(
    WidgetTester tester,
    GameLevel level, {
    int seed = 7,
  }) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Remontar do zero: sem isto a segunda chamada reaproveitaria o estado da
    // tela anterior (mesmo tipo, mesma posição) e o cartão de início não
    // voltaria.
    await tester.pumpWidget(const SizedBox());
    notifier = GameNotifier(
      random: Random(seed),
      storage: InMemoryGameStorage(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameProvider.overrideWith((ref) => notifier),
          tutorialStorageProvider.overrideWithValue(storage),
        ],
        child: localizedApp(home: GameScreen(level: level)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(startLevelKey));
    // Dois quadros: o do toque e o do balão que a checagem pós-quadro sobe.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // Mais um: a camada mede os alvos depois do próprio primeiro quadro.
    await tester.pump();
  }

  /// Joga a troca [a] → [b] pelo mesmo caminho do arrasto do dedo.
  Future<void> swipe(WidgetTester tester, Position a, Position b) async {
    tester.widget<BoardGridWidget>(find.byType(BoardGridWidget)).onTileSwipe!(
      a,
      b,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // Mais um: a camada mede os alvos depois do próprio primeiro quadro.
    await tester.pump();
  }

  final l10n = l10nFor();

  testWidgets('fase 1: a mão mostra uma troca válida, e só a primeira vez', (
    tester,
  ) async {
    final level = kCampaign.first;
    await pumpLevel(tester, level);

    expect(find.byKey(tutorialBalloonKey), findsOneWidget);
    expect(find.text(l10n.tutorialFirstSwap), findsOneWidget);
    expect(find.byKey(tutorialHandKey), findsOneWidget);
    expect(find.byKey(tutorialVeilKey), findsOneWidget);

    // A mão faz o gesto e para: `pumpAndSettle` termina com o balão no ar.
    await tester.pumpAndSettle();
    expect(find.text(l10n.tutorialFirstSwap), findsOneWidget);
    expect(storage.tutorialSeen, contains(TutorialStep.firstSwap.name));

    final (a, b) = notifier.tutorialSwapSuggestion(avoidResult: 4)!;
    expect(
      notifier.engine!.swapCreatesMatch(notifier.state.board, a, b),
      isTrue,
    );

    // Remontar a fase: o passo já foi visto, a mão não volta.
    await pumpLevel(tester, level, seed: 8);
    expect(find.text(l10n.tutorialFirstSwap), findsNothing);
  });

  testWidgets('fase 1: a fusão é contada com os valores da jogada, e o '
      'objetivo vem depois', (tester) async {
    final level = kCampaign.first;
    await pumpLevel(tester, level);

    final before = notifier.state.board;
    final (a, b) = notifier.tutorialSwapSuggestion(avoidResult: 4)!;
    final fusion = notifier.describeFusion(before, a, b)!;

    await swipe(tester, a, b);
    expect(notifier.state.moves, 1);
    expect(notifier.state.isOver, isFalse, reason: 'semente com fase viva');

    // A mão sumiu com a jogada; o balão da fusão traz os números reais.
    expect(find.text(l10n.tutorialFirstSwap), findsNothing);
    expect(find.byKey(tutorialHandKey), findsNothing);
    final amount = l10n.tutorialAmount(switch (fusion.count) {
      3 => 'three',
      4 => 'four',
      5 => 'five',
      _ => 'other',
    });
    expect(
      find.text(l10n.tutorialFusion(amount, fusion.from, fusion.to)),
      findsOneWidget,
    );

    await tester.tap(find.byKey(tutorialGotItKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final objective = l10n.tutorialObjective(
      l10n.objectiveLabel(level.objective),
    );
    expect(find.text(objective), findsOneWidget);
    expect(objective, 'Crie um 4 para vencer.');

    // O lembrete é leve: fecha sozinho, e nada mais sobe na fase 1.
    await tester.pump(kTutorialAutoClose);
    await tester.pumpAndSettle();
    expect(find.byKey(tutorialBalloonKey), findsNothing);
    expect(storage.tutorialSeen, containsAll(['fusion', 'objective']));
  });

  testWidgets('"Pular tutorial" marca todos os passos como vistos', (
    tester,
  ) async {
    await pumpLevel(tester, kCampaign.first);
    expect(find.byKey(tutorialBalloonKey), findsOneWidget);

    await tester.tap(find.byKey(tutorialSkipKey));
    await tester.pumpAndSettle();

    expect(find.byKey(tutorialBalloonKey), findsNothing);
    expect(storage.tutorialSeen, {
      for (final step in TutorialStep.values) step.name,
    });

    // Nem a fase 2 mostra mais nada.
    await pumpLevel(tester, kCampaign[1]);
    expect(find.byKey(tutorialBalloonKey), findsNothing);
  });

  testWidgets('fase 2: aponta as jogadas, e a troca recusada não gasta', (
    tester,
  ) async {
    await pumpLevel(tester, kCampaign[1]);
    expect(find.text(l10n.tutorialMovesMedallion), findsOneWidget);

    final board = notifier.state.board;
    final engine = notifier.engine!;
    final (a, b) = engine
        .candidateSwaps(board)
        .firstWhere(
          (pair) => !engine.swapCreatesMatch(board, pair.$1, pair.$2),
        );

    await swipe(tester, a, b);
    expect(notifier.state.moves, 0);
    expect(find.text(l10n.tutorialFreeMiss), findsOneWidget);
    expect(find.text(l10n.tutorialMovesMedallion), findsNothing);

    // Uma vez só: a segunda recusa não reabre o balão.
    await tester.tap(find.byKey(tutorialGotItKey));
    await tester.pumpAndSettle();
    await swipe(tester, a, b);
    expect(find.byKey(tutorialBalloonKey), findsNothing);
  });

  testWidgets('fase 3: aponta o dock, e usar o booster encerra o passo', (
    tester,
  ) async {
    await pumpLevel(tester, kCampaign[2]);
    expect(find.text(l10n.tutorialBoosterDock), findsOneWidget);

    await tester.tap(find.byKey(hammerButtonKey));
    await tester.pump();

    expect(find.byKey(tutorialBalloonKey), findsNothing);
    expect(storage.tutorialSeen, contains('boosterDock'));
  });

  testWidgets('estreia do gelo na fase 8: aponta uma célula coberta', (
    tester,
  ) async {
    // Quem chega à fase 8 já passou pelo resto do tutorial.
    storage.tutorialSeen = {'boosterDock'};
    await pumpLevel(tester, kCampaign[7]);

    expect(find.text(l10n.tutorialObstacleIce), findsOneWidget);
    expect(storage.tutorialSeen, contains('obstacleIce'));
  });

  testWidgets('sem disco ligado, a fase 1 não mostra tutorial nenhum', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final game = GameNotifier(
      random: Random(7),
      storage: InMemoryGameStorage(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [gameProvider.overrideWith((ref) => game)],
        child: localizedApp(home: GameScreen(level: kCampaign.first)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(startLevelKey));
    await tester.pumpAndSettle();

    expect(find.byKey(tutorialBalloonKey), findsNothing);
  });
}
