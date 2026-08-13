// Simulador da economia do NineFuse.
//
// Responde à pergunta que bloqueia o sistema de fases: quantos movimentos
// custa alcançar cada dígito? Sem isso, escolher o alvo e o limite de
// movimentos de uma fase é adivinhação.
//
// Roda o MatchEngine de verdade — não uma reimplementação — para que os
// números descrevam o jogo que existe.
//
// Uso: dart run tool/simulate_economy.dart [--games=N] [--moves=N]

// Script de linha de comando: aqui o print é a saída do programa.
// ignore_for_file: avoid_print

import 'dart:math';

import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/endless_progression.dart';
import 'package:nine_fuse/features/game/domain/fusion_rule.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/level_generator.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';
import 'package:nine_fuse/features/game/domain/position.dart';

/// Como o jogador simulado escolhe a jogada.
enum Strategy {
  /// Escolhe qualquer jogada válida. Piso: jogador distraído.
  random('aleatório'),

  /// Escolhe a jogada que funde o maior dígito disponível, desempatando pela
  /// combinação mais longa. Aproxima um jogador competente que persegue o alvo.
  greedy('guloso');

  const Strategy(this.label);
  final String label;
}

/// Resultado de uma partida simulada.
class GameOutcome {
  GameOutcome({
    required this.movesPlayed,
    required this.firstReach,
    required this.explosions,
    required Map<int, List<int>> producedAt,
  }) {
    this.producedAt.addAll(producedAt);
  }

  /// Em quantos movimentos o jogador criaria [count] peças de [digit]?
  /// `null` se não conseguiu na partida inteira.
  int? movesToProduce(int digit, int count) {
    final events = producedAt[digit];
    if (events == null || events.length < count) return null;
    return events[count - 1];
  }

  /// Movimentos jogados até travar ou até o teto.
  final int movesPlayed;

  /// Dígito → número do movimento em que ele apareceu pela primeira vez.
  final Map<int, int> firstReach;

  /// Dígito → movimentos em que uma peça daquele dígito foi **criada** por
  /// fusão, em ordem. Peça vinda do sorteio não entra: para um objetivo de
  /// fase, "criar um 5" não é "receber um 5 do topo".
  final Map<int, List<int>> producedAt = {};

  /// Total de explosões do dígito máximo na partida.
  final int explosions;
}

/// Joga uma partida inteira e registra quando cada dígito surgiu.
GameOutcome playGame({
  required MatchEngine engine,
  required Strategy strategy,
  required Random random,
  required int moveCap,
}) {
  var board = engine.generateBoard();
  final firstReach = <int, int>{};
  final producedAt = <int, List<int>>{};
  var moves = 0;
  var explosions = 0;

  // Os dígitos do tabuleiro inicial contam como alcançados no movimento 0.
  for (final tile in board.getAllTiles()) {
    firstReach.putIfAbsent(tile.value, () => 0);
  }

  while (moves < moveCap) {
    final options = _rankMoves(engine, board);
    if (options.isEmpty) break;

    final chosen = switch (strategy) {
      Strategy.random => options[random.nextInt(options.length)],
      Strategy.greedy => options.first,
    };

    final resolution = engine.resolve(
      engine.swap(board, chosen.from, chosen.to),
      anchor: chosen.to,
    );
    board = resolution.board;
    moves++;
    explosions += resolution.explosions;

    for (final digit in resolution.producedDigits) {
      producedAt.putIfAbsent(digit, () => []).add(moves);
      firstReach.putIfAbsent(digit, () => moves);
    }
    for (final tile in board.getAllTiles()) {
      firstReach.putIfAbsent(tile.value, () => moves);
    }
  }

  return GameOutcome(
    movesPlayed: moves,
    firstReach: firstReach,
    explosions: explosions,
    producedAt: producedAt,
  );
}

class _Move {
  _Move({
    required this.from,
    required this.to,
    required this.value,
    required this.length,
  });

  final Position from;
  final Position to;

  /// Maior dígito envolvido na combinação que a troca cria.
  final int value;

  /// Tamanho da maior combinação criada.
  final int length;
}

