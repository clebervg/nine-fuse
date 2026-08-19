# Gatilho de Migração para o Modo Recorde — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Quando o jogador perde a mesma fase da campanha 3 vezes seguidas — e o Endless já está desbloqueado — mostrar um dialog sugerindo o Modo Recorde, seguindo exatamente o padrão visual e de estado já usado por `HammerOfferDialog`/`MovesOfferDialog`.

**Architecture:** Um contador `consecutiveLosses` e uma flag `endlessOfferShown` entram em `GameState`, mantidos por `GameNotifier` (incrementa em derrota, reseta ao vencer ou trocar de fase). Um novo getter `shouldOfferEndless` expõe o gatilho. `game_screen.dart` combina esse getter com a checagem de desbloqueio do Endless (extraída para uma função pura em `endless_notifier.dart`) para decidir quando abrir o novo `EndlessSuggestionDialog`, empilhado sobre o `LevelOutcomeCard` do mesmo jeito que os outros dois overlays.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod`), `flutter_test`, l10n via arquivos `.arb` (`flutter gen-l10n`).

## Global Constraints

- Nada de `Future.delayed` em widgets de UI — usar `AnimationController` quando houver animação (não há animação nova nesta feature).
- O contador de derrotas vive **apenas em memória**, no `GameState` — sem novo campo em `GameStorage`, sem migração.
- O padrão de overlay a seguir é o de `HammerOfferDialog`/`MovesOfferDialog`: camada do `Stack` de `game_screen.dart`, nunca `showDialog`.
- Quem marca a oferta como "mostrada" é a **tela** (via `ref.listen`), não o notifier diretamente — mesmo padrão de `markMovesOfferShown()`.
- Toda string nova de UI entra nos dois arquivos `.arb` (`lib/l10n/app_pt.arb` e `lib/l10n/app_en.arb`), com blocos `@chave`/`placeholders` apenas no `app_en.arb`, seguindo o padrão de `movesOfferTitle`/`movesOfferBody`.
- Testes seguem os padrões de arquivo já usados no projeto: `game_notifier_test.dart` para lógica de estado, testes de widget no estilo de `moves_offer_test.dart` para a tela.

---

### Task 1: Contador de derrotas e getter de gatilho em `GameState`

**Files:**
- Modify: `lib/features/game/providers/game_state.dart`
- Test: `test/features/game/providers/game_state_test.dart`

**Interfaces:**
- Consumes: nada de tarefas anteriores.
- Produces: `GameState.consecutiveLosses` (`int`), `GameState.endlessOfferShown` (`bool`), `GameState.shouldOfferEndless` (`bool` getter), `kConsecutiveLossesForEndlessOffer` (`int`, valor `3`). `GameNotifier` (Task 2) lê e escreve os dois primeiros via `copyWith`.

- [ ] **Step 1: Escrever o teste que falha, construindo o `GameState` diretamente**

Adicionar ao final de `test/features/game/providers/game_state_test.dart` (antes do `}` de fechamento do `void main()`):

```dart
  group('shouldOfferEndless', () {
    test('padrão nasce zerado e sem oferta', () {
      notifier.startLevel(
        const GameLevel(
          number: 89,
          objective: Objective(digit: 4, count: 3),
          moveLimit: 50,
        ),
      );

      expect(notifier.state.consecutiveLosses, 0);
      expect(notifier.state.endlessOfferShown, isFalse);
      expect(notifier.state.shouldOfferEndless, isFalse);
    });

    test('só é verdadeiro com a fase perdida e o contador no limiar', () {
      final base = notifier.state.copyWith(
        status: GameStatus.lost,
        consecutiveLosses: kConsecutiveLossesForEndlessOffer,
      );

      expect(base.shouldOfferEndless, isTrue);
      expect(
        base
            .copyWith(consecutiveLosses: kConsecutiveLossesForEndlessOffer - 1)
            .shouldOfferEndless,
        isFalse,
      );
      expect(
        base.copyWith(status: GameStatus.playing).shouldOfferEndless,
        isFalse,
      );
      expect(
        base.copyWith(endlessOfferShown: true).shouldOfferEndless,
        isFalse,
      );
    });
  });
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `flutter test test/features/game/providers/game_state_test.dart`
Expected: FAIL — `The getter 'consecutiveLosses' isn't defined for the type 'GameState'` (ou erro equivalente de `copyWith`/`shouldOfferEndless` inexistentes).

- [ ] **Step 3: Adicionar a constante do limiar**

Em `lib/features/game/providers/game_state.dart`, logo abaixo da declaração de `kPreChurnMovesLeft` (linha 30, antes de `enum GameStatus`):

```dart
const int kPreChurnMovesLeft = 2;

/// Quantas derrotas seguidas na mesma fase sugerem o Modo Recorde.
///
/// Três, e não uma: sugerir na primeira derrota leria como o jogo desistindo
/// do jogador antes dele. É o mesmo limiar que a análise de retenção do
/// produto definiu como "energia da fase acabou".
const int kConsecutiveLossesForEndlessOffer = 3;
```

- [ ] **Step 4: Adicionar os dois campos ao construtor e às declarações**

Em `lib/features/game/providers/game_state.dart`, no construtor (linha 48-70), adicionar dois parâmetros com default, na mesma posição relativa de `movesOfferShown`:

```dart
    this.movesOfferShown = false,
    this.boardObstacleGoal,
    this.hammer = const HammerState(),
    this.consecutiveLosses = 0,
    this.endlessOfferShown = false,
  });
```

E logo abaixo do campo `movesOfferShown` (depois da linha 176, antes do campo `hammer`):

```dart
  /// Quantas vezes seguidas o jogador perdeu **esta mesma fase**.
  ///
  /// Vive só em memória: fechar o app no meio de uma sequência de derrotas
  /// zera a contagem, e é uma perda aceitável — o contador é gatilho de
  /// sugestão, não métrica de produto que precise sobreviver a reinícios.
  /// Reseta ao vencer a fase ou ao trocar para outra (ver [GameNotifier]);
  /// **não** reseta ao simplesmente recomeçar a mesma fase perdida, porque é
  /// justamente essa sequência de tentativas que o contador mede.
  final int consecutiveLosses;

  /// O convite de migração para o Modo Recorde já foi mostrado nesta fase.
  ///
  /// Mesma razão de [movesOfferShown]: sem a trava, [shouldOfferEndless]
  /// continuaria verdadeiro a cada nova derrota depois da terceira, e o
  /// convite reabriria sozinho.
  final bool endlessOfferShown;
```

- [ ] **Step 5: Adicionar o getter `shouldOfferEndless`**

Logo abaixo do getter `shouldOfferMoves` (depois da linha 261, antes de `GameState copyWith`):

```dart
  /// A fase acabou de perder feio o bastante para valer sugerir o Modo
  /// Recorde?
  ///
  /// As três guardas: **fase perdida** (o convite é sobre o desfecho, não
  /// sobre uma fase em andamento — diferente do convite de movimentos, que é
  /// pre-churn), **contador no limiar** e **ainda não mostrado nesta fase**.
  /// Não checa se o Endless está desbloqueado: `GameState` não tem acesso ao
  /// progresso da campanha (é outro provider); quem combina os dois é
  /// `game_screen.dart`.
  bool get shouldOfferEndless =>
      status == GameStatus.lost &&
      consecutiveLosses >= kConsecutiveLossesForEndlessOffer &&
      !endlessOfferShown;
```

- [ ] **Step 6: Atualizar `copyWith`**

Nos parâmetros de `copyWith` (depois de `HammerState? hammer,`, linha 294):

```dart
    HammerState? hammer,
    int? consecutiveLosses,
    bool? endlessOfferShown,
  }) => GameState(
```

E no corpo do `copyWith` (depois de `hammer: hammer ?? this.hammer,`, linha 322):

```dart
    hammer: hammer ?? this.hammer,
    consecutiveLosses: consecutiveLosses ?? this.consecutiveLosses,
    endlessOfferShown: endlessOfferShown ?? this.endlessOfferShown,
  );
```

- [ ] **Step 7: Atualizar `==` e `hashCode`**

Em `operator ==` (depois de `hammer == other.hammer;`, linha 356), trocar o `;` de fechamento:

```dart
          hammer == other.hammer &&
          consecutiveLosses == other.consecutiveLosses &&
          endlessOfferShown == other.endlessOfferShown;
```

Em `hashCode` (dentro da lista de `Object.hashAll`, depois de `hammer,` na linha 381):

```dart
    hammer,
    consecutiveLosses,
    endlessOfferShown,
  ]);
```

- [ ] **Step 8: Rodar o teste e confirmar que passa**

Run: `flutter test test/features/game/providers/game_state_test.dart`
Expected: PASS

- [ ] **Step 9: Rodar a suíte inteira de `game_state_test.dart` e `flutter analyze` para checar regressão**

Run: `flutter analyze lib/features/game/providers/game_state.dart`
Expected: `No issues found!`

- [ ] **Step 10: Commit**

