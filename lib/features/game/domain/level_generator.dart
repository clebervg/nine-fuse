import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';

/// Quantas fases da campanha são escritas à mão.
///
/// Deliberadamente uma constante e não `kCampaign.length`: este arquivo é
/// aritmética pura e não precisa conhecer o catálogo. Quem casa os dois é
/// `level_catalog.dart`, com teste travando a igualdade.
const int kHandcraftedLevels = 10;

/// Fases por bloco de progressão.
///
/// É o mesmo tamanho do capítulo: o jogador vê o bloco terminar e o capítulo
/// virar no mesmo pin, e as duas coisas concordarem é o que faz o ritmo ser
/// legível em vez de aleatório.
const int kBlockSize = 10;

/// Teto de peças pedidas num objetivo de dígito.
///
/// Sem teto o `count` cresceria para sempre e a fase viraria expediente, não
/// desafio: a partir de certo ponto o jogador só repete a mesma fusão.
const int kMaxObjectiveCount = 6;

/// Teto de coberturas no tabuleiro.
///
/// `placeObstacles` descarta em silêncio a cobertura que não acha lugar — as
/// coberturas não podem nascer encostadas. Pedir mais do que cabe faria a fase
/// pedida deixar de ser a fase jogada.
const int kMaxObstacles = 7;

/// Piso do limite de movimentos.
///
/// O aperto por bloco é percentual, e percentual aplicado para sempre chega a
/// zero. O piso é onde a curva para de apertar e a dificuldade passa a vir
/// inteira dos outros eixos.
const int kMinMoveLimit = 8;

/// A fase de número [number], calculada.
///
/// Determinística por construção: só faz aritmética sobre [number]. O
/// **tabuleiro** continua sorteado a cada tentativa — o que esta função fixa é
/// o contrato da fase, não o grid. Fixar o grid faria repetir uma fase perdida
/// virar decorar a solução.
GameLevel generateLevel(int number) {
  assert(
    number > kHandcraftedLevels,
    'as $kHandcraftedLevels primeiras fases são artesanais',
  );

  final block = _blockOf(number);
  final position = _positionOf(number);

  final spawnMin = _spawnMinFor(block);
  final spawnMax = spawnMin + kSpawnWidth - 1;
  final obstacles = _obstaclesFor(block);
  final objective = _objectiveFor(
    position: position,
    block: block,
    spawnMax: spawnMax,
    obstacles: obstacles,
  );

  return GameLevel(
    number: number,
    objective: objective,
    moveLimit: _movesFor(objective: objective, block: block),
    spawnMin: spawnMin,
    spawnMax: spawnMax,
    obstacles: obstacles,
  );
}

/// Índice do bloco de progressão, contado a partir da primeira fase gerada.
int _blockOf(int number) => (number - kHandcraftedLevels - 1) ~/ kBlockSize;

/// Posição dentro do bloco, de 0 a [kBlockSize] - 1.
int _positionOf(int number) => (number - kHandcraftedLevels - 1) % kBlockSize;

/// O degrau da janela de sorteio.
///
/// Sobe um a cada bloco até o teto (`spawnMin` 5 é a janela em que o dígito
/// máximo é alvo) e depois **cicla** a partir de 2, porque o degrau tem topo
/// mas o jogo não tem. Nunca volta a 0 nem a 1: o `0` parar de cair é uma
/// conquista da fase 7, e devolvê-lo seria regredir a sensação de progresso.
int _spawnMinFor(int block) {
  const int first = 3; // continua de onde a fase 10 parou
  const int last = 5; // acima disso `spawnMax` alcançaria o dígito máximo
  const int cycleFrom = 2;

  final climb = first + block;
  if (climb <= last) return climb;

  final cycleLength = last - cycleFrom + 1;
  final ascent = last - first + 1;
  return cycleFrom + (block - ascent) % cycleLength;
}