/// Jogadas válidas, da mais valiosa para a menos valiosa.
List<_Move> _rankMoves(MatchEngine engine, Board board) {
  final moves = <_Move>[];

  for (final (from, to) in engine.candidateSwaps(board)) {
    final swapped = engine.swap(board, from, to);
    final matches = engine.detectMatches(swapped);
    if (matches.isEmpty) continue;

    var bestValue = -1;
    var bestLength = 0;
    for (final match in matches) {
      final value = swapped.getTileAt(match.first)?.value ?? -1;
      if (value > bestValue ||
          (value == bestValue && match.length > bestLength)) {
        bestValue = value;
        bestLength = match.length;
      }
    }

    moves.add(_Move(from: from, to: to, value: bestValue, length: bestLength));
  }

  moves.sort((a, b) {
    final byValue = b.value.compareTo(a.value);
    return byValue != 0 ? byValue : b.length.compareTo(a.length);
  });

  return moves;
}

// -----------------------------------------------------------------------------
// Relatório
// -----------------------------------------------------------------------------

int? _median(List<int> values) {
  if (values.isEmpty) return null;
  final sorted = [...values]..sort();
  return sorted[sorted.length ~/ 2];
}

String _pad(String text, int width) => text.padRight(width);
String _padLeft(String text, int width) => text.padLeft(width);

void _report({
  required String heading,
  required String subheading,
  required FusionRule rule,
  required Strategy strategy,
  required int games,
  required int moveCap,
  int spawnMin = kSpawnMin,
  int spawnMax = kSpawnMax,
  ExplosionShape explosion = ExplosionShape.none,
}) {
  final outcomes = <GameOutcome>[];

  for (int seed = 0; seed < games; seed++) {
    // Semente distinta por partida, e o mesmo conjunto de sementes para todas
    // as configurações: a comparação não depende de sorte.
    outcomes.add(
      playGame(
        engine: MatchEngine(
          random: Random(seed),
          fusionRule: rule,
          spawnMin: spawnMin,
          spawnMax: spawnMax,
          explosionShape: explosion,
        ),
        strategy: strategy,
        random: Random(1000 + seed),
        moveCap: moveCap,
      ),
    );
  }

  print('');
  print('  $heading');
  print('  $subheading');
  print('  ${'-' * 58}');
  print('  ${_pad('dígito', 8)}${_padLeft('alcançou', 10)}'
      '${_padLeft('mediana', 12)}${_padLeft('mín', 8)}${_padLeft('máx', 8)}');
  print('  ${'-' * 58}');

  for (int digit = 4; digit <= kMaxDigit; digit++) {
    final reached = outcomes
        .map((o) => o.firstReach[digit])
        .whereType<int>()
        .toList();
    final rate = reached.length / outcomes.length;

    final median = _median(reached);
    print('  ${_pad('$digit', 8)}'
        '${_padLeft('${(rate * 100).round()}%', 10)}'
        '${_padLeft(median == null ? '—' : '$median mov', 12)}'
        '${_padLeft(reached.isEmpty ? '—' : '${reached.reduce(min)}', 8)}'
        '${_padLeft(reached.isEmpty ? '—' : '${reached.reduce(max)}', 8)}');
  }

  final lengths = outcomes.map((o) => o.movesPlayed).toList();
  final stalled = outcomes.where((o) => o.movesPlayed < moveCap).length;
  final blasts = outcomes.map((o) => o.explosions).toList();
  print('  ${'-' * 58}');
  print('  partida: mediana ${_median(lengths)} movimentos   '
      'TRAVOU em $stalled/${outcomes.length}');
  if (blasts.any((b) => b > 0)) {
    print('  explosões por partida: mediana ${_median(blasts)}   '
        'máx ${blasts.reduce(max)}');
  }
}

