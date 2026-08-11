import 'package:nine_fuse/features/game/domain/obstacle.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';

/// Representa o tabuleiro do jogo (matriz 8x8 imutável)
/// Contém todos os tiles e oferece métodos para acessar e manipular o estado
class Board {
  static const int boardSize = 8;

  final List<List<Tile?>> grid; // Matriz [row][col] com tiles opcionais

  const Board({required this.grid})
    : assert(boardSize == 8, 'Board deve ser 8x8');

  /// Cria um Board vazio com tiles nulos
  factory Board.empty() {
    final grid = List<List<Tile?>>.generate(
      boardSize,
      (_) => List<Tile?>.filled(boardSize, null, growable: false),
      growable: false,
    );
    return Board(grid: grid);
  }

  /// Obtém um tile em uma posição específica
  Tile? getTileAt(Position position) {
    if (!isValidPosition(position)) return null;
    return grid[position.row][position.col];
  }

  /// A posição cai dentro da matriz 8x8?
  ///
  /// Não depende do conteúdo do tabuleiro, daí a versão estática — evita
  /// construir um Board só para checar limites.
  static bool contains(Position position) =>
      position.row >= 0 &&
      position.row < boardSize &&
      position.col >= 0 &&
      position.col < boardSize;

  /// Verifica se uma posição é válida no tabuleiro
  bool isValidPosition(Position position) => contains(position);

  /// Cria um novo Board com um tile alterado em uma posição
  Board updateTile(Position position, Tile? tile) {
    if (!isValidPosition(position)) return this;

    final newGrid = grid.map((row) => [...row]).toList();
    newGrid[position.row][position.col] = tile;

    return Board(grid: newGrid);
  }

  /// Cria um novo Board com múltiplos tiles alterados
  Board updateTiles(Map<Position, Tile?> updates) {
    var board = this;
    for (final entry in updates.entries) {
      board = board.updateTile(entry.key, entry.value);
    }
    return board;
  }

  /// Retorna lista de todos os tiles não nulos no tabuleiro
  List<Tile> getAllTiles() {
    final tiles = <Tile>[];
    for (final row in grid) {
      for (final tile in row) {
        if (tile case Tile t) {
          tiles.add(t);
        }
      }
    }
    return tiles;
  }

  /// Retorna todos os tiles em uma linha específica
  List<Tile> getTilesInRow(int row) {
    if (row < 0 || row >= boardSize) return [];
    return grid[row].whereType<Tile>().toList();
  }

  /// Retorna todos os tiles em uma coluna específica
  List<Tile> getTilesInCol(int col) {
    if (col < 0 || col >= boardSize) return [];
    return grid.map((row) => row[col]).whereType<Tile>().toList();
  }

  /// Conta quantos tiles não nulos existem no tabuleiro
  int get tileCount {
    int count = 0;
    for (final row in grid) {
      for (final tile in row) {
        if (tile != null) count++;
      }
    }
    return count;
  }

  /// Quantas peças estão presas por uma cobertura de [type].
  ///
  /// É a única fonte honesta do alvo de um objetivo "limpe todo o gelo": o
  /// pedido da fase (`ObstacleLayout`) pode ter sido podado por
  /// `placeObstacles`, e cobrar do jogador uma cobertura que nunca nasceu
  /// tornaria a fase impossível.
  int countObstacles(ObstacleType type) {
    if (type == ObstacleType.none) return 0;

    int count = 0;
    for (final row in grid) {
      for (final tile in row) {
        if (tile?.obstacle == type) count++;
      }
    }
    return count;
  }

  /// Verifica se o tabuleiro está vazio
  bool get isEmpty => tileCount == 0;

  /// Verifica se o tabuleiro está cheio
  bool get isFull => tileCount == (boardSize * boardSize);

  /// Retorna uma lista de posições vazias no tabuleiro
  List<Position> getEmptyPositions() {
    final empty = <Position>[];
    for (int row = 0; row < boardSize; row++) {
      for (int col = 0; col < boardSize; col++) {
        if (grid[row][col] == null) {
          empty.add(Position(row: row, col: col));
        }
      }
    }
    return empty;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Board &&
          runtimeType == other.runtimeType &&
          _gridEquals(grid, other.grid);

  @override
  int get hashCode {
    int hash = 0;
    for (final row in grid) {
      for (final tile in row) {
        hash ^= tile?.hashCode ?? 0;
      }
    }
    return hash;
  }

  /// Compara duas matrizes de tiles
  static bool _gridEquals(List<List<Tile?>> grid1, List<List<Tile?>> grid2) {
    if (grid1.length != grid2.length) return false;
    for (int i = 0; i < grid1.length; i++) {
      if (grid1[i].length != grid2[i].length) return false;
      for (int j = 0; j < grid1[i].length; j++) {
        if (grid1[i][j] != grid2[i][j]) return false;
      }
    }
    return true;
  }

  @override
  String toString() {
    final buffer = StringBuffer('Board 8x8:\n');
    for (int row = 0; row < boardSize; row++) {
      for (int col = 0; col < boardSize; col++) {
        final tile = grid[row][col];
        buffer.write(tile != null ? '[${tile.value}]' : '[ ]');
      }
      buffer.write('\n');
    }
    return buffer.toString();
  }
}