```bash
git add lib/features/game/providers/game_state.dart test/features/game/providers/game_state_test.dart
git commit -m "$(cat <<'EOF'
feat: adiciona contador de derrotas e gatilho de sugestão do Endless ao GameState

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: `GameNotifier` incrementa, reseta e expõe `markEndlessOfferShown`

**Files:**
- Modify: `lib/features/game/providers/game_notifier.dart:94-123` (`startLevel`), `:358-414` (`_finishMove`)
- Test: `test/features/game/providers/game_notifier_test.dart`

**Interfaces:**
- Consumes: `GameState.consecutiveLosses`, `GameState.endlessOfferShown`, `GameState.shouldOfferEndless`, `kConsecutiveLossesForEndlessOffer` (Task 1).
- Produces: `GameNotifier.markEndlessOfferShown()` (`void`), e a garantia comportamental de que `consecutiveLosses`/`endlessOfferShown` incrementam/resetam corretamente — consumida por `game_screen.dart` (Task 6).

- [ ] **Step 1: Escrever os testes que falham**

Adicionar, em `test/features/game/providers/game_notifier_test.dart`, um novo `group` (por exemplo logo após o `group('limite de movimentos', ...)`, antes do fechamento de `void main()`):

```dart
  group('sugestão de migração para o Endless', () {
    // Fase que trava em um movimento: qualquer troca que forme combinação já
    // esgota o saldo antes de o objetivo (inalcançável) ser cumprido.
    const stuck = GameLevel(
      number: 95,
      objective: Objective(digit: kMaxDigitForTest, count: 9),
      moveLimit: 1,
    );

    void loseOnce() {
      final pair = findSwap(creatingMatch: true)!;
      notifier.swapTiles(pair.$1, pair.$2);
    }

    test('derrota incrementa o contador na mesma fase', () {
      notifier.startLevel(stuck);
      loseOnce();
      expect(notifier.state.status, GameStatus.lost);
      expect(notifier.state.consecutiveLosses, 1);

      notifier.restartLevel();
      loseOnce();
      expect(notifier.state.consecutiveLosses, 2);
    });

    test('sugere o Endless só na terceira derrota seguida, não antes', () {
      notifier.startLevel(stuck);
      for (int i = 0; i < 2; i++) {
        loseOnce();
        expect(notifier.state.shouldOfferEndless, isFalse);
        notifier.restartLevel();
      }
      loseOnce();

      expect(notifier.state.consecutiveLosses, 3);
      expect(notifier.state.shouldOfferEndless, isTrue);
    });

    test('vencer zera o contador', () {
      notifier.startLevel(stuck);
      loseOnce();
      notifier.restartLevel();
      loseOnce();
      expect(notifier.state.consecutiveLosses, 2);

      const winnable = GameLevel(
        number: 96,
        objective: Objective(digit: 4),
        moveLimit: 50,
      );
      notifier.startLevel(winnable);
      while (notifier.state.status == GameStatus.playing) {
        final pair = findSwap(creatingMatch: true);
        if (pair == null) break;
        notifier.swapTiles(pair.$1, pair.$2);
      }

      expect(notifier.state.status, GameStatus.won);
      expect(notifier.state.consecutiveLosses, 0);
    });

    test('trocar de fase depois de perder zera o contador, mesmo sem vencer', () {
      notifier.startLevel(stuck);
      loseOnce();
      expect(notifier.state.consecutiveLosses, 1);

      const otherLevel = GameLevel(
        number: 97,
        objective: Objective(digit: 4),
        moveLimit: 50,
      );
      notifier.startLevel(otherLevel);

      expect(notifier.state.consecutiveLosses, 0);
    });

    test('markEndlessOfferShown trava o convite até a próxima fase', () {
      notifier.startLevel(stuck);
      for (int i = 0; i < 2; i++) {
        loseOnce();
        notifier.restartLevel();
      }
      loseOnce();
      expect(notifier.state.shouldOfferEndless, isTrue);

      notifier.markEndlessOfferShown();
      expect(notifier.state.shouldOfferEndless, isFalse);

      // Recomeçar a mesma fase perdida não reabre o convite: a fase segue
      // sendo a mesma, e a oferta já foi gasta.
      notifier.restartLevel();
      loseOnce();
      expect(notifier.state.consecutiveLosses, 4);
      expect(notifier.state.shouldOfferEndless, isFalse);
    });
  });
```

- [ ] **Step 2: Rodar os testes e confirmar que falham**

Run: `flutter test test/features/game/providers/game_notifier_test.dart --plain-name "sugestão de migração para o Endless"`
Expected: FAIL — `The method 'markEndlessOfferShown' isn't defined for the type 'GameNotifier'` (e as expectativas de `consecutiveLosses`/`shouldOfferEndless` falham, pois `startLevel`/`_finishMove` ainda não os tocam).

- [ ] **Step 3: Atualizar `startLevel` para resetar ao trocar de fase**

Em `lib/features/game/providers/game_notifier.dart`, dentro de `startLevel` (linha 95-123), capturar se é a mesma fase **antes** de recriar o motor, e propagar os dois campos:

```dart
  /// Começa a fase [level] com um tabuleiro novo.
  void startLevel(GameLevel level) {
    // A mesma fase, tentada de novo, mantém a sequência de derrotas — é
    // justamente essa sequência que `shouldOfferEndless` mede. Qualquer outra
    // fase (avançar, recomeçar do mapa) é uma folga nova.
    final samePhase = state.level.number == level.number;

    _engine = MatchEngine(
      random: _random,
      spawnMin: level.spawnMin,
      spawnMax: level.spawnMax,
    );

    final board = _engine!.generateBoard(obstacles: level.obstacles);

    state = GameState(
      board: board,
      level: level,
      status: GameStatus.playing,
      hint: _engine!.findHint(board),
      // Cada partida tem o seu número. Sem ele, recomeçar a fase atual sem
      // tê-la perdido é indistinguível de nada ter mudado, e a UI não teria
      // como saber que precisa reabrir o cartão de início.
      runId: state.runId + 1,
      boardObstacleGoal: _obstacleGoalFor(level, board),
      // O inventário atravessa a fase nova (é do jogador, não da partida), mas
      // a mira e o estilhaço ficam para trás com a partida que acabou.
      hammer: state.hammer.inventoryOnly,
      consecutiveLosses: samePhase ? state.consecutiveLosses : 0,
      endlessOfferShown: samePhase ? state.endlessOfferShown : false,
    );

    // O Endless pode ter gastado um martelo enquanto esta tela estava viva: os
    // dois notifiers compartilham o estoque, e quem chegou por último ao disco
    // manda.
    refreshHammers();
  }
```

