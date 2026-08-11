import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';
import 'package:nine_fuse/features/game/presentation/widgets/obstacle_overlay.dart';
import 'package:nine_fuse/features/game/presentation/widgets/tile_widget.dart';
import '../../../support/localized.dart';

void main() {
  const origin = Position(row: 0, col: 0);

  Future<void> pumpTile(WidgetTester tester, Tile tile) async {
    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 48,
              height: 48,
              child: TileWidget(tile: tile, side: 48),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Tile tile({ObstacleType obstacle = ObstacleType.none, int damage = 0}) {
    var result = const Tile(
      id: 't0',
      value: 4,
      position: origin,
    ).withObstacle(obstacle);
    for (int i = 0; i < damage; i++) {
      result = result.damageObstacle();
    }
    return result;
  }

  ObstacleOverlay overlay(WidgetTester tester) =>
      tester.widget<ObstacleOverlay>(find.byType(ObstacleOverlay));

  testWidgets('peça livre não ganha cobertura nenhuma', (tester) async {
    await pumpTile(tester, tile());

    expect(find.byType(ObstacleOverlay), findsNothing);
  });

  testWidgets('o gelo cobre a peça', (tester) async {
    await pumpTile(tester, tile(obstacle: ObstacleType.ice));

    expect(overlay(tester).type, ObstacleType.ice);
    expect(overlay(tester).cracked, isFalse);
  });

  testWidgets('o vidro só mostra a trinca depois do primeiro impacto', (
    tester,
  ) async {
    await pumpTile(tester, tile(obstacle: ObstacleType.glass));
    expect(overlay(tester).cracked, isFalse);

    await pumpTile(tester, tile(obstacle: ObstacleType.glass, damage: 1));
    expect(overlay(tester).type, ObstacleType.glass);
    expect(overlay(tester).cracked, isTrue);
  });

  testWidgets('a pedra cobre a peça', (tester) async {
    await pumpTile(tester, tile(obstacle: ObstacleType.stone));

    expect(overlay(tester).type, ObstacleType.stone);
  });

  testWidgets('a cobertura não usa Opacity nem FadeTransition', (tester) async {
    // Os testes de saída de peça e de clarão de combinação grande usam esses
    // tipos como marcadores; um a mais dentro da peça os quebraria em silêncio.
    await pumpTile(tester, tile(obstacle: ObstacleType.stone));

    // Escopo na peça: as transições de rota do MaterialApp usam FadeTransition
    // e não têm nada a ver com a cobertura.
    Finder insideTile(Type type) => find.descendant(
      of: find.byType(TileWidget),
      matching: find.byType(type),
    );

    expect(insideTile(Opacity), findsNothing);
    expect(insideTile(FadeTransition), findsNothing);
  });

  testWidgets('o número continua legível por baixo do gelo', (tester) async {
    // O dígito não some: o obstáculo prende a peça, não a substitui.
    await pumpTile(tester, tile(obstacle: ObstacleType.ice));

    expect(find.text('4'), findsWidgets);
  });
}
