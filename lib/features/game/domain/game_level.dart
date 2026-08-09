import 'package:nine_fuse/features/game/domain/match_engine.dart';

/// O que uma fase pede do jogador.
///
/// Só conta peça **criada por fusão** — receber um dígito do sorteio do topo
/// não cumpre o objetivo. É o que dá sentido a "crie um 6".
class Objective {
  const Objective({required this.digit, this.count = 1})
    : assert(digit >= 0 && digit <= kMaxDigit),
      assert(count >= 1);

  final int digit;
  final int count;

  /// Rótulo **de desenvolvedor**, não de jogador.
  ///
  /// O texto que o jogador lê é montado na apresentação, a partir de [digit] e
  /// [count] (ver `AppLocalizations.objectiveCreateOne`/`objectiveCreateMany`).
  /// Este aqui existe para o `toString()` e para o relatório de
  /// `tool/simulate_economy.dart`, que roda em `dart run` — fora de qualquer
  /// árvore de widgets, e portanto sem `BuildContext` de onde tirar tradução.
  String get debugLabel =>
      count == 1 ? 'Crie um $digit' : 'Crie $count peças $digit';

  @override
  bool operator ==(Object other) =>
      other is Objective && other.digit == digit && other.count == count;

  @override
  int get hashCode => Object.hash(digit, count);

  @override
  String toString() => 'Objective($digit x$count)';
}

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

  /// O que a fase ensina, mostrado como dica. Nulo quando não ensina nada novo.
  final LevelTip? teaches;

  @override
  String toString() =>
      'Fase $number (${objective.debugLabel}, '
      '$moveLimit mov, spawn $spawnMin-$spawnMax)';
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
  GameLevel(
    number: 8,
    objective: Objective(digit: 7),
    moveLimit: 45,
    spawnMin: 1,
    spawnMax: 4,
  ),
  GameLevel(
    number: 9,
    objective: Objective(digit: 8),
    moveLimit: 45,
    spawnMin: 2,
    spawnMax: 5,
  ),
  GameLevel(
    number: 10,
    objective: Objective(digit: kMaxDigit),
    moveLimit: 45,
    spawnMin: 3,
    spawnMax: 6,
    teaches: LevelTip.apexExplodes,
  ),
];
