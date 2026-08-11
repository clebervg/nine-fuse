import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/presentation/screens/game_screen.dart';
import 'package:nine_fuse/features/game/presentation/widgets/board_grid_widget.dart';
import 'package:nine_fuse/features/game/presentation/widgets/level_start_dialog.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_state.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import '../../../support/localized.dart';

void main() {
  late GameNotifier notifier;

  const level = GameLevel(
    number: 7,
    objective: Objective(digit: 6, count: 2),
    moveLimit: 14,
    teaches: LevelTip.zeroStopped,
  );

  setUp(() {
    notifier = GameNotifier(random: Random(42), storage: InMemoryGameStorage());
  });

  Future<void> pumpGame(WidgetTester tester, {GameLevel target = level}) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [gameProvider.overrideWith((ref) => notifier)],
        child: localizedApp(home: GameScreen(level: target)),
      ),
    );
    await tester.pumpAndSettle();
  }

  (Position, Position)? matchingSwap() {
    final engine = notifier.engine!;
    final board = notifier.state.board;
    for (final (a, b) in engine.candidateSwaps(board)) {
      if (engine.swapCreatesMatch(board, a, b)) return (a, b);
    }
    return null;
  }

  group('cartão de início de fase', () {
    testWidgets('abre sozinho, antes da primeira jogada', (tester) async {
      await pumpGame(tester);

      expect(find.byKey(levelStartKey), findsOneWidget);
      expect(find.text('Fase 7'), findsWidgets);
      expect(find.text('Crie 2 peças 6'), findsWidgets);
      expect(find.text('14 Movimentos'), findsOneWidget);
      expect(find.byKey(startLevelKey), findsOneWidget);
      expect(find.text('JOGAR'), findsOneWidget);
    });

    testWidgets('a dica da fase aparece no cartão', (tester) async {
      await pumpGame(tester);

      expect(find.text(l10nFor().tipZeroStopped), findsWidgets);
    });

    // O ponto do cartão: informar **antes** de o toque valer. Um dedo que
    // encoste fora dele não pode gastar movimento.
    testWidgets('o tabuleiro não aceita toque enquanto ele está aberto', (
      tester,
    ) async {
      await pumpGame(tester);

      final pair = matchingSwap()!;
      await tester.tap(find.byKey(tileKey(pair.$1)), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(tileKey(pair.$2)), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(notifier.state.moves, 0);
      expect(
        notifier.state.selectedTile,
        isNull,
        reason: 'nem a seleção deveria ter passado pelo cartão',
      );
    });

    testWidgets('"JOGAR" fecha o cartão e libera o tabuleiro', (tester) async {
      await pumpGame(tester);

      await tester.tap(find.byKey(startLevelKey));
      await tester.pumpAndSettle();

      expect(find.byKey(levelStartKey), findsNothing);

      final pair = matchingSwap()!;
      await tester.tap(find.byKey(tileKey(pair.$1)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(tileKey(pair.$2)));
      await tester.pumpAndSettle();

      expect(notifier.state.moves, 1);
    });

    // Ao tentar de novo o jogador pode ter esquecido o objetivo; ao avançar,
    // ele é outro. Nos dois casos a fase é nova e o cartão volta.
    testWidgets('volta a aparecer quando a fase recomeça', (tester) async {
      await pumpGame(tester);
      await tester.tap(find.byKey(startLevelKey));
      await tester.pumpAndSettle();
      expect(find.byKey(levelStartKey), findsNothing);

      notifier.restartLevel();
      await tester.pumpAndSettle();

      expect(find.byKey(levelStartKey), findsOneWidget);
    });

    testWidgets('mostra o objetivo da fase seguinte ao avançar', (
      tester,
    ) async {
      await pumpGame(tester, target: kCampaign.first);
      await tester.tap(find.byKey(startLevelKey));
      await tester.pumpAndSettle();

      notifier.nextLevel();
      await tester.pumpAndSettle();

      expect(find.byKey(levelStartKey), findsOneWidget);
      expect(find.text('Fase ${kCampaign[1].number}'), findsWidgets);
      expect(find.text(objectiveText(kCampaign[1].objective)), findsWidgets);
    });

    // Perder na primeira jogada não pode deixar cartão de início e cartão de
    // desfecho empilhados na tela.
    testWidgets('não convive com o cartão de fim de fase', (tester) async {
      const tight = GameLevel(
        number: 50,
        objective: Objective(digit: 9, count: 9),
        moveLimit: 1,
      );
      await pumpGame(tester, target: tight);
      await tester.tap(find.byKey(startLevelKey));
      await tester.pumpAndSettle();

      final pair = matchingSwap()!;
      await tester.tap(find.byKey(tileKey(pair.$1)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(tileKey(pair.$2)));
      await tester.pumpAndSettle();

      expect(notifier.state.status, GameStatus.lost);
      expect(find.byKey(const Key('level_outcome')), findsOneWidget);
      expect(find.byKey(levelStartKey), findsNothing);
    });

    testWidgets('cabe num iPhone SE sem estourar o layout', (tester) async {
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [gameProvider.overrideWith((ref) => notifier)],
          child: const MaterialApp(
            locale: kTestLocale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: GameScreen(
              // Limite de três dígitos: o rótulo mais longo que a fase pode ter.
              level: GameLevel(
                number: 51,
                objective: Objective(digit: 9, count: 9),
                moveLimit: 500,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // O botão principal precisa estar ao alcance do polegar, não abaixo da
      // dobra: `findsOneWidget` acharia um botão fora da tela.
      final rect = tester.getRect(find.byKey(startLevelKey));
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(rect.top, greaterThanOrEqualTo(0.0));
      expect(rect.bottom, lessThanOrEqualTo(screen.height));
      expect(rect.left, greaterThanOrEqualTo(0.0));
      expect(rect.right, lessThanOrEqualTo(screen.width));
    });
  });
}
