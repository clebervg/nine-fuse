import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';
import 'package:nine_fuse/features/game/domain/position.dart';

/// Cada balão do tutorial interativo. Todos aparecem **uma vez por
/// instalação**: o que já foi visto é gravado pelo nome (ver
/// `TutorialNotifier`), e por isso renomear um valor daqui faz o passo
/// reaparecer para quem já o tinha visto.
enum TutorialStep {
  /// Fase 1, antes da primeira jogada: a mão mostra uma troca que forma trio.
  firstSwap,

  /// Logo depois da primeira fusão: "três 3 viram um 4".
  fusion,

  /// Fase 1, depois da fusão: aponta o objetivo no HUD.
  objective,

  /// Fase 2: aponta o medalhão de jogadas.
  movesMedallion,

  /// Primeira troca recusada (da fase 2 em diante): não gastou jogada.
  freeMiss,

  /// Fase 3, ou a primeira fase com booster em estoque: aponta o dock.
  boosterDock,

  /// Estreia de cada cobertura, apontando uma célula coberta.
  obstacleIce,
  obstacleGlass,
  obstacleStone,
  obstacleChain,

  /// Primeira fase com objetivo "funda N peças X": aponta o objetivo e diz
  /// que conta a peça que **entra** na fusão, não a que nasce. Sem o balão,
  /// "funda" e "crie" pareceriam a mesma meta com verbos diferentes.
  collectGoal,

  /// Primeiro tabuleiro recortado: as casas escuras não existem, e as peças
  /// caem por cima delas.
  boardShape,
}

/// O passo que apresenta a cobertura [type], ou nulo para [ObstacleType.none].
TutorialStep? obstacleTutorialStep(ObstacleType type) => switch (type) {
  ObstacleType.ice => TutorialStep.obstacleIce,
  ObstacleType.glass => TutorialStep.obstacleGlass,
  ObstacleType.stone => TutorialStep.obstacleStone,
  ObstacleType.chain => TutorialStep.obstacleChain,
  ObstacleType.none => null,
};

/// Ordem em que as coberturas são apresentadas quando duas estreiam juntas: a
/// mais fraca primeiro, a mesma ordem em que a campanha as introduz.
const List<ObstacleType> _obstacleOrder = [
  ObstacleType.ice,
  ObstacleType.glass,
  ObstacleType.stone,
  ObstacleType.chain,
];

/// Qual passo "de repouso" mostrar agora, ou nulo.
///
/// "De repouso" são os passos que não dependem de um acontecimento — a fusão
/// e a troca recusada são disparadas pela tela, no instante em que acontecem.
/// Quem chama garante que a fase está em andamento e sem nada sendo encenado;
/// aqui fica só a regra de **qual** balão, para ser testável sem tela.
///
/// [pending] responde se um passo ainda não foi visto. [coveredOnBoard] são os
/// tipos de cobertura presentes no tabuleiro agora.
TutorialStep? idleTutorialStep({
  required int levelNumber,
  required int movesMade,
  required bool Function(TutorialStep step) pending,
  required int boosterStock,
  required Set<ObstacleType> coveredOnBoard,
  bool collectObjective = false,
  bool shapedBoard = false,
}) {
  if (levelNumber == 1 && movesMade == 0 && pending(TutorialStep.firstSwap)) {
    return TutorialStep.firstSwap;
  }
  // O lembrete do objetivo vem **depois** da fusão: antes dela "crie um 4" é
  // uma frase; depois de ver três 3 virarem um 4, é um plano.
  if (levelNumber == 1 &&
      movesMade > 0 &&
      !pending(TutorialStep.fusion) &&
      pending(TutorialStep.objective)) {
    return TutorialStep.objective;
  }
  if (levelNumber == 2 && pending(TutorialStep.movesMedallion)) {
    return TutorialStep.movesMedallion;
  }
  // As duas novidades da campanha longa, também pela primeira vez que
  // aparecem e não pelo número da fase. O objetivo vem antes do formato:
  // entender o que se pede importa mais do que entender o tabuleiro.
  if (collectObjective && pending(TutorialStep.collectGoal)) {
    return TutorialStep.collectGoal;
  }
  if (shapedBoard && pending(TutorialStep.boardShape)) {
    return TutorialStep.boardShape;
  }
  // A estreia da cobertura não olha o número da fase: vale a primeira vez que
  // o tipo aparece no tabuleiro, inclusive para quem "Reviu o tutorial" já
  // longe na campanha.
  for (final type in _obstacleOrder) {
    final step = obstacleTutorialStep(type)!;
    if (coveredOnBoard.contains(type) && pending(step)) return step;
  }
  // Na fase 3 o dock é apresentado mesmo vazio: o "+" do estoque zero também
  // é uma saída que o jogador precisa conhecer. Depois dela, só quem tem o que
  // usar — apontar um dock vazio na fase 40 seria propaganda, não tutorial.
  if (levelNumber >= 3 &&
      pending(TutorialStep.boosterDock) &&
      (levelNumber == 3 || boosterStock > 0)) {
    return TutorialStep.boosterDock;
  }
  return null;
}

