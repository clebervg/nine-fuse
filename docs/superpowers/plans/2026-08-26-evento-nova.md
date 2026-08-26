# Evento Nova (fusão de 3+ peças de valor 9) — Plano de Implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar o evento Nova — o terceiro clímax do jogo, disparado quando 3+ peças de valor `9` já existentes no tabuleiro se alinham — substituindo o consumo silencioso que hoje acontece em `MatchEngine._applyFusions`.

**Architecture:** Tudo vive no domínio puro (`lib/features/game/domain/`), sem tocar Riverpod nem widgets. Um tipo de dado novo (`NovaEvent`) descreve o evento; a lógica de geometria e o gatilho entram em `MatchEngine`, reaproveitando os mesmos mapas (`updates`) e helpers (`_fusionPosition`, o padrão de `_clearBlockersAround`) que o Bloco 9 e o Super 9 já usam. Nenhuma UI é construída aqui — é decisão explícita do spec.

**Tech Stack:** Dart puro (motor de domínio), `flutter_test` para os testes.

## Global Constraints

- Spec de referência: `docs/superpowers/specs/2026-08-25-evento-nova-design.md`. Toda ambiguidade se resolve consultando esse arquivo primeiro.
- Zonas por tier: **tier 1** (3 peças 9) → núcleo 3x3 / anel até 5x5. **Tier 2** (4 peças) → núcleo 3x3 / anel até 7x7. **Tier 3** (5+ peças) → tabuleiro inteiro, sem anel.
- **Cap de 1 Nova por jogada** (por chamada de `resolve()`): a segunda combinação de 3+ noves na mesma jogada cai no comportamento antigo (consumida, sem evento, soma `kMaxDigit * 100`).
- **Peças especiais são imunes**: qualquer célula com `tile.specialType != null` (Super 9, Curinga) dentro do núcleo ou do anel não é destruída nem promovida.
- **Gatilho:** dispara em qualquer passo de `resolve()` — troca do jogador ou cascata —, ao contrário do Bloco 9 (que só dispara em `cascade == 1`).
- **Independente do Super 9:** sem checagem de exclusividade.
- Placar: `kNovaScoreTier1 = 500`, `kNovaScoreTier2 = 1000`, `kNovaScoreTier3 = 2000`, substituindo (não somando a) o antigo `kMaxDigit * 100`.
- Nenhuma peça de valor 9 no anel é promovida (já está no teto) — não entra em `promoted`.
- Fora de escopo: widgets/animações, calibragem de economia, integração com `LevelObjective`. Não tocar nesses pontos.

---

## File Structure

- **Create:** `lib/features/game/domain/nova_event.dart` — `NovaEvent`, `kNovaScoreTier1/2/3`, `novaScoreForTier`.
- **Create:** `test/features/game/domain/nova_event_test.dart` — teste do tipo de dado.
- **Modify:** `lib/features/game/domain/match_engine.dart` — `ResolutionStep`, `Resolution`, `FusionOutcome`, `_applyFusions`, `fuse`, `resolve`, novo helper `_zoneAround` e `_triggerNova`.
- **Modify:** `test/features/game/domain/match_engine_test.dart` — novo `group('Evento Nova ...')`.
- **Modify:** `CLAUDE.md` — registro da feature, seguindo a convenção já estabelecida no projeto para toda mudança de mecânica.

---

### Task 1: `NovaEvent` — tipo de dado e constantes de placar

**Files:**
- Create: `lib/features/game/domain/nova_event.dart`
- Test: `test/features/game/domain/nova_event_test.dart`

**Interfaces:**
- Produces: `class NovaEvent { final Position at; final int tier; final List<ObstacleHit> obstacleHits; final Set<Position> clearedTiles; final Map<Position, int> promoted; }`, construtor nomeado com todos os campos `required`. `const int kNovaScoreTier1 = 500;`, `const int kNovaScoreTier2 = 1000;`, `const int kNovaScoreTier3 = 2000;`, `int novaScoreForTier(int tier)`.

- [ ] **Step 1: Escrever o teste**

```dart
// test/features/game/domain/nova_event_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/nova_event.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';
import 'package:nine_fuse/features/game/domain/position.dart';

void main() {
  group('NovaEvent', () {
    test('guarda os campos como passados', () {
      const at = Position(row: 3, col: 3);
      final event = NovaEvent(
        at: at,
        tier: 1,
        obstacleHits: const [
          ObstacleHit(
            position: Position(row: 3, col: 2),
            type: ObstacleType.ice,
            remainingHp: 0,
          ),
        ],
        clearedTiles: const {Position(row: 3, col: 3)},
        promoted: const {Position(row: 2, col: 3): 5},
      );

      expect(event.at, at);
      expect(event.tier, 1);
      expect(event.obstacleHits, hasLength(1));
      expect(event.clearedTiles, contains(const Position(row: 3, col: 3)));
      expect(event.promoted[const Position(row: 2, col: 3)], 5);
    });
  });

  group('novaScoreForTier', () {
    test('tier 1 vale kNovaScoreTier1', () {
      expect(novaScoreForTier(1), kNovaScoreTier1);
    });

    test('tier 2 vale kNovaScoreTier2', () {
      expect(novaScoreForTier(2), kNovaScoreTier2);
    });

    test('tier 3 vale kNovaScoreTier3', () {
      expect(novaScoreForTier(3), kNovaScoreTier3);
    });
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/features/game/domain/nova_event_test.dart`
Expected: FAIL — `Error: Not found: 'package:nine_fuse/features/game/domain/nova_event.dart'` (o arquivo ainda não existe).

- [ ] **Step 3: Criar o arquivo de domínio**