/// Taxa de sucesso de uma fase (criar [count] peças de [digit]) para vários
/// limites de movimento. É o número que decide o limite de cada fase: a
/// mediana esconde a variância, e um limite na mediana reprova metade das
/// tentativas.
void _reportPhaseTargets({
  required int games,
  required int moveCap,
  required List<(int digit, int count)> targets,
  required List<int> limits,
}) {
  final outcomes = <GameOutcome>[];
  for (int seed = 0; seed < games; seed++) {
    outcomes.add(
      playGame(
        engine: MatchEngine(random: Random(seed)),
        strategy: Strategy.greedy,
        random: Random(1000 + seed),
        moveCap: moveCap,
      ),
    );
  }

  print('');
  print('  ${_pad('objetivo', 16)}${limits.map((l) => _padLeft('$l mov', 9)).join()}');
  print('  ${'-' * (16 + limits.length * 9)}');

  for (final (digit, count) in targets) {
    final needed = outcomes
        .map((o) => o.movesToProduce(digit, count))
        .toList();

    final cells = limits.map((limit) {
      final wins = needed.where((n) => n != null && n <= limit).length;
      return _padLeft('${(wins / outcomes.length * 100).round()}%', 9);
    }).join();

    final label = count == 1 ? 'criar um $digit' : 'criar $count x $digit';
    print('  ${_pad(label, 16)}$cells');
  }

  print('');
  print('  Leitura: uma fase agradável fica entre 70% e 90%. Abaixo de 50% o');
  print('  jogador reprova mais do que passa; acima de 95% o limite não pesa.');
}

/// Joga cada fase de [kCampaign] com a sua própria configuração e mede a taxa
/// de vitória. Valida o catálogo que está no app, não uma aproximação dele.
void _reportCampaign({required int games}) {
  print('');
  print('  ${_pad('fase', 6)}${_pad('objetivo', 16)}${_pad('spawn', 8)}'
      '${_padLeft('limite', 8)}${_padLeft('vitórias', 10)}'
      '${_padLeft('mov (mediana)', 15)}');
  print('  ${'-' * 63}');

  for (final level in kCampaign) {
    final movesToWin = <int>[];
    var stalled = 0;

    for (int seed = 0; seed < games; seed++) {
      final engine = MatchEngine(
        random: Random(seed),
        spawnMin: level.spawnMin,
        spawnMax: level.spawnMax,
      );
      final chooser = Random(1000 + seed);

      var board = engine.generateBoard(obstacles: level.obstacles);
      final target = _targetOf(level, board);
      var produced = 0;
      var moves = 0;

      while (moves < level.moveLimit && produced < target) {
        final options = _rankMoves(engine, board);
        if (options.isEmpty) {
          stalled++;
          break;
        }

        final chosen = options.first;
        final resolution = engine.resolve(
          engine.swap(board, chosen.from, chosen.to),
          anchor: chosen.to,
        );
        board = resolution.board;
        produced += _gainOf(level, resolution);
        moves++;
        // Silencia o aviso de variável não usada quando a estratégia é fixa.
        chooser.nextInt(2);
      }

      if (produced >= target) movesToWin.add(moves);
    }

    final rate = movesToWin.length / games;
    final median = _median(movesToWin);

    print('  ${_pad('${level.number}', 6)}'
        '${_pad(level.objective.debugLabel, 16)}'
        '${_pad('${level.spawnMin}-${level.spawnMax}', 8)}'
        '${_padLeft('${level.moveLimit}', 8)}'
        '${_padLeft('${(rate * 100).round()}%', 10)}'
        '${_padLeft(median == null ? '—' : '$median', 15)}'
        '${stalled > 0 ? '   travou $stalled x' : ''}');
  }

  print('');
  print('  Meta: 70-90% de vitórias. Fase com 0% é intransponível; fase com');
  print('  100% e mediana muito abaixo do limite não tem tensão nenhuma.');
}

/// Percentil [p] (0..1) de uma lista, pelo método do índice mais próximo.
int? _percentile(List<int> values, double p) {
  if (values.isEmpty) return null;
  final sorted = [...values]..sort();
  final index = (p * (sorted.length - 1)).round();
  return sorted[index];
}

/// Alvo de aprovação de uma fase da campanha.
const double _minWinRate = 0.70;
const double _maxWinRate = 0.90;

