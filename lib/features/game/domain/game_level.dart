import 'package:nine_fuse/features/game/domain/level_objective.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';

// [Objective] mudou de arquivo quando ganhou os objetivos de cobertura, mas
// continua sendo lido a partir daqui por toda a UI e por todos os testes: quem
// pede uma fase quase sempre pede o objetivo junto.
export 'package:nine_fuse/features/game/domain/level_objective.dart';

/// O que uma fase ensina, como **identidade** e não como frase.
///
/// A frase em si mora nos arquivos de tradução: guardá-la aqui obrigaria a
/// camada `domain` a conhecer `BuildContext`, e todo teste de regra de jogo
/// passaria a precisar de uma árvore de widgets para existir.
enum LevelTip {
  alignThree,
  repeatFusion,
  chainFusion,
  biggerMatches,
  longLevel,
  zeroStopped,

  /// A explosão do dígito máximo. Traduzida com o dígito como parâmetro, para
  /// a frase acompanhar [kMaxDigit] em vez de repetir "9" à mão.
  apexExplodes,

  /// A peça coberta: não combina, não troca, e só se solta com uma fusão
  /// encostada nela.
  obstacleBlocks,
}

/// Uma fase da campanha: um objetivo, um limite de movimentos e a janela de
/// valores que cai do topo.
class GameLevel {
  const GameLevel({
    required this.number,
    required this.objective,
    required this.moveLimit,
    this.spawnMin = kSpawnMin,
    this.spawnMax = kSpawnMax,
    this.obstacles = ObstacleLayout.none,
    this.teaches,
  }) : assert(moveLimit > 0),
       assert(
         spawnMax - spawnMin == kSpawnWidth - 1,
         'a janela da fase tem exatamente $kSpawnWidth valores',
       ),
       assert(
         spawnMin >= 0 && spawnMax < kMaxDigit,
         'o dígito máximo nunca cai pronto do topo',
       );

  // Nota: "o dígito do objetivo tem de estar acima da janela de spawn" é
  // invariante do catálogo, não deste construtor — se o alvo cai pronto do
  // topo, a fase vira sorte em vez de plano. Um `assert` const não consegue
  // ler `objective.digit`, então a regra é verificada em teste, sobre todas as
  // fases de [kCampaign], o que aliás cobre mais do que o assert cobriria.

  final int number;
  final Objective objective;

  /// Movimentos disponíveis. Só troca válida consome movimento.
  final int moveLimit;

  /// Janela de valores sorteados nesta fase.
  final int spawnMin;
  final int spawnMax;

  /// Coberturas que a fase espalha pelo tabuleiro no sorteio inicial.
  ///
  /// É pedido, não posição: onde cada uma cabe é decisão do motor
  /// (`MatchEngine.placeObstacles`), que garante tabuleiro jogável.
  final ObstacleLayout obstacles;

  /// O que a fase ensina, mostrado como dica. Nulo quando não ensina nada novo.
  final LevelTip? teaches;

  @override
  String toString() =>
      'Fase $number (${objective.debugLabel}, '
      '$moveLimit mov, spawn $spawnMin-$spawnMax'
      '${obstacles.isEmpty ? '' : ', $obstacles'})';
}

/// As dez primeiras fases.
///
/// Os limites de movimento **não** foram escolhidos a olho: vêm da taxa de
/// sucesso medida em `tool/simulate_economy.dart --mode=phases`, com um jogador
/// automático que sempre escolhe a fusão de maior valor. A meta é 70-90% de
/// aprovação — abaixo de 50% o jogador reprova mais do que passa, acima de 95%
/// o limite não pesa e a fase perde a tensão.
///
/// A progressão dos dígitos altos vem de subir a janela de spawn, não de
/// apertar o limite. O motivo está provado em teste (`invariância da janela de
/// spawn`): nada no jogo olha o valor absoluto de uma peça, então
/// `spawn 1-4 + alvo 6` é exatamente tão difícil quanto `spawn 0-3 + alvo 5`.
/// Assim a campanha chega ao 9 sem que a última fase seja impossível.
const List<GameLevel> kCampaign = [
  GameLevel(
    number: 1,
    objective: Objective(digit: 4),
    moveLimit: 6,
    teaches: LevelTip.alignThree,
  ),
  GameLevel(
    number: 2,
    objective: Objective(digit: 4, count: 3),
    moveLimit: 10,
    teaches: LevelTip.repeatFusion,
  ),
  GameLevel(
    number: 3,
    objective: Objective(digit: 5),
    moveLimit: 10,
    teaches: LevelTip.chainFusion,
  ),
  GameLevel(number: 4, objective: Objective(digit: 5, count: 2), moveLimit: 15),
  GameLevel(
    number: 5,
    objective: Objective(digit: 5, count: 3),
    moveLimit: 21,
    teaches: LevelTip.biggerMatches,
  ),
  GameLevel(
    number: 6,
    objective: Objective(digit: 6),
    moveLimit: 45,
    teaches: LevelTip.longLevel,
  ),

  // A partir daqui a janela sobe. Cada fase repete uma dificuldade já
  // calibrada, um dígito acima.
  GameLevel(
    number: 7,
    objective: Objective(digit: 6, count: 2),
    moveLimit: 14,
    spawnMin: 1,
    spawnMax: 4,
    teaches: LevelTip.zeroStopped,
  ),
  // Da fase 8 em diante entram as coberturas, um tipo por estreia. O gelo
  // primeiro porque cede a um impacto: ensina a regra ("fusão encostada
  // quebra") sem punir quem ainda não a entendeu.
  GameLevel(
    number: 8,
    objective: Objective(digit: 7),
    moveLimit: 45,
    spawnMin: 1,
    spawnMax: 4,
    obstacles: ObstacleLayout(ice: 3),
    teaches: LevelTip.obstacleBlocks,
  ),
  GameLevel(
    number: 9,
    objective: Objective(digit: 8),
    moveLimit: 45,
    spawnMin: 2,
    spawnMax: 5,
    obstacles: ObstacleLayout(ice: 2, glass: 2),
  ),
  // A pedra aguenta três impactos, e só aparece aqui: esta é a fase que dá a
  // onda de choque do dígito máximo, a saída que varre a célula coberta por
  // inteiro. Pedir pedra antes disso seria pedir paciência, não plano.
  GameLevel(
    number: 10,
    objective: Objective(digit: kMaxDigit),
    moveLimit: 45,
    spawnMin: 3,
    spawnMax: 6,
    obstacles: ObstacleLayout(glass: 2, stone: 2),
    teaches: LevelTip.apexExplodes,
  ),
];
