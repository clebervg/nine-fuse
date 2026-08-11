import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';
import 'package:nine_fuse/features/game/presentation/widgets/board_geometry.dart';
import 'package:nine_fuse/features/game/presentation/widgets/board_grid_widget.dart';
import 'package:nine_fuse/features/game/presentation/widgets/tile_widget.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';
import '../../../support/localized.dart';

/// Monta um tabuleiro em que o id de cada peça é `r{linha}c{coluna}` e o valor
/// vem da matriz, para os testes poderem endereçar peças por id.
Board boardOf(List<List<int>> values) {
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

List<List<int>> plainGrid() => [
  for (int row = 0; row < Board.boardSize; row++)
    [for (int col = 0; col < Board.boardSize; col++) (row + col) % 3],
];

void main() {
  /// Canto da peça **como ela é pintada**.
  ///
  /// Tem de descer até o widget da peça: o empurrão da troca recusada é um
  /// `Transform.translate`, que desloca o filho na pintura mas deixa o próprio
  /// nó no lugar. Medir o nó de fora não veria movimento nenhum.
  Offset tileCorner(WidgetTester tester, String tileId) => tester.getTopLeft(
    find.descendant(
      of: find.byKey(tileVisualKey(tileId)),
      matching: find.byType(TileWidget),
    ),
  );

  /// Envolve o tabuleiro num tamanho fixo, para as coordenadas serem estáveis.
  Widget host({
    required Board board,
    Tile? selectedTile,
    (Position, Position)? rejectedSwap,
    (Position, Position)? hint,
    Set<String> bigFusionTileIds = const {},
    bool hintEnabled = true,
    void Function(Position)? onTileTap,
    void Function(Position, Position)? onTileSwipe,
  }) => MaterialApp(
    locale: kTestLocale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 400,
          height: 400,
          child: BoardGridWidget(
            board: board,
            selectedTile: selectedTile,
            rejectedSwap: rejectedSwap,
            hint: hint,
            bigFusionTileIds: bigFusionTileIds,
            hintEnabled: hintEnabled,
            onTileTap: onTileTap,
            onTileSwipe: onTileSwipe,
          ),
        ),
      ),
    ),
  );

  group('desenho', () {
    testWidgets('desenha uma peça por célula', (tester) async {
      await tester.pumpWidget(host(board: boardOf(plainGrid())));
      await tester.pumpAndSettle();

      expect(find.byType(TileWidget), findsNWidgets(64));
    });

    testWidgets('cada peça tem chave própria pelo seu id', (tester) async {
      await tester.pumpWidget(host(board: boardOf(plainGrid())));
      await tester.pumpAndSettle();

      // Amarrar o desenho ao id é o que permite ao Flutter reaproveitar o
      // widget quando a peça muda de lugar, e assim interpolar o movimento.
      expect(find.byKey(tileVisualKey('r0c0')), findsOneWidget);
      expect(find.byKey(tileVisualKey('r7c7')), findsOneWidget);
    });

    testWidgets('a peça selecionada aparece realçada', (tester) async {
      final board = boardOf(plainGrid());
      final selected = board.getTileAt(Position(row: 2, col: 3))!;

      await tester.pumpWidget(host(board: board, selectedTile: selected));
      await tester.pumpAndSettle();

      final highlighted = tester.widget<TileWidget>(
        find.descendant(
          of: find.byKey(tileVisualKey(selected.id)),
          matching: find.byType(TileWidget),
        ),
      );
      expect(highlighted.isSelected, isTrue);

      final other = tester.widget<TileWidget>(
        find.descendant(
          of: find.byKey(tileVisualKey('r0c0')),
          matching: find.byType(TileWidget),
        ),
      );
      expect(other.isSelected, isFalse);
    });
  });

  group('toque', () {
    testWidgets('o toque é endereçado por posição, não por peça', (
      tester,
    ) async {
      final tapped = <Position>[];

      await tester.pumpWidget(
        host(board: boardOf(plainGrid()), onTileTap: tapped.add),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(tileKey(Position(row: 3, col: 5))));
      await tester.pump();

      expect(tapped, [Position(row: 3, col: 5)]);
    });

    testWidgets('há uma área tocável para cada uma das 64 células', (
      tester,
    ) async {
      await tester.pumpWidget(host(board: boardOf(plainGrid())));
      await tester.pumpAndSettle();

      for (int row = 0; row < Board.boardSize; row++) {
        for (int col = 0; col < Board.boardSize; col++) {
          expect(
            find.byKey(tileKey(Position(row: row, col: col))),
            findsOneWidget,
          );
        }
      }
    });
  });

  group('arrastar o dedo', () {
    /// Arrasta a partir do centro da célula [from] por [delta].
    Future<void> dragFrom(
      WidgetTester tester,
      Position from,
      Offset delta,
    ) async {
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(tileKey(from))),
      );
      // Em passos: um único movimento grande pode ser lido como fling.
      await gesture.moveBy(delta / 4);
      await gesture.moveBy(delta / 4);
      await gesture.moveBy(delta / 4);
      await gesture.moveBy(delta / 4);
      await gesture.up();
      await tester.pump();
    }

    /// Lado da célula, para calibrar o arraste ao tamanho real.
    double cellSide(WidgetTester tester) =>
        tester.getSize(find.byKey(tileKey(Position(row: 0, col: 0)))).width;

    testWidgets('arrastar para a direita troca com a vizinha da direita', (
      tester,
    ) async {
      final swaps = <(Position, Position)>[];
      await tester.pumpWidget(
        host(
          board: boardOf(plainGrid()),
          onTileSwipe: (a, b) => swaps.add((a, b)),
        ),
      );
      await tester.pump();

      await dragFrom(
        tester,
        Position(row: 3, col: 3),
        Offset(cellSide(tester), 0),
      );

      expect(swaps, [(Position(row: 3, col: 3), Position(row: 3, col: 4))]);
    });

    testWidgets('arrastar para baixo troca com a vizinha de baixo', (
      tester,
    ) async {
      final swaps = <(Position, Position)>[];
      await tester.pumpWidget(
        host(
          board: boardOf(plainGrid()),
          onTileSwipe: (a, b) => swaps.add((a, b)),
        ),
      );
      await tester.pump();

      await dragFrom(
        tester,
        Position(row: 3, col: 3),
        Offset(0, cellSide(tester)),
      );

      expect(swaps, [(Position(row: 3, col: 3), Position(row: 4, col: 3))]);
    });

    testWidgets('arrastar para cima e para a esquerda também funciona', (
      tester,
    ) async {
      final swaps = <(Position, Position)>[];
      await tester.pumpWidget(
        host(
          board: boardOf(plainGrid()),
          onTileSwipe: (a, b) => swaps.add((a, b)),
        ),
      );
      await tester.pump();

      final side = cellSide(tester);
      await dragFrom(tester, Position(row: 3, col: 3), Offset(0, -side));
      await dragFrom(tester, Position(row: 3, col: 3), Offset(-side, 0));

      expect(swaps, [
        (Position(row: 3, col: 3), Position(row: 2, col: 3)),
        (Position(row: 3, col: 3), Position(row: 3, col: 2)),
      ]);
    });

    testWidgets('o eixo dominante decide a direção do arraste na diagonal', (
      tester,
    ) async {
      final swaps = <(Position, Position)>[];
      await tester.pumpWidget(
        host(
          board: boardOf(plainGrid()),
          onTileSwipe: (a, b) => swaps.add((a, b)),
        ),
      );
      await tester.pump();

      final side = cellSide(tester);
      // Mais horizontal que vertical: vale a horizontal.
      await dragFrom(tester, Position(row: 3, col: 3), Offset(side, side / 3));

      expect(swaps, [(Position(row: 3, col: 3), Position(row: 3, col: 4))]);
    });

    testWidgets('tremor de dedo não conta como arraste', (tester) async {
      final swaps = <(Position, Position)>[];
      await tester.pumpWidget(
        host(
          board: boardOf(plainGrid()),
          onTileSwipe: (a, b) => swaps.add((a, b)),
        ),
      );
      await tester.pump();

      await dragFrom(tester, Position(row: 3, col: 3), const Offset(3, 2));

      expect(swaps, isEmpty);
    });

    testWidgets('um gesto vale uma troca só', (tester) async {
      final swaps = <(Position, Position)>[];
      await tester.pumpWidget(
        host(
          board: boardOf(plainGrid()),
          onTileSwipe: (a, b) => swaps.add((a, b)),
        ),
      );
      await tester.pump();

      // Arrasto longo, atravessando várias células: manter o dedo apertado não
      // pode disparar trocas em sequência.
      await dragFrom(
        tester,
        Position(row: 3, col: 3),
        Offset(cellSide(tester) * 3, 0),
      );

      expect(swaps, hasLength(1));
    });

    testWidgets('arrastar para fora do tabuleiro não faz nada', (tester) async {
      final swaps = <(Position, Position)>[];
      await tester.pumpWidget(
        host(
          board: boardOf(plainGrid()),
          onTileSwipe: (a, b) => swaps.add((a, b)),
        ),
      );
      await tester.pump();

      // A peça do canto não tem vizinha à esquerda.
      await dragFrom(
        tester,
        Position(row: 0, col: 0),
        Offset(-cellSide(tester), 0),
      );

      expect(swaps, isEmpty);
    });

    testWidgets('o toque continua funcionando ao lado do arraste', (
      tester,
    ) async {
      final tapped = <Position>[];
      final swaps = <(Position, Position)>[];

      await tester.pumpWidget(
        host(
          board: boardOf(plainGrid()),
          onTileTap: tapped.add,
          onTileSwipe: (a, b) => swaps.add((a, b)),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(tileKey(Position(row: 1, col: 1))));
      await tester.pump();

      expect(tapped, [Position(row: 1, col: 1)]);
      expect(swaps, isEmpty);
    });
  });

  group('tamanho da célula', () {
    /// Lado da célula com [available] pontos de largura disponíveis.
    Future<double> cellSideAt(WidgetTester tester, double available) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: kTestLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: available,
                child: BoardGridWidget(board: boardOf(plainGrid())),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return tester
          .getSize(find.byKey(tileKey(Position(row: 0, col: 0))))
          .width;
    }

    // Larguras de tela menos a margem lateral usada pelas telas de jogo.
    const devices = {
      'iPhone SE': 375.0 - 16,
      'iPhone 15/16': 393.0 - 16,
      'iPhone 16 Pro': 402.0 - 16,
      'iPhone Pro Max': 430.0 - 16,
    };

    testWidgets('o tabuleiro não desperdiça largura disponível', (
      tester,
    ) async {
      // É isto que o layout controla de fato. Num 8x8 o alvo de 44pt é
      // inalcançável em tela pequena — 8 células de 44 já somam 352pt — então
      // o que se pode exigir é que nenhum ponto seja jogado fora.
      for (final entry in devices.entries) {
        final side = await cellSideAt(tester, entry.value);
        final usado = side * Board.boardSize;

        expect(
          usado / entry.value,
          greaterThan(0.9),
          reason:
              '${entry.key}: o tabuleiro só usa '
              '${(usado / entry.value * 100).round()}% da largura',
        );
      }
    });

    testWidgets('a célula alcança o alvo de toque nos aparelhos onde cabe', (
      tester,
    ) async {
      for (final name in ['iPhone 16 Pro', 'iPhone Pro Max']) {
        final side = await cellSideAt(tester, devices[name]!);

        expect(
          side,
          greaterThanOrEqualTo(kMinTouchTarget),
          reason: '$name regrediu para ${side.toStringAsFixed(1)}pt',
        );
      }
    });

    testWidgets('em tela pequena a célula fica abaixo do alvo, como esperado', (
      tester,
    ) async {
      // Documenta a limitação em vez de escondê-la: se um dia o tabuleiro
      // encolher para 7x7, ou a margem sumir, este teste avisa que a situação
      // mudou e o comentário acima precisa ser revisto.
      final se = await cellSideAt(tester, devices['iPhone SE']!);

      expect(se, lessThan(kMinTouchTarget));
      expect(
        se,
        greaterThan(40),
        reason: 'abaixo disso o toque fica inviável mesmo com arraste',
      );
    });

    testWidgets('em tela larga o tabuleiro para de crescer', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: kTestLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 1200,
                child: BoardGridWidget(board: boardOf(plainGrid())),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final board = tester.getSize(find.byType(BoardGridWidget));
      expect(board.width, lessThanOrEqualTo(1200));

      final side = tester
          .getSize(find.byKey(tileKey(Position(row: 0, col: 0))))
          .width;
      expect(side, lessThan(kMaxBoardSide / Board.boardSize + 1));
    });
  });

  group('queda das peças', () {
    testWidgets('uma peça que muda de linha desliza até o lugar novo', (
      tester,
    ) async {
      final grid = plainGrid();
      var board = boardOf(grid);

      await tester.pumpWidget(host(board: board));
      await tester.pumpAndSettle();

      final start = tileCorner(tester, 'r0c0');

      // A mesma peça (mesmo id) passa a ocupar a linha 4.
      final moved = board.getTileAt(Position(row: 0, col: 0))!;
      board = board
          .updateTile(Position(row: 0, col: 0), null)
          .updateTile(
            Position(row: 4, col: 0),
            moved.moveTo(Position(row: 4, col: 0)),
          );

      await tester.pumpWidget(host(board: board));
      // No meio da animação a peça tem de estar entre as duas posições.
      await tester.pump(kTileMoveDuration ~/ 2);

      final middle = tileCorner(tester, 'r0c0');
      expect(
        middle.dy,
        greaterThan(start.dy),
        reason: 'a peça deveria ter começado a descer',
      );

      await tester.pumpAndSettle();
      final end = tileCorner(tester, 'r0c0');
      expect(
        end.dy,
        greaterThan(middle.dy),
        reason: 'a peça deveria ter continuado até o destino',
      );
    });
  });

  group('troca recusada', () {
    testWidgets('as peças avançam uma para a outra e voltam', (tester) async {
      final board = boardOf(plainGrid());
      const a = Position(row: 0, col: 0);
      const b = Position(row: 0, col: 1);

      await tester.pumpWidget(host(board: board));
      await tester.pumpAndSettle();

      final resting = tileCorner(tester, 'r0c0');

      await tester.pumpWidget(host(board: board, rejectedSwap: (a, b)));
      await tester.pump(kRejectedSwapDuration ~/ 2);

      final nudged = tileCorner(tester, 'r0c0');
      expect(
        nudged.dx,
        greaterThan(resting.dx),
        reason: 'a peça em (0,0) deveria andar na direção de (0,1)',
      );

      await tester.pumpAndSettle();

      final back = tileCorner(tester, 'r0c0');
      expect(
        back.dx,
        closeTo(resting.dx, 0.5),
        reason: 'a peça deveria ter voltado ao lugar',
      );
    });

    testWidgets('a peça parceira anda no sentido contrário', (tester) async {
      final board = boardOf(plainGrid());
      const a = Position(row: 0, col: 0);
      const b = Position(row: 0, col: 1);

      await tester.pumpWidget(host(board: board));
      await tester.pumpAndSettle();
      final resting = tileCorner(tester, 'r0c1');

      await tester.pumpWidget(host(board: board, rejectedSwap: (a, b)));
      await tester.pump(kRejectedSwapDuration ~/ 2);

      final nudged = tileCorner(tester, 'r0c1');
      expect(nudged.dx, lessThan(resting.dx));

      await tester.pumpAndSettle();
    });

    testWidgets('peças fora da troca não se movem', (tester) async {
      final board = boardOf(plainGrid());

      await tester.pumpWidget(host(board: board));
      await tester.pumpAndSettle();
      final resting = tileCorner(tester, 'r5c5');

      await tester.pumpWidget(
        host(
          board: board,
          rejectedSwap: (Position(row: 0, col: 0), Position(row: 0, col: 1)),
        ),
      );
      await tester.pump(kRejectedSwapDuration ~/ 2);

      expect(tileCorner(tester, 'r5c5'), resting);
      await tester.pumpAndSettle();
    });

    testWidgets('uma troca vertical recusada empurra na vertical', (
      tester,
    ) async {
      final board = boardOf(plainGrid());

      await tester.pumpWidget(host(board: board));
      await tester.pumpAndSettle();
      final resting = tileCorner(tester, 'r0c0');

      await tester.pumpWidget(
        host(
          board: board,
          rejectedSwap: (Position(row: 0, col: 0), Position(row: 1, col: 0)),
        ),
      );
      await tester.pump(kRejectedSwapDuration ~/ 2);

      final nudged = tileCorner(tester, 'r0c0');
      expect(nudged.dy, greaterThan(resting.dy));
      expect(nudged.dx, closeTo(resting.dx, 0.5));

      await tester.pumpAndSettle();
    });
  });

  group('saída das peças eliminadas', () {
    /// Remove três peças, como uma fusão faria.
    Board withoutTrio(Board board) => board
        .updateTile(Position(row: 5, col: 1), null)
        .updateTile(Position(row: 5, col: 2), null)
        .updateTile(Position(row: 5, col: 3), null);

    testWidgets('a peça consumida continua desenhada enquanto desaparece', (
      tester,
    ) async {
      final board = boardOf(plainGrid());
      await tester.pumpWidget(host(board: board));
      await tester.pumpAndSettle();

      await tester.pumpWidget(host(board: withoutTrio(board)));
      await tester.pump(kTileExitDuration ~/ 3);

      // Sem isso a peça sumiria de um frame para o outro — e com as vizinhas
      // deslizando suavemente, o corte seco fica mais visível, não menos.
      expect(find.byKey(tileExitKey('r5c2')), findsOneWidget);
    });

    testWidgets('a peça vai apagando ao longo da saída', (tester) async {
      final board = boardOf(plainGrid());
      await tester.pumpWidget(host(board: board));
      await tester.pumpAndSettle();

      await tester.pumpWidget(host(board: withoutTrio(board)));

      double opacityOf(String id) => tester
          .widget<Opacity>(
            find.descendant(
              of: find.byKey(tileExitKey(id)),
              matching: find.byType(Opacity),
            ),
          )
          .opacity;

      await tester.pump(kTileExitDuration ~/ 4);
      final early = opacityOf('r5c2');

      await tester.pump(kTileExitDuration ~/ 2);
      expect(
        opacityOf('r5c2'),
        lessThan(early),
        reason: 'a peça deveria estar mais apagada com o tempo',
      );

      await tester.pumpAndSettle();
    });

    testWidgets('o rastro é removido ao fim da saída', (tester) async {
      final board = boardOf(plainGrid());
      await tester.pumpWidget(host(board: board));
      await tester.pumpAndSettle();

      await tester.pumpWidget(host(board: withoutTrio(board)));
      await tester.pumpAndSettle();

      // Contraprova: o rastro não pode ficar no tabuleiro para sempre.
      expect(find.byKey(tileExitKey('r5c2')), findsNothing);
      expect(find.byType(TileWidget), findsNWidgets(61));
    });

    testWidgets('o rastro não intercepta toque', (tester) async {
      final tapped = <Position>[];
      final board = boardOf(plainGrid());

      await tester.pumpWidget(host(board: board, onTileTap: tapped.add));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        host(board: withoutTrio(board), onTileTap: tapped.add),
      );
      await tester.pump(kTileExitDuration ~/ 3);

      // A célula esvaziada tem de continuar tocável durante a saída.
      await tester.tap(find.byKey(tileKey(Position(row: 5, col: 2))));
      await tester.pump();

      expect(tapped, [Position(row: 5, col: 2)]);
      await tester.pumpAndSettle();
    });

    testWidgets('trocar o tabuleiro inteiro não deixa rastro', (tester) async {
      // Recomeçar fase, hot restart ou nova corrida substituem o tabuleiro:
      // todas as peças ganham id novo. Isso não é eliminação — se cada uma
      // deixar rastro, o tabuleiro novo nasce coberto de dígitos fantasma.
      await tester.pumpWidget(host(board: boardOf(plainGrid())));
      await tester.pumpAndSettle();

      var replacement = Board.empty();
      for (int row = 0; row < Board.boardSize; row++) {
        for (int col = 0; col < Board.boardSize; col++) {
          final position = Position(row: row, col: col);
          replacement = replacement.updateTile(
            position,
            Tile(
              id: 'novo_${row}_$col',
              value: (row + col) % 4,
              position: position,
            ),
          );
        }
      }

      await tester.pumpWidget(host(board: replacement));
      await tester.pump(kTileExitDuration ~/ 3);

      expect(
        find.byKey(tileExitKey('r0c0')),
        findsNothing,
        reason: 'peça de tabuleiro substituído não deveria virar rastro',
      );
      expect(
        find.byType(TileWidget),
        findsNWidgets(64),
        reason: 'deveriam existir só as 64 peças novas',
      );

      await tester.pumpAndSettle();
    });

    testWidgets('nada sai quando nenhuma peça é eliminada', (tester) async {
      final board = boardOf(plainGrid());
      await tester.pumpWidget(host(board: board));
      await tester.pumpAndSettle();

      // Só um valor muda: ninguém saiu do tabuleiro.
      final evolved = board.getTileAt(Position(row: 2, col: 2))!.evolve();
      await tester.pumpWidget(
        host(board: board.updateTile(Position(row: 2, col: 2), evolved)),
      );
      await tester.pump(kTileExitDuration ~/ 3);

      expect(find.byKey(tileExitKey('r2c2')), findsNothing);
      expect(find.byType(TileWidget), findsNWidgets(64));
      await tester.pumpAndSettle();
    });
  });

  group('dica', () {
    /// Intensidade do brilho de dica na peça.
    double glowOf(WidgetTester tester, String tileId) => tester
        .widget<TileWidget>(
          find.descendant(
            of: find.byKey(tileVisualKey(tileId)),
            matching: find.byType(TileWidget),
          ),
        )
        .hintGlow;

    /// A espera é encurtada em test/flutter_test_config.dart.
    final delay = BoardGridWidget.debugHintDelayOverride!;

    const hint = (Position(row: 2, col: 2), Position(row: 2, col: 3));

    testWidgets('não acende de imediato', (tester) async {
      await tester.pumpWidget(host(board: boardOf(plainGrid()), hint: hint));
      await tester.pump(delay ~/ 3);

      // Quem acabou de jogar não precisa de dica em cima do movimento.
      expect(glowOf(tester, 'r2c2'), 0);
    });

    testWidgets('acende depois da espera', (tester) async {
      await tester.pumpWidget(host(board: boardOf(plainGrid()), hint: hint));
      await tester.pumpAndSettle();

      expect(glowOf(tester, 'r2c2'), greaterThan(0));
      expect(glowOf(tester, 'r2c3'), greaterThan(0));
    });

    testWidgets('só as duas peças da jogada acendem', (tester) async {
      await tester.pumpWidget(host(board: boardOf(plainGrid()), hint: hint));
      await tester.pumpAndSettle();

      expect(glowOf(tester, 'r0c0'), 0);
      expect(glowOf(tester, 'r7c7'), 0);
    });

    testWidgets('jogar apaga a dica e reinicia a contagem', (tester) async {
      var board = boardOf(plainGrid());
      await tester.pumpWidget(host(board: board, hint: hint));
      await tester.pumpAndSettle();
      expect(glowOf(tester, 'r2c2'), greaterThan(0));

      // O tabuleiro mudou: o jogador agiu.
      final evolved = board.getTileAt(Position(row: 6, col: 6))!.evolve();
      board = board.updateTile(Position(row: 6, col: 6), evolved);

      await tester.pumpWidget(host(board: board, hint: hint));
      await tester.pump(delay ~/ 3);

      expect(
        glowOf(tester, 'r2c2'),
        0,
        reason: 'a dica deveria apagar quando o jogador age',
      );

      await tester.pumpAndSettle();
    });

    testWidgets('selecionar uma peça também reinicia a contagem', (
      tester,
    ) async {
      final board = boardOf(plainGrid());
      await tester.pumpWidget(host(board: board, hint: hint));
      await tester.pumpAndSettle();
      expect(glowOf(tester, 'r2c2'), greaterThan(0));

      await tester.pumpWidget(
        host(
          board: board,
          hint: hint,
          selectedTile: board.getTileAt(Position(row: 5, col: 5)),
        ),
      );
      await tester.pump(delay ~/ 3);

      expect(glowOf(tester, 'r2c2'), 0);
      await tester.pumpAndSettle();
    });

    testWidgets('sem jogada possível, nada acende', (tester) async {
      await tester.pumpWidget(host(board: boardOf(plainGrid())));
      await tester.pumpAndSettle();

      expect(glowOf(tester, 'r2c2'), 0);
    });

    testWidgets('a dica fica desligada quando a partida acabou', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(board: boardOf(plainGrid()), hint: hint, hintEnabled: false),
      );
      await tester.pumpAndSettle();

      // Tela de fim de fase não deve ficar sugerindo jogada por trás.
      expect(glowOf(tester, 'r2c2'), 0);
    });
  });

  group('fusão', () {
    /// A escala é aplicada na pintura, não no layout — `getSize` devolveria o
    /// mesmo valor sempre. O que se lê é a própria animação.
    double scaleOf(WidgetTester tester, String tileId) {
      final transition = tester.widget<ScaleTransition>(
        find.descendant(
          of: find.byKey(tileVisualKey(tileId)),
          // Pela chave, não pelo tipo: o salto da seleção é um AnimatedScale,
          // que por dentro também é um ScaleTransition.
          matching: find.byKey(tilePopKey),
        ),
      );
      return transition.scale.value;
    }

    testWidgets('a peça pula quando o valor muda', (tester) async {
      var board = boardOf(plainGrid());

      await tester.pumpWidget(host(board: board));
      await tester.pumpAndSettle();
      expect(scaleOf(tester, 'r3c3'), 1.0);

      // A mesma peça evolui: mesmo id, valor novo.
      final evolved = board.getTileAt(Position(row: 3, col: 3))!.evolve();
      board = board.updateTile(Position(row: 3, col: 3), evolved);

      await tester.pumpWidget(host(board: board));
      await tester.pump(kTilePopDuration ~/ 3);

      expect(
        scaleOf(tester, 'r3c3'),
        greaterThan(1.0),
        reason: 'a peça deveria crescer ao evoluir',
      );

      await tester.pumpAndSettle();
      expect(
        scaleOf(tester, 'r3c3'),
        1.0,
        reason: 'a peça deveria voltar ao tamanho normal',
      );
    });

    testWidgets('peça que não mudou de valor não pula', (tester) async {
      var board = boardOf(plainGrid());

      await tester.pumpWidget(host(board: board));
      await tester.pumpAndSettle();

      // Contraprova: uma mudança em outra peça não pode fazer esta pular.
      final evolved = board.getTileAt(Position(row: 3, col: 3))!.evolve();
      board = board.updateTile(Position(row: 3, col: 3), evolved);

      await tester.pumpWidget(host(board: board));
      await tester.pump(kTilePopDuration ~/ 3);

      expect(scaleOf(tester, 'r0c0'), 1.0);
      await tester.pumpAndSettle();
    });

    testWidgets('combinação grande pula mais que combinação de três', (
      tester,
    ) async {
      // Mesma peça, mesma evolução, mesmo instante da animação: a única
      // diferença é ter vindo de uma combinação grande.
      var board = boardOf(plainGrid());
      const spot = Position(row: 3, col: 3);

      await tester.pumpWidget(host(board: board));
      await tester.pumpAndSettle();

      final evolved = board.getTileAt(spot)!.evolve();
      board = board.updateTile(spot, evolved);

      await tester.pumpWidget(host(board: board));
      await tester.pump(kTilePopDuration ~/ 3);
      final normal = scaleOf(tester, 'r3c3');
      await tester.pumpAndSettle();

      // Refaz o mesmo passo, agora marcando a peça como fusão grande.
      var big = boardOf(plainGrid());
      await tester.pumpWidget(host(board: big));
      await tester.pumpAndSettle();

      big = big.updateTile(spot, big.getTileAt(spot)!.evolve());
      await tester.pumpWidget(
        host(board: big, bigFusionTileIds: const {'r3c3'}),
      );
      await tester.pump(kTilePopDuration ~/ 3);

      expect(
        scaleOf(tester, 'r3c3'),
        greaterThan(normal),
        reason: 'a combinação grande deveria crescer mais',
      );
      await tester.pumpAndSettle();
    });

    testWidgets('combinação grande dá um clarão que some', (tester) async {
      var board = boardOf(plainGrid());
      await tester.pumpWidget(host(board: board));
      await tester.pumpAndSettle();

      const spot = Position(row: 3, col: 3);
      board = board.updateTile(spot, board.getTileAt(spot)!.evolve());

      await tester.pumpWidget(
        host(board: board, bigFusionTileIds: const {'r3c3'}),
      );
      await tester.pump(kTilePopDuration ~/ 4);

      double flashOf(String id) => tester
          .widget<FadeTransition>(
            find.descendant(
              of: find.byKey(tileVisualKey(id)),
              matching: find.byType(FadeTransition),
            ),
          )
          .opacity
          .value;

      expect(flashOf('r3c3'), greaterThan(0));

      await tester.pumpAndSettle();
      expect(flashOf('r3c3'), 0, reason: 'o clarão deveria ter sumido');
    });

    testWidgets('combinação de três não dá clarão', (tester) async {
      var board = boardOf(plainGrid());
      await tester.pumpWidget(host(board: board));
      await tester.pumpAndSettle();

      const spot = Position(row: 3, col: 3);
      board = board.updateTile(spot, board.getTileAt(spot)!.evolve());

      await tester.pumpWidget(host(board: board));
      await tester.pump(kTilePopDuration ~/ 4);

      // Contraprova: sem o clarão, a diferença entre 3 e 4+ não se lê.
      expect(
        find.descendant(
          of: find.byKey(tileVisualKey('r3c3')),
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
      );
      await tester.pumpAndSettle();
    });

    testWidgets('peça nova entra com o mesmo pulo', (tester) async {
      var board = boardOf(plainGrid());
      await tester.pumpWidget(host(board: board));
      await tester.pumpAndSettle();

      // Peça inédita, como as que a reposição cria no topo.
      const spot = Position(row: 0, col: 0);
      board = board.updateTile(
        spot,
        const Tile(id: 'recem_criada', value: 5, position: spot),
      );

      await tester.pumpWidget(host(board: board));
      await tester.pump(kTilePopDuration ~/ 3);

      expect(scaleOf(tester, 'recem_criada'), greaterThan(1.0));
      await tester.pumpAndSettle();
      expect(scaleOf(tester, 'recem_criada'), 1.0);
    });
  });

  group('tela larga', () {
    /// O mesmo tabuleiro num espaço maior que [kMaxBoardSide].
    Widget wideHost(Board board) => MaterialApp(
      locale: kTestLocale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: kMaxBoardSide + 400,
            height: kMaxBoardSide + 400,
            child: BoardGridWidget(board: board),
          ),
        ),
      ),
    );

    testWidgets('as peças ficam dentro da moldura do tabuleiro', (
      tester,
    ) async {
      // O tabuleiro para de crescer em `kMaxBoardSide` e é centralizado. As
      // peças eram posicionadas somando o deslocamento da centralização *dentro*
      // da moldura já centralizada, então em tablet elas escorriam para a
      // direita, saindo da própria moldura.
      await tester.pumpWidget(wideHost(boardOf(plainGrid())));
      await tester.pumpAndSettle();

      final frame = tester.getRect(find.byType(BoardGridWidget));
      final corner = tester.getRect(find.byKey(tileVisualKey('r0c0')));
      final far = tester.getRect(find.byKey(tileVisualKey('r7c7')));

      // Centralizado: a sobra é igual dos dois lados.
      expect(
        corner.left - (frame.left + (frame.width - kMaxBoardSide) / 2),
        closeTo(BoardGeometry.padding, 1),
      );
      expect(far.right, lessThanOrEqualTo(frame.right));
    });
  });
}