- [ ] **Step 4: Atualizar `_finishMove` para incrementar/resetar**

Em `lib/features/game/providers/game_notifier.dart`, dentro de `_finishMove` (linha 358-414), depois de calcular `outcome` (linha 378-390) e antes do `state = state.copyWith(...)` (linha 392), adicionar:

```dart
    final outcome = _outcomeAfterMove(
      progress: progress,
      target: state.objectiveTarget,
      moves: moves,
      movesAvailable: state.level.moveLimit + bonusMoves,
      hasMove: hint != null,
    );

    // O contador de derrotas seguidas mede a mesma fase: cresce a cada
    // derrota, e só uma vitória o zera — trocar de fase é responsabilidade de
    // `startLevel`, não deste método.
    final consecutiveLosses = switch (outcome.status) {
      GameStatus.lost => state.consecutiveLosses + 1,
      GameStatus.won => 0,
      _ => state.consecutiveLosses,
    };
    final endlessOfferShown = outcome.status == GameStatus.won
        ? false
        : state.endlessOfferShown;

    state = state.copyWith(
      board: resolution.board,
      score: state.score + extraScore,
      moves: moves,
      bonusMoves: bonusMoves,
      objectiveProgress: progress,
      status: outcome.status,
      lossReason: outcome.loss,
      clearLossReason: outcome.loss == null,
      hint: hint,
      clearHint: hint == null,
      bigFusionTileIds: resolution.bigFusionTileIds,
      clearActiveStep: true,
      comboCount: 0,
      isResolving: false,
      clearSelectedTile: true,
      clearRejectedSwap: true,
      apexCelebrated: state.apexCelebrated || resolution.explosions > 0,
      explosions: state.explosions + (extraExplosions ?? resolution.explosions),
      consecutiveLosses: consecutiveLosses,
      endlessOfferShown: endlessOfferShown,
    );
  }
```

- [ ] **Step 5: Adicionar `markEndlessOfferShown()`**

Logo abaixo de `markMovesOfferShown()` (depois da linha 149, antes de `grantBonusMoves`):

```dart
  /// O convite abriu na tela.
  ///
  /// Quem marca é a **UI**, e não o notifier, pela mesma razão de
  /// [markMovesOfferShown]: a regra sabe dizer que a fase justifica a
  /// sugestão, só a tela sabe se o cartão chegou a subir.
  void markEndlessOfferShown() {
    if (state.endlessOfferShown) return;
    state = state.copyWith(endlessOfferShown: true);
  }
```

- [ ] **Step 6: Rodar os testes e confirmar que passam**

Run: `flutter test test/features/game/providers/game_notifier_test.dart`
Expected: PASS (toda a suíte, não só o grupo novo — para pegar regressão em `startLevel`/`_finishMove`)

- [ ] **Step 7: `flutter analyze`**

Run: `flutter analyze lib/features/game/providers/game_notifier.dart`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/features/game/providers/game_notifier.dart test/features/game/providers/game_notifier_test.dart
git commit -m "$(cat <<'EOF'
feat: GameNotifier rastreia derrotas seguidas e libera o convite do Endless

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Extrair `endlessIsUnlocked` como função pura reutilizável

**Files:**
- Modify: `lib/features/game/providers/endless_notifier.dart:338`
- Modify: `lib/features/game/presentation/screens/level_select_screen.dart:211-213`
- Test: `test/features/game/providers/endless_notifier_test.dart`

**Interfaces:**
- Consumes: nada de tarefas anteriores.
- Produces: `bool endlessIsUnlocked(int campaignProgress)` — consumida por `game_screen.dart` (Task 6) e por `level_select_screen.dart`.

- [ ] **Step 1: Escrever o teste que falha**

Adicionar a `test/features/game/providers/endless_notifier_test.dart`, dentro de `void main()` (antes ou depois do `group` existente):

```dart
  group('endlessIsUnlocked', () {
    test('bloqueado abaixo da fase de desbloqueio', () {
      expect(endlessIsUnlocked(kEndlessUnlockLevel - 1), isFalse);
    });

    test('liberado a partir da fase de desbloqueio', () {
      expect(endlessIsUnlocked(kEndlessUnlockLevel), isTrue);
      expect(endlessIsUnlocked(kEndlessUnlockLevel + 1), isTrue);
    });
  });
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `flutter test test/features/game/providers/endless_notifier_test.dart --plain-name "endlessIsUnlocked"`
Expected: FAIL — `The function 'endlessIsUnlocked' isn't defined`

- [ ] **Step 3: Adicionar a função em `endless_notifier.dart`**

Em `lib/features/game/providers/endless_notifier.dart`, logo abaixo de `const int kEndlessUnlockLevel = 5;` (linha 338):

```dart
const int kEndlessUnlockLevel = 5;

/// O Modo Recorde está liberado para quem chegou até [campaignProgress] na
/// campanha?
///
/// Função pura, e não um getter espalhado por cada tela que precisa saber:
/// hoje só `level_select_screen.dart` e o novo convite de migração
/// (`game_screen.dart`) fazem essa pergunta, mas as duas têm de concordar —
/// duas cópias da mesma comparação divergiriam no primeiro ajuste do
/// desbloqueio.
bool endlessIsUnlocked(int campaignProgress) =>
    campaignProgress >= kEndlessUnlockLevel;
```