/// Valida a **eficiência** de cada fase da campanha.
///
///     Eficiência = objetivo (peças a criar) / movimentos permitidos
///
/// O número sozinho não diz nada: 3 peças em 21 movimentos é confortável para
/// um alvo 5 e impossível para um alvo 8. O que dá sentido a ele é a
/// eficiência que a *janela daquela fase* permite de fato — quantas peças do
/// dígito alvo o jogador consegue criar por movimento, medida jogando a fase
/// sem limite. Daí saem dois números comparáveis:
///
/// - **exigida**: o que a fase pede (`count / moveLimit`);
/// - **alcançável**: o que o motor entrega (`count / movimentos medidos`).
///
/// Exigida acima de alcançável é uma fase que a taxa de spawn e a
/// probabilidade de cascata daquela janela não sustentam — e o relatório
/// avisa, com o limite mínimo que a tornaria viável.
void _reportEfficiency({required int games}) {
  print('');
  print('  ${_pad('fase', 6)}${_pad('objetivo', 16)}${_pad('spawn', 8)}'
      '${_padLeft('limite', 8)}${_padLeft('exigida', 10)}'
      '${_padLeft('alcançável', 12)}${_padLeft('vitórias', 10)}  diagnóstico');
  print('  ${'-' * 96}');

  var problems = 0;

  for (final level in kCampaign) {
    // Teto generoso: aqui interessa o custo real do objetivo, não se ele cabe
    // no limite — essa comparação vem depois.
    final cap = level.moveLimit * 6;
    final needed = <int>[];

    for (int seed = 0; seed < games; seed++) {
      final engine = MatchEngine(
        random: Random(seed),
        spawnMin: level.spawnMin,
        spawnMax: level.spawnMax,
      );

      var board = engine.generateBoard(obstacles: level.obstacles);
      final target = _targetOf(level, board);
      var produced = 0;
      var moves = 0;

      while (moves < cap && produced < target) {
        final options = _rankMoves(engine, board);
        if (options.isEmpty) break; // tabuleiro travado: partida perdida

        final chosen = options.first;
        final resolution = engine.resolve(
          engine.swap(board, chosen.from, chosen.to),
          anchor: chosen.to,
        );
        board = resolution.board;
        produced += _gainOf(level, resolution);
        moves++;
      }

      if (produced >= target) needed.add(moves);
    }

    final reachRate = needed.length / games;
    final wins = needed.where((n) => n <= level.moveLimit).length / games;

    // Limite que aprovaria [_minWinRate] das partidas. Só existe se pelo menos
    // essa fração alcançou o objetivo em algum momento.
    final viableLimit =
        reachRate >= _minWinRate ? _percentile(needed, _minWinRate) : null;

    // O alvo nominal da fase basta aqui: a eficiência é um retrato da fase, não
    // de um sorteio.
    final nominalTarget = level.objective.type ==
            ObjectiveType.clearAllObstacles
        ? level.obstacles.countOf(level.objective.obstacle)
        : level.objective.count;

    final required = nominalTarget / level.moveLimit;
    final attainable = _median(needed) == null
        ? null
        : nominalTarget / _median(needed)!;

    final String diagnosis;
    if (reachRate < _minWinRate) {
      problems++;
      diagnosis = 'INVIÁVEL: só ${(reachRate * 100).round()}% das partidas '
          'alcançam o objetivo, mesmo com $cap movimentos';
    } else if (wins < _minWinRate) {
      problems++;
      diagnosis = 'APERTADA: eficiência exigida acima da alcançável — '
          'limite mínimo viável $viableLimit';
    } else if (wins > _maxWinRate) {
      diagnosis = 'frouxa: o limite não pesa (sugestão $viableLimit)';
    } else {
      diagnosis = 'ok';
    }

    print('  ${_pad('${level.number}', 6)}'
        '${_pad(level.objective.debugLabel, 16)}'
        '${_pad('${level.spawnMin}-${level.spawnMax}', 8)}'
        '${_padLeft('${level.moveLimit}', 8)}'
        '${_padLeft(required.toStringAsFixed(3), 10)}'
        '${_padLeft(
            attainable == null ? '—' : attainable.toStringAsFixed(3), 12)}'
        '${_padLeft('${(wins * 100).round()}%', 10)}  $diagnosis');
  }

  print('');
  if (problems == 0) {
    print('  Nenhuma fase com eficiência inviável.');
  } else {
    print('  ATENÇÃO: $problems fase(s) com eficiência inviável ou apertada.');
  }
}

