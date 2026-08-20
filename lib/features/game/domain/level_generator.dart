import 'dart:math' show cos, pi;

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

/// Teto de peças pedidas quando o dígito-alvo é [kMaxDigit].
///
/// O ápice não é só "o dígito mais caro": alcançá-lo dispara a onda de choque
/// (ver a Fase 8/12 em `match_engine.dart`), que varre os vizinhos e reseta o
/// progresso que o jogador vinha construindo em volta. Cada peça-alvo seguinte
/// não custa "mais uma vez o mesmo preço" — custa reconstruir a vizinhança que
/// a explosão anterior acabou de zerar, e o custo composto por peça sobe muito
/// mais rápido que a distância linear que [_digitMoves] mede. Medido com
/// `--mode=probe`: "crie 2 peças 9" (janela 3-6) já pede 90 movimentos para
/// 99%, contra os ~16 que a fórmula linear dava; "crie 6" não passa de ~50%
/// nem com 120. Nenhum multiplicador de [_digitMoves] cobre as duas pontas ao
/// mesmo tempo, porque a curva real não é linear — por isso o teto é sobre a
/// **contagem**, não sobre o custo por peça: acima de duas peças-9 na mesma
/// fase, o objetivo é estruturalmente injogável em qualquer limite razoável de
/// movimentos, e é isso — não um multiplicador maior — que faz a fase 96
/// ("crie 6 peças 9", medida em 0% até 90 movimentos) existir.
const int kMaxApexObjectiveCount = 2;

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

/// Piso de movimentos das fases "pesadas": mais de dois alvos de dígito
/// alto (7, 8 ou o próprio [kMaxDigit]) na mesma fase.
///
/// [kMinMoveLimit] (10) é o piso geral, calibrado para o caso comum. Um
/// objetivo com mais de duas peças de nível 7+ pesa mais do que a fórmula
/// linear de [_digitMoves] sozinha reconhece — cada peça daquele patamar
/// exige várias fusões de preparo antes mesmo de a primeira aparecer no
/// tabuleiro —, e o piso de 10 já se mostrou curto demais para esse caso na
/// tabela de calibragem. 16 é o valor pedido para essas fases especificamente;
/// as demais continuam no piso geral.
const int kHeavyDigitMoveFloor = 16;

/// A partir de qual dígito um alvo conta como "alto" para
/// [kHeavyDigitMoveFloor].
const int kHeavyDigitThreshold = 7;

/// Quantos alvos de dígito alto uma fase precisa pedir para o piso pesado
/// entrar em vigor. "Mais de 2" no pedido original, ou seja, a partir de 3.
const int kHeavyDigitCountThreshold = 2;

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

/// Amplitude da curva senoidal de ritmo (pacing).
///
/// Depois do aperto por bloco (que só encolhe), esta curva alterna o limite de
/// movimentos ±12% a cada fase: uma fase "difícil" (fator abaixo de 1) é
/// sempre seguida por uma "relaxante" (fator acima de 1), porque
/// `cos((n+1)π) = -cos(nπ)` inverte o sinal a cada fase consecutiva. É o que
/// evita que uma sequência de fases igualmente apertadas canse o jogador antes
/// de ele reagir a uma queda de dificuldade real.
const double kPacingAmplitude = 0.12;

/// O fator de ritmo da fase [number].
///
/// `cos(nπ)` é `+1` para `n` par e `-1` para `n` ímpar — uma onda senoidal
/// (cosseno é seno deslocado de π/2) de período 2, que é exatamente a cadência
/// pedida: cada fase de um lado da onda é seguida pela do lado oposto. Usar
/// `sin(nπ)` teria dado zero para todo `n` inteiro, por isso o cosseno.
double _pacingFactor(int number) => 1 + kPacingAmplitude * cos(number * pi);

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
  final spawnMin = _spawnMinFor(block);
  final spawnMax = spawnMin + kSpawnWidth - 1;
  final obstacles = _obstaclesFor(block);
  final objective = _finalObjectiveFor(number);

  return GameLevel(
    number: number,
    objective: objective,
    moveLimit: _movesFor(
      objective: objective,
      block: block,
      spawnMin: spawnMin,
      spawnMax: spawnMax,
      number: number,
    ),
    spawnMin: spawnMin,
    spawnMax: spawnMax,
    obstacles: obstacles,
  );
}