- [ ] **Step 4: Usar a função em `level_select_screen.dart`**

Em `lib/features/game/presentation/screens/level_select_screen.dart:211-213`, trocar:

```dart
                  EndlessHighlight(
                    isUnlocked: progress >= kEndlessUnlockLevel,
                    unlockedAt: kEndlessUnlockLevel,
```

por:

```dart
                  EndlessHighlight(
                    isUnlocked: endlessIsUnlocked(progress),
                    unlockedAt: kEndlessUnlockLevel,
```

- [ ] **Step 5: Rodar os testes e confirmar que passam**

Run: `flutter test test/features/game/providers/endless_notifier_test.dart test/features/game/presentation/level_select_screen_test.dart`
Expected: PASS (o segundo arquivo cobre `level_select_screen.dart` — confirma que o refactor não mudou comportamento)

- [ ] **Step 6: `flutter analyze`**

Run: `flutter analyze lib/features/game/providers/endless_notifier.dart lib/features/game/presentation/screens/level_select_screen.dart`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/features/game/providers/endless_notifier.dart lib/features/game/presentation/screens/level_select_screen.dart test/features/game/providers/endless_notifier_test.dart
git commit -m "$(cat <<'EOF'
refactor: extrai endlessIsUnlocked como função pura reutilizável

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Strings de l10n para o convite

**Files:**
- Modify: `lib/l10n/app_pt.arb`
- Modify: `lib/l10n/app_en.arb`

**Interfaces:**
- Consumes: nada.
- Produces: `AppLocalizations.endlessSuggestionTitle`, `.endlessSuggestionBody`, `.endlessSuggestionGo`, `.endlessSuggestionDecline` — consumidas por `EndlessSuggestionDialog` (Task 5).

- [ ] **Step 1: Adicionar as chaves ao `app_pt.arb`**

Em `lib/l10n/app_pt.arb`, logo depois de `"movesOfferFailed": "Nenhum anúncio disponível agora.",` (linha 159):

```json
  "movesOfferFailed": "Nenhum anúncio disponível agora.",
  "endlessSuggestionTitle": "Sem energia agora?",
  "endlessSuggestionBody": "Sua energia nesta fase acabou! Que tal bater seu Recorde Pessoal enquanto ela recarrega?",
  "endlessSuggestionGo": "IR PARA O MODO RECORDE",
  "endlessSuggestionDecline": "CONTINUAR TENTANDO",
```

- [ ] **Step 2: Adicionar as chaves ao `app_en.arb`**

Em `lib/l10n/app_en.arb`, logo depois de `"movesOfferFailed": "No ad available right now.",` (linha 315):

```json
  "movesOfferFailed": "No ad available right now.",
  "endlessSuggestionTitle": "Out of energy?",
  "endlessSuggestionBody": "Your energy for this level ran out! How about beating your Personal Best while it recharges?",
  "endlessSuggestionGo": "GO TO RECORD MODE",
  "endlessSuggestionDecline": "KEEP TRYING",
```

Nenhuma das quatro chaves tem placeholder — nenhum bloco `@chave` é necessário (mesmo padrão de `movesOfferTitle`/`movesOfferDecline`, que também não têm).

- [ ] **Step 3: Gerar as classes de localização**

Run: `flutter gen-l10n`
Expected: comando termina sem erro, e `lib/l10n/app_localizations_pt.dart`/`app_localizations_en.dart` (arquivos gerados) passam a ter os quatro getters novos.

- [ ] **Step 4: Confirmar que o projeto compila com as novas chaves**

Run: `flutter analyze lib/l10n`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/app_pt.arb lib/l10n/app_en.arb lib/l10n/app_localizations*.dart
git commit -m "$(cat <<'EOF'
feat: adiciona textos pt/en do convite de migração para o Endless

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Widget `EndlessSuggestionDialog`

**Files:**
- Create: `lib/features/game/presentation/widgets/endless_suggestion_dialog.dart`
- Test: `test/features/game/presentation/endless_suggestion_dialog_test.dart`

**Interfaces:**
- Consumes: `GameDialog`, `GameButton` (`lib/features/game/presentation/widgets/game_dialog.dart`), `AppColors.digit9` (`lib/core/constants/app_colors.dart`), `AppLocalizations.endlessSuggestionTitle`/`.endlessSuggestionBody`/`.endlessSuggestionGo`/`.endlessSuggestionDecline` (Task 4).
- Produces: `EndlessSuggestionDialog` (widget, `onGoToEndless: VoidCallback`, `onDecline: VoidCallback`), `endlessSuggestionKey`, `endlessSuggestionGoKey`, `endlessSuggestionDeclineKey` — consumidos por `game_screen.dart` (Task 6) e pelo teste desta task.

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/features/game/presentation/endless_suggestion_dialog_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/presentation/widgets/endless_suggestion_dialog.dart';
import '../../../support/localized.dart';

