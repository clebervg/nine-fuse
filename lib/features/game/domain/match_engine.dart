import 'dart:math';

import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/fusion_rule.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';

/// Dígito máximo do jogo.
const int kMaxDigit = 9;

/// Menor e maior valor sorteados na criação do tabuleiro e na reposição do
/// topo. O MVP usa 0-3 para facilitar os primeiros movimentos.
const int kSpawnMin = 0;
const int kSpawnMax = 3;

/// Quantos dígitos distintos podem cair do topo ao mesmo tempo.
///
/// Quatro não é número redondo escolhido a gosto: é o que a simulação impôs.
/// Com sete valores na janela (`--mode=endless`, estratégia "alargando"),
/// juntar três iguais fica raro, há menos fusões, menos peças saem do
/// tabuleiro — e a partida morre por travamento em 90 movimentos, três vezes
/// mais rápido que sem mexer em nada. A janela precisa ser **estreita e
/// deslizante**, nunca larga.
const int kSpawnWidth = 4;

/// Comprimento mínimo de uma combinação.
const int kMinMatch = 3;

/// Movimentos devolvidos ao jogador por cada dígito máximo criado.
///
/// A explosão já limpa o tabuleiro, mas isso é recompensa de *espaço*, não de
/// *fase*: quem gastou jogadas montando o 9 continuava perdendo no saldo. Três
/// é o suficiente para pagar o investimento sem transformar a fase em infinita
/// — na campanha o 9 só é alcançável nas fases finais, e uma vez por partida.
const int kExplosionBonusMoves = 3;

/// Teto de cascatas por movimento. É rede de segurança contra loop, não
/// regra de jogo — em partida normal nunca deve ser alcançado.
const int _maxCascades = 64;

/// O que acontece quando uma fusão cria o dígito máximo.
///
/// A peça no topo da escala não tem para onde evoluir, e não há como juntar
/// três dela com facilidade. Sem uma saída, peças de valor alto acumulam sem
/// parceiro e o tabuleiro assoreia até não haver mais troca válida — foi o que
/// a simulação mostrou ser o verdadeiro limite do jogo, não a economia da
/// fusão. A explosão é essa saída: o dígito máximo se consome levando
/// vizinhança com ele, devolvendo espaço.
enum ExplosionShape {
  /// Sem explosão: a peça fica no tabuleiro. Serve de linha de base para
  /// medir o efeito das outras opções.
  none,

  /// Limpa o quadrado 3x3 centrado na peça (até 9 células).
  area,

  /// Limpa a linha e a coluna inteiras (até 15 células).
  cross,
}

/// Tentativas de gerar um tabuleiro inicial jogável antes de desistir.
const int _maxBoardAttempts = 32;

/// Resultado de resolver o tabuleiro após um movimento.
class Resolution {
  Resolution({required this.board, required this.steps});

  /// Tabuleiro final, depois de todas as cascatas.
  final Board board;

  /// Cada ciclo de combinação, em ordem. Tudo o mais é derivado daqui, para
  /// não existirem duas versões da mesma verdade.
  final List<ResolutionStep> steps;

  /// Quantos ciclos ocorreram. 1 é movimento simples; 2+ houve cascata.
  int get cascades => steps.length;

  late final int score = steps.fold(0, (total, step) => total + step.score);

  late final int fusions = steps.fold(
    0,
    (total, step) => total + step.fusions.length,
  );

  late final int explosions = steps.fold(
    0,
    (total, step) => total + step.explosionCentres.length,
  );

  /// Todos os dígitos criados por fusão, na ordem em que nasceram.
  ///
  /// Não dá para inferir isso do tabuleiro final: uma peça pode ser consumida
  /// por uma cascata (ou pela própria explosão) no mesmo movimento em que
  /// nasceu. É também o que distingue "criar um 5" de "receber um 5 do
  /// sorteio" — só o que está aqui conta para o objetivo de uma fase.
  late final List<int> producedDigits = [
    for (final step in steps)
      for (final fusion in step.fusions) fusion.value,
  ];

