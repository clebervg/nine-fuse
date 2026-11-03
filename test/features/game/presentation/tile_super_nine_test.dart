import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/special_tile.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';
import 'package:nine_fuse/features/game/presentation/widgets/tile_widget.dart';

/// O Super 9 precisa ser legível como peça especial — aro de gema e ouro e o
/// selo das jogadas que faltam para reverter —, e o 9 comum, não.
void main() {
  const position = Position(row: 0, col: 0);

  Future<void> pumpTile(WidgetTester tester, Tile tile) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 60,
            height: 60,
            child: TileWidget(key: const Key('t'), tile: tile, side: 60),
          ),
        ),
      ),
    );
    // Termina: o pulso de nascimento é finito.
    await tester.pumpAndSettle();
  }

  Tile superNine() => Tile.withSpecial(
    id: 's',
    value: kMaxDigit,
    position: position,
    specialType: SpecialTileType.superNine,
  );

  testWidgets('o 9 comum não tem aro nem selo', (tester) async {
    await pumpTile(
      tester,
      const Tile(id: 'n', value: kMaxDigit, position: position),
    );

    expect(find.byKey(superNineRingKey), findsNothing);
    expect(find.byKey(superNineTurnsKey), findsNothing);
  });

  testWidgets('o Super 9 tem aro e mostra as jogadas restantes', (
    tester,
  ) async {
    await pumpTile(tester, superNine());

    expect(find.byKey(superNineRingKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(superNineTurnsKey),
        matching: find.text('$kSpecialTileLifespan'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('o selo acompanha o decaimento: 3, 2, 1', (tester) async {
    var tile = superNine();
    for (var turns = kSpecialTileLifespan; turns >= 1; turns--) {
      await pumpTile(tester, tile);
      expect(
        find.descendant(
          of: find.byKey(superNineTurnsKey),
          matching: find.text('$turns'),
        ),
        findsOneWidget,
      );
      tile = tile.decaySpecial();
    }

    // Revertido: volta a ser um 9 comum, sem aro.
    await pumpTile(tester, tile);
    expect(tile.specialType, isNull);
    expect(find.byKey(superNineRingKey), findsNothing);
  });

  testWidgets('o aro não usa Opacity nem FadeTransition dentro da peça', (
    tester,
  ) async {
    await pumpTile(tester, superNine());

    final inTile = find.byKey(const Key('t'));
    for (final type in [Opacity, FadeTransition]) {
      expect(
        find.descendant(of: inTile, matching: find.byType(type)),
        findsNothing,
      );
    }
  });
}