void main() {
  testWidgets('mostra o cartão e os dois botões', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(
          body: EndlessSuggestionDialog(
            onGoToEndless: () {},
            onDecline: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(endlessSuggestionKey), findsOneWidget);
    expect(find.byKey(endlessSuggestionGoKey), findsOneWidget);
    expect(find.byKey(endlessSuggestionDeclineKey), findsOneWidget);
  });

  testWidgets('tocar em "ir para o Modo Recorde" chama o callback', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(
          body: EndlessSuggestionDialog(
            onGoToEndless: () => tapped = true,
            onDecline: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(endlessSuggestionGoKey));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('tocar em "continuar tentando" chama o callback', (
    tester,
  ) async {
    var declined = false;
    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(
          body: EndlessSuggestionDialog(
            onGoToEndless: () {},
            onDecline: () => declined = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(endlessSuggestionDeclineKey));
    await tester.pump();

    expect(declined, isTrue);
  });
}
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `flutter test test/features/game/presentation/endless_suggestion_dialog_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'nine_fuse'... endless_suggestion_dialog.dart` (arquivo ainda não existe)

- [ ] **Step 3: Criar o widget**

Criar `lib/features/game/presentation/widgets/endless_suggestion_dialog.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/features/game/presentation/widgets/game_dialog.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Chave do cartão de sugestão do Modo Recorde.
const Key endlessSuggestionKey = Key('endless_suggestion');

/// Chave do botão que leva ao Modo Recorde.
const Key endlessSuggestionGoKey = Key('endless_suggestion_go');

/// Chave do botão que recusa e mantém o cartão de desfecho da fase.
const Key endlessSuggestionDeclineKey = Key('endless_suggestion_decline');

/// Convite para migrar ao Modo Recorde, aberto depois de três derrotas
/// seguidas na mesma fase da campanha.
///
/// Sobe **sobre** o `LevelOutcomeCard` (a fase já perdeu), e não em vez dele:
/// recusar mantém o cartão de desfecho visível, com o botão de tentar de
/// novo. Quem decide se ele aparece é `GameState.shouldOfferEndless`
/// combinado com `endlessIsUnlocked`, lidos em `game_screen.dart` — este
/// widget só apresenta a escolha.
class EndlessSuggestionDialog extends StatelessWidget {
  const EndlessSuggestionDialog({
    super.key,
    required this.onGoToEndless,
    required this.onDecline,
  });

  /// O jogador quer testar o Modo Recorde agora.
  final VoidCallback onGoToEndless;

  /// O jogador prefere continuar tentando a fase.
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return GameDialog(
      cardKey: endlessSuggestionKey,
      title: l10n.endlessSuggestionTitle,
      accent: AppColors.digit9,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            color: AppColors.digit9,
            size: 44,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.endlessSuggestionBody,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
          const SizedBox(height: 18),
          GameButton(
            key: endlessSuggestionGoKey,
            label: l10n.endlessSuggestionGo,
            color: AppColors.digit9,
            icon: Icons.emoji_events_rounded,
            onPressed: onGoToEndless,
          ),
          const SizedBox(height: 10),
          GameButton(
            key: endlessSuggestionDeclineKey,
            label: l10n.endlessSuggestionDecline,
            color: AppColors.darkSurface,
            foreground: Colors.white70,
            onPressed: onDecline,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `flutter test test/features/game/presentation/endless_suggestion_dialog_test.dart`
Expected: PASS

- [ ] **Step 5: `flutter analyze`**

Run: `flutter analyze lib/features/game/presentation/widgets/endless_suggestion_dialog.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/game/presentation/widgets/endless_suggestion_dialog.dart test/features/game/presentation/endless_suggestion_dialog_test.dart
git commit -m "$(cat <<'EOF'
feat: cria o widget EndlessSuggestionDialog

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Ligar o convite em `game_screen.dart`

**Files:**
- Modify: `lib/features/game/presentation/screens/game_screen.dart`
- Test: `test/features/game/presentation/endless_suggestion_flow_test.dart`

**Interfaces:**
- Consumes: `GameState.shouldOfferEndless` (Task 1), `GameNotifier.markEndlessOfferShown()` (Task 2), `endlessIsUnlocked(int)` (Task 3), `EndlessSuggestionDialog` + suas chaves (Task 5), `campaignProgressProvider` (já existe em `game_notifier.dart`), `endlessHighScoreProvider` (já existe em `endless_notifier.dart`), `EndlessScreen` (já existe em `endless_screen.dart`).
- Produces: comportamento observável na tela — nada consumido por outra task.

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/features/game/presentation/endless_suggestion_flow_test.dart`, seguindo o mesmo formato de `moves_offer_test.dart`:

```dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/presentation/screens/game_screen.dart';
import 'package:nine_fuse/features/game/presentation/widgets/endless_suggestion_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/level_start_dialog.dart';
import 'package:nine_fuse/features/game/providers/endless_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_state.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import '../../../support/localized.dart';

void main() {
  late GameNotifier notifier;

  /// Fase que trava em um movimento: qualquer combinação já esgota o saldo
  /// antes do objetivo (inalcançável) ser cumprido.
  const stuck = GameLevel(
    number: 95,
    objective: Objective(digit: kMaxDigitForTest, count: 9),
    moveLimit: 1,
  );

  setUp(() {
    notifier = GameNotifier(random: Random(7), storage: InMemoryGameStorage());
  });

  Future<void> pumpGame(WidgetTester tester, {required int campaignProgress}) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameProvider.overrideWith((ref) => notifier),
          campaignProgressProvider.overrideWith(
            (ref) => CampaignProgress(storage: InMemoryGameStorage())
              ..complete(campaignProgress),
          ),
        ],
        child: localizedApp(home: const GameScreen(level: stuck)),
      ),
    );
    await tester.pumpAndSettle();
    if (find.byKey(startLevelKey).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(startLevelKey));
      await tester.pumpAndSettle();
    }
  }

  (Position, Position)? _swap() {
    final engine = notifier.engine!;
    final board = notifier.state.board;
    for (final (a, b) in engine.candidateSwaps(board)) {
      if (engine.swapCreatesMatch(board, a, b)) return (a, b);
    }
    return null;
  }

  Future<void> loseOnce(WidgetTester tester) async {
    final pair = _swap()!;
    notifier.swapTiles(pair.$1, pair.$2);
    await tester.pumpAndSettle();
  }

  Future<void> retry(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('retry_level')));
    await tester.pumpAndSettle();
  }

  testWidgets('não aparece antes da terceira derrota', (tester) async {
    await pumpGame(tester, campaignProgress: kEndlessUnlockLevel);
    await loseOnce(tester);

    expect(find.byKey(endlessSuggestionKey), findsNothing);
  });

  testWidgets('aparece na terceira derrota seguida, com o Endless liberado', (
    tester,
  ) async {
    await pumpGame(tester, campaignProgress: kEndlessUnlockLevel);
    await loseOnce(tester);
    await retry(tester);
    await loseOnce(tester);
    await retry(tester);
    await loseOnce(tester);

    expect(find.byKey(endlessSuggestionKey), findsOneWidget);
  });

  testWidgets('não aparece se o Endless ainda está bloqueado', (
    tester,
  ) async {
    await pumpGame(tester, campaignProgress: kEndlessUnlockLevel - 1);
    await loseOnce(tester);
    await retry(tester);
    await loseOnce(tester);
    await retry(tester);
    await loseOnce(tester);

    expect(find.byKey(endlessSuggestionKey), findsNothing);
  });

  testWidgets('recusar fecha o convite e mantém o cartão de desfecho', (
    tester,
  ) async {
    await pumpGame(tester, campaignProgress: kEndlessUnlockLevel);
    await loseOnce(tester);
    await retry(tester);
    await loseOnce(tester);
    await retry(tester);
    await loseOnce(tester);

    await tester.tap(find.byKey(endlessSuggestionDeclineKey));
    await tester.pumpAndSettle();

    expect(find.byKey(endlessSuggestionKey), findsNothing);
    expect(find.byKey(const Key('level_outcome')), findsOneWidget);
  });
}
```

Nota de implementação do teste: `Position` precisa do import
`package:nine_fuse/features/game/domain/position.dart` — adicionar ao topo do
arquivo de teste junto com os demais imports.

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `flutter test test/features/game/presentation/endless_suggestion_flow_test.dart`
Expected: FAIL — `find.byKey(endlessSuggestionKey)` nunca aparece, porque `game_screen.dart` ainda não monta o widget (o `import` do arquivo de teste para `endless_suggestion_dialog.dart` resolve normalmente, já que a Task 5 já criou o arquivo; é a tela que ainda não reage).

- [ ] **Step 3: Adicionar os imports novos em `game_screen.dart`**

Em `lib/features/game/presentation/screens/game_screen.dart`, depois de `import 'package:nine_fuse/features/game/presentation/widgets/apex_celebration.dart';` (linha 12), adicionar em ordem alfabética junto aos demais:

```dart
import 'package:nine_fuse/features/game/presentation/widgets/endless_suggestion_dialog.dart';
```

E depois de `import 'package:nine_fuse/features/game/providers/campaign_records.dart';` (linha 10):

```dart
import 'package:nine_fuse/features/game/presentation/screens/endless_screen.dart';
import 'package:nine_fuse/features/game/providers/endless_notifier.dart';
```

(A ordem exata de import não importa para o compilador; o `flutter analyze`/`dart format` no Step 8 corrige qualquer desalinhamento de estilo.)

- [ ] **Step 4: Adicionar o campo de estado `_endlessSuggestionOpen`**

Em `_GameScreenState`, logo abaixo de `bool _movesOfferOpen = false;` (linha 83):

```dart
  bool _movesOfferOpen = false;

  /// O convite de migração para o Modo Recorde está aberto agora?
  ///
  /// Mesmo motivo de [_movesOfferOpen]: precisa ser separado de
  /// `GameState.shouldOfferEndless` porque abrir o convite não muda o
  /// contador — só `markEndlessOfferShown()` o gasta, e é a tela quem decide
  /// chamá-lo.
  bool _endlessSuggestionOpen = false;
