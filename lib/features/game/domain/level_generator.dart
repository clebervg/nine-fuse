import 'dart:math' show cos, min, pi;

import 'package:nine_fuse/features/game/domain/board_shape.dart';
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

/// Distância (dígito-alvo menos o centro da janela de sorteio) a partir da
/// qual um objetivo de dígito **não-ápice** também cai sob
/// [kMaxApexObjectiveCount].
///
/// O mesmo efeito composto documentado em [kMaxApexObjectiveCount] — custo por
/// peça subindo muito mais rápido que a distância linear — não é exclusivo do
/// `9`. É consequência de a janela de sorteio **ciclar de volta para baixo**
/// (`_spawnMinFor`): a fase 122 ("crie 6 peças 7", janela 2-5, distância 3,5)
/// mede 6% de vitória mesmo no limite que a fórmula escolheu (25 movimentos), e
/// a fase 124 ("crie 6 peças 8", mesma janela, distância 4,5) mede **0%** — os
/// dois números vieram de `--mode=generated` depois que a fórmula linear já
/// tinha sido aplicada, ou seja, o piso pesado ([kHeavyDigitMoveFloor]) não
/// bastou. 3,0 é o corte: a fase 103 ("crie 6 peças 8", janela 4-7, distância
/// 2,5) mede 100% e fica abaixo dele; a fase 22 ("crie 2 peças 9", distância
/// 3,5, já protegida pelo teto de ápice) confirma que 3,5 já é território de
/// ápice mesmo fora do dígito 9.
const double kHeavyDigitDistanceThreshold = 3.0;

/// Teto de coberturas no tabuleiro.
///
/// `placeObstacles` descarta em silêncio a cobertura que não acha lugar — as
/// coberturas não podem nascer encostadas. Pedir mais do que cabe faria a fase
/// pedida deixar de ser a fase jogada.
const int kMaxObstacles = 7;

/// O primeiro bloco gerado com corrente (fases 31-40). O bloco 0 estreia os
/// formatos e a coleta; empilhar a corrente ali seriam três novidades em dez
/// fases, e cada uma merece o seu capítulo.
const int kFirstChainBlock = 2;

/// Quantas correntes cada fase espalha a partir de [kFirstChainBlock], por
/// cima do teto [kMaxObstacles] das outras coberturas.
const int kChainsPerLevel = 2;

/// Movimentos por corrente pedida em "solte N correntes". Bem abaixo de
/// [kObstacleMovesPerUnit]: a corrente tem um impacto só e ainda cede a uma
/// combinação que passe por ela — o jogador pode mirá-la diretamente.
const double kChainMovesPerUnit = 7.0;

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

/// A partir de qual fase o gerador começa a intercalar fases "hard".
///
/// 30 é o pedido original: as fases artesanais (1-10) e os primeiros dois
/// blocos gerados (11-30) continuam sem variação de intensidade — o jogador
/// ainda está aprendendo o ritmo normal da campanha gerada.
const int kHardLevelStart = 30;

/// O quanto o limite de movimentos encolhe numa fase hard, em relação ao
/// que a fórmula normal (aperto por bloco + ritmo) já calculou para aquele
/// número. 0,75 é o "-25%" pedido.
///
/// Aplicado **depois** do aperto por bloco e do ritmo senoidal, e **antes**
/// do piso de projeto ([kMinMoveLimit]/[kHeavyDigitMoveFloor]) — a fase hard
/// nunca fica mais curta que o piso que já vale para qualquer fase.
const double kHardMoveMultiplier = 0.75;