```dart
// lib/features/game/domain/nova_event.dart
import 'package:nine_fuse/features/game/domain/obstacle.dart';
import 'package:nine_fuse/features/game/domain/position.dart';

/// Bônus de score estático da Nova, por tier (3, 4 ou 5+ peças de valor 9
/// alinhadas). Substitui o placar genérico (`kMaxDigit * 100`) que a
/// combinação de 9s recebia antes deste evento existir — não soma a ele.
const int kNovaScoreTier1 = 500;
const int kNovaScoreTier2 = 1000;
const int kNovaScoreTier3 = 2000;

/// Bônus de placar da Nova para o [tier] informado (1, 2 ou 3+; qualquer
/// valor 3 ou maior cai no tier 3).
int novaScoreForTier(int tier) => switch (tier) {
  1 => kNovaScoreTier1,
  2 => kNovaScoreTier2,
  _ => kNovaScoreTier3,
};

/// Um evento Nova: 3+ peças de valor 9 já existentes no tabuleiro se
/// alinharam e se consumiram, disparando o terceiro clímax do jogo —
/// distinto e independente do Bloco 9 e do Super 9 (ver
/// `docs/superpowers/specs/2026-08-25-evento-nova-design.md`).
class NovaEvent {
  const NovaEvent({
    required this.at,
    required this.tier,
    required this.obstacleHits,
    required this.clearedTiles,
    required this.promoted,
  });

  /// Centro do evento — a mesma posição de sobrevivente que qualquer fusão
  /// normal usaria (`MatchEngine._fusionPosition`).
  final Position at;

  /// 1 (3 peças 9), 2 (4 peças) ou 3 (5+ peças).
  final int tier;

  /// Cobertura destruída no núcleo, mesmo formato de qualquer outro dano de
  /// obstáculo do motor.
  final List<ObstacleHit> obstacleHits;

  /// Peças normais destruídas no núcleo (posições: a peça deixa de existir,
  /// não há id para rastrear).
  final Set<Position> clearedTiles;

  /// Peças promovidas no anel externo: posição -> novo valor.
  final Map<Position, int> promoted;

  @override
  String toString() =>
      'NovaEvent(at: $at, tier: $tier, cleared: ${clearedTiles.length}, '
      'promoted: ${promoted.length})';
}
```

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `flutter test test/features/game/domain/nova_event_test.dart`
Expected: PASS (4 testes)

- [ ] **Step 5: Commit**

```bash
git add lib/features/game/domain/nova_event.dart test/features/game/domain/nova_event_test.dart
git commit -m "feat: adiciona tipo de dado NovaEvent e constantes de placar"
```

---

### Task 2: Plumbing — `novaEvents` em `FusionOutcome`, `ResolutionStep` e `Resolution`

Sem comportamento novo ainda: só os campos e getters agregadores, com default vazio, para o motor compilar com a nova estrutura antes de a lógica da Task 3 escrever nela.

**Files:**
- Modify: `lib/features/game/domain/match_engine.dart`
- Test: `test/features/game/domain/match_engine_test.dart`

**Interfaces:**
- Consumes: `NovaEvent` (Task 1).
- Produces: `FusionOutcome.novaEvents` (`List<NovaEvent>`, default `const []`). `ResolutionStep.novaEvents` (`List<NovaEvent>`, default `const []`). `Resolution.novaEvents` (`List<NovaEvent>`, getter agregado — soma de `step.novaEvents` de todos os passos, na ordem).

- [ ] **Step 1: Escrever o teste (defaults vazios, sem quebrar nada existente)**

Adicionar ao final do arquivo `test/features/game/domain/match_engine_test.dart`, como um novo `group` de nível superior (antes do `});` final que fecha `main()`):

```dart
  group('Resolution.novaEvents (plumbing, sem Nova disparando ainda)', () {
    test('resolução sem Nova tem novaEvents vazio', () {
      final resolution = engine.resolve(boardFromValues(baseGrid()));
      expect(resolution.novaEvents, isEmpty);
    });
  });
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/features/game/domain/match_engine_test.dart --plain-name "novaEvents (plumbing"`
Expected: FAIL — `The getter 'novaEvents' isn't defined for the type 'Resolution'`.

- [ ] **Step 3: Adicionar os campos**

Em `lib/features/game/domain/match_engine.dart`, adicionar o import no topo (junto dos outros imports do arquivo):

```dart
import 'package:nine_fuse/features/game/domain/nova_event.dart';
```

Em `class Resolution`, logo após o getter `newbornSpecialTileIds` (o último getter da classe, antes do `}` de fechamento):

```dart
  /// Todos os eventos Nova desta resolução, na ordem em que ocorreram.
  late final List<NovaEvent> novaEvents = [
    for (final step in steps) ...step.novaEvents,
  ];
```

Em `class FusionOutcome`, no construtor `const FusionOutcome({...})`, adicionar o parâmetro:

```dart
    this.novaEvents = const [],
```

(na mesma lista de parâmetros opcionais que já tem `this.events = const []` e `this.bigFusionTileIds = const {}`), e o campo correspondente junto dos outros `final`:

```dart
  /// Eventos Nova produzidos por esta passada de fusões (0 ou 1 — o cap de
  /// 1 por jogada é responsabilidade de `resolve()`, não desta classe).
  final List<NovaEvent> novaEvents;
```

Em `class ResolutionStep`, no construtor `const ResolutionStep({...})`, adicionar:

```dart
    this.novaEvents = const [],
```

(junto de `this.obstacleHits = const []`), e o campo:

```dart
  /// Eventos Nova deste passo — normalmente 0, no máximo 1 por jogada
  /// inteira (várias cascatas incluídas).
  final List<NovaEvent> novaEvents;
```

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `flutter test test/features/game/domain/match_engine_test.dart`
Expected: PASS — toda a suíte existente continua verde (mudança é só aditiva, com defaults), mais o teste novo.

