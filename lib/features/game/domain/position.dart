/// Representa uma posição no tabuleiro (linha, coluna)
class Position {
  final int row;
  final int col;

  const Position({required this.row, required this.col});

  /// Cria uma nova Position com valores opcionalmente alterados
  Position copyWith({int? row, int? col}) =>
      Position(row: row ?? this.row, col: col ?? this.col);

  /// Verifica se duas posições são adjacentes (horizontalmente ou verticalmente)
  bool isAdjacentTo(Position other) {
    final rowDiff = (row - other.row).abs();
    final colDiff = (col - other.col).abs();
    return (rowDiff == 1 && colDiff == 0) || (rowDiff == 0 && colDiff == 1);
  }

  /// Retorna a distância de Manhattan entre duas posições
  int distanceTo(Position other) =>
      (row - other.row).abs() + (col - other.col).abs();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Position &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          col == other.col;

  @override
  int get hashCode => row.hashCode ^ col.hashCode;

  @override
  String toString() => 'Position(row: $row, col: $col)';
}
