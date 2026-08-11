import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';
import 'package:nine_fuse/features/game/presentation/screens/game_screen.dart';
import 'package:nine_fuse/features/game/presentation/widgets/board_grid_widget.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_button.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_offer_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_targeting_layer.dart';
import 'package:nine_fuse/features/game/presentation/widgets/juice_overlay.dart';
import 'package:nine_fuse/features/game/presentation/widgets/level_start_dialog.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import 'package:nine_fuse/features/game/providers/hammer_booster.dart';
import '../../../support/localized.dart';

void main() {
  late GameNotifier notifier;
  late InMemoryGameStorage storage;

  /// Fase folgada: a tela não pode acabar no meio do teste.
  const roomy = GameLevel(
    number: 42,
    objective: Objective(digit: 8, count: 9),
    moveLimit: 500,
  );

  // Linha alta de propósito: nesta janela de teste o hit-test só alcança a
  // metade de cima do tabuleiro, e é a região que o resto da suíte já usa.
  const target = Position(row: 1, col: 1);

  /// Tabuleiro estável com um `7` solitário na mira. O 7 está fora da janela de
  /// sorteio, então nenhuma reposição pode fabricar outro.
  Board stableBoard({ObstacleType? cover}) {
    var board = Board.empty();
    for (int row = 0; row < Board.boardSize; row++) {
      for (int col = 0; col < Board.boardSize; col++) {
        final position = Position(row: row, col: col);
        board = board.updateTile(
          position,
          Tile(
            id: 'r${row}c$col',
            value: position == target ? 7 : (row + col) % 3,
            position: position,
          ),
        );
      }
    }
    if (cover != null) {
      board = board.updateTile(
        target,
        board.getTileAt(target)!.withObstacle(cover),
      );
    }
    return board;
  }

  late void Function() realTargeting;
  late void Function() realRejection;

  setUp(() {
    realTargeting = HammerBooster.targetingFeedback;
    realRejection = HammerBooster.rejectionFeedback;
    HammerBooster.targetingFeedback = () {};
    HammerBooster.rejectionFeedback = () {};
    storage = InMemoryGameStorage();
    notifier = GameNotifier(random: Random(42), storage: storage);
  });

  tearDown(() {
    HammerBooster.targetingFeedback = realTargeting;
    HammerBooster.rejectionFeedback = realRejection;
  });

  /// Monta a tela da fase com [hammers] martelos em estoque.
  Future<void> pumpGame(
    WidgetTester tester, {
    int hammers = 1,
    Future<bool> Function()? ad,
    ObstacleType? cover,
  }) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameProvider.overrideWith((ref) => notifier),
          if (ad != null) hammerAdProvider.overrideWithValue(ad),
        ],
        child: localizedApp(home: const GameScreen(level: roomy)),
      ),
    );
    await tester.pumpAndSettle();
    if (find.byKey(startLevelKey).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(startLevelKey));
      await tester.pumpAndSettle();
    }

    if (hammers > 0) notifier.grantHammer(count: hammers);
    notifier.debugSetBoard(stableBoard(cover: cover));
    await tester.pumpAndSettle();
  }

  Future<void> tapTarget(WidgetTester tester) async {
    await tester.tap(find.byKey(tileKey(target)));
    await tester.pumpAndSettle();
  }

  group('botão do martelo', () {
    testWidgets('mostra o estoque no HUD', (tester) async {
      await pumpGame(tester, hammers: 2);

      expect(find.byKey(hammerButtonKey), findsOneWidget);
      expect(find.textContaining('2'), findsWidgets);
    });

    testWidgets('vira CANCELAR ao entrar em mira', (tester) async {
      await pumpGame(tester);

      await tester.tap(find.byKey(hammerButtonKey));
      await tester.pumpAndSettle();

      expect(notifier.state.isHammerTargeting, isTrue);
      expect(find.text('CANCELAR'), findsOneWidget);
    });

    testWidgets('o próprio botão cancela a mira', (tester) async {
      await pumpGame(tester);
      await tester.tap(find.byKey(hammerButtonKey));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(hammerButtonKey));
      await tester.pumpAndSettle();

      expect(notifier.state.isHammerTargeting, isFalse);
      expect(find.text('CANCELAR'), findsNothing);
    });

    testWidgets('não aparece na fase encerrada', (tester) async {
      // Um booster oferecido sobre o cartão de derrota promete o que não
      // cumpre: a fase já acabou.
      await pumpGame(tester);
      notifier.startLevel(
        const GameLevel(
          number: 41,
          objective: Objective(digit: 9),
          moveLimit: 1,
        ),
      );
      await tester.pumpAndSettle();
      if (find.byKey(startLevelKey).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(startLevelKey));
        await tester.pumpAndSettle();
      }
      final engine = notifier.engine!;
      final pair = engine
          .candidateSwaps(notifier.state.board)
          .firstWhere(
            (s) => engine.swapCreatesMatch(notifier.state.board, s.$1, s.$2),
          );
      notifier.swapTiles(pair.$1, pair.$2);
      await tester.pumpAndSettle();

      expect(notifier.state.isOver, isTrue);
      expect(find.byKey(hammerButtonKey), findsNothing);
    });
  });

  group('mira', () {
    testWidgets('o scrim escurece a tela e cancela ao ser tocado', (
      tester,
    ) async {
      await pumpGame(tester);
      await tester.tap(find.byKey(hammerButtonKey));
      await tester.pumpAndSettle();
      expect(find.byKey(hammerScrimKey), findsOneWidget);

      // Um toque à esquerda do tabuleiro: área vazia, e portanto scrim.
      await tester.tapAt(const Offset(100, 1300));
      await tester.pumpAndSettle();

      expect(notifier.state.isHammerTargeting, isFalse);
      expect(find.byKey(hammerScrimKey), findsNothing);
    });

    testWidgets('fora da mira não há scrim', (tester) async {
      await pumpGame(tester);

      expect(find.byKey(hammerScrimKey), findsNothing);
    });

    testWidgets('em mira, tocar a peça quebra a célula', (tester) async {
      await pumpGame(tester);
      await tester.tap(find.byKey(hammerButtonKey));
      await tester.pumpAndSettle();

      await tapTarget(tester);

      expect(
        notifier.state.board.getAllTiles().where((t) => t.value == 7),
        isEmpty,
      );
      expect(notifier.state.hammerCount, 0);
      expect(notifier.state.moves, 0, reason: 'o golpe não gasta movimento');
    });

    testWidgets('em mira, tocar a peça não a seleciona para troca', (
      tester,
    ) async {
      // Mira e seleção de troca não podem conviver: o toque tem um só destino.
      await pumpGame(tester, cover: ObstacleType.stone);
      await tester.tap(find.byKey(hammerButtonKey));
      await tester.pumpAndSettle();

      await tapTarget(tester);

      expect(notifier.state.selectedTile, isNull);
      expect(notifier.state.board.countObstacles(ObstacleType.stone), 0);
    });

    testWidgets('fora da mira, tocar a peça volta a selecionar', (
      tester,
    ) async {
      await pumpGame(tester);

      await tapTarget(tester);

      expect(notifier.state.selectedTile?.position, target);
      expect(notifier.state.hammerCount, 1, reason: 'nada foi cobrado');
    });
  });

  group('funil de conversão', () {
    testWidgets('sem estoque, mirar abre o convite com o alvo guardado', (
      tester,
    ) async {
      await pumpGame(tester, hammers: 0);
      await tester.tap(find.byKey(hammerButtonKey));
      await tester.pumpAndSettle();

      await tapTarget(tester);

      expect(find.byKey(hammerOfferKey), findsOneWidget);
      expect(notifier.state.pendingHammerTarget, target);
      expect(
        notifier.state.board.getTileAt(target)?.value,
        7,
        reason: 'nada é destruído antes de o martelo existir',
      );
    });

    testWidgets('assistir ao anúncio aplica no alvo já destacado', (
      tester,
    ) async {
      await pumpGame(tester, hammers: 0, ad: () async => true);
      await tester.tap(find.byKey(hammerButtonKey));
      await tester.pumpAndSettle();
      await tapTarget(tester);

      await tester.tap(find.byKey(hammerOfferWatchKey));
      await tester.pumpAndSettle();

      expect(
        notifier.state.board.getAllTiles().where((t) => t.value == 7),
        isEmpty,
      );
      expect(find.byKey(hammerOfferKey), findsNothing);
      expect(notifier.state.moves, 0);
    });

    testWidgets('anúncio que falha não cobra nem destrói', (tester) async {
      await pumpGame(tester, hammers: 0, ad: () async => false);
      await tester.tap(find.byKey(hammerButtonKey));
      await tester.pumpAndSettle();
      await tapTarget(tester);

      await tester.tap(find.byKey(hammerOfferWatchKey));
      await tester.pumpAndSettle();

      expect(notifier.state.board.getTileAt(target)?.value, 7);
      expect(notifier.state.hammerCount, 0);
    });

    testWidgets('recusar o convite descarta a mira e o alvo', (tester) async {
      await pumpGame(tester, hammers: 0);
      await tester.tap(find.byKey(hammerButtonKey));
      await tester.pumpAndSettle();
      await tapTarget(tester);

      await tester.tap(find.byKey(hammerOfferDeclineKey));
      await tester.pumpAndSettle();

      expect(find.byKey(hammerOfferKey), findsNothing);
      expect(notifier.state.pendingHammerTarget, isNull);
      expect(notifier.state.isHammerTargeting, isFalse);
    });
  });

  group('estilhaço', () {
    testWidgets('o golpe desenha o estilhaço na cor do dígito', (tester) async {
      await pumpGame(tester);
      await tester.tap(find.byKey(hammerButtonKey));
      await tester.pumpAndSettle();

      await tapTarget(tester);

      // O 7 é ciano: o estilhaço herda a cor da peça que morreu, senão o
      // jogador não liga o efeito ao que ele acabou de escolher quebrar.
      final effect = tester.widget<ShatterEffect>(find.byType(ShatterEffect));
      expect(effect.color, AppColors.getColorByDigit(7));
    });

    testWidgets('sem golpe não há estilhaço', (tester) async {
      await pumpGame(tester);

      expect(find.byType(ShatterEffect), findsNothing);
    });
  });

  group('persistência', () {
    testWidgets('o saldo gasto é gravado', (tester) async {
      await pumpGame(tester, hammers: 2);
      await tester.tap(find.byKey(hammerButtonKey));
      await tester.pumpAndSettle();

      await tapTarget(tester);
      await tester.pumpAndSettle();

      expect(storage.hammerCount, 1);
    });
  });
}