  /// Ids das peças nascidas de combinação de [kBigMatch]+ peças.
  ///
  /// Vai por id, e não por posição, porque a peça ainda vai cair e mudar de
  /// lugar antes de a UI desenhá-la — a identidade é o que sobrevive.
  late final Set<String> bigFusionTileIds = {
    for (final step in steps)
      for (final fusion in step.fusions)
        if (fusion.isBig) fusion.tileId,
  };

  /// Maior dígito criado, ou -1 se nada foi fundido.
  int get highestProduced =>
      producedDigits.isEmpty ? -1 : producedDigits.reduce(max);

  /// Quantas peças de [digit] foram criadas nesta resolução.
  int countProduced(int digit) =>
      producedDigits.where((value) => value == digit).length;
}

/// Resultado de aplicar as combinações de um tabuleiro **uma vez**, sem
/// gravidade nem reposição.
///
/// Fica exposto porque é a unidade que dá para verificar com precisão — e é
/// também o passo que as animações vão precisar renderizar separadamente.
class FusionOutcome {
  const FusionOutcome({
    required this.board,
    required this.score,
    required this.produced,
    required this.maxed,
    this.events = const [],
    this.bigFusionTileIds = const {},
  });

  final Board board;
  final int score;

  /// Dígitos criados, na ordem.
  final List<int> produced;

  /// Onde nasceram peças no dígito máximo (candidatas a explodir).
  final List<Position> maxed;

  /// Uma entrada por combinação: de onde veio, onde nasceu e quanto valeu.
  final List<FusionEvent> events;

  /// Ids das peças nascidas de combinação de [kBigMatch]+ peças.
  final Set<String> bigFusionTileIds;

  bool get isEmpty => produced.isEmpty && maxed.isEmpty;
}

/// Quantas peças uma combinação precisa ter para valer efeito especial.
const int kBigMatch = 4;

/// Uma fusão: quais peças foram consumidas, onde nasceu a nova e quanto valeu.
///
/// A UI precisa disto para animar. Só o tabuleiro final não basta: sem saber
/// **de onde** as peças vieram não dá para encolhê-las em direção ao ponto de
/// fusão, nem colocar a pontuação flutuante no lugar certo.
class FusionEvent {
  const FusionEvent({
    required this.consumed,
    required this.at,
    required this.tileId,
    required this.value,
    required this.matchLength,
    required this.score,
  });

  /// Todas as células da combinação, inclusive a que sobrevive.
  final List<Position> consumed;

  /// Onde nasce a peça evoluída.
  final Position at;

  /// Id da peça nascida, para a UI segui-la depois da queda.
  final String tileId;

  final int value;
  final int matchLength;
  final int score;

  /// Combinação grande merece efeito próprio.
  bool get isBig => matchLength >= kBigMatch;

  /// As peças que somem, sem contar a que sobrevive.
  Iterable<Position> get absorbed => consumed.where((p) => p != at);
}

/// Um ciclo de (combinação → fusão → queda → reposição).
///
/// A resolução de um movimento pode ter vários. Guardá-los em vez de só o
/// tabuleiro final é o que permite à UI mostrar a cascata acontecendo, e não
/// um salto instantâneo do começo ao fim.
class ResolutionStep {
  const ResolutionStep({
    required this.cascade,
    required this.fusions,
    required this.explosionCentres,
    required this.clearedByExplosion,
    required this.boardAfterFusion,
    required this.boardAfterSettle,
    required this.score,
  });

  /// 1 para o movimento do jogador, 2+ para as cascatas que ele desencadeou.
  final int cascade;

  final List<FusionEvent> fusions;

  /// Peças que alcançaram o dígito máximo e explodiram.
  final List<Position> explosionCentres;

  /// Células varridas pela explosão.
  final Set<Position> clearedByExplosion;

  /// Tabuleiro logo após fundir, **antes** de cair. É o quadro em que as peças
  /// absorvidas ainda estão visíveis encolhendo.
  final Board boardAfterFusion;

  /// Tabuleiro depois de cair e repor.
  final Board boardAfterSettle;