/// Objetivo final da fase [number], já passado pelo controle de
/// anti-repetição.
///
/// Memoizado porque o controle olha para trás (fase [number] - 1 e - 2): sem
/// cache, cada fase recomputaria toda a cadeia até [kHandcraftedLevels] a cada
/// chamada. A função continua pura — o cache só evita trabalho repetido, não
/// muda o resultado, que depende exclusivamente de [number].
final Map<int, Objective> _objectiveCache = {};

Objective _finalObjectiveFor(int number) {
  return _objectiveCache.putIfAbsent(number, () {
    final block = _blockOf(number);
    final position = _positionOf(number);
    final spawnMax = _spawnMinFor(block) + kSpawnWidth - 1;
    final obstacles = _obstaclesFor(block);

    final candidate = _objectiveFor(
      position: position,
      block: block,
      spawnMax: spawnMax,
      obstacles: obstacles,
    );

    return _avoidRepetition(number: number, candidate: candidate, obstacles: obstacles);
  });
}

/// Evita que a fase [number] peça o mesmo `targetValue`/`targetCount` que a
/// fase anterior ou a retrasada.
///
/// O histórico "dos últimos 10 objetivos" do pedido original vive no
/// [_objectiveCache] acima — toda fase gerada fica registrada nele, não só as
/// dez mais recentes, porque descartar as mais antigas não compraria nada:
/// olhar para trás de verdade custa duas leituras (N-1 e N-2), que é a regra
/// que decide a mudança. Comparar contra dez fases recuaria a origem do
/// padrão sem mudar a decisão de forçar ou não.
Objective _avoidRepetition({
  required int number,
  required Objective candidate,
  required ObstacleLayout obstacles,
}) {
  if (number <= kHandcraftedLevels + 1) {
    // Fase 11 é a primeira gerada: não há N-1 nem N-2 geradas para comparar.
    return candidate;
  }

  final previous = <Objective>[
    if (number - 1 > kHandcraftedLevels) _finalObjectiveFor(number - 1),
    if (number - 2 > kHandcraftedLevels) _finalObjectiveFor(number - 2),
  ];

  // Um único passo de `_varied` pode escapar da fase N-2 e cair exatamente no
  // padrão da fase N-1 (ou vice-versa) — os dois alvos comparados não são o
  // mesmo, e mudar para longe de um pode ser mudar para perto do outro. Por
  // isso o loop: cada volta varia de novo até não colidir com nenhum dos dois,
  // com um teto para o caso raro em que os dois eixos ajustáveis do objetivo
  // já estão no limite e não sobra para onde variar. `attempts` é passado
  // adiante porque a **estratégia** de variação muda a partir da segunda
  // colisão — ver o comentário em `_varied`.
  var result = candidate;
  var attempts = 0;
  while (previous.any((past) => _samePattern(past, result)) && attempts < 10) {
    result = _varied(result, obstacles, attempt: attempts);
    attempts++;
  }
  return result;
}

bool _samePattern(Objective a, Objective b) =>
    a.type == b.type && a.digit == b.digit && a.obstacle == b.obstacle && a.count == b.count;

