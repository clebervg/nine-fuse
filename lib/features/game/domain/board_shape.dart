import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/position.dart';

/// O formato do tabuleiro de uma fase: quais casas da matriz 8x8 existem.
///
/// Existe porque, depois de o dígito-alvo saturar em 9 e as coberturas
/// pararem de crescer, o formato é o eixo que mais muda a cara de uma fase com
/// o menor custo de regra: um gargalo, um buraco no centro ou cantos cortados
/// mudam onde as combinações cabem, sem nenhuma mecânica nova a ensinar.
///
/// Todos os formatos são **simétricos na horizontal** (o olho lê assimetria
/// como defeito de desenho) e mantêm toda coluna com pelo menos uma casa: uma
/// coluna inteira fora do tabuleiro é só um tabuleiro mais estreito.
enum BoardShape {
  /// A matriz inteira.
  full,

  /// Os quatro cantos cortados em triângulo de 3 casas.
  cornersCut,

  /// Um buraco 2x2 no centro: o tabuleiro vira um anel.
  ring,

  /// Cintura estreita no meio, cortando 2 casas de cada borda nas linhas 3-4.
  hourglass,

  /// Duas colunas interrompidas no meio: as peças caem por cima do vão.
  pillars,

  /// Um vão horizontal no centro: duas metades unidas pelas bordas.
  bridge,

  /// Cantos 2x2 cortados: uma cruz larga.
  cross,

  /// Cantos em triângulo de 6 casas: um losango.
  diamond;

  /// As casas fora do tabuleiro neste formato.
  Set<Position> get voids => _voidsCache[this] ??= _buildVoids(this);

  /// Quantas casas este formato tem.
  int get playableCount => Board.boardSize * Board.boardSize - voids.length;

  /// Um formato diferente de [full].
  bool get isShaped => this != BoardShape.full;
}

final Map<BoardShape, Set<Position>> _voidsCache = {};

const int _last = Board.boardSize - 1;

/// Espelha [cells] nos quatro cantos (horizontal e vertical).
Set<Position> _mirrored(Iterable<(int, int)> cells) => {
  for (final (row, col) in cells) ...[
    Position(row: row, col: col),
    Position(row: row, col: _last - col),
    Position(row: _last - row, col: col),
    Position(row: _last - row, col: _last - col),
  ],
};

Set<Position> _buildVoids(BoardShape shape) => Set.unmodifiable(switch (shape) {
  BoardShape.full => <Position>{},
  BoardShape.cornersCut => _mirrored([(0, 0), (0, 1), (1, 0)]),
  BoardShape.ring => _mirrored([(3, 3)]),
  BoardShape.hourglass => _mirrored([(3, 0), (3, 1)]),
  BoardShape.pillars => _mirrored([(2, 2), (3, 2)]),
  BoardShape.bridge => _mirrored([(3, 2), (3, 3)]),
  BoardShape.cross => _mirrored([(0, 0), (0, 1), (1, 0), (1, 1)]),
  BoardShape.diamond => _mirrored([
    (0, 0),
    (0, 1),
    (0, 2),
    (1, 0),
    (1, 1),
    (2, 0),
  ]),
});