  final int score;

  bool get hasBigFusion => fusions.any((f) => f.isBig);
}

/// Desfecho de uma tentativa de jogada.
///
/// Existe para que campanha e Endless compartilhem a mecânica da jogada e se
/// diferenciem só no que fazem com o resultado — sem duplicar as guardas de
/// adjacência, a recusa da troca inválida e a resolução em cascata.
sealed class MoveResult {
  const MoveResult();
}

/// A troca não era possível: fora do tabuleiro, não adjacente ou casa vazia.
class MoveImpossible extends MoveResult {
  const MoveImpossible();
}

/// A troca era possível mas não formava combinação, então foi desfeita.
class MoveRejected extends MoveResult {
  const MoveRejected(this.from, this.to);

  final Position from;
  final Position to;
}

/// A troca valeu e o tabuleiro foi resolvido.
class MoveResolved extends MoveResult {
  const MoveResolved(this.resolution);

  final Resolution resolution;
}

/// Motor puro do Match-3 com fusão. Não conhece Riverpod nem widgets:
/// recebe um [Board] e devolve outro, o que torna cada regra testável
/// isoladamente com tabuleiros montados à mão.
class MatchEngine {
  MatchEngine({
    Random? random,
    this.spawnMin = kSpawnMin,
    this.spawnMax = kSpawnMax,
    this.fusionRule = const TieredFusion(),
    this.explosionShape = ExplosionShape.area,
    this.allowWideSpawn = false,
  }) : assert(spawnMin <= spawnMax),
       assert(
         allowWideSpawn
             ? spawnMax - spawnMin >= 2
             : spawnMax - spawnMin == kSpawnWidth - 1,
         'a janela do jogo tem exatamente $kSpawnWidth valores',
       ),
       _random = random ?? Random();

  /// Libera janelas fora da largura padrão.
  ///
  /// Existe para o simulador poder **medir** o que acontece com uma janela
  /// larga — foi essa medição que fixou a regra. Nenhum caminho do jogo liga
  /// isto: campanha e Endless usam sempre [kSpawnWidth] valores.
  final bool allowWideSpawn;

  final Random _random;

  /// Janela de valores sorteados, inclusiva nas duas pontas.
  ///
  /// Subir o piso é o que dá parceiros às peças altas: com a janela em 0-3, um
  /// `7` no tabuleiro nunca encontra outros dois `7` e fica ocupando célula
  /// até a partida travar.
  ///
  /// Não é `final` porque o modo Endless sobe a janela no meio da partida.
  /// Recriar o motor no lugar disso zeraria o contador de ids e as peças novas
  /// colidiriam com as que já estão em tela.
  int spawnMin;
  int spawnMax;

  /// Sobe (ou desce) a janela de sorteio sem perder o estado do motor.
  void setSpawnWindow({required int min, required int max}) {
    assert(min <= max);
    assert(
      allowWideSpawn ? max - min >= 2 : max - min == kSpawnWidth - 1,
      'a janela do jogo tem exatamente $kSpawnWidth valores',
    );
    spawnMin = min;
    spawnMax = max;
  }

  /// Economia do jogo: o que cada combinação produz.
  final FusionRule fusionRule;

  /// O que acontece ao criar o dígito máximo.
  final ExplosionShape explosionShape;

  /// Quantidade de valores distintos que podem ser sorteados.
  int get spawnWidth => spawnMax - spawnMin + 1;

  int _idCounter = 0;

  /// IDs precisam ser únicos por peça criada (e não por posição), porque as
  /// peças se movem e as animações vão rastreá-las por identidade.
  String _newId() => 't${_idCounter++}';

  // ---------------------------------------------------------------------------
  // Criação do tabuleiro
  // ---------------------------------------------------------------------------

  /// Gera um tabuleiro cheio, sem combinações já formadas e com pelo menos
  /// um movimento válido disponível.
  Board generateBoard() {
    for (int attempt = 0; attempt < _maxBoardAttempts; attempt++) {
      final board = _generateCandidate();
      if (hasValidMoves(board)) return board;
    }
    // Nunca observado na prática; melhor um tabuleiro jogável porém com
    // combinação pronta do que um tabuleiro sem jogada.
    return _generateCandidate();
  }