/// A troca que a mão do tutorial mostra, ou nulo se o tabuleiro travou.
///
/// Sai das [MatchEngine.candidateSwaps] do tabuleiro real — nunca uma jogada
/// fixa, que o sorteio tornaria impossível. A ordem do par importa: a peça
/// evoluída nasce no **segundo** elemento (é a regra de `tryMove`), então o
/// par é orientado para a combinação passar por ele — a mão termina o gesto
/// exatamente onde a fusão acontece.
///
/// Preferências, nesta ordem: trio exato (o que o balão promete) e que não
/// produza [avoidResult] (o dígito que venceria a fase na hora — o balão da
/// fusão e o lembrete do objetivo perderiam o sentido sob o cartão de
/// vitória). Sem candidato ideal, qualquer troca válida serve.
(Position, Position)? tutorialSwap(
  MatchEngine engine,
  Board board, {
  int? avoidResult,
}) {
  (Position, Position)? fallback;
  (Position, Position)? trio;

  for (final (a, b) in engine.candidateSwaps(board)) {
    final fusion = describeSwapFusion(engine, board, a, b);
    if (fusion == null) continue;

    final oriented = fusion.anchor == a ? (b, a) : (a, b);
    fallback ??= oriented;
    if (fusion.count != 3) continue;
    trio ??= oriented;
    if (fusion.to != avoidResult) return oriented;
  }
  return trio ?? fallback;
}

/// O que a troca [a] → [b] funde: quantas peças, de que valor, em qual.
///
/// `anchor` é a ponta do par por onde a combinação passa — [b] quando as duas
/// passam, porque é ali que `tryMove` faz a peça nascer. Nulo se a troca não
/// forma combinação.
///
/// Calculado sobre o tabuleiro **de antes** da troca, sem resolver nada: o
/// motor sorteia peças novas ao resolver, e rodar `tryMove` só para ler o
/// resultado consumiria o gerador de números e mudaria o tabuleiro seguinte.
({int count, int from, int to, Position anchor})? describeSwapFusion(
  MatchEngine engine,
  Board board,
  Position a,
  Position b,
) {
  final swapped = engine.swap(board, a, b);
  final matches = engine.detectMatches(swapped);
  if (matches.isEmpty) return null;

  final throughB = matches.where((m) => m.contains(b));
  final throughA = matches.where((m) => m.contains(a));
  final (match, anchor) = throughB.isNotEmpty
      ? (throughB.first, b)
      : throughA.isNotEmpty
      ? (throughA.first, a)
      : (matches.first, b);

  // Toda casa de uma combinação tem o mesmo valor (até as de um L ou T, que
  // só se juntam por compartilhar casa).
  final from = swapped.getTileAt(match.first)?.value ?? 0;
  final produced = engine.fusionRule.outcome(length: match.length, value: from);
  return (count: match.length, from: from, to: produced.first, anchor: anchor);
}
