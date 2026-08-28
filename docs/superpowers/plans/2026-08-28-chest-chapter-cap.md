# Teto no baú de capítulo (`claimChapterChest`) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Impedir que `WalletNotifier.claimChapterChest` pague moeda além do
capítulo 20, travando a impressão infinita de `kChapterChestReward` que a
campanha gerada (infinita) hoje permite.

**Architecture:** Uma constante nova (`kChapterChestPayableCount = 20`) em
`economy.dart`, e uma guarda de uma linha no topo de `claimChapterChest`
que devolve `false` sem tocar em estado nem em disco para qualquer
capítulo acima do teto. Nenhuma UI é criada ou modificada nesta task.

**Tech Stack:** Dart / Flutter, `flutter_test` (sem widgets envolvidos —
teste puro de `WalletNotifier` com `InMemoryGameStorage`).

## Global Constraints

- Teto: `kChapterChestPayableCount = 20` (capítulos 1-20 pagam; 21+ não
  pagam nada). Regra de borda é `>`, não `>=` — capítulo 20 ainda paga.
- Nenhuma migração de dados: jogo não lançado, sem baú em produção, sem
  capítulo além de 20 persistido em disco de jogador real.
- Fora de escopo: qualquer UI de baú (mapa da saga, indicador, botão).

---

### Task 1: Constante `kChapterChestPayableCount`

**Files:**
- Modify: `lib/features/game/domain/economy.dart`

**Interfaces:**
- Consumes: nada.
- Produces: `const int kChapterChestPayableCount` — usada pela Task 2.

- [ ] **Step 1: Adicionar a constante**

Adicione, logo abaixo de `kChapterChestReward` (linha 23) em
`lib/features/game/domain/economy.dart`:

```dart
/// O que o baú de fim de capítulo paga, uma única vez por capítulo.
const int kChapterChestReward = 200;

/// Último capítulo que ainda paga baú. Acima disto, `claimChapterChest`
/// não credita nada — sem este teto, a campanha gerada (infinita, Fase
/// 15) imprimiria moeda para sempre, um capítulo de cada vez.
///
/// Capítulos 1-2 são os artesanais (fases 1-10); capítulos 3-20 são os
/// primeiros 18 capítulos gerados (10 fases cada, `kBlockSize` em
/// `level_generator.dart`) — cobre até a fase ~190. Teto de moeda
/// vitalícia via baú: 20 * kChapterChestReward = 4000.
const int kChapterChestPayableCount = 20;
```

Não há teste isolado para uma constante — ela é exercitada pelos testes
da Task 2.

- [ ] **Step 2: Commit**

```bash
git add lib/features/game/domain/economy.dart
git commit -m "feat: adiciona kChapterChestPayableCount, teto de capítulos que pagam baú"
```

---

### Task 2: Guarda em `claimChapterChest`

**Files:**
- Modify: `lib/features/game/providers/wallet.dart:103-118`
- Test: `test/features/game/providers/wallet_test.dart`

**Interfaces:**
- Consumes: `kChapterChestPayableCount` da Task 1.
- Produces: `WalletNotifier.claimChapterChest(int chapter) -> bool`
  (assinatura inalterada) agora devolve `false` sem efeito colateral
  algum para `chapter > kChapterChestPayableCount`.

- [ ] **Step 1: Escrever os três testes falhando**

Em `test/features/game/providers/wallet_test.dart`, adicione estes três
testes logo depois do teste `'baús de capítulos diferentes pagam cada
um'` (linha 81, antes do teste `'falha de disco vale como saldo vazio,
sem propagar'`):

```dart
    test('capítulo acima do teto não paga', () async {
      final storage = InMemoryGameStorage();
      final wallet = WalletNotifier(storage: storage);
      await wallet.refresh();

      expect(
        wallet.claimChapterChest(kChapterChestPayableCount + 1),
        isFalse,
      );
      expect(wallet.state.coins, 0);
      expect(
        wallet.state.hasClaimedChest(kChapterChestPayableCount + 1),
        isFalse,
      );
    });

    test('capítulo exatamente no teto ainda paga', () async {
      final storage = InMemoryGameStorage();
      final wallet = WalletNotifier(storage: storage);
      await wallet.refresh();

      expect(wallet.claimChapterChest(kChapterChestPayableCount), isTrue);
      expect(wallet.state.coins, kChapterChestReward);
    });

    test(
      'claimedChests nunca cresce além do teto, mesmo tentando vários '
      'capítulos futuros em sequência',
      () async {
        final storage = InMemoryGameStorage();
        final wallet = WalletNotifier(storage: storage);
        await wallet.refresh();

        for (
          var chapter = kChapterChestPayableCount + 1;
          chapter <= kChapterChestPayableCount + 20;
          chapter++
        ) {
          wallet.claimChapterChest(chapter);
        }

        expect(wallet.state.coins, 0);
        expect(wallet.state.claimedChests, isEmpty);
      },
    );
```