  Board _generateCandidate() {
    var board = Board.empty();
    for (int row = 0; row < Board.boardSize; row++) {
      for (int col = 0; col < Board.boardSize; col++) {
        final position = Position(row: row, col: col);
        board = board.updateTile(
          position,
          Tile(
            id: _newId(),
            value: _drawValueWithoutMatch(board, row, col),
            position: position,
          ),
        );
      }
    }
    return board;
  }

  /// Sorteia um valor para (row, col) descartando os que fechariam um trio
  /// com os dois vizinhos à esquerda ou com os dois vizinhos acima.
  int _drawValueWithoutMatch(Board board, int row, int col) {
    final forbidden = <int>{};

    if (col >= 2) {
      final a = board.getTileAt(Position(row: row, col: col - 1));
      final b = board.getTileAt(Position(row: row, col: col - 2));
      if (a != null && b != null && a.value == b.value) {
        forbidden.add(a.value);
      }
    }

    if (row >= 2) {
      final a = board.getTileAt(Position(row: row - 1, col: col));
      final b = board.getTileAt(Position(row: row - 2, col: col));
      if (a != null && b != null && a.value == b.value) {
        forbidden.add(a.value);
      }
    }

    // A janela tem no mínimo 3 valores e no máximo 2 ficam proibidos, então
    // sempre resta candidato.
    final candidates = [
      for (int value = spawnMin; value <= spawnMax; value++)
        if (!forbidden.contains(value)) value,
    ];

    return candidates[_random.nextInt(candidates.length)];
  }

  /// Sorteia um valor livre para reposição do topo.
  int _drawSpawnValue() => spawnMin + _random.nextInt(spawnWidth);

  // ---------------------------------------------------------------------------
  // Movimento
  // ---------------------------------------------------------------------------

  /// Troca duas peças de lugar. Não valida adjacência — quem chama decide.
  Board swap(Board board, Position a, Position b) {
    final tileA = board.getTileAt(a);
    final tileB = board.getTileAt(b);
    if (tileA == null || tileB == null) return board;

    return board.updateTile(a, tileB.moveTo(a)).updateTile(b, tileA.moveTo(b));
  }

  /// Uma troca só é permitida se produzir alguma combinação — é o que dá peso
  /// ao limite de movimentos.
  bool swapCreatesMatch(Board board, Position a, Position b) {
    return detectMatches(swap(board, a, b)).isNotEmpty;
  }

  /// Tenta a jogada [a] ↔ [b] e resolve o tabuleiro se ela for válida.
  ///
  /// A peça evoluída nasce em [b], a posição que o jogador tocou por último.
  MoveResult tryMove(Board board, Position a, Position b) {
    if (!board.isValidPosition(a) || !board.isValidPosition(b)) {
      return const MoveImpossible();
    }
    if (!a.isAdjacentTo(b)) return const MoveImpossible();
    if (board.getTileAt(a) == null || board.getTileAt(b) == null) {
      return const MoveImpossible();
    }

    final swapped = swap(board, a, b);
    if (detectMatches(swapped).isEmpty) return MoveRejected(a, b);

    return MoveResolved(resolve(swapped, anchor: b));
  }

  // ---------------------------------------------------------------------------
  // Resolução (combinação → fusão → queda → reposição → repete)
  // ---------------------------------------------------------------------------

