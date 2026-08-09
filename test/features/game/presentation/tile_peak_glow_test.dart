import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';
import 'package:nine_fuse/features/game/presentation/widgets/board_grid_widget.dart';
import 'package:nine_fuse/features/game/presentation/widgets/tile_widget.dart';
import '../../../support/localized.dart';

/// Tabuleiro cheio de [filler], com [peaks] células trocadas por [peakValue].
Board boardWith({
  required int filler,
  required int peakValue,
  required int peaks,
}) {
  var board = Board.empty();
  var placed = 0;

  for (int row = 0; row < Board.boardSize; row++) {
    for (int col = 0; col < Board.boardSize; col++) {
      final position = Position(row: row, col: col);
      final isPeak = placed < peaks;
      if (isPeak) placed++;

      board = board.updateTile(
        position,
        Tile(
          id: 'r${row}c$col',
          value: isPeak ? peakValue : filler,
          position: position,
        ),
      );
    }
  }

  return board;
}

void main() {
  Future<void> pumpBoard(WidgetTester tester, Board board) async {
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(body: BoardGridWidget(board: board)),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// As peças marcadas como pico na árvore renderizada.
  Iterable<TileWidget> peakTiles(WidgetTester tester) => tester
      .widgetList<TileWidget>(find.byType(TileWidget))
      .where((t) => t.isPeak);

  testWidgets('a peça mais alta brilha quando é rara', (tester) async {
    await pumpBoard(tester, boardWith(filler: 1, peakValue: 7, peaks: 1));

    final glowing = peakTiles(tester).toList();

    expect(glowing, hasLength(1));
    expect(glowing.single.tile.value, 7);
  });

  testWidgets('o brilho vale para todas as peças empatadas no topo', (
    tester,
  ) async {
    await pumpBoard(
      tester,
      boardWith(filler: 1, peakValue: 7, peaks: kPeakGlowMaxTiles),
    );

    expect(peakTiles(tester), hasLength(kPeakGlowMaxTiles));
  });

  testWidgets('valor comum no topo não acende nada', (tester) async {
    // É o caso do tabuleiro recém-sorteado: o topo da janela de spawn aparece
    // numa peça em cada quatro. Acender dezesseis células não destacaria nada,
    // e o brilho perderia o significado justamente onde ele mais importa.
    await pumpBoard(
      tester,
      boardWith(filler: 1, peakValue: 3, peaks: kPeakGlowMaxTiles + 1),
    );

    expect(peakTiles(tester), isEmpty);
  });

  testWidgets('tabuleiro de valor único não acende', (tester) async {
    await pumpBoard(tester, boardWith(filler: 2, peakValue: 2, peaks: 0));

    expect(peakTiles(tester), isEmpty);
  });
}
