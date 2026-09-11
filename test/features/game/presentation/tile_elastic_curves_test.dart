import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';
import 'package:nine_fuse/features/game/presentation/widgets/board_grid_widget.dart';
import 'package:nine_fuse/features/game/presentation/widgets/tile_widget.dart';
import '../../../support/localized.dart';

/// Física tátil: a fusão "estoura a mola" (elástica) e a queda quica ao
/// chegar na célula.
void main() {
  const at = Position(row: 0, col: 0);

  testWidgets('a curva de queda/troca do tabuleiro é bounceOut', (
    tester,
  ) async {
    var board = Board.empty();
    for (int row = 0; row < Board.boardSize; row++) {
      for (int col = 0; col < Board.boardSize; col++) {
        final position = Position(row: row, col: col);
        board = board.updateTile(
          position,
          Tile(id: 'r${row}c$col', value: 3, position: position),
        );
      }
    }

    await tester.pumpWidget(
      localizedApp(home: Scaffold(body: BoardGridWidget(board: board))),
    );
    await tester.pumpAndSettle();

    final positioned = tester.widgetList<AnimatedPositioned>(
      find.byType(AnimatedPositioned),
    );
    expect(positioned, isNotEmpty);
    for (final p in positioned) {
      expect(p.curve, Curves.bounceOut);
    }
  });

  testWidgets(
    'o pulo da fusão estoura a mola: a escala oscila em vez de só desacelerar',
    (tester) async {
      Widget host(Tile tile) => localizedApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 60,
              height: 60,
              child: TileWidget(tile: tile, side: 60, animateEntrance: false),
            ),
          ),
        ),
      );

      await tester.pumpWidget(host(const Tile(id: 't3', value: 3, position: at)));
      await tester.pumpAndSettle();

      // Fusão: o valor muda, o `_controller` reinicia do zero.
      await tester.pumpWidget(host(const Tile(id: 't3', value: 4, position: at)));

      double scaleAt(Duration d) {
        return tester
            .widget<ScaleTransition>(find.byKey(tilePopKey))
            .scale
            .value;
      }

      final samples = <double>[];
      for (int i = 0; i < 12; i++) {
        await tester.pump(kTilePopDuration ~/ 12);
        samples.add(scaleAt(kTilePopDuration ~/ 12));
      }

      // `easeOut` (a curva anterior) nunca cruza abaixo de 1.0 vindo de cima —
      // desacelera monotonicamente até o alvo. `elasticOut` estoura a mola: em
      // algum quadro do retorno o valor passa por baixo de 1.0 antes de se
      // assentar. É essa oscilação que distingue as duas curvas aqui.
      expect(samples.any((s) => s < 0.995), isTrue, reason: 'amostras: $samples');

      await tester.pumpAndSettle();
    },
  );
}