  /// Resolve o tabuleiro até estabilizar.
  ///
  /// [anchor] é a posição tocada pelo jogador: quando ela participa da
  /// primeira combinação, é ali que a peça evoluída aparece (conforme o
  /// design, a fusão acontece no ponto de interação). Nas cascatas, que não
  /// têm interação, a fusão cai no centro da combinação.
  Resolution resolve(Board board, {Position? anchor}) {
    var current = board;
    final steps = <ResolutionStep>[];
    Position? currentAnchor = anchor;

    while (steps.length < _maxCascades) {
      final matches = detectMatches(current);
      if (matches.isEmpty) break;

      final fused = _applyFusions(current, matches, currentAnchor);
      current = fused.board;
      var stepScore = fused.score;

      // A âncora vale só para a combinação do movimento do jogador.
      currentAnchor = null;

      // A explosão vem antes da queda: ela abre os vazios que a gravidade
      // então preenche, no mesmo passo da cascata.
      var cleared = <Position>{};
      // Só conta como explosão o que de fato estourou: com
      // ExplosionShape.none a peça alcança o topo mas permanece no tabuleiro.
      var detonated = const <Position>[];

      if (fused.maxed.isNotEmpty && explosionShape != ExplosionShape.none) {
        final blast = _detonate(current, fused.maxed);
        current = blast.board;
        stepScore += blast.score;
        cleared = blast.cleared;
        detonated = fused.maxed;
      }

      // Guardado antes da queda: é o quadro em que as peças absorvidas ainda
      // aparecem, e é o que a UI precisa para animar a fusão.
      final afterFusion = current;

      current = applyGravity(current);
      current = refill(current);

      steps.add(
        ResolutionStep(
          cascade: steps.length + 1,
          fusions: fused.events,
          explosionCentres: detonated,
          clearedByExplosion: cleared,
          boardAfterFusion: afterFusion,
          boardAfterSettle: current,
          score: stepScore,
        ),
      );
    }

    return Resolution(board: current, steps: steps);
  }

  /// Limpa a vizinhança de cada peça que alcançou o dígito máximo, e a própria
  /// peça. Explosões não encadeiam: uma peça destruída pelo estouro não
  /// dispara o seu.
  ({Board board, int score, Set<Position> cleared}) _detonate(
    Board board,
    List<Position> centres,
  ) {
    final cleared = <Position>{};

    for (final centre in centres) {
      cleared.addAll(_blastRadius(centre));
    }

    var result = board;
    for (final position in cleared) {
      result = result.updateTile(position, null);
    }

    // A explosão é o clímax do jogo: vale mais que uma fusão comum.
    return (board: result, score: cleared.length * 50, cleared: cleared);
  }

  /// Células atingidas por uma explosão centrada em [centre], incluindo ela.
  Iterable<Position> _blastRadius(Position centre) {
    final hit = <Position>[];

    switch (explosionShape) {
      case ExplosionShape.none:
        break;

      case ExplosionShape.area:
        for (int row = centre.row - 1; row <= centre.row + 1; row++) {
          for (int col = centre.col - 1; col <= centre.col + 1; col++) {
            final position = Position(row: row, col: col);
            if (Board.contains(position)) hit.add(position);
          }
        }

      case ExplosionShape.cross:
        for (int col = 0; col < Board.boardSize; col++) {
          hit.add(Position(row: centre.row, col: col));
        }
        for (int row = 0; row < Board.boardSize; row++) {
          if (row != centre.row) hit.add(Position(row: row, col: centre.col));
        }
    }

    return hit;
  }

  /// Aplica de uma vez todas as combinações presentes em [board].
  ///
  /// Cada combinação consome as suas peças e devolve o que a [fusionRule]
  /// determinar — no match-3 clássico, uma única peça de V+1 no lugar de três.
  /// Não move nada: gravidade e reposição são passos separados.
  FusionOutcome fuse(Board board, {Position? anchor}) =>
      _applyFusions(board, detectMatches(board), anchor);