/// Um objetivo alternativo para quando [candidate] repete o padrão de uma das
/// duas fases anteriores.
///
/// [attempt] é 0 na primeira colisão (com N-1 ou N-2) e sobe se o resultado
/// ainda colidir com a outra fase. Isto importa porque uma cadeia de três
/// fases seguidas com a mesma contagem — comum nos blocos de contagem alta,
/// onde `count` já satura em [kMaxObjectiveCount] — só tem dois valores de
/// dígito disponíveis por posição (`spawnMax+1`/`spawnMax+2`), e a terceira da
/// cadeia colide com as outras duas ao mesmo tempo. Empilhar dígito de novo
/// (a única saída de `attempt == 0`) resolveria a segunda colisão criando um
/// objetivo pior do que qualquer uma das duas fases originais: a calibragem
/// (`--mode=generated`) mediu uma fase assim ("crie 6 peças 9", janela 3-6) em
/// **0%** de vitória mesmo com o piso de movimentos aplicado — o próprio bug
/// que este ajuste deveria evitar. Por isso, a partir de `attempt >= 1` a
/// variação troca de **natureza** o objetivo em vez de continuar empilhando o
/// mesmo eixo, como o pedido original sugere ("alternar para... quebrar
/// bloqueios"): vira uma fase de quebra de cobertura sobre o que o bloco já
/// espalha, que tem seu próprio limite de movimentos calibrado
/// (`kObstacleMovesPerUnit`) e não herda o custo inflado do dígito.
Objective _varied(Objective candidate, ObstacleLayout obstacles, {required int attempt}) {
  switch (candidate.type) {
    case ObjectiveType.reachDigit:
      if (attempt == 0) {
        final digit = candidate.digit!;
        final bumped = digit + 1;
        // Empilhar para dentro do ápice por este caminho — que, ao contrário
        // de [_objectiveFor], não sabe a distância até `spawnMax` — reproduziu
        // a fase 96 ("crie 6 peças 9", janela 3-6, 0% até 90 movimentos): ver a
        // nota de [kMaxApexObjectiveCount]. O ápice só é seguro quando nasce da
        // fórmula que já respeita essa distância; aqui ele pula direto para o
        // escape de cobertura.
        if (digit < kMaxDigit && bumped < kMaxDigit) {
          return Objective(digit: bumped, count: candidate.count);
        }
        return _toObstacleGoal(obstacles) ?? candidate;
      }
      return _toObstacleGoal(obstacles) ?? candidate;

    case ObjectiveType.clearObstacles:
      final available = obstacles.countOf(candidate.obstacle);
      if (candidate.count < available) {
        return Objective.clearObstacles(obstacle: candidate.obstacle, count: candidate.count + 1);
      }
      // A contagem já pede tudo que o tabuleiro tem daquele tipo: não há como
      // subir sem pedir cobertura que não existe. Troca o tipo de cobertura
      // em vez da contagem — é o mesmo recurso da fase de "limpe tudo" logo
      // abaixo.
      final alternative = _secondHardestOf(obstacles, avoiding: candidate.obstacle);
      if (alternative == null) return candidate;
      final alternativeAvailable = obstacles.countOf(alternative);
      return Objective.clearObstacles(
        obstacle: alternative,
        count: candidate.count.clamp(1, alternativeAvailable),
      );

    case ObjectiveType.clearAllObstacles:
      final alternative = _secondHardestOf(obstacles, avoiding: candidate.obstacle);
      return alternative == null ? candidate : Objective.clearAllObstacles(alternative);
  }
}

/// Converte para um objetivo de quebra de cobertura sobre o que [obstacles]
/// espalha, usado como escape de uma fase de dígito que já colidiu duas vezes.
/// `null` só quando o bloco não espalha cobertura nenhuma — não acontece hoje
/// (`_obstaclesFor` sempre inclui gelo), mas a fase não pode pedir o que o
/// tabuleiro não tem.
Objective? _toObstacleGoal(ObstacleLayout obstacles) {
  if (obstacles.isEmpty) return null;
  final hardest = _hardestOf(obstacles);
  final available = obstacles.countOf(hardest);
  final count = available < 2 ? available : 2;
  return Objective.clearObstacles(obstacle: hardest, count: count);
}

