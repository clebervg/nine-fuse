import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';
import 'package:nine_fuse/features/game/presentation/screens/game_screen.dart';
import 'package:nine_fuse/features/game/presentation/widgets/level_start_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/moves_offer_dialog.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_state.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import '../../../support/localized.dart';

Board _boardFromValues(List<List<int>> values) {
  var board = Board.empty();
  for (int row = 0; row < Board.boardSize; row++) {
    for (int col = 0; col < Board.boardSize; col++) {
      final position = Position(row: row, col: col);
      board = board.updateTile(
        position,
        Tile(id: 'r${row}c$col', value: values[row][col], position: position),
      );
    }
  }
  return board;
}

/// A uma troca de fundir três peças de [value], em **L**.
Board _boardWithTrio(int value) {
  final grid = [
    for (int row = 0; row < Board.boardSize; row++)
      [for (int col = 0; col < Board.boardSize; col++) (row + col) % 3],
  ];
  grid[4][2] = value;
  grid[4][4] = value;
  grid[3][3] = value;
  return _boardFromValues(grid);
}

void _playTrio(void Function(Position, Position) swap) =>
    swap(const Position(row: 3, col: 3), const Position(row: 4, col: 3));

void main() {
  late GameNotifier notifier;

  /// Fase que chega ao limiar depois de uma única jogada.
  const tight = GameLevel(
    number: 42,
    objective: Objective(digit: 6, count: 99),
    moveLimit: kPreChurnMovesLeft + 1,
  );

  setUp(() {
    notifier = GameNotifier(random: Random(7), storage: InMemoryGameStorage());
  });

  Future<void> pumpGame(
    WidgetTester tester, {
    required Future<bool> Function() ad,
  }) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameProvider.overrideWith((ref) => notifier),
          movesAdProvider.overrideWithValue(ad),
        ],
        child: localizedApp(home: const GameScreen(level: tight)),
      ),
    );
    await tester.pumpAndSettle();
    if (find.byKey(startLevelKey).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(startLevelKey));
      await tester.pumpAndSettle();
    }
  }

  /// Leva a fase ao limiar de movimentos.
  Future<void> reachThreshold(WidgetTester tester) async {
    notifier.debugSetBoard(_boardWithTrio(5));
    _playTrio(notifier.swapTiles);
    await tester.pumpAndSettle();
  }

  testWidgets('o convite não aparece com a fase folgada', (tester) async {
    await pumpGame(tester, ad: () async => true);

    expect(find.byKey(movesOfferKey), findsNothing);
  });

  testWidgets('o convite sobe ao cruzar o limiar de movimentos', (
    tester,
  ) async {
    await pumpGame(tester, ad: () async => true);
    await reachThreshold(tester);

    expect(find.byKey(movesOfferKey), findsOneWidget);
  });

  testWidgets('assistir ao anúncio credita os movimentos e fecha o convite', (
    tester,
  ) async {
    await pumpGame(tester, ad: () async => true);
    await reachThreshold(tester);

    final before = notifier.state.movesLeft;
    final reward = notifier.state.rewardedMoves;

    // O número que o cartão promete tem de ser o que o crédito paga: é a
    // divergência que `rewardedMoves` existe para impedir. O `find` fica
    // escopado no próprio cartão do convite (`movesOfferKey`), para não casar
    // por acidente com o contador de movimentos ou o número da fase, que
    // também vivem na tela.
    expect(
      find.descendant(
        of: find.byKey(movesOfferKey),
        matching: find.textContaining('$reward'),
      ),
      findsWidgets,
    );

    await tester.tap(find.byKey(movesOfferWatchKey));
    await tester.pumpAndSettle();

    expect(notifier.state.movesLeft, before + reward);
    expect(find.byKey(movesOfferKey), findsNothing);
  });

  testWidgets('recusar fecha o convite sem cobrar nem pagar', (tester) async {
    await pumpGame(tester, ad: () async => true);
    await reachThreshold(tester);

    final before = notifier.state.movesLeft;
    await tester.tap(find.byKey(movesOfferDeclineKey));
    await tester.pumpAndSettle();

    expect(find.byKey(movesOfferKey), findsNothing);
    expect(notifier.state.movesLeft, before);
  });

  testWidgets('recusado, o convite não volta na jogada seguinte', (
    tester,
  ) async {
    // Sem a trava o convite reabriria a cada movimento enquanto o saldo ficasse
    // no limiar — um anúncio que se reoferece sozinho é o churn que ele deveria
    // estar evitando.
    await pumpGame(tester, ad: () async => true);
    await reachThreshold(tester);
    await tester.tap(find.byKey(movesOfferDeclineKey));
    await tester.pumpAndSettle();

    notifier.debugSetBoard(_boardWithTrio(5));
    _playTrio(notifier.swapTiles);
    await tester.pumpAndSettle();

    expect(find.byKey(movesOfferKey), findsNothing);
  });

  testWidgets('anúncio que não vem avisa sem fechar o convite', (tester) async {
    // Fechar na falha faria o jogador perder a única oferta da fase por culpa
    // da rede. A resposta pertence à pergunta que ele fez.
    await pumpGame(tester, ad: () async => false);
    await reachThreshold(tester);

    final before = notifier.state.movesLeft;
    await tester.tap(find.byKey(movesOfferWatchKey));
    await tester.pumpAndSettle();

    expect(find.byKey(movesOfferKey), findsOneWidget);
    expect(notifier.state.movesLeft, before);
  });
}