  FusionOutcome _applyFusions(
    Board board,
    List<List<Position>> matches,
    Position? anchor,
  ) {
    final updates = <Position, Tile?>{};
    final maxed = <Position>[];
    final produced = <int>[];
    final bigFusions = <String>{};
    final events = <FusionEvent>[];
    var score = 0;

    for (final match in matches) {
      final survivor = _fusionPosition(match, anchor);
      final tile = board.getTileAt(survivor);
      if (tile == null) continue;

      if (tile.value >= kMaxDigit) {
        // Já está no topo da escala: a combinação inteira é consumida.
        for (final position in match) {
          updates[position] = null;
        }
        score += kMaxDigit * 100;
        continue;
      }

      final scoreBefore = score;

      // A peça da fusão vem primeiro; o que a regra gerar além dela ocupa as
      // outras casas da combinação, e as casas restantes ficam vazias.
      final outcome = fusionRule.outcome(
        length: match.length,
        value: tile.value,
      );
      final slots = [survivor, ...match.where((p) => p != survivor)];

      for (int i = 0; i < slots.length; i++) {
        final position = slots[i];

        if (i >= outcome.length) {
          updates[position] = null;
          continue;
        }

        final value = outcome[i].clamp(0, kMaxDigit);
        // A peça da fusão preserva a identidade da original, para que as
        // animações possam segui-la; as extras são peças novas.
        final born = i == 0
            ? tile.copyWith(value: value)
            : Tile(id: _newId(), value: value, position: position);
        updates[position] = born;

        if (match.length >= kBigMatch) bigFusions.add(born.id);

        score += value * 10;
        produced.add(value);
        if (value >= kMaxDigit) maxed.add(position);
      }

      final born = updates[survivor];
      if (born != null) {
        events.add(
          FusionEvent(
            consumed: match,
            at: survivor,
            tileId: born.id,
            value: born.value,
            matchLength: match.length,
            score: score - scoreBefore,
          ),
        );
      }
    }

    return FusionOutcome(
      board: board.updateTiles(updates),
      score: score,
      produced: produced,
      maxed: maxed,
      events: events,
      bigFusionTileIds: bigFusions,
    );
  }

  /// Onde nasce a peça evoluída.
  ///
  /// A âncora (o ponto que o jogador tocou) tem prioridade. Sem ela, num
  /// formato em L ou T a fusão acontece no cruzamento — é onde o olho espera,
  /// e é o único ponto que pertence aos dois braços. Numa sequência reta, o
  /// meio.
  Position _fusionPosition(List<Position> match, Position? anchor) {
    if (anchor != null && match.contains(anchor)) return anchor;

    final crossing = _crossing(match);
    if (crossing != null) return crossing;

    return match[match.length ~/ 2];
  }