/// A cobertura mais dura de [layout] que não seja [avoiding], se houver
/// alguma.
ObstacleType? _secondHardestOf(ObstacleLayout layout, {required ObstacleType avoiding}) {
  for (final type in [ObstacleType.stone, ObstacleType.glass, ObstacleType.ice]) {
    if (type != avoiding && layout.countOf(type) > 0) return type;
  }
  return null;
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
  final digit0 = position.isOdd ? spawnMax + 2 : spawnMax + 1;
  final digit = digit0 > kMaxDigit ? kMaxDigit : digit0;
  final count = (1 + position % 3 + block ~/ 2).clamp(1, _maxCountFor(digit));

  return Objective(digit: digit, count: count);
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

/// O teto de contagem que vale para um objetivo de dígito [digit].
///
/// [kMaxApexObjectiveCount] no ápice, [kMaxObjectiveCount] em qualquer outro
/// dígito — ver a nota de [kMaxApexObjectiveCount] para o porquê do ápice ter
/// um teto próprio, bem mais baixo.
int _maxCountFor(int digit) => digit == kMaxDigit ? kMaxApexObjectiveCount : kMaxObjectiveCount;

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
int _movesFor({
  required Objective objective,
  required int block,
  required int spawnMin,
  required int spawnMax,
  required int number,
}) {
  final double base = switch (objective.type) {
    ObjectiveType.reachDigit => _digitMoves(objective, spawnMin: spawnMin, spawnMax: spawnMax),
    ObjectiveType.clearObstacles => kObstacleMovesPerUnit * objective.count,
    ObjectiveType.clearAllObstacles => kClearAllMoves,
  };

  // Aperto de 2% por bloco, com teto: a fase encolhe devagar o bastante para o
  // jogador sentir que melhorou, e para de encolher antes de a conta se virar
  // contra ele. O `clamp` inferior é o conserto do defeito que fazia a fase 500
  // sair com um movimento — um percentual aplicado para sempre não tende a um
  // limite apertado, tende a nenhum limite.
  final tighteningFactor = (1 - kTighteningPerBlock * block).clamp(kTighteningFloor, 1.0);

  // A curva senoidal de ritmo entra por último, sobre o valor já apertado: ela
  // é quem decide se esta fase específica é a "difícil" ou a "relaxante" do
  // par, não quem define a tendência de longo prazo — essa continua sendo o
  // aperto por bloco.
  final paced = base * tighteningFactor * _pacingFactor(number);

  final floor = _moveFloorFor(objective);
  final result = paced.floor();
  return result < floor ? floor : result;
}

/// A fórmula pedida para objetivos de "crie N peças de nível X":
/// `moves = count * (targetValue - averageBoardTileLevel) + 8`.
///
/// `averageBoardTileLevel` é o centro da janela de sorteio da fase
/// (`(spawnMin + spawnMax) / 2`) — a régua que já governa toda a dificuldade
/// da campanha gerada (ver a nota de invariância da janela de spawn em
/// `game_level.dart`): o jogo nunca olha o valor absoluto de uma peça, só a
/// distância dela até o que cai do topo. `targetValue - averageBoardTileLevel`
/// é essa distância. O dígito-alvo é sempre estritamente maior que
/// `spawnMax` (invariante travada em teste), e `spawnMax` é sempre maior que
/// o centro da janela, então esta diferença nunca é negativa.
double _digitMoves(Objective objective, {required int spawnMin, required int spawnMax}) {
  final averageBoardTileLevel = (spawnMin + spawnMax) / 2;
  return objective.count * (objective.digit! - averageBoardTileLevel) + 8;
}

/// O piso de movimentos que vale para [objective].
///
/// [kHeavyDigitMoveFloor] só entra em fases de dígito que pedem mais de
/// [kHeavyDigitCountThreshold] peças de nível [kHeavyDigitThreshold]+: são as
/// únicas em que a fórmula linear de [_digitMoves] mediu curto na calibragem.
/// Todo o resto continua no piso geral [kMinMoveLimit].
int _moveFloorFor(Objective objective) {
  final isHeavyDigitGoal = objective.type == ObjectiveType.reachDigit &&
      objective.count > kHeavyDigitCountThreshold &&
      (objective.digit ?? 0) >= kHeavyDigitThreshold;

  return isHeavyDigitGoal ? kHeavyDigitMoveFloor : kMinMoveLimit;
}
