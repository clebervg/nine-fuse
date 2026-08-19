import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/presentation/screens/game_screen.dart';
import 'package:nine_fuse/features/game/presentation/widgets/endless_suggestion_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/level_start_dialog.dart';
import 'package:nine_fuse/features/game/providers/endless_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_state.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import '../../../support/localized.dart';
// `kMaxDigitForTest` mora em `game_notifier_test.dart`, não num arquivo de
// suporte compartilhado. O `show` evita colisão com o `main()` deste arquivo,
// que a importação completa da biblioteca de teste traria junto.
import '../providers/game_notifier_test.dart' show kMaxDigitForTest;

void main() {
  late GameNotifier notifier;

  /// Fase que trava em um movimento: qualquer combinação já esgota o saldo
  /// antes do objetivo (inalcançável) ser cumprido.
  const stuck = GameLevel(
    number: 95,
    objective: Objective(digit: kMaxDigitForTest, count: 9),
    moveLimit: 1,
  );

  setUp(() {
    notifier = GameNotifier(random: Random(7), storage: InMemoryGameStorage());
  });

  Future<void> pumpGame(
    WidgetTester tester, {
    required int campaignProgress,
  }) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameProvider.overrideWith((ref) => notifier),
          campaignProgressProvider.overrideWith(
            (ref) =>
                CampaignProgress(storage: InMemoryGameStorage())
                  ..complete(campaignProgress),
          ),
        ],
        child: localizedApp(home: const GameScreen(level: stuck)),
      ),
    );
    await tester.pumpAndSettle();
    if (find.byKey(startLevelKey).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(startLevelKey));
      await tester.pumpAndSettle();
    }
  }

  (Position, Position)? _swap() {
    final engine = notifier.engine!;
    final board = notifier.state.board;
    for (final (a, b) in engine.candidateSwaps(board)) {
      if (engine.swapCreatesMatch(board, a, b)) return (a, b);
    }
    return null;
  }

  Future<void> loseOnce(WidgetTester tester) async {
    final pair = _swap()!;
    notifier.swapTiles(pair.$1, pair.$2);
    await tester.pumpAndSettle();
  }

  Future<void> retry(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('retry_level')));
    await tester.pumpAndSettle();
  }

  testWidgets('não aparece antes da terceira derrota', (tester) async {
    await pumpGame(tester, campaignProgress: kEndlessUnlockLevel);
    await loseOnce(tester);

    expect(find.byKey(endlessSuggestionKey), findsNothing);
  });

  testWidgets('aparece na terceira derrota seguida, com o Endless liberado', (
    tester,
  ) async {
    await pumpGame(tester, campaignProgress: kEndlessUnlockLevel);
    await loseOnce(tester);
    await retry(tester);
    await loseOnce(tester);
    await retry(tester);
    await loseOnce(tester);

    expect(find.byKey(endlessSuggestionKey), findsOneWidget);
  });

  testWidgets('não aparece se o Endless ainda está bloqueado', (tester) async {
    await pumpGame(tester, campaignProgress: kEndlessUnlockLevel - 1);
    await loseOnce(tester);
    await retry(tester);
    await loseOnce(tester);
    await retry(tester);
    await loseOnce(tester);

    expect(find.byKey(endlessSuggestionKey), findsNothing);
  });

  testWidgets('recusar fecha o convite e mantém o cartão de desfecho', (
    tester,
  ) async {
    await pumpGame(tester, campaignProgress: kEndlessUnlockLevel);
    await loseOnce(tester);
    await retry(tester);
    await loseOnce(tester);
    await retry(tester);
    await loseOnce(tester);

    await tester.tap(find.byKey(endlessSuggestionDeclineKey));
    await tester.pumpAndSettle();

    expect(find.byKey(endlessSuggestionKey), findsNothing);
    expect(find.byKey(const Key('level_outcome')), findsOneWidget);
  });
}