```

- [ ] **Step 5: Resetar a flag quando uma nova partida começa**

No `ref.listen`, no bloco que reage a `next.runId != previous.runId` (linha 153-161), adicionar a linha:

```dart
      if (previous != null && next.runId != previous.runId) {
        setState(() {
          _ready = false;
          _movesOfferOpen = false;
          _endlessSuggestionOpen = false;
        });
      }
```

- [ ] **Step 6: Adicionar o gatilho no `ref.listen`**

Logo depois do bloco que abre `_movesOfferOpen` (linha 167-170), antes do fechamento do `ref.listen`:

```dart
      if (!_movesOfferOpen && _ready && next.shouldOfferMoves) {
        _movesOfferOpen = true;
        ref.read(gameProvider.notifier).markMovesOfferShown();
      }

      // O convite de migração só sobe depois de a fase acabar em derrota —
      // diferente do de movimentos, que é pre-churn. `endlessIsUnlocked` lê o
      // progresso da campanha porque `GameState` não tem acesso a ele.
      if (!_endlessSuggestionOpen &&
          next.shouldOfferEndless &&
          endlessIsUnlocked(ref.read(campaignProgressProvider))) {
        _endlessSuggestionOpen = true;
        ref.read(gameProvider.notifier).markEndlessOfferShown();
      }
    });