/// A fase [number] é uma fase "hard"?
///
/// Exatamente uma fase hard a cada [kBlockSize] fases, a partir de
/// [kHardLevelStart] — mas a posição dentro do bloco **cicla** em vez de
/// ficar presa sempre na mesma (posição 8, `kBlockSize - 2`): fixa, ela
/// caía sempre no arquétipo de quebra de cobertura (`_objectiveFor` só
/// devolve `clearObstacles`/`clearAllObstacles` a partir da posição
/// `kBlockSize - 3`), e a intensificação da fase hard nunca visitava uma
/// fase de dígito — o oposto do objetivo de reduzir repetição que o resto
/// deste gerador persegue. [_hardPositionFor] cicla pela mesma razão que
/// [_spawnMinFor] cicla a janela de sorteio: nunca a posição 0 (a costura
/// teria uma fase hard logo na abertura do bloco, sem nenhuma fase normal
/// antes para contrastar) e nunca a última posição, `kBlockSize - 1` (o
/// fecho "limpe tudo" já é um arquétipo fixo por conta própria — a mesma
/// razão que excluía a última posição na versão anterior desta função —, e
/// não deveria carregar as duas intensificações ao mesmo tempo).
bool isHardLevel(int number) {
  if (number < kHardLevelStart) return false;
  return _positionOf(number) == _hardPositionFor(_blockOf(number));
}

/// A posição hard do bloco [block], ciclando por `1..kBlockSize - 2` — nunca
/// a posição 0 nem a última do bloco (ver [isHardLevel]). O intervalo
/// cobre tanto posições de dígito (`_objectiveFor` até `kBlockSize - 4`)
/// quanto as duas de quebra de cobertura, então a fase hard varia de
/// arquétipo em vez de sempre cair no mesmo.
int _hardPositionFor(int block) => 1 + block % (kBlockSize - 2);

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

/// Movimentos por peça pedida num objetivo "funda N peças X" com o X **dentro**
/// da janela de sorteio.
///
/// Abaixo de um movimento por peça porque cada combinação consome três ou
/// mais de uma vez, e as cascatas também contam. Fixado por
/// `simulate_economy.dart --mode=generated`.
const double kCollectMovesPerPiece = 0.9;

/// Movimentos por peça pedida quando o X fica **acima** da janela: cada peça
/// tem de ser criada por fusão antes de poder ser fundida de novo.
const double kCollectAboveMovesPerPiece = 4.8;

/// Folga de movimentos por fração de casas fora do formato do tabuleiro.
///
/// Tabuleiro menor tem menos combinações possíveis por jogada e cascata mais
/// curta; sem compensar, todo formato seria só uma fase mais difícil, e o que
/// ele quer ser é uma fase **diferente**. `1.0` dá ao losango (24 casas de
/// vão, 37,5%) 19% de movimentos a mais.
const double kShapeMovesPerVoidFraction = 0.5;

/// A partir de qual fase entram os formatos de tabuleiro. A fase 12 é a
/// primeira de posição 1 no primeiro bloco gerado — logo depois da costura com
/// a campanha artesanal, que termina na matriz inteira.
const int kFirstShapedLevel = 12;

/// Quantos 9 o fecho de ápice pede (ver `_objectiveFor`, fecho `block % 4 ==
/// 2`, sempre na janela 5-8).
///
/// Dez, e não os dois do teto [kMaxApexObjectiveCount]: na janela 5-8 o 9
/// está a uma fusão do topo, e medido com o bot guloso ele faz **cinco** 9 em
/// seis jogadas 73% das vezes — com o piso de [kMinMoveLimit] qualquer
/// contagem pequena dava 100%. Dez em ~14 jogadas fica em 75-90%.
const int kApexClosingCount = 10;

/// Movimentos por 9 pedido no fecho de ápice. Régua própria porque a fórmula
/// de dígito ([_digitMoves]) foi calibrada em janelas baixas, onde o 9 custa
/// várias fusões, e superestima este caso por mais do dobro.
const double kApexClosingMovesPerPiece = 1.4;

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
  final obstacles = _obstaclesFor(block, hard: isHardLevel(number));
  final objective = _finalObjectiveFor(number);
  final shape = shapeForLevel(number);

  return GameLevel(
    number: number,
    objective: objective,
    moveLimit: _movesFor(
      objective: objective,
      block: block,
      spawnMin: spawnMin,
      spawnMax: spawnMax,
      number: number,
      shape: shape,
    ),
    spawnMin: spawnMin,
    spawnMax: spawnMax,
    obstacles: obstacles,
    shape: shape,
  );
}

