import 'package:nine_fuse/features/game/domain/position.dart';

/// Representa um bloco individual no tabuleiro
/// Imutável e contém todas as informações necessárias para renderizar e lógica do jogo
class Tile {
  final String id; // ID único do tile
  final int value; // Valor do dígito (0-9)
  final Position position; // Posição no tabuleiro
  final bool isSelected; // Se está selecionado para troca

  const Tile({
    required this.id,
    required this.value,
    required this.position,
    this.isSelected = false,
  }) : assert(value >= 0 && value <= 9, 'Value deve estar entre 0 e 9');

  /// Cria uma nova Tile com valores opcionalmente alterados
  Tile copyWith({
    String? id,
    int? value,
    Position? position,
    bool? isSelected,
  }) => Tile(
    id: id ?? this.id,
    value: value ?? this.value,
    position: position ?? this.position,
    isSelected: isSelected ?? this.isSelected,
  );

  /// Cria uma nova Tile com a mesma posição mas em uma linha diferente
  Tile moveToRow(int newRow) =>
      copyWith(position: position.copyWith(row: newRow));

  /// Cria uma nova Tile com a mesma posição mas em uma coluna diferente
  Tile moveToCol(int newCol) =>
      copyWith(position: position.copyWith(col: newCol));

  /// Cria uma nova Tile com uma posição diferente
  Tile moveTo(Position newPosition) => copyWith(position: newPosition);

  /// Incrementa o valor do tile em 1 (para a evolução de fusão)
  Tile evolve() => copyWith(value: (value + 1).clamp(0, 9));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          value == other.value &&
          position == other.position &&
          isSelected == other.isSelected;

  @override
  int get hashCode =>
      id.hashCode ^ value.hashCode ^ position.hashCode ^ isSelected.hashCode;

  @override
  String toString() =>
      'Tile(id: $id, value: $value, position: $position, isSelected: $isSelected)';
}
