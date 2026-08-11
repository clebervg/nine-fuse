import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/presentation/widgets/board_geometry.dart';

void main() {
  // A camada de mira do martelo converte o toque em célula com a mesma conta
  // que posiciona as peças. Se as duas divergirem, o jogador bate numa célula e
  // vê a vizinha explodir.
  group('cellAt', () {
    final geometry = BoardGeometry(availableWidth: 400);

    test('o centro de cada célula devolve a própria célula', () {
      for (int row = 0; row < 8; row++) {
        for (int col = 0; col < 8; col++) {
          final cell = Position(row: row, col: col);
          expect(
            geometry.cellAt(geometry.centerOf(cell)),
            cell,
            reason: 'o centro de $cell não voltou nele mesmo',
          );
        }
      }
    });

    test('fora do tabuleiro devolve nulo', () {
      expect(geometry.cellAt(const Offset(-10, 10)), isNull);
      expect(geometry.cellAt(const Offset(10, -10)), isNull);
      expect(geometry.cellAt(const Offset(10000, 10)), isNull);
      expect(geometry.cellAt(const Offset(10, 10000)), isNull);
    });

    test('o vão entre as células ainda pertence a alguém', () {
      // O gap tem 3pt. Recusar o toque ali faria o dedo "escorregar" entre as
      // peças, num tabuleiro em que cada ponto já é disputado.
      final between = Offset(
        geometry.left(3) + geometry.tileSize + 1,
        geometry.centerOf(const Position(row: 3, col: 3)).dy,
      );

      expect(geometry.cellAt(between), isNotNull);
    });

    test('o tabuleiro estreitado respeita o deslocamento horizontal', () {
      // Numa tela larga o tabuleiro é centralizado; ignorar esse deslocamento
      // faria a mira errar por dezenas de pontos justamente em tablet.
      final wide = BoardGeometry(availableWidth: kMaxBoardSide + 200);
      final cell = const Position(row: 2, col: 0);

      expect(wide.cellAt(wide.centerOf(cell)), cell);
      expect(wide.cellAt(const Offset(4, 4)), isNull);
    });
  });
}