  /// A casa que tem vizinho na horizontal **e** na vertical dentro da mesma
  /// combinação. Nula quando a combinação é uma linha reta.
  Position? _crossing(List<Position> match) {
    final cells = match.toSet();

    for (final position in match) {
      final horizontal =
          cells.contains(Position(row: position.row, col: position.col - 1)) ||
          cells.contains(Position(row: position.row, col: position.col + 1));
      final vertical =
          cells.contains(Position(row: position.row - 1, col: position.col)) ||
          cells.contains(Position(row: position.row + 1, col: position.col));

      if (horizontal && vertical) return position;
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Detecção
  // ---------------------------------------------------------------------------

  /// Encontra as combinações de [kMinMatch]+ peças iguais.
  ///
  /// Sequências que se cruzam formam **uma** combinação só: um L, um T ou um
  /// cruzamento valem pelo total de peças, não pelo braço mais longo. Isso
  /// importa porque a [fusionRule] paga por tamanho — antes, o braço que
  /// sobrava era simplesmente desperdiçado.
  ///
  /// As combinações são sempre disjuntas: uma peça nunca aparece em duas. Sem
  /// isso a mesma peça poderia ser evoluída por uma e removida por outra no
  /// mesmo passo.
  List<List<Position>> detectMatches(Board board) {
    final runs = [
      ..._runs(board, horizontal: true),
      ..._runs(board, horizontal: false),
    ];

    // Junta sequências que compartilham alguma casa. Duas sequências só podem
    // se cruzar se tiverem o mesmo valor — a casa em comum tem um valor só.
    final groups = <Set<Position>>[];

    for (final run in runs) {
      final touching = groups
          .where((group) => run.any(group.contains))
          .toList();

      if (touching.isEmpty) {
        groups.add(run.toSet());
        continue;
      }

      final merged = touching.first..addAll(run);
      for (final other in touching.skip(1)) {
        merged.addAll(other);
        groups.remove(other);
      }
    }

    // Ordem estável, para a posição da fusão não depender da varredura.
    return [
      for (final group in groups)
        group.toList()..sort(
          (a, b) =>
              a.row == b.row ? a.col.compareTo(b.col) : a.row.compareTo(b.row),
        ),
    ];
  }

  /// Todas as sequências maximais de [kMinMatch]+ peças iguais, numa direção.
  List<List<Position>> _runs(Board board, {required bool horizontal}) {
    final runs = <List<Position>>[];

    for (int outer = 0; outer < Board.boardSize; outer++) {
      var current = <Position>[];
      int? currentValue;

      void flush() {
        if (current.length >= kMinMatch) runs.add(current);
        current = [];
      }

      for (int inner = 0; inner < Board.boardSize; inner++) {
        final position = horizontal
            ? Position(row: outer, col: inner)
            : Position(row: inner, col: outer);
        final value = board.getTileAt(position)?.value;

        if (value != null && value == currentValue) {
          current.add(position);
        } else {
          flush();
          currentValue = value;
          if (value != null) current = [position];
        }
      }

      flush();
    }

    return runs;
  }

  // ---------------------------------------------------------------------------
  // Gravidade e reposição
  // ---------------------------------------------------------------------------

  /// Empurra as peças de cada coluna para baixo, preenchendo os vazios
  /// deixados pelas fusões. Os buracos passam a ficar no topo.
  Board applyGravity(Board board) {
    var result = board;

    for (int col = 0; col < Board.boardSize; col++) {
      final column = [
        for (int row = 0; row < Board.boardSize; row++)
          if (board.getTileAt(Position(row: row, col: col)) case final Tile t)
            t,
      ];

      for (int row = 0; row < Board.boardSize; row++) {
        result = result.updateTile(Position(row: row, col: col), null);
      }

      // A coluna fica encostada na base: a primeira peça ocupa a linha
      // correspondente à quantidade de vazios.
      final offset = Board.boardSize - column.length;
      for (int i = 0; i < column.length; i++) {
        final position = Position(row: offset + i, col: col);
        result = result.updateTile(position, column[i].moveTo(position));
      }
    }

    return result;
  }

  /// Cria peças novas em todas as células vazias (o topo, após a gravidade).
  Board refill(Board board) {
    var result = board;
    for (final position in board.getEmptyPositions()) {
      result = result.updateTile(
        position,
        Tile(id: _newId(), value: _drawSpawnValue(), position: position),
      );
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Fim de jogo
  // ---------------------------------------------------------------------------

  /// Todas as trocas de peças adjacentes possíveis, formem combinação ou não.
  ///
  /// Percorre apenas direita e baixo: as outras duas direções são as mesmas
  /// trocas vistas a partir da peça vizinha.
  Iterable<(Position, Position)> candidateSwaps(Board board) sync* {
    for (int row = 0; row < Board.boardSize; row++) {
      for (int col = 0; col < Board.boardSize; col++) {
        final position = Position(row: row, col: col);
        if (board.getTileAt(position) == null) continue;

        for (final neighbour in [
          Position(row: row, col: col + 1),
          Position(row: row + 1, col: col),
        ]) {
          if (!board.isValidPosition(neighbour)) continue;
          if (board.getTileAt(neighbour) == null) continue;
          yield (position, neighbour);
        }
      }
    }
  }

  /// Uma troca que forma combinação, ou `null` se o tabuleiro travou.
  ///
  /// Serve de dica para o jogador e, de quebra, é a própria definição de "ainda
  /// dá para jogar" — daí [hasValidMoves] ser derivado daqui em vez de repetir
  /// a varredura.
  (Position, Position)? findHint(Board board) {
    for (final (a, b) in candidateSwaps(board)) {
      if (swapCreatesMatch(board, a, b)) return (a, b);
    }
    return null;
  }

  /// Existe alguma troca de peças adjacentes que forme combinação?
  bool hasValidMoves(Board board) => findHint(board) != null;
}
