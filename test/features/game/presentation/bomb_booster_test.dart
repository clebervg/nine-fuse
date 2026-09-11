import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';
import 'package:nine_fuse/features/game/presentation/screens/game_screen.dart';
import 'package:nine_fuse/features/game/presentation/widgets/board_grid_widget.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_button.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_targeting_layer.dart';
import 'package:nine_fuse/features/game/presentation/widgets/level_start_dialog.dart';
import 'package:nine_fuse/features/game/providers/bomb_booster.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import '../../../support/localized.dart';

/// A Bomba: mesma máquina de mira do Martelo, área 3x3 em vez de célula
/// única, e sem o funil de aquisição (Modo Fantasma/anúncio) que o Martelo
/// tem.
void main() {
  late GameNotifier notifier;
  late InMemoryGameStorage storage;

  const roomy = GameLevel(
    number: 43,
    objective: Objective(digit: 8, count: 9),
    moveLimit: 500,
  );

  // Centro da área: linha alta o bastante para o hit-test alcançar (mesma
  // região que o teste do Martelo já usa), com folga de uma célula em volta
  // para o 3x3 inteiro caber no tabuleiro.
  const target = Position(row: 2, col: 2);

  /// Tabuleiro estável com valores fora da janela de sorteio na área da
  /// bomba, para nenhuma reposição fabricar um dígito igual por acidente.
  Board stableBoard() {
    var board = Board.empty();
    for (int row = 0; row < Board.boardSize; row++) {
      for (int col = 0; col < Board.boardSize; col++) {
        final position = Position(row: row, col: col);
        final inBlastZone =
            (row - target.row).abs() <= 1 && (col - target.col).abs() <= 1;
        board = board.updateTile(
          position,
          Tile(
            id: 'r${row}c$col',
            value: inBlastZone ? 7 : (row + col) % 3,
            position: position,
          ),
        );
      }
    }
    return board;
  }

  late void Function() realTargeting;
  late void Function() realRejection;
  late void Function() realStrike;

  setUp(() {
    realTargeting = BombBooster.targetingFeedback;
    realRejection = BombBooster.rejectionFeedback;
    realStrike = BombBooster.strikeFeedback;
    BombBooster.targetingFeedback = () {};
    BombBooster.rejectionFeedback = () {};
    BombBooster.strikeFeedback = () {};
    storage = InMemoryGameStorage();
    notifier = GameNotifier(random: Random(42), storage: storage);
  });

  tearDown(() {
    BombBooster.targetingFeedback = realTargeting;
    BombBooster.rejectionFeedback = realRejection;
    BombBooster.strikeFeedback = realStrike;
  });

  Future<void> pumpGame(WidgetTester tester, {int bombs = 1}) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [gameProvider.overrideWith((ref) => notifier)],
        child: localizedApp(home: const GameScreen(level: roomy)),
      ),
    );
    await tester.pumpAndSettle();
    if (find.byKey(startLevelKey).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(startLevelKey));
      await tester.pumpAndSettle();
    }

    if (bombs > 0) notifier.grantBomb(count: bombs);
    notifier.debugSetBoard(stableBoard());
    await tester.pumpAndSettle();
  }

  Future<void> tapTarget(WidgetTester tester) async {
    await tester.tap(find.byKey(tileKey(target)));
    await tester.pumpAndSettle();
  }

  group('botão da bomba', () {
    testWidgets('mostra o estoque no HUD', (tester) async {
      await pumpGame(tester, bombs: 3);

      expect(find.byKey(bombButtonKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(bombBadgeKey),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('vira X vermelho ao entrar em mira', (tester) async {
      await pumpGame(tester);

      await tester.tap(find.byKey(bombButtonKey));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(bombButtonKey),
          matching: find.byIcon(Icons.close_rounded),
        ),
        findsOneWidget,
      );
    });

    testWidgets('o próprio botão cancela a mira', (tester) async {
      await pumpGame(tester);

      await tester.tap(find.byKey(bombButtonKey));
      await tester.pumpAndSettle();
      expect(notifier.state.isBombTargeting, isTrue);

      await tester.tap(find.byKey(bombButtonKey));
      await tester.pumpAndSettle();
      expect(notifier.state.isBombTargeting, isFalse);
    });

    testWidgets('sem estoque, o toque recusa e não entra em mira', (
      tester,
    ) async {
      await pumpGame(tester, bombs: 0);

      await tester.tap(find.byKey(bombButtonKey));
      await tester.pumpAndSettle();

      expect(notifier.state.isBombTargeting, isFalse);
    });
  });

  group('mira em área', () {
    testWidgets('o destaque cobre um 3x3, não uma célula só', (tester) async {
      await pumpGame(tester);

      await tester.tap(find.byKey(bombButtonKey));
      await tester.pumpAndSettle();

      final layer = tester.widget<HammerTargetingLayer>(
        find.byType(HammerTargetingLayer),
      );
      expect(layer.areaRadius, 1);

      // Com o dedo na tela (sem soltar), nada foi destruído ainda — é só a
      // prévia visual do 3x3 que muda.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(tileKey(target))),
      );
      await tester.pump();
      expect(
        notifier.state.board.getAllTiles().where((t) => t.value == 7),
        isNotEmpty,
        reason: 'com o dedo na tela nada foi destruído',
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('o toque explode o 3x3 inteiro em vez de uma célula', (
      tester,
    ) async {
      await pumpGame(tester);
      await tester.tap(find.byKey(bombButtonKey));
      await tester.pumpAndSettle();

      await tapTarget(tester);

      // As nove células da zona (valor 7, fora da janela de sorteio normal)
      // não sobrevivem — se a bomba só tivesse limpado o centro, ao menos
      // algumas ainda teriam valor 7.
      expect(
        notifier.state.board.getAllTiles().where((t) => t.value == 7),
        isEmpty,
      );
      expect(notifier.state.bombCount, 0);
      expect(notifier.state.moves, 0, reason: 'a bomba não gasta movimento');
    });

    testWidgets('em mira, tocar o tabuleiro não seleciona para troca', (
      tester,
    ) async {
      await pumpGame(tester);
      await tester.tap(find.byKey(bombButtonKey));
      await tester.pumpAndSettle();

      await tapTarget(tester);

      expect(notifier.state.selectedTile, isNull);
    });

    testWidgets('arrastar para fora do tabuleiro e soltar cancela', (
      tester,
    ) async {
      await pumpGame(tester);
      await tester.tap(find.byKey(bombButtonKey));
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(tileKey(target))),
      );
      await tester.pump();
      await gesture.moveTo(const Offset(100, 1300));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(notifier.state.isBombTargeting, isFalse);
      expect(notifier.state.bombCount, 1, reason: 'desistir não cobra');
    });
  });

  group('tranco do golpe', () {
    testWidgets('o tabuleiro sacode e volta ao lugar', (tester) async {
      await pumpGame(tester);
      final before = notifier.state.bombStrikes;

      await tester.tap(find.byKey(bombButtonKey));
      await tester.pumpAndSettle();
      await tapTarget(tester);

      expect(notifier.state.bombStrikes, greaterThan(before));

      await tester.pumpAndSettle();
      final board = tester.getTopLeft(find.byType(BoardGridWidget));
      expect(board, isNotNull);
    });
  });

  group('persistência', () {
    testWidgets('o saldo gasto é gravado', (tester) async {
      await pumpGame(tester, bombs: 2);
      await tester.tap(find.byKey(bombButtonKey));
      await tester.pumpAndSettle();

      await tapTarget(tester);
      await tester.pumpAndSettle();

      expect(storage.bombCount, 1);
    });
  });
}
