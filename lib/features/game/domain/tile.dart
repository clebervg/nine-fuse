import 'package:nine_fuse/features/game/domain/obstacle.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/special_tile.dart';

/// Representa um bloco individual no tabuleiro
/// Imutável e contém todas as informações necessárias para renderizar e lógica do jogo
class Tile {
  final String id; // ID único do tile
  final int value; // Valor do dígito (0-9)
  final Position position; // Posição no tabuleiro
  final bool isSelected; // Se está selecionado para troca

  /// Cobertura que prende esta peça, se houver.
  final ObstacleType obstacle;

  /// Impactos que a cobertura ainda aguenta. Zero fora de [ObstacleType.none]
  /// não existe: a cobertura some no mesmo instante em que zera.
  final int obstacleHp;

  /// Tipo de peça especial, se houver. Anda sempre junto com
  /// [specialTurnsLeft] — os dois nascem e morrem juntos.
  final SpecialTileType? specialType;

  /// Turnos restantes antes da peça especial reverter para uma peça normal
  /// do mesmo valor.
  final int? specialTurnsLeft;

  const Tile({
    required this.id,
    required this.value,
    required this.position,
    this.isSelected = false,
    this.obstacle = ObstacleType.none,
    this.obstacleHp = 0,
    this.specialType,
    this.specialTurnsLeft,
  }) : assert(value >= 0 && value <= 9, 'Value deve estar entre 0 e 9'),
       assert(
         (obstacle == ObstacleType.none) == (obstacleHp == 0),
         'cobertura e resistência andam juntas',
       ),
       assert(
         (specialType == null) == (specialTurnsLeft == null),
         'peça especial e contador de vida andam juntos',
       );

  /// Único caminho de criação de peça especial: amarra tipo e contador de
  /// vida, sempre nascendo em [kSpecialTileLifespan].
  factory Tile.withSpecial({
    required String id,
    required int value,
    required Position position,
    required SpecialTileType specialType,
  }) => Tile(
    id: id,
    value: value,
    position: position,
    specialType: specialType,
    specialTurnsLeft: kSpecialTileLifespan,
  );

  /// Cria uma nova Tile com valores opcionalmente alterados
  Tile copyWith({
    String? id,
    int? value,
    Position? position,
    bool? isSelected,
    ObstacleType? obstacle,
    int? obstacleHp,
    SpecialTileType? specialType,
    int? specialTurnsLeft,
    bool clearSpecial = false,
  }) => Tile(
    id: id ?? this.id,
    value: value ?? this.value,
    position: position ?? this.position,
    isSelected: isSelected ?? this.isSelected,
    obstacle: obstacle ?? this.obstacle,
    obstacleHp: obstacleHp ?? this.obstacleHp,
    specialType: clearSpecial ? null : (specialType ?? this.specialType),
    specialTurnsLeft: clearSpecial
        ? null
        : (specialTurnsLeft ?? this.specialTurnsLeft),
  );

  /// A peça está presa por uma cobertura.
  bool get isBlocked => obstacle != ObstacleType.none;

  /// A cobertura já levou pelo menos um impacto — o vidro usa isto para
  /// mostrar a trinca.
  bool get isDamaged => isBlocked && obstacleHp < obstacle.hitPoints;

  /// Cobre a peça, com a resistência cheia do tipo.
  ///
  /// É o único caminho que o desenho de fase usa: passar [obstacleHp] à mão no
  /// construtor permitiria um gelo de três impactos, que não é gelo nenhum.
  Tile withObstacle(ObstacleType type) =>
      copyWith(obstacle: type, obstacleHp: type.hitPoints);

  /// Um impacto de fusão na cobertura. Ao zerar, a peça é liberada.
  ///
  /// Peça livre absorve o impacto sem efeito — quem chama não precisa filtrar.
  Tile damageObstacle() {
    if (!isBlocked) return this;

    final remaining = obstacleHp - 1;
    return remaining <= 0
        ? copyWith(obstacle: ObstacleType.none, obstacleHp: 0)
        : copyWith(obstacleHp: remaining);
  }

  /// Um turno do jogador se passou. Decrementa a vida da peça especial; ao
  /// zerar, ela reverte para uma peça normal do mesmo valor. Peça sem
  /// [specialType] devolve a si mesma sem efeito.
  Tile decaySpecial() {
    if (specialType == null) return this;

    final left = specialTurnsLeft! - 1;
    if (left <= 0) {
      return copyWith(clearSpecial: true);
    }
    return copyWith(specialTurnsLeft: left);
  }

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
          isSelected == other.isSelected &&
          obstacle == other.obstacle &&
          obstacleHp == other.obstacleHp &&
          specialType == other.specialType &&
          specialTurnsLeft == other.specialTurnsLeft;

  @override
  int get hashCode => Object.hash(
    id,
    value,
    position,
    isSelected,
    obstacle,
    obstacleHp,
    specialType,
    specialTurnsLeft,
  );

  @override
  String toString() =>
      'Tile(id: $id, value: $value, position: $position, '
      'isSelected: $isSelected, obstacle: ${obstacle.name}($obstacleHp), '
      'special: ${specialType?.name}($specialTurnsLeft))';
}
