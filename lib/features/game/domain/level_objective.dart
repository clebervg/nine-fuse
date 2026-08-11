import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';

/// A natureza do que a fase pede.
///
/// Existe porque as três metas se medem em unidades diferentes — peças
/// **criadas** por fusão contra coberturas **destruídas** — e o contador de
/// progresso precisa saber qual das duas somar a cada jogada. Deduzir o tipo de
/// um campo nulo (`digit == null` logo é obstáculo) funcionaria hoje e quebraria
/// na primeira meta nova.
enum ObjectiveType {
  /// Formar N peças de um dígito. É o objetivo original da campanha.
  reachDigit,

  /// Destruir N coberturas de um tipo, venham de onde vierem.
  clearObstacles,

  /// Destruir **todas** as coberturas daquele tipo que o tabuleiro trouxer.
  ///
  /// A quantidade não é declarada aqui de propósito: `placeObstacles` descarta
  /// a cobertura que não acha lugar, então o número que a fase pediu e o que o
  /// tabuleiro entregou podem não coincidir. Pedir "todas" sobre um número fixo
  /// tornaria a fase impossível justamente quando o motor foi conservador.
  clearAllObstacles,
}

/// O que uma fase pede do jogador.
///
/// No objetivo de dígito só conta peça **criada por fusão** — receber um dígito
/// do sorteio do topo não cumpre nada. É o que dá sentido a "crie um 6".
///
/// Nos objetivos de cobertura só conta a quebra: um impacto que apenas trinca o
/// vidro não soma. O jogador conta o que sumiu do tabuleiro, e o contador tem de
/// contar a mesma coisa.
class Objective {
  /// Formar [count] peças de [digit].
  const Objective({required int this.digit, this.count = 1})
    : type = ObjectiveType.reachDigit,
      obstacle = ObstacleType.none,
      assert(digit >= 0 && digit <= kMaxDigit),
      assert(count >= 1);

  /// Destruir [count] coberturas de [obstacle].
  const Objective.clearObstacles({required this.obstacle, this.count = 1})
    : type = ObjectiveType.clearObstacles,
      digit = null,
      assert(
        obstacle != ObstacleType.none,
        'sem cobertura não há o que quebrar',
      ),
      assert(count >= 1);

  /// Limpar do tabuleiro toda cobertura de [obstacle].
  ///
  /// [count] fica em 1 apenas para o campo não ser nulo; quem manda no alvo é o
  /// tabuleiro sorteado (ver `GameState.objectiveTarget`).
  const Objective.clearAllObstacles(this.obstacle)
    : type = ObjectiveType.clearAllObstacles,
      digit = null,
      count = 1,
      assert(
        obstacle != ObstacleType.none,
        'sem cobertura não há o que quebrar',
      );

  final ObjectiveType type;

  /// O dígito a criar. Nulo fora de [ObjectiveType.reachDigit] — um objetivo de
  /// pedra não tem dígito nenhum, e um valor de fachada faria a UI pintar a fase
  /// com a cor de um alvo que não existe.
  final int? digit;

  /// A cobertura a quebrar. [ObstacleType.none] fora dos objetivos de cobertura.
  final ObstacleType obstacle;

  /// Quantas unidades a fase declara.
  ///
  /// Em [ObjectiveType.clearAllObstacles] este número **não** é o alvo: lá o
  /// alvo sai do tabuleiro que o jogador recebeu.
  final int count;

  /// O objetivo se mede em coberturas destruídas?
  bool get isObstacleGoal => obstacle != ObstacleType.none;

  /// Rótulo **de desenvolvedor**, não de jogador.
  ///
  /// O texto que o jogador lê é montado na apresentação (ver
  /// `DomainLabels.objectiveLabel`). Este aqui existe para o `toString()` e para
  /// o relatório de `tool/simulate_economy.dart`, que roda em `dart run` — fora
  /// de qualquer árvore de widgets, e portanto sem `BuildContext` de onde tirar
  /// tradução.
  String get debugLabel => switch (type) {
    ObjectiveType.reachDigit =>
      count == 1 ? 'Crie um $digit' : 'Crie $count peças $digit',
    ObjectiveType.clearObstacles => 'Quebre $count ${obstacle.name}',
    ObjectiveType.clearAllObstacles => 'Limpe todo ${obstacle.name}',
  };

  @override
  bool operator ==(Object other) =>
      other is Objective &&
      other.type == type &&
      other.digit == digit &&
      other.obstacle == obstacle &&
      other.count == count;

  @override
  int get hashCode => Object.hash(type, digit, obstacle, count);

  @override
  String toString() => 'Objective(${debugLabel.toLowerCase()})';
}