/// O que a fase pede.
///
/// O ciclo dentro do bloco é sete fases de dígito, duas de quebra e uma de
/// limpeza total como fecho. A variedade não é enfeite: o dígito satura em
/// [kMaxDigit] por volta do terceiro bloco, e a partir dali é a **natureza** da
/// meta, não o alvo, que mantém as fases distintas umas das outras.
Objective _objectiveFor({
  required int position,
  required int block,
  required int spawnMax,
  required ObstacleLayout obstacles,
}) {
  // Fecho de bloco: limpar tudo do tipo mais duro que a fase espalha.
  if (position == kBlockSize - 1) {
    return Objective.clearAllObstacles(_hardestOf(obstacles));
  }

  // As duas antes do fecho: quebrar uma quantidade declarada.
  if (position >= kBlockSize - 3) {
    final obstacle = _hardestOf(obstacles);
    final asked = 2 + block ~/ 2;
    return Objective.clearObstacles(
      obstacle: obstacle,
      // Nunca mais do que a fase espalha: cobrar cobertura que não existe no
      // tabuleiro é fabricar uma fase impossível.
      count: asked.clamp(1, obstacles.countOf(obstacle)),
    );
  }

  // O corpo do bloco: formar o dígito acima da janela.
  //
  // O `+1` alternando com `+2` dá dois patamares de esforço dentro do mesmo
  // degrau de janela — uma fusão contra duas — sem precisar de outro eixo.
  final digit = position.isOdd ? spawnMax + 2 : spawnMax + 1;
  final count = (1 + position % 3 + block ~/ 2).clamp(1, kMaxObjectiveCount);

  return Objective(
    digit: digit > kMaxDigit ? kMaxDigit : digit,
    count: count,
  );
}

/// As coberturas que o bloco espalha.
///
/// Toda fase gerada tem pelo menos um gelo: as duas fases de cobertura do bloco
/// escolhem seu alvo daqui, e um bloco sem cobertura nenhuma não teria o que
/// pedir. A dureza entra por bloco, do mais macio para o mais duro, na mesma
/// ordem em que a campanha artesanal as apresentou.
ObstacleLayout _obstaclesFor(int block) {
  final ice = (2 + block % 3).clamp(1, 4);
  final glass = (1 + block ~/ 2).clamp(1, 3);
  final stone = (block ~/ 3).clamp(0, 3);

  // O teto é do tabuleiro, não do desenho: o excesso é aparado da cobertura
  // mais macia, que é a que menos muda o que a fase pede.
  var trimmedIce = ice;
  var total = ice + glass + stone;
  while (total > kMaxObstacles && trimmedIce > 1) {
    trimmedIce--;
    total--;
  }

  return ObstacleLayout(ice: trimmedIce, glass: glass, stone: stone);
}

/// A cobertura mais dura que [layout] espalha.
ObstacleType _hardestOf(ObstacleLayout layout) {
  if (layout.stone > 0) return ObstacleType.stone;
  if (layout.glass > 0) return ObstacleType.glass;
  return ObstacleType.ice;
}

/// O limite de movimentos.
///
/// A base sai do arquétipo do objetivo, porque as três metas se medem em
/// unidades diferentes: três peças custam cerca de três vezes uma peça, e uma
/// cobertura só cede a fusões encostadas nela — que o jogador não escolhe
/// diretamente, e por isso custam mais.
///
/// Os números são **provisórios** e serão fixados por
/// `tool/simulate_economy.dart --mode=generated`.
int _movesFor({required Objective objective, required int block}) {
  final base = switch (objective.type) {
    ObjectiveType.reachDigit => 15 * objective.count,
    ObjectiveType.clearObstacles => 12 * objective.count,
    ObjectiveType.clearAllObstacles => 30,
  };

  // Aperto de 2% por bloco: a fase encolhe devagar o bastante para o jogador
  // sentir que melhorou, e não que o jogo o traiu.
  final tightened = (base * (1 - 0.02 * block)).floor();
  return tightened < kMinMoveLimit ? kMinMoveLimit : tightened;
}