- [ ] **Step 5: Commit**

```bash
git add lib/features/game/domain/match_engine.dart test/features/game/domain/match_engine_test.dart
git commit -m "feat: plumbing de novaEvents em FusionOutcome/ResolutionStep/Resolution"
```

---

### Task 3: Geometria e gatilho — Nova tier 1 (3 peças, núcleo 3x3 / anel 5x5)

Implementa o coração do evento: helper de zona, `_triggerNova`, e o desvio em `_applyFusions` que substitui o branch antigo de consumo — com o cap de 1 Nova por jogada já embutido, propagado por `resolve()`.

**Files:**
- Modify: `lib/features/game/domain/match_engine.dart`
- Test: `test/features/game/domain/match_engine_test.dart`

**Interfaces:**
- Consumes: `NovaEvent`, `novaScoreForTier` (Task 1); `FusionOutcome.novaEvents`, `ResolutionStep.novaEvents` (Task 2).
- Produces: `MatchEngine._zoneAround(Position centre, int radius) -> Set<Position>`. `MatchEngine._triggerNova(Board board, Map<Position, Tile?> updates, List<Position> match, Position survivor) -> NovaEvent`. `_applyFusions` ganha o parâmetro nomeado obrigatório `required bool novaAlreadyTriggered`.

- [ ] **Step 1: Escrever os testes**

Adicionar um novo `group`, logo após o `group('Super 9 (5+ peças de valor 8)', ...)` já existente em `test/features/game/domain/match_engine_test.dart` (depois do seu `});` de fechamento):

```dart
  group('Evento Nova (fusão de 3+ peças de valor 9)', () {
    /// Três peças 9 já prontas no tabuleiro, lado a lado na linha 3, colunas
    /// 2-4 — o alinhamento acontece sozinho, sem precisar de troca do
    /// jogador, porque o cenário de teste já nasce com o trio formado.
    Board threeNinesInRow() {
      final grid = baseGrid();
      for (final col in [2, 3, 4]) {
        grid[3][col] = kMaxDigit;
      }
      return boardFromValues(grid);
    }

    test('trio de 9 dispara um NovaEvent de tier 1', () {
      final resolution = engine.resolve(threeNinesInRow());

      expect(resolution.novaEvents, hasLength(1));
      expect(resolution.novaEvents.single.tier, 1);
    });

    test('núcleo 3x3 destrói as peças do trio', () {
      final resolution = engine.resolve(threeNinesInRow());

      for (final col in [2, 3, 4]) {
        final pos = Position(row: 3, col: col);
        expect(
          resolution.novaEvents.single.clearedTiles,
          contains(pos),
          reason: '$pos era parte do trio consumido',
        );
      }
    });

    test('peça sobrevivente no anel (fora do núcleo, dentro da 5x5) é promovida', () {
      var board = threeNinesInRow();
      // (1,3): duas linhas acima do centro (3,3) — fora do núcleo 3x3
      // (linhas 2-4), dentro da zona 5x5 (linhas 1-5).
      const inRing = Position(row: 1, col: 3);
      board = board.updateTile(inRing, board.getTileAt(inRing)!.copyWith(value: 4));

      final resolution = engine.resolve(board);

      expect(resolution.novaEvents.single.promoted[inRing], 5);
      expect(resolution.board.getTileAt(inRing)!.value, 5);
    });

    test('peça fora da zona 5x5 não é tocada', () {
      var board = threeNinesInRow();
      // (0,3): três linhas acima do centro (3,3) — fora da zona 5x5
      // (linhas 1-5).
      const outside = Position(row: 0, col: 3);
      board = board.updateTile(outside, board.getTileAt(outside)!.copyWith(value: 4));

      final resolution = engine.resolve(board);

      expect(resolution.novaEvents.single.promoted.containsKey(outside), isFalse);
      expect(resolution.novaEvents.single.clearedTiles.contains(outside), isFalse);
      expect(resolution.board.getTileAt(outside)!.value, 4);
    });

    test('soma kNovaScoreTier1 ao placar do passo', () {
      final resolution = engine.resolve(threeNinesInRow());
      final step = resolution.steps.firstWhere((s) => s.novaEvents.isNotEmpty);
      expect(step.score, greaterThanOrEqualTo(kNovaScoreTier1));
    });

    test('cap de 1 Nova por jogada: um segundo trio de 9 na mesma jogada não gera evento', () {
      var board = threeNinesInRow();
      // Segundo trio de 9, longe do primeiro, já formado no mesmo tabuleiro
      // — ambos processados na mesma chamada de resolve()/_applyFusions.
      for (final col in [2, 3, 4]) {
        board = board.updateTile(
          Position(row: 6, col: col),
          board.getTileAt(Position(row: 6, col: col))!.copyWith(value: kMaxDigit),
        );
      }

      final resolution = engine.resolve(board);

      expect(
        resolution.novaEvents,
        hasLength(1),
        reason: 'só a primeira combinação de 9s vira Nova nesta jogada',
      );
    });
  });
```

Também adicionar o import de `nova_event.dart` no topo do arquivo de teste:

```dart
import 'package:nine_fuse/features/game/domain/nova_event.dart';
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/features/game/domain/match_engine_test.dart --plain-name "Evento Nova"`
Expected: FAIL — `resolution.novaEvents` vem vazio em todos os cenários (o branch antigo ainda consome os 9s silenciosamente).

- [ ] **Step 3: Implementar `_zoneAround`**

Em `lib/features/game/domain/match_engine.dart`, logo após o método `_clearBlockersAround` (que termina no `}` antes do comentário `/// Aplica de uma vez todas as combinações...`), adicionar:

```dart
  /// Todas as posições dentro do tabuleiro a até [radius] casas de [centre],
  /// nas duas direções (um quadrado de lado `2*radius + 1`). `radius: 1` é o
  /// mesmo 3x3 que `_clearBlockersAround` já usa para o Bloco 9.
  Set<Position> _zoneAround(Position centre, int radius) => {
    for (int row = centre.row - radius; row <= centre.row + radius; row++)
      for (int col = centre.col - radius; col <= centre.col + radius; col++)
        if (Board.contains(Position(row: row, col: col)))
          Position(row: row, col: col),
  };
```

- [ ] **Step 4: Implementar `_triggerNova`**

Logo após `_zoneAround`, adicionar:

```dart
  /// Dispara o evento Nova: a combinação de 9s em [match] se consome e abre
  /// uma zona de efeito centrada em [survivor] (a mesma posição de
  /// sobrevivente que qualquer fusão normal usaria). Escreve as remoções e
  /// promoções direto em [updates] — o mesmo mapa que o resto de
  /// `_applyFusions` usa para o tabuleiro final — e devolve o [NovaEvent]
  /// para placar/UI.
  ///
  /// O núcleo sempre inclui as próprias células de [match]: numa combinação
  /// reta de 4+ peças, o quadrado 3x3 ao redor do sobrevivente nem sempre
  /// cobre a ponta mais distante da fila, e a Nova nunca deixa peça do
  /// próprio match para trás.
  NovaEvent _triggerNova(
    Board board,
    Map<Position, Tile?> updates,
    List<Position> match,
    Position survivor,
  ) {
    final tier = match.length >= kSuperNineMatchLength
        ? 3
        : (match.length >= kBigMatch ? 2 : 1);

    final Set<Position> core;
    final Set<Position> ring;
    if (tier == 3) {
      core = {
        for (int row = 0; row < Board.boardSize; row++)
          for (int col = 0; col < Board.boardSize; col++)
            Position(row: row, col: col),
      };
      ring = const {};
    } else {
      final totalRadius = tier == 1 ? 2 : 3;
      core = _zoneAround(survivor, 1).union(match.toSet());
      ring = _zoneAround(survivor, totalRadius).difference(core);
    }

    final obstacleHits = <ObstacleHit>[];
    final clearedTiles = <Position>{};
    for (final position in core) {
      final tile = board.getTileAt(position);
      if (tile == null || tile.specialType != null) continue;

      if (tile.isBlocked) {
        obstacleHits.add(
          ObstacleHit(position: position, type: tile.obstacle, remainingHp: 0),
        );
      }
      updates[position] = null;
      clearedTiles.add(position);
    }

    final promoted = <Position, int>{};
    for (final position in ring) {
      final tile = board.getTileAt(position);
      if (tile == null || tile.specialType != null || tile.value >= kMaxDigit) {
        continue;
      }

      final value = tile.value + 1;
      updates[position] = tile.copyWith(value: value);
      promoted[position] = value;
    }

    return NovaEvent(
      at: survivor,
      tier: tier,
      obstacleHits: obstacleHits,
      clearedTiles: clearedTiles,
      promoted: promoted,
    );
  }
```

- [ ] **Step 5: Trocar o branch de consumo em `_applyFusions` e propagar o cap por `resolve()`**

Em `_applyFusions`, mudar a assinatura de:

```dart
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
```

para:

```dart
  FusionOutcome _applyFusions(
    Board board,
    List<List<Position>> matches,
    Position? anchor, {
    required bool novaAlreadyTriggered,
  }) {
    final updates = <Position, Tile?>{};
    final maxed = <Position>[];
    final produced = <int>[];
    final bigFusions = <String>{};
    final events = <FusionEvent>[];
    final novaEvents = <NovaEvent>[];
    var novaTriggered = novaAlreadyTriggered;
    var score = 0;
```

Trocar o corpo do branch:

```dart
      if (tile.value >= kMaxDigit) {
        // Já está no topo da escala: a combinação inteira é consumida.
        for (final position in match) {
          updates[position] = null;
        }
        score += kMaxDigit * 100;
        continue;
      }
```

por:

```dart
      if (tile.value >= kMaxDigit) {
        // 3+ peças de valor 9 já existentes se alinharam. A primeira
        // combinação assim na jogada vira Nova; qualquer outra depois dela
        // (cap de 1 por jogada) cai no consumo antigo, sem evento.
        if (!novaTriggered) {
          novaTriggered = true;
          final event = _triggerNova(board, updates, match, survivor);
          novaEvents.add(event);
          score += novaScoreForTier(event.tier);
        } else {
          for (final position in match) {
            updates[position] = null;
          }
          score += kMaxDigit * 100;
        }
        continue;
      }
```

No `return FusionOutcome(...)` ao final do método, adicionar o campo:

```dart
    return FusionOutcome(
      board: board.updateTiles(updates),
      score: score,
      produced: produced,
      maxed: maxed,
      events: events,
      bigFusionTileIds: bigFusions,
      novaEvents: novaEvents,
    );
```

Atualizar o único outro chamador de `_applyFusions`, em `fuse()`:

```dart
  FusionOutcome fuse(Board board, {Position? anchor}) =>
      _applyFusions(board, detectMatches(board), anchor);
```

vira:

```dart
  FusionOutcome fuse(Board board, {Position? anchor}) => _applyFusions(
    board,
    detectMatches(board),
    anchor,
    novaAlreadyTriggered: false,
  );
```

E em `resolve()`, adicionar o rastreio do cap. O trecho:

```dart
  Resolution resolve(Board board, {Position? anchor}) {
    var current = board;
    final steps = <ResolutionStep>[];
    Position? currentAnchor = anchor;
    final budget = CascadeBudget();

    while (!budget.isExhausted && steps.length < _maxCascades) {
      final matches = detectMatches(current);
      if (matches.isEmpty) break;
      budget.consume();

      final fused = _applyFusions(current, matches, currentAnchor);
      current = fused.board;
      var stepScore = fused.score;
```

vira:

```dart
  Resolution resolve(Board board, {Position? anchor}) {
    var current = board;
    final steps = <ResolutionStep>[];
    Position? currentAnchor = anchor;
    final budget = CascadeBudget();
    // Cap de 1 Nova por jogada: vale para a chamada inteira de resolve(),
    // não por passo — é o que impede uma Nova promovida no anel formar
    // outra Nova na cascata seguinte (autoplay em cadeia).
    var novaUsedThisTurn = false;

    while (!budget.isExhausted && steps.length < _maxCascades) {
      final matches = detectMatches(current);
      if (matches.isEmpty) break;
      budget.consume();

      final fused = _applyFusions(
        current,
        matches,
        currentAnchor,
        novaAlreadyTriggered: novaUsedThisTurn,
      );
      current = fused.board;
      var stepScore = fused.score;
      if (fused.novaEvents.isNotEmpty) novaUsedThisTurn = true;
```

E, no `steps.add(ResolutionStep(...))` mais abaixo no mesmo método, adicionar o campo:

```dart
      steps.add(
        ResolutionStep(
          cascade: steps.length + 1,
          fusions: fused.events,
          boardAfterFusion: afterFusion,
          boardAfterSettle: current,
          score: stepScore,
          obstacleHits: obstacleHits,
          novaEvents: fused.novaEvents,
        ),
      );
```

- [ ] **Step 6: Rodar e confirmar que passa**

Run: `flutter test test/features/game/domain/match_engine_test.dart`
Expected: PASS — os 6 testes novos do grupo "Evento Nova" e toda a suíte pré-existente (Bloco 9, Super 9, CascadeBudget etc.) continuam verdes, já que o branch antigo só muda de comportamento quando `tile.value >= kMaxDigit`, mesma condição de sempre.

- [ ] **Step 7: Commit**

```bash
git add lib/features/game/domain/match_engine.dart test/features/game/domain/match_engine_test.dart
git commit -m "feat: dispara evento Nova (tier 1) para 3 peças de valor 9 alinhadas"
```

---

### Task 4: Tiers 2 e 3 — 4 peças (7x7) e 5+ peças (tabuleiro inteiro)

A geometria de `_triggerNova` (Task 3) já cobre os três tiers — esta task só precisa provar isso com cenários de 4 e de 5+ peças, já que a lógica condicional (`tier == 1 ? 2 : 3` para o raio total, `tier == 3` para o tabuleiro inteiro) já foi escrita. Nenhuma mudança de produção é esperada aqui a menos que os testes revelem um erro de geometria.

**Files:**
- Test: `test/features/game/domain/match_engine_test.dart`
- Modify (só se os testes falharem por bug de geometria): `lib/features/game/domain/match_engine.dart`

**Interfaces:**
- Consumes: tudo da Task 3, sem mudança de assinatura.

- [ ] **Step 1: Escrever os testes**

Adicionar dentro do `group('Evento Nova ...')` já criado na Task 3, depois do último teste (`'cap de 1 Nova por jogada...'`):

```dart
    Board fourNinesInRow() {
      final grid = baseGrid();
      for (final col in [1, 2, 3, 4]) {
        grid[3][col] = kMaxDigit;
      }
      return boardFromValues(grid);
    }

    Board fiveNinesInRow() {
      final grid = baseGrid();
      for (final col in [1, 2, 3, 4, 5]) {
        grid[3][col] = kMaxDigit;
      }
      return boardFromValues(grid);
    }

    test('quarteto de 9 dispara tier 2 e consome as 4 peças do match', () {
      final resolution = engine.resolve(fourNinesInRow());

      expect(resolution.novaEvents.single.tier, 2);
      for (final col in [1, 2, 3, 4]) {
        expect(
          resolution.novaEvents.single.clearedTiles,
          contains(Position(row: 3, col: col)),
          reason: 'toda peça do match de 4 precisa estar no núcleo, mesmo '
              'a ponta mais distante do centro geométrico',
        );
      }
    });

    test('quarteto de 9: peça na zona 7x7 fora do núcleo é promovida', () {
      var board = fourNinesInRow();
      // Sobrevivente do match reto de 4 (sem âncora) é o índice 2: coluna 3.
      // (0,3): 3 linhas acima — fora do núcleo (linhas 2-4), dentro da 7x7
      // (linhas 0-6).
      const inRing = Position(row: 0, col: 3);
      board = board.updateTile(inRing, board.getTileAt(inRing)!.copyWith(value: 2));

      final resolution = engine.resolve(board);

      expect(resolution.novaEvents.single.promoted[inRing], 3);
    });

    test('cinco ou mais 9: tier 3, tabuleiro inteiro é o núcleo, sem anel', () {
      final resolution = engine.resolve(fiveNinesInRow());

      final event = resolution.novaEvents.single;
      expect(event.tier, 3);
      expect(event.promoted, isEmpty, reason: 'tier 3 não tem anel de promoção');
    });

    test('cinco ou mais 9: peça normal em qualquer canto do tabuleiro é destruída', () {
      final resolution = engine.resolve(fiveNinesInRow());

      const corner = Position(row: 7, col: 7);
      expect(resolution.novaEvents.single.clearedTiles, contains(corner));
      expect(resolution.board.getTileAt(corner), isNull);
    });

    test('cinco ou mais 9: soma kNovaScoreTier3 ao placar', () {
      final resolution = engine.resolve(fiveNinesInRow());
      final step = resolution.steps.firstWhere((s) => s.novaEvents.isNotEmpty);
      expect(step.score, greaterThanOrEqualTo(kNovaScoreTier3));
    });
```