/// Mede o modo Endless: janela fixa contra janela progressiva.
///
/// O número que importa é a linha TRAVOU. Uma partida Endless que morre por
/// falta de jogada em poucos minutos não é um modo de high score, é um bug de
/// design.
void _reportEndless({required int games, required int moveCap}) {
  const progression = EndlessProgression();

  /// Uma estratégia de janela devolve (min, max) para um degrau.
  void run({
    required String label,
    required bool escalate,
    (int, int) Function(int step)? window,
  }) {
    final windowFor = window ??
        (int step) => (
              progression.spawnMinFor(step),
              progression.spawnMaxFor(step),
            );
    final lengths = <int>[];
    final scores = <int>[];
    final topDigits = <int>[];
    final finalSteps = <int>[];
    var stalled = 0;

    for (int seed = 0; seed < games; seed++) {
      // A estratégia "alargando" existe justamente para medir uma janela fora
      // da largura padrão — é o único lugar do projeto que precisa disso.
      final engine = MatchEngine(random: Random(seed), allowWideSpawn: true);
      var step = EndlessProgression.firstStep;
      final start = windowFor(step);
      engine.setSpawnWindow(min: start.$1, max: start.$2);

      var board = engine.generateBoard();
      var moves = 0;
      var score = 0;
      var top = 0;

      while (moves < moveCap) {
        final options = _rankMoves(engine, board);
        if (options.isEmpty) {
          stalled++;
          break;
        }

        final chosen = options.first;
        final resolution = engine.resolve(
          engine.swap(board, chosen.from, chosen.to),
          anchor: chosen.to,
        );
        board = resolution.board;
        score += resolution.score;
        moves++;

        for (final digit in resolution.producedDigits) {
          if (digit > top) top = digit;
        }

        if (escalate) {
          final next = progression.advance(
            step: step,
            produced: resolution.producedDigits,
          );
          if (next != step) {
            step = next;
            final w = windowFor(step);
            engine.setSpawnWindow(min: w.$1, max: w.$2);
          }
        }
      }

      lengths.add(moves);
      scores.add(score);
      topDigits.add(top);
      finalSteps.add(step);
    }

    print('');
    print('  $label');
    print('  partida: mediana ${_median(lengths)} movimentos '
        '(máx ${lengths.reduce(max)})');
    print('  TRAVOU em $stalled/$games');
    print('  maior dígito criado: mediana ${_median(topDigits)}   '
        'máx ${topDigits.reduce(max)}');
    print('  pontos: mediana ${_median(scores)}');
    if (escalate) {
      print('  degrau final: mediana ${_median(finalSteps)}   '
          'máx ${finalSteps.reduce(max)} de ${EndlessProgression.lastStep}');
    }
  }

  run(label: 'A) FIXA em 0-3 (o que existe hoje)', escalate: false);

  run(
    label: 'B) DESLIZANTE 0-3 -> 3-6 (piso sobe; peças baixas ficam órfãs)',
    escalate: true,
  );

  run(
    label: 'C) ALARGANDO 0-3 -> 0-6 (piso fica; nada perde fornecimento)',
    escalate: true,
    window: (step) => (0, 3 + step.clamp(0, EndlessProgression.lastStep)),
  );

  run(
    label: 'D) DESLIZANTE LENTA 0-3 -> 2-5 (meio-termo)',
    escalate: true,
    window: (step) {
      final min = (step ~/ 2).clamp(0, 2);
      return (min, min + 3);
    },
  );
}

int _intArg(List<String> args, String name, int fallback) {
  final prefix = '--$name=';
  final match = args.firstWhere(
    (a) => a.startsWith(prefix),
    orElse: () => '',
  );
  if (match.isEmpty) return fallback;
  return int.tryParse(match.substring(prefix.length)) ?? fallback;
}

String _multipliers(FusionRule rule) =>
    'm3=${rule.valueMultiplier(3).toStringAsFixed(2)}x '
    'm4=${rule.valueMultiplier(4).toStringAsFixed(2)}x '
    'm5=${rule.valueMultiplier(5).toStringAsFixed(2)}x';

