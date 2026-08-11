import 'package:nine_fuse/features/game/domain/position.dart';

/// Obstáculos que cobrem uma célula do tabuleiro.
///
/// A cobertura não substitui a peça: o dígito continua ali embaixo, intacto.
/// O que ela faz é **prender** a peça — enquanto o obstáculo existe, aquela
/// célula não pode ser trocada pelo jogador nem participar de combinação. A
/// única saída é uma fusão acontecer encostada nela.
///
/// É essa assimetria que dá o desenho de fase: o obstáculo não é uma peça mais
/// difícil, é uma região do tabuleiro que o jogador precisa alcançar de fora.
enum ObstacleType {
  /// Sem cobertura: a peça joga normalmente.
  none,

  /// Gelo: derrete no primeiro impacto.
  ice,

  /// Vidro: dois impactos; trinca no primeiro.
  glass,

  /// Pedra: três impactos. Também cede de uma vez à onda de choque do
  /// dígito máximo, que varre a célula inteira.
  stone,
}

/// Resistência de cada obstáculo, em impactos de fusão.
extension ObstacleHitPoints on ObstacleType {
  int get hitPoints => switch (this) {
    ObstacleType.none => 0,
    ObstacleType.ice => 1,
    ObstacleType.glass => 2,
    ObstacleType.stone => 3,
  };
}

/// Quantas coberturas de cada tipo uma fase pede ao sortear o tabuleiro.
///
/// É **desenho de fase**, não estado de jogo: descreve o pedido, e o motor
/// decide onde cada cobertura cabe (ver `MatchEngine.placeObstacles`). Guardar
/// posições fixas aqui tornaria toda fase idêntica a cada tentativa — e a
/// campanha do NineFuse é procedural.
class ObstacleLayout {
  const ObstacleLayout({this.ice = 0, this.glass = 0, this.stone = 0})
    : assert(ice >= 0 && glass >= 0 && stone >= 0);

  /// Fase sem obstáculo nenhum.
  static const ObstacleLayout none = ObstacleLayout();

  final int ice;
  final int glass;
  final int stone;

  int get total => ice + glass + stone;

  /// Quantas coberturas de [type] esta fase pede.
  ///
  /// É o **pedido**, e não o que o tabuleiro entregou: `placeObstacles` descarta
  /// a cobertura que não acha lugar. Para o alvo de um objetivo "limpe todo o
  /// gelo" quem vale é o tabuleiro (ver `Board.countObstacles`); este número
  /// serve ao cartão de início, que fala antes de a fase existir.
  int countOf(ObstacleType type) => switch (type) {
    ObstacleType.none => 0,
    ObstacleType.ice => ice,
    ObstacleType.glass => glass,
    ObstacleType.stone => stone,
  };

  bool get isEmpty => total == 0;

  /// As quantidades expandidas em pedidos individuais, **do mais duro para o
  /// mais fácil**.
  ///
  /// A ordem não é estética: as coberturas não podem nascer encostadas, então
  /// as últimas da fila são as que correm risco de não caber. Perder um gelo
  /// muda pouco a fase; perder a pedra muda o que ela pede do jogador.
  List<ObstacleType> get types => [
    for (int i = 0; i < stone; i++) ObstacleType.stone,
    for (int i = 0; i < glass; i++) ObstacleType.glass,
    for (int i = 0; i < ice; i++) ObstacleType.ice,
  ];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ObstacleLayout &&
          ice == other.ice &&
          glass == other.glass &&
          stone == other.stone;

  @override
  int get hashCode => Object.hash(ice, glass, stone);

  @override
  String toString() => 'ObstacleLayout(gelo: $ice, vidro: $glass, pedra: $stone)';
}

/// Um obstáculo que levou dano num passo da resolução.
///
/// A UI precisa disto para disparar as partículas certas (lascas de gelo,
/// cacos de vidro, poeira de pedra) no lugar certo: só o tabuleiro antes e
/// depois não diz **qual** cobertura cedeu, nem se ela apenas trincou.
///
/// A posição é a de **antes da gravidade** — é onde a quebra acontece na tela,
/// no mesmo quadro em que as peças da combinação ainda estão visíveis.
class ObstacleHit {
  const ObstacleHit({
    required this.position,
    required this.type,
    required this.remainingHp,
  });

  final Position position;

  /// O obstáculo que **levou** o impacto, mesmo que tenha sido destruído por
  /// ele. Sem isso a UI não saberia que partícula desenhar numa quebra.
  final ObstacleType type;

  /// Quanto sobrou depois do impacto. Zero significa cobertura destruída.
  final int remainingHp;

  bool get cleared => remainingHp <= 0;

  @override
  String toString() =>
      'ObstacleHit($position, ${type.name}, hp: $remainingHp)';
}