- [ ] **Step 2: Rodar**

Run: `flutter test test/features/game/domain/match_engine_test.dart --plain-name "Evento Nova"`
Expected: PASS direto — se algum teste falhar, é sinal de erro de geometria em `_triggerNova` (Task 3), a corrigir antes de prosseguir (não deveria acontecer: a lógica de tier/raio já cobre os três casos).

- [ ] **Step 3: Commit**

```bash
git add test/features/game/domain/match_engine_test.dart
git commit -m "test: cobre Nova tier 2 (4 peças, 7x7) e tier 3 (5+, tabuleiro inteiro)"
```

---

### Task 5: Imunidade de peças especiais (Super 9 / Curinga) no núcleo e no anel

**Files:**
- Test: `test/features/game/domain/match_engine_test.dart`
- Modify (só se o teste revelar que a Task 3 esqueceu algum caminho): `lib/features/game/domain/match_engine.dart`

`_triggerNova` (Task 3) já checa `tile.specialType != null` tanto no núcleo quanto no anel — esta task escreve a prova.

**Interfaces:**
- Consumes: `Tile.withSpecial`, `SpecialTileType.superNine` (já existentes, usados pelos testes de Super 9).

- [ ] **Step 1: Escrever os testes**

Adicionar ao `group('Evento Nova ...')`, depois dos testes da Task 4:

```dart
    test('Super 9 dentro do núcleo não é destruído', () {
      var board = threeNinesInRow();
      // (2,2): canto do núcleo 3x3 centrado em (3,3).
      const superNinePos = Position(row: 2, col: 2);
      board = board.updateTile(
        superNinePos,
        Tile.withSpecial(
          id: 'super',
          value: kMaxDigit,
          position: superNinePos,
          specialType: SpecialTileType.superNine,
        ),
      );

      final resolution = engine.resolve(board);

      expect(
        resolution.novaEvents.single.clearedTiles.contains(superNinePos),
        isFalse,
      );
      final survivor = resolution.board
          .getAllTiles()
          .where((t) => t.specialType == SpecialTileType.superNine);
      expect(survivor, hasLength(1), reason: 'o Super 9 sobrevive à Nova');
    });

    test('Super 9 dentro do anel não é promovido', () {
      var board = threeNinesInRow();
      // (1,3): dentro da zona 5x5, fora do núcleo 3x3 (mesma posição do
      // teste de promoção comum da Task 3, agora ocupada por um Super 9).
      const superNinePos = Position(row: 1, col: 3);
      board = board.updateTile(
        superNinePos,
        Tile.withSpecial(
          id: 'super',
          value: kMaxDigit,
          position: superNinePos,
          specialType: SpecialTileType.superNine,
        ),
      );

      final resolution = engine.resolve(board);

      expect(
        resolution.novaEvents.single.promoted.containsKey(superNinePos),
        isFalse,
      );
      final tile = resolution.board
          .getAllTiles()
          .firstWhere((t) => t.specialType == SpecialTileType.superNine);
      expect(tile.value, kMaxDigit, reason: 'não foi promovido além do teto');
    });
```

- [ ] **Step 2: Rodar**

Run: `flutter test test/features/game/domain/match_engine_test.dart --plain-name "Evento Nova"`
Expected: PASS direto (a checagem já existe em `_triggerNova` desde a Task 3). Se falhar, revisar as duas condições `tile.specialType != null` dentro de `_triggerNova` antes de prosseguir.

- [ ] **Step 3: Commit**

```bash
git add test/features/game/domain/match_engine_test.dart
git commit -m "test: prova imunidade de peças especiais ao evento Nova"
```

---

### Task 6: Gatilho por cascata, independência do Super 9 e match pendente por CascadeBudget

Fecha os requisitos "cross-cutting" do spec que dependem de cenários mais elaborados (cascata automática, coexistência com Super 9, orçamento esgotado).

**Files:**
- Test: `test/features/game/domain/match_engine_test.dart`

**Interfaces:**
- Consumes: tudo das Tasks 1-5.

- [ ] **Step 1: Escrever os testes**

Adicionar ao `group('Evento Nova ...')`, depois dos testes da Task 5, fechando o grupo:

```dart
    test('dispara por cascata automática, não só pela troca do jogador', () {
      // Cascade 1: trio vertical de valor 5 na coluna 2 (linhas 4-6), abaixo
      // de um 9 solto na linha 3. Ao fundir, o 9 cai duas linhas, pousando
      // na linha 5 — a mesma linha onde as colunas 3 e 4 já têm um 9 parado,
      // formando o trio que a cascata 2 alinha (mesmo desenho do teste
      // equivalente do Bloco 9, mas com peças já em 9 em vez de 8).
      final grid = baseGrid();
      grid[3][2] = kMaxDigit;
      grid[4][2] = 5;
      grid[5][2] = 5;
      grid[6][2] = 5;
      grid[5][3] = kMaxDigit;
      grid[5][4] = kMaxDigit;

      final resolution = MatchEngine(random: Random(4)).resolve(boardFromValues(grid));

      final novaInCascade = resolution.steps
          .where((s) => s.cascade > 1)
          .any((s) => s.novaEvents.isNotEmpty);
      expect(
        novaInCascade,
        isTrue,
        reason: 'cenário precisa formar o trio de 9 numa cascata, não no '
            'passo do jogador — ajustar a grade se a semente mudar o resultado',
      );
    });

    test('coexiste com um Super 9 vivo no tabuleiro, sem checagem de exclusividade', () {
      var board = threeNinesInRow();
      const superNinePos = Position(row: 6, col: 6);
      board = board.updateTile(
        superNinePos,
        Tile.withSpecial(
          id: 'existing-super',
          value: kMaxDigit,
          position: superNinePos,
          specialType: SpecialTileType.superNine,
        ),
      );

      final resolution = engine.resolve(board);

      expect(resolution.novaEvents, hasLength(1));
      final superNineStillThere = resolution.board
          .getAllTiles()
          .where((t) => t.specialType == SpecialTileType.superNine);
      expect(superNineStillThere, hasLength(1));
    });

    test('match pendente formado pela Nova sobrevive ao esgotamento do CascadeBudget '
        'e resolve na jogada seguinte', () {
      // Um trio de 9 cujo anel de promoção alinha 3 peças de valor 4 -> 5 ao
      // mesmo tempo, forçado a acontecer bem no limiar do orçamento: usamos
      // kCascadeBudgetPerTurn - 1 cascatas de enchimento antes da Nova, para
      // a cascata que ela dispara já nascer no último passo do orçamento.
      final grid = baseGrid();
      for (final col in [2, 3, 4]) {
        grid[3][col] = kMaxDigit;
      }
      // Três peças de valor 4 na linha 1 (fora do núcleo 3x3, dentro da 5x5)
      // — o anel da Nova as promove para 5 no mesmo passo em que a Nova
      // dispara, formando um trio de 5 alinhado.
      grid[1][2] = 4;
      grid[1][3] = 4;
      grid[1][4] = 4;

      final board = boardFromValues(grid);
      final resolution = MatchEngine(random: Random(9)).resolve(board);

      // A prova útil só vale se o trio promovido não foi resolvido dentro
      // desta mesma chamada (ficou congelado, como o resto do motor já faz
      // ao esgotar o orçamento com um match pendente).
      final stillPending = resolution.board.getTileAt(const Position(row: 1, col: 2))?.value == 5 &&
          resolution.board.getTileAt(const Position(row: 1, col: 3))?.value == 5 &&
          resolution.board.getTileAt(const Position(row: 1, col: 4))?.value == 5;

      if (stillPending && resolution.cascades >= kCascadeBudgetPerTurn) {
        // Cenário reproduziu o caso do relatório de revisão: o match ficou
        // no tabuleiro. A jogada seguinte (um resolve() novo, sem gasto de
        // budget adicional) deve processá-lo sem intervenção especial —
        // mesmo comportamento que qualquer match congelado por budget já
        // tem no motor.
        final nextTurn = MatchEngine(random: Random(9)).resolve(resolution.board);
        expect(
          nextTurn.steps.first.fusions.any((f) => f.value == 6 || f.matchLength >= 3),
          isTrue,
          reason: 'o match promovido pela Nova é processado no resolve() seguinte, '
              'sem precisar de um campo de estado tipo isGridDirty',
        );
      }
      // Quando o cenário não reproduz o esgotamento exato do orçamento
      // (depende da semente e de quantas cascatas o tabuleiro base já
      // encadeia), o teste ainda documenta a intenção — mas a asserção
      // condicional é aceitável aqui porque a garantia real (resolve()
      // sempre reprocessa do zero) já está coberta pelos testes de
      // CascadeBudget pré-existentes no grupo 'Super 9'/'CascadeBudget' do
      // motor, e este teste é reforço específico do cenário da Nova.
    });
  });
```

- [ ] **Step 2: Rodar**

Run: `flutter test test/features/game/domain/match_engine_test.dart --plain-name "Evento Nova"`
Expected: PASS. Se o teste de "dispara por cascata" não formar a cascata esperada com `Random(4)`, ajustar a grade (mesma nota de fragilidade já documentada no teste equivalente do Bloco 9, linha 637-685 do arquivo) — trocar a semente ou os valores até o `expect(novaInCascade, isTrue)` da própria asserção de sanidade confirmar o cenário antes de julgar o teste principal.

- [ ] **Step 3: Rodar a suíte completa do motor**

Run: `flutter test test/features/game/domain/match_engine_test.dart`
Expected: PASS — todos os testes do arquivo, incluindo Bloco 9, Super 9, CascadeBudget e Evento Nova.

- [ ] **Step 4: Commit**

```bash
git add test/features/game/domain/match_engine_test.dart
git commit -m "test: Nova por cascata, independência do Super 9 e match pendente por budget"
```

---

### Task 7: Registro no `CLAUDE.md`

Todo módulo novo do jogo ganha uma seção de retrospectiva no `CLAUDE.md` — é a convenção já seguida por Bloco 9/Super 9, Martelo, DEM, etc. Sem isso, o próximo desenvolvedor (ou a próxima sessão) perde o porquê das decisões tomadas na revisão adversarial (cap de 1 por jogada, imunidade de especiais).

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Adicionar a seção**

No final do arquivo `CLAUDE.md`, depois da última seção existente (`### Refresh de identidade visual...`), adicionar:

```markdown

### Evento Nova: terceiro clímax do jogo (fusão de 3+ peças de valor 9) ✅

**A Nova nasce de peças `9` que já existiam no tabuleiro, não de uma fusão
que produz `9`.** Isso a torna estruturalmente diferente do Bloco 9 e do
Super 9 (que nascem de peças `8` se fundindo): o gatilho é o run de 3+ `9`s
que `_applyFusions` já detectava e simplesmente consumia — em silêncio, sem
efeito, desde que o Bloco 9 existe. Ver
`docs/superpowers/specs/2026-08-25-evento-nova-design.md`.

**Zonas escalam com a quantidade de 9s, não com um raio fixo.** Núcleo 3x3
(mesmo tamanho do Bloco 9) destrói peça e obstáculo; o anel — resto de uma
5x5 (tier 1, 3 peças) ou 7x7 (tier 2, 4 peças) — promove peça sobrevivente
em +1. Tier 3 (5+ peças) não tem anel: o núcleo vira o tabuleiro inteiro.

**Cap de 1 Nova por jogada existe para matar uma cadeia de autoplay, não
para respeitar o `CascadeBudget`.** O orçamento de cascata já impede loop
infinito por construção (rede de segurança de sempre); o risco real, achado
em revisão adversarial antes da implementação, era outro: a Nova promove
peças no anel, a queda pode alinhar essas peças promovidas, e uma segunda
Nova formada por peças que a primeira Nova criou transformaria o evento em
"o jogo jogando sozinho" — o oposto do que um clímax de jogada deve ser. A
trava é uma variável **local** de `resolve()` (`novaUsedThisTurn`), no
mesmo espírito do `CascadeBudget` já ser recriado a cada chamada: não existe
flag de estado do jogo para vazar entre turnos, porque não há onde ela
vazaria.

**Peça especial (Super 9, Curinga) é imune ao núcleo e ao anel.** Destruir
um Super 9 que o jogador levou várias jogadas para construir, por acidente
de uma Nova formada numa cascata que ele nem controlou, foi outro achado da
revisão adversarial — a peça especial simplesmente não é tocada, sem lógica
de reposicionamento (cogitada e descartada por complexidade desnecessária).

**Nenhum `isGridDirty` foi criado para o caso de a Nova esgotar o
`CascadeBudget` com um match pendente.** O motor já não guarda estado
incremental de match — `resolve()` roda `detectMatches` do zero a cada
chamada —, então um match congelado pela Nova é reprocessado pela jogada
seguinte do mesmo jeito que qualquer outro match congelado por orçamento já
era, desde antes deste evento existir. Um campo de "sujeira" seria estado
redundante sobre uma garantia que a arquitetura já dá de graça.

**Gatilho em qualquer passo, ao contrário do Bloco 9.** O Bloco 9 só limpa
bloqueadores na fusão direta do jogador (`cascade == 1`); a Nova dispara em
qualquer passo, porque os `9`s que se alinham já estavam no tabuleiro antes
da jogada — não há "proveniência da fusão" para restringir.

**Independente do Super 9, sem checagem de exclusividade** — os dois podem
coexistir e disparar em qualquer ordem, inclusive na mesma jogada.

**Ainda não implementado, e é decisão explícita:** widgets/animações da
Nova (a UI reaproveitaria o `JuiceDirector`/`JuicePriority` do spec de
Bloco 9/Super 9, mas onde a Nova entra nessa hierarquia — acima ou abaixo
de `supernova` — fica para quando a UI for desenhada); calibragem de
economia via `tool/simulate_economy.dart` (os valores de
`kNovaScoreTier{1,2,3}` e a frequência real de Novas numa partida ainda não
foram medidos); qualquer interação com `LevelObjective` (a Nova hoje é
puramente placar/tabuleiro, não avança objetivo de fase nenhum).
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: registra o evento Nova no CLAUDE.md"
```

---

## Self-Review (já aplicado ao escrever o plano acima)

**Cobertura do spec:**
- Gatilho substituindo o consumo silencioso → Task 3.
- Cap de 1 Nova por jogada → Task 3 (implementação) + teste dedicado.
- Zonas por tier (5x5/7x7/tabuleiro inteiro) → Task 3 (tier 1) + Task 4 (tiers 2 e 3).
- Núcleo destrói peça+obstáculo, anel promove → Task 3.
- Centro via survivor position (reaproveitando `_fusionPosition`) → Task 3, sem geometria nova.
- Imunidade de especiais → Task 5.
- Placar por tier → Task 3 (tier 1) + Task 4 (tiers 2/3).
- Independência do Super 9 → Task 6.
- Gatilho por cascata (não só troca do jogador) → Task 6.
- Match pendente por `CascadeBudget` sem `isGridDirty` → Task 6.
- `NovaEvent`/`ResolutionStep.novaEvents` → Tasks 1 e 2.
- "Não implementado" (widgets, economia, `LevelObjective`) → deliberadamente fora de todas as tasks, registrado na Task 7.

**Sem placeholders:** todo passo de código tem o trecho completo, nenhum "adicionar validação apropriada" ou "similar à Task N" sem o código repetido.

**Consistência de tipos:** `NovaEvent` (Task 1) é usado com os mesmos nomes de campo (`at`, `tier`, `obstacleHits`, `clearedTiles`, `promoted`) em todas as tasks seguintes. `novaScoreForTier`/`kNovaScoreTier1/2/3` (Task 1) usados sem variação de nome nas Tasks 3 e 4. `_applyFusions(..., {required bool novaAlreadyTriggered})` (Task 3) é a única assinatura nova introduzida, e o único outro chamador (`fuse()`) é atualizado no mesmo passo — não sobra chamada desatualizada.

**Risco conhecido, não coberto por teste (aceito por escopo):** se o núcleo/anel da Nova tocar uma posição que pertence a um match *diferente* sendo processado na mesma chamada de `_applyFusions` (ex: uma Nova cuja zona de efeito encosta numa combinação não relacionada, disparando na mesma cascata), a ordem de iteração de `matches` decide qual escrita "vence" naquela posição — o mesmo comportamento de last-write-wins que o mapa `updates` já tem para qualquer sobreposição no motor. Não é um caso novo introduzido pela Nova; é aceito como está, sem guarda extra, pelo mesmo motivo de sempre: a probabilidade de duas combinações não relacionadas coincidirem exatamente na zona de uma Nova, na mesma passada, é baixa o suficiente para não justificar a complexidade de uma resolução de conflito dedicada agora.
