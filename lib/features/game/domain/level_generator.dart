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
/// Não é uma válvula de segurança aritmética — quem impede o aperto de chegar
/// a zero é [kTighteningFloor]. É um piso de **projeto**: abaixo de dez
/// movimentos a fase deixa de ser um plano e vira um sorteio, porque o primeiro
/// tabuleiro decide tudo. Uma fase de "crie um 7" com um movimento não é uma
/// fase difícil, é uma fase que não existe — o jogador não chega a jogar.
///
/// Dez também é a ordem de grandeza das primeiras fases artesanais (6, 10, 10),
/// que são as mais curtas que o jogo já se permitiu.
const int kMinMoveLimit = 10;

/// Quantos movimentos vale cada peça pedida num objetivo de dígito.
///
/// O nome sugere que este número governa o limite das fases de dígito, mas na
/// prática ele quase não participa: com `count` de 1 a 4 a base
/// (`2.2 * count`) fica entre 2,2 e 8,8, sempre abaixo de [kMinMoveLimit] — o
/// piso decide sozinho, e só as contagens 5-6 em blocos baixos chegam a
/// escapar dele. [kTighteningFloor] também não morde nessas fases (13,2 × 0,75
/// = 9,9 < 10). Quem de fato calibra o limite das fases de dígito é o piso de
/// dez movimentos, não este multiplicador — o valor aqui só evita que a base
/// fique **acima** do piso nas contagens altas, o que voltaria a inflar o
/// limite sem necessidade.
const double kDigitMovesPerPiece = 2.2;

/// Quantos movimentos vale cada cobertura pedida.
///
/// Muito maior que o de dígito porque o jogador não escolhe quebrar uma
/// cobertura: ela só cede a fusões que nasçam encostadas nela, e o bot guloso
/// nunca mira. É o mesmo motivo pelo qual a taxa de vitória dessas fases é lida
/// como piso, e não como nota.
const double kObstacleMovesPerUnit = 12.0;

/// Movimentos de uma fase de "limpe tudo".
///
/// Fixo, e não proporcional, porque o alvo real sai do tabuleiro sorteado e não
/// do pedido da fase — `placeObstacles` descarta a cobertura que não acha
/// lugar, então multiplicar pelo pedido daria movimentos por uma cobertura que
/// pode não estar lá.
const double kClearAllMoves = 30.0;

/// Quanto o limite de movimentos encolhe a cada bloco.
const double kTighteningPerBlock = 0.02;

/// Teto do aperto por bloco: o limite nunca cai abaixo desta fração da base.
///
/// Sem teto, `1 - 0.02 * bloco` cruza zero por volta do bloco 50 (fase ~510) e
/// **vira negativo**: as fases distantes desabavam no piso e saíam com 0% de
/// vitória. Uma campanha infinita cujas fases distantes são matematicamente
/// invencíveis é pior do que não ter fase nenhuma ali.
///
/// 0,75 — um quarto a menos, e nada além disso — porque a partir do bloco 12 a
/// dificuldade já tem para onde crescer sem o limite: a contagem do objetivo
/// sobe até [kMaxObjectiveCount], a cobertura endurece até a pedra, e a janela
/// cicla. O aperto do limite é o eixo que **assintota**; os outros continuam.
/// Apertar mais do que isso só transferiria a dificuldade para o único lugar
/// onde ela não é lida como desafio, e sim como bug: o tabuleiro inicial.
const double kTighteningFloor = 0.75;

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
  // O teto da pedra voltou a 3. O motivo do teto reduzido a 2 era um bug do
  // motor — a onda de choque do dígito máximo varria a cobertura da tela sem
  // emitir `ObstacleHit`, então "limpe todas as pedras" não tinha como fechar
  // por explosão — e esse bug **foi corrigido** em `MatchEngine._detonate`
  // (`_mergeObstacleHits`): o estouro agora credita a cobertura que varre.
  // Remedido com `--mode=generated`, o teto 3 não faz a fase 1000 ("limpe todo
  // stone", janela 5-8) despencar: 56%, contra 16% com o bug ativo. O teto 2
  // mede alguns pontos acima, e os dois números são piso — o bot guloso nunca
  // mira a cobertura de propósito. A variedade de
  // três pedras no fecho de bloco vale mais do que os poucos pontos percentuais
  // de folga que o teto 2 comprava.
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
/// Os três multiplicadores foram fixados por `tool/simulate_economy.dart
/// --mode=generated`, e cada um tem o seu porquê registrado na sua própria
/// constante. O que **não** se faz aqui é deformar a base para a métrica ceder:
/// o eixo de calibragem é este limite, e ele tem um piso de projeto
/// ([kMinMoveLimit]) abaixo do qual nenhum número é aceito, por melhor que a
/// taxa de vitória fique.
int _movesFor({required Objective objective, required int block}) {
  final double base = switch (objective.type) {
    ObjectiveType.reachDigit => kDigitMovesPerPiece * objective.count,
    ObjectiveType.clearObstacles => kObstacleMovesPerUnit * objective.count,
    ObjectiveType.clearAllObstacles => kClearAllMoves,
  };

  // Aperto de 2% por bloco, com teto: a fase encolhe devagar o bastante para o
  // jogador sentir que melhorou, e para de encolher antes de a conta se virar
  // contra ele. O `clamp` inferior é o conserto do defeito que fazia a fase 500
  // sair com um movimento — um percentual aplicado para sempre não tende a um
  // limite apertado, tende a nenhum limite.
  final factor = (1 - kTighteningPerBlock * block).clamp(kTighteningFloor, 1.0);
  final tightened = (base * factor).floor();
  return tightened < kMinMoveLimit ? kMinMoveLimit : tightened;
}