void main(List<String> args) {
  final games = _intArg(args, 'games', 30);
  final moveCap = _intArg(args, 'moves', 400);
  final mode = args.firstWhere(
    (a) => a.startsWith('--mode='),
    orElse: () => '--mode=both',
  ).substring('--mode='.length);

  const rules = [NeutralFusion(), TieredFusion(), AggressiveFusion()];

  print('');
  print('NineFuse — custo em movimentos por dígito');
  print('$games partidas por configuração, teto de $moveCap movimentos');
  print('=' * 62);

  if (mode == 'rules' || mode == 'both') {
    print('');
    print('#' * 62);
    print('# A) REGRA DE FUSÃO   (janela de spawn fixa em $kSpawnMin-$kSpawnMax)');
    print('#' * 62);

    for (final strategy in Strategy.values) {
      for (final rule in rules) {
        _report(
          heading: 'Regra: ${rule.label}',
          subheading: 'Jogador: ${strategy.label}   ${_multipliers(rule)}',
          rule: rule,
          strategy: strategy,
          games: games,
          moveCap: moveCap,
        );
      }
    }
  }

  if (mode == 'endless' || mode == 'both') {
    print('');
    print('#' * 62);
    print('# F) MODO ENDLESS');
    print('#' * 62);
    print('# A janela fixa sempre trava. Aqui se mede se a progressão');
    print('# resolve — olhar a linha TRAVOU.');
    print('#' * 62);

    _reportEndless(games: games, moveCap: moveCap);
  }

  if (mode == 'campaign' || mode == 'both') {
    print('');
    print('#' * 62);
    print('# E) A CAMPANHA COMO ESTÁ NO APP');
    print('#' * 62);
    print('# Cada fase jogada com o seu objetivo, limite e janela de spawn.');
    print('#' * 62);

    _reportCampaign(games: games);
  }

  if (mode == 'efficiency' || mode == 'both') {
    print('');
    print('#' * 62);
    print('# G) EFICIÊNCIA DAS FASES   (objetivo / movimentos permitidos)');
    print('#' * 62);
    print('# Compara o que a fase exige com o que a janela dela sustenta.');
    print('# Fase cuja eficiência exigida passa da alcançável é avisada.');
    print('#' * 62);

    _reportEfficiency(games: games);
  }

  if (mode == 'phases' || mode == 'both') {
    print('');
    print('#' * 62);
    print('# D) CALIBRAGEM DAS FASES   (padrão do jogo, jogador guloso)');
    print('#' * 62);
    print('# Taxa de sucesso por limite de movimentos, para cada objetivo.');
    print('#' * 62);

    _reportPhaseTargets(
      games: games,
      moveCap: moveCap,
      targets: const [
        (4, 1),
        (4, 3),
        (5, 1),
        (5, 2),
        (5, 3),
        (6, 1),
        (6, 2),
        (7, 1),
      ],
      limits: const [5, 10, 15, 20, 25, 30, 40, 60],
    );
  }

  if (mode == 'obstacles' || mode == 'both') {
    print('');
    print('#' * 62);
    print('# H) FASES DE LIMPEZA DE COBERTURA   (candidatas)');
    print('#' * 62);
    print('# Taxa de sucesso por limite, com o jogador guloso de sempre —');
    print('# que nunca mira a cobertura. O número é um piso.');
    print('#' * 62);

    _reportObstaclePhases(
      games: games,
      limits: const [5, 10, 15, 20, 25, 30, 40],
      phases: const [
        (
          layout: ObstacleLayout(ice: 3),
          objective: Objective.clearAllObstacles(ObstacleType.ice),
          label: 'limpe 3 gelos',
        ),
        (
          layout: ObstacleLayout(glass: 3),
          objective: Objective.clearAllObstacles(ObstacleType.glass),
          label: 'limpe 3 vidros',
        ),
        (
          layout: ObstacleLayout(stone: 3),
          objective: Objective.clearAllObstacles(ObstacleType.stone),
          label: 'limpe 3 pedras',
        ),
        (
          layout: ObstacleLayout(ice: 2, glass: 2, stone: 2),
          objective: Objective.clearObstacles(
            obstacle: ObstacleType.stone,
            count: 2,
          ),
          label: 'quebre 2 pedras',
        ),
      ],
    );

    print('');
    print('  Meta: 70-90%. Coluna 100% cedo demais quer dizer que a');
    print('  cobertura cai sozinha e a fase não pede nada de propósito.');
  }

  if (mode == 'generated' || mode == 'both') {
    print('');
    print('#' * 62);
    print('# I) FASES GERADAS   (campanha infinita)');
    print('#' * 62);
    print('# Taxa de vitória das fases procedurais, no limite que o');
    print('# próprio gerador escolheu. Meta: 70-90%.');
    print('#' * 62);

    _reportGeneratedLevels(
      games: games,
      // Os pontos em que a curva muda de natureza: primeira fase gerada, troca
      // de degrau de janela, saturação do dígito máximo, e o longo prazo.
      // Sete amostras não provam mil fases; provam que a curva não descarrila
      // onde ela muda.
      numbers: const [11, 25, 50, 100, 250, 500, 1000],
    );
  }

  if (mode == 'explosion' || mode == 'both') {
    print('');
    print('#' * 62);
    print('# C) EXPLOSÃO DO DÍGITO $kMaxDigit');
    print('#' * 62);
    print('# A peça no topo da escala não tem para onde evoluir. Sem uma');
    print('# saída, peças altas sem parceiro assoreiam o tabuleiro. Aqui se');
    print('# mede se a explosão dá vazão — olhar a linha TRAVOU.');
    print('#');
    print('# A explosão só age se o jogador chegar ao $kMaxDigit, então o');
    print('# formato é cruzado com a janela de spawn: numa janela baixa a');
    print('# válvula fica numa porta que ninguém alcança.');
    print('#' * 62);

    for (final window in [(0, 3), (2, 5), (3, 6)]) {
      print('');
      print('  === janela de spawn ${window.$1}-${window.$2} ===');
      for (final shape in ExplosionShape.values) {
        _report(
          heading: 'Explosão: ${shape.name}',
          subheading: 'Jogador: guloso   regra: graduada   '
              'spawn ${window.$1}-${window.$2}',
          rule: const TieredFusion(),
          strategy: Strategy.greedy,
          games: games,
          moveCap: moveCap,
          spawnMin: window.$1,
          spawnMax: window.$2,
          explosion: shape,
        );
      }
    }
  }

  if (mode == 'spawn' || mode == 'both') {
    print('');
    print('#' * 62);
    print('# B) JANELA DE SPAWN   (regra fixa: graduada, jogador guloso)');
    print('#' * 62);
    print('# Hipótese: o teto não é a economia da fusão, é o tabuleiro');
    print('# entupir. Peças altas sem parceiro ocupam célula até travar.');
    print('#' * 62);

    for (final window in [(0, 3), (1, 4), (2, 5), (3, 6), (4, 7)]) {
      _report(
        heading: 'Janela de spawn: ${window.$1}-${window.$2}',
        subheading: 'Jogador: guloso   regra: graduada',
        rule: const TieredFusion(),
        strategy: Strategy.greedy,
        games: games,
        moveCap: moveCap,
        spawnMin: window.$1,
        spawnMax: window.$2,
      );
    }
  }

  print('');
}