```

- [ ] **Step 7: Adicionar o overlay no `Stack`, depois do `LevelOutcomeCard`**

Depois do bloco `if (state.isOver) _OutcomeOverlay(child: LevelOutcomeCard(...))` (linha 363-373), antes do fechamento `],` do `Stack`:

```dart
            if (state.isOver)
              _OutcomeOverlay(
                child: LevelOutcomeCard(
                  state: state,
                  onRetry: notifier.restartLevel,
                  onNext: notifier.nextLevel,
                  onBack: () => Navigator.of(context).maybePop(),
                  starsInChapter: chapterStars,
                  starsGained: _chapterStarsGained,
                ),
              ),
            // Sobe **sobre** o cartão de desfecho: recusar revela o mesmo
            // cartão, com o botão de tentar de novo intacto.
            if (_endlessSuggestionOpen)
              _OutcomeOverlay(
                child: EndlessSuggestionDialog(
                  onGoToEndless: () {
                    setState(() => _endlessSuggestionOpen = false);
                    Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (_) => const EndlessScreen(),
                          ),
                        )
                        .then((_) {
                          if (mounted) {
                            ref
                                .read(endlessHighScoreProvider.notifier)
                                .refresh();
                            ref.read(walletProvider.notifier).refresh();
                          }
                        });
                  },
                  onDecline: () =>
                      setState(() => _endlessSuggestionOpen = false),
                ),
              ),
          ],
```

- [ ] **Step 8: Rodar o teste e confirmar que passa**

Run: `flutter test test/features/game/presentation/endless_suggestion_flow_test.dart`
Expected: PASS

- [ ] **Step 9: Rodar a suíte inteira de widgets da fase, para regressão**

Run: `flutter test test/features/game/presentation/`
Expected: PASS (nenhum outro teste de `game_screen`/`moves_offer`/`hammer_offer` quebra)

- [ ] **Step 10: `flutter analyze` e `dart format`**

Run: `flutter analyze lib/features/game/presentation/screens/game_screen.dart && dart format lib/features/game/presentation/screens/game_screen.dart test/features/game/presentation/endless_suggestion_flow_test.dart`
Expected: `No issues found!`, e `dart format` reporta 0 ou 2 arquivos formatados sem introduzir erro.

- [ ] **Step 11: Commit**

```bash
git add lib/features/game/presentation/screens/game_screen.dart test/features/game/presentation/endless_suggestion_flow_test.dart
git commit -m "$(cat <<'EOF'
feat: liga o convite de migração para o Endless na tela da fase

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Rodada final de verificação

**Files:** nenhum arquivo novo — só execução.

**Interfaces:** nenhuma — task de verificação.

- [ ] **Step 1: Suíte completa**

Run: `flutter test`
Expected: todos os testes passam (nenhuma regressão em outras telas/notifiers).

- [ ] **Step 2: Análise estática completa**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Confirmar visualmente o fluxo (checklist manual, sem automação)**

Não há como automatizar a checagem visual do dialog num teste headless de golden sem golden file — este passo é registrar no PR/relatório final que o fluxo foi conferido rodando `flutter run` numa fase de teste com `moveLimit: 1` e verificando que o cartão aparece na 3ª derrota, com o design do `GameDialog` (cor dourada, ícone de troféu) e que "continuar tentando" revela o `LevelOutcomeCard` por trás.

- [ ] **Step 4: Commit final (se sobrar algum ajuste de formatação)**

```bash
git status
# Se houver mudanças pendentes de dart format/analyze, commitar:
git add -A
git commit -m "$(cat <<'EOF'
chore: ajustes finais de formatação do gatilho de migração para o Endless

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review Notes

- **Cobertura do spec:** contador em memória (Task 1+2), gatilho de 3 derrotas (Task 1+2), unlock check reaproveitado (Task 3), copy pt/en (Task 4), dialog no padrão `HammerOfferDialog`/`MovesOfferDialog` (Task 5+6), navegação para `EndlessScreen` (Task 6). Testes de regressão de `restartLevel`/troca de fase incluídos na Task 2.
- **Sem placeholders:** todo código é literal, nenhum "TODO"/"similar a".
- **Consistência de tipos:** `shouldOfferEndless` (GameState) → lido em `game_screen.dart` combinado com `endlessIsUnlocked(int)` (não duplicado); `markEndlessOfferShown()` (GameNotifier) chamado uma única vez, no `ref.listen`; `EndlessSuggestionDialog.onGoToEndless`/`.onDecline` batem com o uso em `game_screen.dart` na Task 6.