/// Isola o efeito de [kHardMoveMultiplier] no limite de movimentos da fase
/// [number], para teste.
///
/// Recalcula o mesmo `moveLimit` que [generateLevel] calcularia para
/// [number] — mesmo objetivo, mesmo bloco, mesma janela de sorteio —, mas
/// forçando [hard] em vez de deixar [_movesFor] ler `isHardLevel(number)`
/// sozinho. Sem isso, comparar `generateLevel(hardLevel)` contra
/// `generateLevel(hardLevel - 1)` mede a diferença de **duas** fases que
/// podem ter arquétipo de objetivo diferente (a posição hard cicla entre
/// dígito e cobertura, ver [isHardLevel]) — o multiplicador fica misturado
/// com a diferença de fórmula entre `reachDigit` e `clearObstacles`. Aqui as
/// duas chamadas usam o objetivo real da própria fase [number]; só o `hard`
/// varia.
int moveLimitForTesting(int number, {required bool hard}) {
  final block = _blockOf(number);
  final spawnMin = _spawnMinFor(block);
  final spawnMax = spawnMin + kSpawnWidth - 1;
  final objective = _finalObjectiveFor(number);
  return _movesFor(
    objective: objective,
    block: block,
    spawnMin: spawnMin,
    spawnMax: spawnMax,
    number: number,
    shape: shapeForLevel(number),
    hardOverride: hard,
  );
}

/// Os formatos que aparecem no corpo de um bloco, do mais brando ao mais
/// recortado. O primeiro da lista é o da estreia (fase [kFirstShapedLevel]):
/// cantos cortados mudam pouco o jogo e muito a cara do tabuleiro.
const List<BoardShape> _bodyShapes = [
  BoardShape.cornersCut,
  BoardShape.pillars,
  BoardShape.bridge,
  BoardShape.ring,
  BoardShape.hourglass,
  BoardShape.cross,
];

/// Os formatos do fecho de capítulo — os mais recortados, para a última fase
/// do capítulo ter cara de chefe.
const List<BoardShape> _closingShapes = [
  BoardShape.ring,
  BoardShape.diamond,
  BoardShape.cross,
  BoardShape.hourglass,
];

/// Os formatos que cortam o meio do tabuleiro.
bool _breaksInTheMiddle(BoardShape shape) =>
    shape == BoardShape.pillars || shape == BoardShape.bridge;

/// O formato do tabuleiro da fase [number].
///
/// Três fases do corpo de cada bloco (posições 1, 4 e 7) e o fecho são
/// recortados; o resto é a matriz inteira. Recortar toda fase apagaria o
/// contraste que faz o formato ser notado, e recortar nenhuma era o problema:
/// da fase 100 em diante as fases só se distinguiam pelo número.
///
/// Os índices andam com o bloco para dois capítulos seguidos não repetirem a
/// mesma sequência de formatos.
BoardShape shapeForLevel(int number) {
  if (number < kFirstShapedLevel) return BoardShape.full;
  final block = _blockOf(number);
  final position = _positionOf(number);

  if (position == kBlockSize - 1) {
    // O índice anda um passo a cada volta completa do ciclo de fechos: sem
    // isso cada natureza de fecho (que também roda por `block % 4`) viria
    // sempre no mesmo formato, e o par se repetiria igual a cada 40 fases.
    return _closingShapes[(block + block ~/ 4) % _closingShapes.length];
  }
  if (position % 3 != 1) return BoardShape.full;
  final shape = _bodyShapes[(block * 3 + position ~/ 3 + block ~/ 4) %
      _bodyShapes.length];

  // Pilares e ponte cortam o miolo do tabuleiro, e é ali que a cobertura
  // (que cai com a gravidade) passa a maior parte da fase: medido com o bot,
  // "quebre 3 pedras" cai de ~80% na matriz inteira para 12% nos pilares e
  // 34% na ponte. Numa meta de cobertura eles viram cantos cortados, o
  // formato que menos pesa (90%).
  if (_breaksInTheMiddle(shape) && _finalObjectiveFor(number).isObstacleGoal) {
    return BoardShape.cornersCut;
  }
  return shape;
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
    final obstacles = _obstaclesFor(block, hard: isHardLevel(number));

    final candidate = _objectiveFor(
      position: position,
      block: block,
      spawnMax: spawnMax,
      obstacles: obstacles,
    );

    return _avoidRepetition(
      number: number,
      candidate: candidate,
      obstacles: obstacles,
      spawnMax: spawnMax,
    );
  });
}