/// O alvo do objetivo desta fase, medido no tabuleiro sorteado.
///
/// Em `clearAllObstacles` o pedido da fase não serve: `placeObstacles` descarta
/// a cobertura que não acha lugar, e simular contra o pedido mediria uma fase
/// mais dura do que a que o jogador recebe.
int _targetOf(GameLevel level, Board board) =>
    level.objective.type == ObjectiveType.clearAllObstacles
    ? board.countObstacles(level.objective.obstacle)
    : level.objective.count;

/// O que uma jogada rendeu ao objetivo — dígitos criados ou coberturas quebradas.
///
/// O jogador automático continua escolhendo a fusão de maior valor, e **não**
/// mira as coberturas. Numa fase de limpeza isso mede o piso: se até o bot
/// distraído passa, a fase é frouxa; se ele reprova, ainda pode ser justa para
/// quem joga de propósito.
int _gainOf(GameLevel level, Resolution resolution) =>
    switch (level.objective.type) {
      ObjectiveType.reachDigit => resolution.countProduced(
        level.objective.digit!,
      ),
      ObjectiveType.clearObstacles ||
      ObjectiveType.clearAllObstacles => resolution.countCleared(
        level.objective.obstacle,
      ),
    };

/// Taxa de vitória de fases **candidatas** de limpeza de cobertura, por limite
/// de movimentos.
///
/// Existe separado da calibragem da campanha porque essas fases ainda não estão
/// em [kCampaign]: o desenho de fase precisa escolher o limite **antes** de
/// gravar a fase, e escolher no olho foi exatamente o que a calibragem por
/// simulação veio substituir.
///
/// O jogador automático continua sendo o guloso de sempre — ele mira a fusão de
/// maior valor e nunca a cobertura. O número que sai daqui é, portanto, um
/// **piso**: a cobertura quebra de raspão, como efeito colateral das fusões.
/// Uma fase que já aprova o bot distraído não vai pesar para ninguém.
void _reportObstaclePhases({
  required int games,
  required List<int> limits,
  required List<({ObstacleLayout layout, Objective objective, String label})>
  phases,
}) {
  final header = limits.map((l) => _padLeft('$l mov', 9)).join();
  print('');
  print('  ${_pad('objetivo', 24)}$header');
  print('  ${'-' * (24 + header.length)}');

  for (final phase in phases) {
    final cells = StringBuffer();

    for (final limit in limits) {
      var wins = 0;

      for (int seed = 0; seed < games; seed++) {
        // Janela 1-4: a mesma das fases de campanha em que a cobertura estreia.
        final engine = MatchEngine(
          random: Random(seed),
          spawnMin: 1,
          spawnMax: 4,
        );

        var board = engine.generateBoard(obstacles: phase.layout);
        final target = phase.objective.type == ObjectiveType.clearAllObstacles
            ? board.countObstacles(phase.objective.obstacle)
            : phase.objective.count;

        var cleared = 0;
        var moves = 0;

        while (moves < limit && cleared < target) {
          final options = _rankMoves(engine, board);
          if (options.isEmpty) break;

          final chosen = options.first;
          final resolution = engine.resolve(
            engine.swap(board, chosen.from, chosen.to),
            anchor: chosen.to,
          );
          board = resolution.board;
          cleared += resolution.countCleared(phase.objective.obstacle);
          moves++;
        }

        if (cleared >= target) wins++;
      }

      cells.write(_padLeft('${(wins / games * 100).round()}%', 9));
    }

    print('  ${_pad(phase.label, 24)}$cells');
  }
}

