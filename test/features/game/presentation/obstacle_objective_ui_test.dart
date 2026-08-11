import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';
import 'package:nine_fuse/features/game/presentation/screens/game_screen.dart';
import 'package:nine_fuse/features/game/presentation/widgets/level_banner.dart';
import 'package:nine_fuse/features/game/presentation/widgets/level_start_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/obstacle_overlay.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import '../../../support/localized.dart';

void main() {
  late GameNotifier notifier;

  /// Fase de limpeza: quebre 3 pedras.
  const stoneLevel = GameLevel(
    number: 11,
    objective: Objective.clearObstacles(
      obstacle: ObstacleType.stone,
      count: 3,
    ),
    moveLimit: 30,
    spawnMin: 1,
    spawnMax: 4,
    obstacles: ObstacleLayout(stone: 3),
  );

  setUp(() => notifier = GameNotifier(random: Random(42), storage: InMemoryGameStorage()));

  Future<void> pumpGame(WidgetTester tester, GameLevel level) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [gameProvider.overrideWith((ref) => notifier)],
        child: localizedApp(home: GameScreen(level: level)),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('cartão de início', () {
    testWidgets('mostra a cobertura-alvo em vez de uma peça-alvo', (
      tester,
    ) async {
      await pumpGame(tester, stoneLevel);

      expect(find.byKey(levelStartKey), findsOneWidget);
      expect(find.byKey(levelStartObstacleKey), findsOneWidget);
      // A textura de verdade, e não um ícone chapado: é o que liga o cartão ao
      // que o jogador vai ver no tabuleiro.
      expect(
        find.descendant(
          of: find.byKey(levelStartObstacleKey),
          matching: find.byType(ObstacleOverlay),
        ),
        findsOneWidget,
      );
    });

    testWidgets('o rótulo diz quantas coberturas e de que tipo', (tester) async {
      await pumpGame(tester, stoneLevel);

      expect(find.text('Quebre 3 pedras'), findsWidgets);
    });

    testWidgets('o plural do rótulo acompanha a quantidade', (tester) async {
      await pumpGame(
        tester,
        const GameLevel(
          number: 12,
          objective: Objective.clearObstacles(obstacle: ObstacleType.ice),
          moveLimit: 30,
          obstacles: ObstacleLayout(ice: 1),
        ),
      );

      expect(find.text('Quebre 1 gelo'), findsWidgets);
    });

    testWidgets('em "limpe todas" o número vem do pedido da fase', (
      tester,
    ) async {
      await pumpGame(
        tester,
        const GameLevel(
          number: 13,
          objective: Objective.clearAllObstacles(ObstacleType.glass),
          moveLimit: 30,
          obstacles: ObstacleLayout(glass: 2),
        ),
      );

      expect(find.text('Limpe o tabuleiro: 2 vidros'), findsWidgets);
    });
  });

  group('HUD', () {
    /// Fecha o cartão de início para o tabuleiro (e o HUD) aparecerem.
    Future<void> startPlaying(WidgetTester tester) async {
      await tester.tap(find.byKey(startLevelKey));
      await tester.pumpAndSettle();
    }

    testWidgets('a pílula do objetivo traz a cobertura e a contagem', (
      tester,
    ) async {
      await pumpGame(tester, stoneLevel);
      await startPlaying(tester);

      final pill = find.byKey(hudObjectiveKey);
      expect(pill, findsOneWidget);

      // A amostra da cobertura ocupa o lugar da peça-alvo.
      expect(
        find.descendant(of: pill, matching: find.byType(ObstacleBadge)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: pill, matching: find.text('0 de 3')),
        findsOneWidget,
      );
    });

    testWidgets('em "limpe todas" a contagem é a do tabuleiro sorteado', (
      tester,
    ) async {
      const level = GameLevel(
        number: 14,
        objective: Objective.clearAllObstacles(ObstacleType.ice),
        moveLimit: 30,
        obstacles: ObstacleLayout(ice: 4),
      );

      await pumpGame(tester, level);
      await startPlaying(tester);

      // O que o motor conseguiu pôr, não o que a fase pediu: coberturas não
      // nascem encostadas, então o pedido pode ter sido podado.
      final placed = notifier.state.board.countObstacles(ObstacleType.ice);

      expect(
        find.descendant(
          of: find.byKey(hudObjectiveKey),
          matching: find.text('0 de $placed'),
        ),
        findsOneWidget,
      );
    });
  });
}