/// Centro da janela de sorteio, a partir de [spawnMax].
///
/// `spawnMin` não precisa ser passado à parte: a janela tem sempre
/// [kSpawnWidth] valores, então `spawnMin = spawnMax - kSpawnWidth + 1` e o
/// centro cai direto em função de `spawnMax`.
double _averageBoardTileLevel(int spawnMax) => spawnMax - (kSpawnWidth - 1) / 2;

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
  required int spawnMax,
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
    result = _varied(result, obstacles, attempt: attempts, spawnMax: spawnMax);
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
Objective _varied(
  Objective candidate,
  ObstacleLayout obstacles, {
  required int attempt,
  required int spawnMax,
}) {
  switch (candidate.type) {
    case ObjectiveType.reachDigit:
      if (attempt == 0) {
        final digit = candidate.digit!;
        final bumped = digit + 1;
        // Empilhar para dentro do ápice por este caminho reproduziu a fase 96
        // ("crie 6 peças 9", janela 3-6, 0% até 90 movimentos): ver a nota de
        // [kMaxApexObjectiveCount]. Reduzir só o `count` do dígito bumpado não
        // bastou para consertar o degrau abaixo do ápice: a fase 124 (janela
        // 2-5, `digit` natural já saturado em `spawnMax + 2 = 7`, bumpado para
        // 8) media **0%** mesmo em 16 movimentos e `count` já reduzido a 2 pelo
        // teto — porque `bumped = 8` fica a distância 4,5 do centro da janela,
        // acima de qualquer distância que [_objectiveFor] algum dia produz
        // naturalmente ali (o teto natural do dígito é `spawnMax + 2`, ou seja
        // distância no máximo 3,5). Empilhar para além desse teto natural entra
        // em território nunca calibrado, e nenhum piso de movimentos cobre —
        // por isso o bump só é aceito até `spawnMax + 2`; além disso, escapa
        // para cobertura como o ápice já fazia.
        final naturalCeiling = spawnMax + 2;
        if (digit < kMaxDigit && bumped < kMaxDigit && bumped <= naturalCeiling) {
          final distance = bumped - _averageBoardTileLevel(spawnMax);
          final count = candidate.count.clamp(1, _maxCountFor(bumped, distance));
          return Objective(digit: bumped, count: count);
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
      final alternative = _secondHardestOf(
        obstacles,
        avoiding: candidate.obstacle,
      );
      return alternative == null
          ? candidate
          : Objective.clearAllObstacles(alternative);

    case ObjectiveType.collectDigit:
      // Troca o dígito e mantém a contagem: o custo de "funda N" dentro da
      // janela não depende de qual dígito da janela é pedido, então descer um
      // dígito muda a fase sem mudar a dificuldade. No piso da janela, sobe.
      final digit = candidate.digit!;
      final spawnMin = spawnMax - kSpawnWidth + 1;
      final next = digit > spawnMin ? digit - 1 : digit + 1;
      if (next >= kMaxDigit) return _toObstacleGoal(obstacles) ?? candidate;
      return Objective.collect(digit: next, count: candidate.count);
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
  final spawnMin = spawnMax - kSpawnWidth + 1;

  // Fecho de bloco: roda entre quatro naturezas de meta, para o último
  // capítulo não terminar sempre igual ao anterior. Antes era sempre "limpe
  // toda a pedra", e da fase 100 em diante isso fazia 10% da campanha ser a
  // mesma fase.
  if (position == kBlockSize - 1) {
    return switch (block % 4) {
      // Limpar tudo do tipo mais duro que a fase espalha (o fecho original).
      0 => Objective.clearAllObstacles(_hardestOf(obstacles)),
      // Uma coleta grande de um dígito do pé da janela. Do pé, e não do
      // topo: o topo é o que toda fusão gulosa já consome, e pedido ali o
      // fecho media 95-99% — o limite não pesava.
      1 => Objective.collect(
        digit: spawnMin + 1,
        count: 24 + 3 * min(block, 4),
      ),
      // O ápice: este degrau do ciclo cai sempre na janela 5-8 (ver
      // [_spawnMinFor]), em que o 9 está a uma fusão do topo. Por isso pede
      // dez, bem acima do teto [kMaxApexObjectiveCount] que vale para as
      // janelas baixas (ver [kApexClosingCount]). É o fecho de festa do
      // ciclo, cheio de Bloco 9.
      2 => const Objective(digit: kMaxDigit, count: kApexClosingCount),
      // Coleta acima da janela: cada peça tem de nascer de fusão antes de
      // ser fundida de novo.
      _ => _collectAbove(spawnMax: spawnMax, count: 6),
    };
  }

  // Nos blocos com corrente, a segunda fase de quebra de blocos alternados
  // pede as correntes: é o que dá à cobertura nova uma meta própria, e não só
  // presença de fundo.
  if (position == kBlockSize - 2 && obstacles.chain > 0 && block.isOdd) {
    return Objective.clearObstacles(
      obstacle: ObstacleType.chain,
      count: obstacles.chain,
    );
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

  // Duas fases de coleta no corpo do bloco: uma dentro da janela, outra (a
  // partir do segundo bloco) acima dela. O primeiro bloco fica só com a de
  // dentro, que ensina a meta nova no seu caso mais legível.
  if (position == 3) {
    return Objective.collect(
      digit: spawnMin + 1 + block % 3,
      count: 12 + 3 * min(block, 4),
    );
  }
  if (position == 6 && block >= 1) {
    return _collectAbove(spawnMax: spawnMax, count: 3 + min(block ~/ 2, 3));
  }

  // O corpo do bloco: formar o dígito acima da janela.
  //
  // O `+1` alternando com `+2` dá dois patamares de esforço dentro do mesmo
  // degrau de janela — uma fusão contra duas — sem precisar de outro eixo.
  final digit0 = position.isOdd ? spawnMax + 2 : spawnMax + 1;
  final digit = digit0 > kMaxDigit ? kMaxDigit : digit0;
  final distance = digit - _averageBoardTileLevel(spawnMax);
  final count = (1 + position % 3 + block ~/ 2).clamp(1, _maxCountFor(digit, distance));

  return Objective(digit: digit, count: count);
}

/// "Funda [count] peças" do dígito logo acima da janela — ou do topo dela,
/// quando o de cima já seria o 9 (que não se funde: três 9 viram Nova, e a
/// Nova não é fusão).
Objective _collectAbove({required int spawnMax, required int count}) {
  final digit = spawnMax + 1 < kMaxDigit ? spawnMax + 1 : spawnMax;
  return Objective.collect(digit: digit, count: count);
}

/// As coberturas que o bloco espalha.
///
/// Toda fase gerada tem pelo menos um gelo: as duas fases de cobertura do bloco
/// escolhem seu alvo daqui, e um bloco sem cobertura nenhuma não teria o que
/// pedir. A dureza entra por bloco, do mais macio para o mais duro, na mesma
/// ordem em que a campanha artesanal as apresentou.
ObstacleLayout _obstaclesFor(int block, {bool hard = false}) {
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

  // Fase hard: camada dupla — dobra cada tipo presente antes do teto. Só
  // dobra o que já existe (multiplicar zero continua zero); o teto de
  // tabuleiro é o mesmo de qualquer fase, então o corte por baixo (menos
  // gelo primeiro) segue valendo igual.
  final doubledIce = hard ? ice * 2 : ice;
  final doubledGlass = hard ? glass * 2 : glass;
  final doubledStone = hard ? stone * 2 : stone;

  // O teto é do tabuleiro, não do desenho: o excesso é aparado da cobertura
  // mais macia primeiro (gelo, até o piso de 1), depois da próxima mais macia
  // (vidro, até o mesmo piso), e só em último caso da pedra (também até o
  // piso de 1) — a mais dura entrega primeiro e é a última a perder unidade.
  // Sem os dois estágios seguintes, uma fase hard cujo vidro e/ou pedra já
  // dobrados sozinhos excedem o teto furava `kMaxObstacles` mesmo com o gelo
  // já no piso — foi o que a densidade dobrada da fase hard expôs.
  var trimmedIce = doubledIce;
  var trimmedGlass = doubledGlass;
  var trimmedStone = doubledStone;
  var total = doubledIce + doubledGlass + doubledStone;
  while (total > kMaxObstacles && trimmedIce > 1) {
    trimmedIce--;
    total--;
  }
  while (total > kMaxObstacles && trimmedGlass > 1) {
    trimmedGlass--;
    total--;
  }
  while (total > kMaxObstacles && trimmedStone > 1) {
    trimmedStone--;
    total--;
  }

  // A corrente entra **por cima** do teto das outras três, com o seu próprio
  // teto: somá-la ao corte acima tiraria gelo das fases já calibradas, e a
  // calibragem de gelo, vidro e pedra não precisa ser refeita por causa dela.
  // Não dobra na fase hard pelo mesmo motivo — a intensificação hard foi
  // medida sem ela.
  final chain = block >= kFirstChainBlock ? kChainsPerLevel : 0;

  return ObstacleLayout(
    ice: trimmedIce,
    glass: trimmedGlass,
    stone: trimmedStone,
    chain: chain,
  );
}

/// O teto de contagem que vale para um objetivo de dígito [digit] a
/// [distance] de peças acima do centro da janela de sorteio.
///
/// [kMaxApexObjectiveCount] no ápice **e** em qualquer dígito cuja distância
/// já esteja no mesmo território caro (ver [kHeavyDigitDistanceThreshold] —
/// o efeito é o mesmo custo composto por peça, só que a janela cíclica pode
/// reproduzi-lo em dígitos bem abaixo de 9). [kMaxObjectiveCount] no resto.
int _maxCountFor(int digit, double distance) {
  if (digit == kMaxDigit) return kMaxApexObjectiveCount;
  if (distance >= kHeavyDigitDistanceThreshold) return kMaxApexObjectiveCount;
  return kMaxObjectiveCount;
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
int _movesFor({
  required Objective objective,
  required int block,
  required int spawnMin,
  required int spawnMax,
  required int number,
  BoardShape shape = BoardShape.full,
  bool? hardOverride,
}) {
  final double objectiveBase = switch (objective.type) {
    ObjectiveType.reachDigit when _isApexClosing(objective) =>
      kApexClosingMovesPerPiece * objective.count,
    ObjectiveType.reachDigit => _digitMoves(
      objective,
      spawnMin: spawnMin,
      spawnMax: spawnMax,
    ),
    ObjectiveType.clearObstacles when objective.obstacle == ObstacleType.chain =>
      kChainMovesPerUnit * objective.count,
    ObjectiveType.clearObstacles => kObstacleMovesPerUnit * objective.count,
    ObjectiveType.clearAllObstacles => kClearAllMoves,
    ObjectiveType.collectDigit => _collectMoves(objective, spawnMax: spawnMax),
  };
  final voidFraction =
      shape.voids.length / (shape.voids.length + shape.playableCount);
  final base = objectiveBase * (1 + kShapeMovesPerVoidFraction * voidFraction);

  // Aperto de 2% por bloco, com teto: a fase encolhe devagar o bastante para o
  // jogador sentir que melhorou, e para de encolher antes de a conta se virar
  // contra ele. O `clamp` inferior é o conserto do defeito que fazia a fase 500
  // sair com um movimento — um percentual aplicado para sempre não tende a um
  // limite apertado, tende a nenhum limite.
  //
  // O fecho de ápice fica fora do aperto: a curva dele é íngreme (10 jogadas
  // dão ~40%, 16 dão ~95%), e o quarto que o aperto tira nos blocos altos o
  // jogava de 96% no bloco 3 para 20% no bloco 14 — a mesma fase, dois jogos.
  final tighteningFactor = _isApexClosing(objective)
      ? 1.0
      : (1 - kTighteningPerBlock * block).clamp(kTighteningFloor, 1.0);

  // A curva senoidal de ritmo entra por último, sobre o valor já apertado: ela
  // é quem decide se esta fase específica é a "difícil" ou a "relaxante" do
  // par, não quem define a tendência de longo prazo — essa continua sendo o
  // aperto por bloco.
  final paced = base * tighteningFactor * _pacingFactor(number);
  final hard = hardOverride ?? isHardLevel(number);
  final hardened = hard ? paced * kHardMoveMultiplier : paced;

  final distance = objective.type == ObjectiveType.reachDigit
      ? objective.digit! - _averageBoardTileLevel(spawnMax)
      : 0.0;
  final floor = _moveFloorFor(objective, distance: distance);
  final result = hardened.floor();
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

/// O fecho de ápice ("crie dez 9" na janela 5-8): o único objetivo de dígito
/// que não passa pela fórmula nem pelo piso pesado de [_digitMoves].
bool _isApexClosing(Objective objective) =>
    objective.type == ObjectiveType.reachDigit &&
    objective.digit == kMaxDigit &&
    objective.count == kApexClosingCount;

/// Movimentos-base de "funda N peças X": mais caro por peça quando o X fica
/// acima da janela, porque ali cada peça tem de nascer antes de entrar.
double _collectMoves(Objective objective, {required int spawnMax}) {
  final above = objective.digit! > spawnMax;
  return objective.count *
      (above ? kCollectAboveMovesPerPiece : kCollectMovesPerPiece);
}

/// O piso de movimentos que vale para [objective], a [distance] peças acima
/// do centro da janela de sorteio.
///
/// [kHeavyDigitMoveFloor] entra em duas situações, cada uma achada por uma
/// calibragem diferente: fases de dígito com mais de
/// [kHeavyDigitCountThreshold] peças de nível [kHeavyDigitThreshold]+ (a
/// fórmula linear de [_digitMoves] mediu curto para essas na calibragem
/// original), **e** qualquer fase de dígito cuja [distance] já esteja no
/// território de [kHeavyDigitDistanceThreshold] — mesmo pedindo só 2 peças. A
/// segunda faltava: a fase 124 ("crie 2 peças 8", janela 2-5, distância 4,5,
/// já com `count` reduzido pelo teto de [kMaxApexObjectiveCount|_maxCountFor])
/// media **0%** em 14 movimentos, porque `count == 2` não passa de
/// [kHeavyDigitCountThreshold] e o piso pesado não entrava — a distância
/// grande sozinha já basta para o custo composto por peça, sem precisar de
/// contagem alta para expor o problema — [_maxCountFor] reduz `count`, mas
/// não move a fase para fora do território caro. Todo o resto continua no
/// piso geral [kMinMoveLimit].
int _moveFloorFor(Objective objective, {required double distance}) {
  final isHeavyDigitGoal =
      objective.type == ObjectiveType.reachDigit &&
      !_isApexClosing(objective) &&
      (objective.digit ?? 0) >= kHeavyDigitThreshold &&
      (objective.count > kHeavyDigitCountThreshold || distance >= kHeavyDigitDistanceThreshold);

  return isHeavyDigitGoal ? kHeavyDigitMoveFloor : kMinMoveLimit;
}