/// Taxa de vitória das fases geradas, cada uma no limite de movimentos que o
/// gerador escolheu para ela.
///
/// O jogador automático é o guloso de sempre — mira a fusão de maior valor e
/// **nunca** a cobertura. Nas fases de objetivo de cobertura o número que sai
/// daqui é portanto um **piso**, pela mesma razão já registrada em
/// `_reportObstaclePhases`.
void _reportGeneratedLevels({
  required int games,
  required List<int> numbers,
}) {
  print('');
  print('  ${_pad('fase', 8)}${_pad('objetivo', 24)}'
      '${_padLeft('janela', 10)}${_padLeft('mov', 7)}${_padLeft('vitórias', 11)}');
  print('  ${'-' * 60}');

  for (final number in numbers) {
    final level = generateLevel(number);
    var wins = 0;

    for (int seed = 0; seed < games; seed++) {
      final engine = MatchEngine(
        random: Random(seed),
        spawnMin: level.spawnMin,
        spawnMax: level.spawnMax,
      );

      var board = engine.generateBoard(obstacles: level.obstacles);

      // `_targetOf` e `_gainOf` já existem no arquivo e já sabem tratar os três
      // tipos de objetivo — inclusive o alvo de "limpe todas", que sai do
      // tabuleiro sorteado e não do pedido da fase. Reusá-los é o que mantém
      // este modo medindo a mesma coisa que os outros.
      final target = _targetOf(level, board);

      var progress = 0;
      var moves = 0;

      while (moves < level.moveLimit && progress < target) {
        final options = _rankMoves(engine, board);
        if (options.isEmpty) break;

        final chosen = options.first;
        final resolution = engine.resolve(
          engine.swap(board, chosen.from, chosen.to),
          anchor: chosen.to,
        );
        board = resolution.board;
        progress += _gainOf(level, resolution);
        moves++;
      }

      if (progress >= target) wins++;
    }

    final rate = (wins / games * 100).toStringAsFixed(0);
    print('  ${_pad('$number', 8)}'
        '${_pad(level.objective.debugLabel, 24)}'
        '${_padLeft('${level.spawnMin}-${level.spawnMax}', 10)}'
        '${_padLeft('${level.moveLimit}', 7)}'
        '${_padLeft('$rate%', 11)}');
  }

  print('');
  print('  Piso nas fases de cobertura: o bot nunca mira a cobertura.');
}