- [ ] **Step 2: Rodar os testes e confirmar que falham**

Run: `flutter test test/features/game/providers/wallet_test.dart --plain-name "teto"`

Expected: os três testes novos falham. `'capítulo acima do teto não
paga'` e o teste de crescimento falham porque `claimChapterChest` hoje
paga qualquer capítulo (`wallet.state.coins` vem `200`/`4000`, não `0`).
`'capítulo exatamente no teto ainda paga'` deve **passar** já — é só a
constante sendo usada para expressar um caso que já funciona (sem
mudança de comportamento nele); confirme que os outros dois efetivamente
falham antes de seguir.

- [ ] **Step 3: Implementar a guarda**

Em `lib/features/game/providers/wallet.dart`, mude o método (linhas
102-118):

```dart
  /// Paga o baú de [chapter], uma vez só. Devolve se pagou agora.
  ///
  /// Capítulo acima de `kChapterChestPayableCount` nunca paga — sem essa
  /// guarda, a campanha gerada (infinita) imprimiria moeda para sempre.
  /// Como esses capítulos nunca entram em `claimedChests`, o Set também
  /// fica naturalmente limitado ao teto, sem precisar de poda.
  bool claimChapterChest(int chapter) {
    if (chapter > kChapterChestPayableCount) return false;
    if (state.hasClaimedChest(chapter)) return false;

    final chests = {...state.claimedChests, chapter};
    state = state.copyWith(
      coins: state.coins + kChapterChestReward,
      claimedChests: chests,
    );
    // Baú primeiro, moeda depois: se só uma gravação for a sobreviver de uma
    // falha de disco, que seja a marca de "já reclamado" — assim o pior caso é
    // o jogador perder a moeda desta vez, não o baú repagar toda sessão que
    // reabrir o mapa (torneira infinita).
    _persistChests(chests);
    _persistCoins();
    return true;
  }
```

- [ ] **Step 4: Rodar os testes e confirmar que passam**

Run: `flutter test test/features/game/providers/wallet_test.dart`

Expected: todos os testes do arquivo passam (os 6 pré-existentes + os 3
novos), sem warnings.

- [ ] **Step 5: Rodar a suíte inteira e o analyzer**

Run: `flutter test`
Expected: todos os testes do projeto passam (nenhuma outra suíte
referencia `claimChapterChest`, então nenhuma regressão é esperada fora
de `wallet_test.dart`).

Run: `flutter analyze lib/features/game/domain/economy.dart lib/features/game/providers/wallet.dart test/features/game/providers/wallet_test.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/game/providers/wallet.dart test/features/game/providers/wallet_test.dart
git commit -m "fix: claimChapterChest para de pagar acima de kChapterChestPayableCount"
```

---

## Self-Review

**Spec coverage:**
- Constante `kChapterChestPayableCount = 20` → Task 1. ✓
- Guarda `chapter > kChapterChestPayableCount` → Task 2, Step 3. ✓
- `Set` limitado ao teto por construção (sem persistir capítulos acima
  do teto) → Task 2, Step 3 (comentário + comportamento) e verificado
  pelo teste de crescimento no Step 1. ✓
- Três testes do spec (acima do teto, exatamente no teto, Set não
  cresce) → Task 2, Step 1. ✓
- Fora de escopo (UI de baú) → nenhuma task toca UI. ✓

**Placeholder scan:** nenhum "TBD"/"depois"/"similar à Task N" — todo
código está completo em cada step.

**Type consistency:** `claimChapterChest(int chapter) -> bool` idêntico
em todas as tasks e ao método existente; `kChapterChestPayableCount` é
`int` em todo lugar que aparece.
