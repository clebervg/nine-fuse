# Dynamic Extra Moves (DEM) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Substituir os +5 movimentos fixos do anúncio de reforço de saldo por um valor calculado a partir das metas que a fase ainda pede.

**Architecture:** Uma função pura nova (`GameBalanceEngine.calculateRewardedMoves`) no domínio, três constantes de calibragem em `domain/economy.dart`, e um getter `GameState.rewardedMoves` que serve de **fonte única** para dois consumidores: o texto do convite (`MovesOfferDialog`) e o crédito (`GameNotifier.grantBonusMoves`). Nada no funil de anúncio muda — opt-in, uma-vez-por-tentativa e crédito-só-no-callback já existem e ficam intactos.

**Tech Stack:** Dart / Flutter, Riverpod, `flutter_test`.

## Global Constraints

- Comentários e nomes de teste em **português**, no tom do repositório (explicar *por que*, não *o quê*).
- `kMovesPerTarget = 3.0`, `kRewardedMinMoves = 4`, `kRewardedMaxMoves = 10` — valores exatos, em `lib/features/game/domain/economy.dart`.
- `kPreChurnMovesLeft = 2` **não muda**.
- `kPreChurnReward` é **removido** ao fim do plano; nenhum arquivo pode continuar a referenciá-lo.
- `GameBalanceEngine` não pode importar Flutter nem Riverpod.
- Rodar `flutter analyze` limpo antes de cada commit.
- Não tocar em `AdIds`, `RewardedAdService`, `movesAdProvider`, nem em `shouldOfferMoves`.

---

### Task 1: `GameBalanceEngine` e as constantes de calibragem

**Files:**
- Create: `lib/features/game/domain/game_balance_engine.dart`
- Modify: `lib/features/game/domain/economy.dart` (acrescentar ao fim)
- Test: `test/features/game/domain/game_balance_engine_test.dart`

**Interfaces:**
- Consumes: nada.
- Produces: `GameBalanceEngine.calculateRewardedMoves({required int remainingTargets, int minMoves, int maxMoves}) -> int`; as constantes `const double kMovesPerTarget`, `const int kRewardedMinMoves`, `const int kRewardedMaxMoves`.

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/features/game/domain/game_balance_engine_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/domain/game_balance_engine.dart';

void main() {
  group('quanto o anúncio de movimentos paga', () {
    test('objetivo já cumprido cai no piso, e não em zero', () {
      // Não deve acontecer (o convite exige objetivo em aberto), mas uma
      // fórmula que devolvesse zero transformaria um anúncio assistido em
      // prêmio nenhum — o pior desfecho possível para o funil.
      expect(
        GameBalanceEngine.calculateRewardedMoves(remainingTargets: 0),
        kRewardedMinMoves,
      );
      expect(
        GameBalanceEngine.calculateRewardedMoves(remainingTargets: -3),
        kRewardedMinMoves,
      );
    });

    test('um alvo restante ainda cai no piso', () {
      // 3.0 * 1 = 3, abaixo do piso de 4: o multiplicador só começa a mandar
      // de dois alvos em diante. É consequência dos números calibrados, e o
      // teste existe para que trocá-los seja uma decisão, não um acidente.
      expect(
        GameBalanceEngine.calculateRewardedMoves(remainingTargets: 1),
        kRewardedMinMoves,
      );
    });

    test('a faixa do meio escala a três movimentos por alvo', () {
      expect(GameBalanceEngine.calculateRewardedMoves(remainingTargets: 2), 6);
      expect(GameBalanceEngine.calculateRewardedMoves(remainingTargets: 3), 9);
    });

    test('o teto trava o prêmio antes de ele virar a fase inteira', () {
      expect(
        GameBalanceEngine.calculateRewardedMoves(remainingTargets: 4),
        kRewardedMaxMoves,
      );
      expect(
        GameBalanceEngine.calculateRewardedMoves(remainingTargets: 40),
        kRewardedMaxMoves,
      );
    });

    test('a faixa pode ser estreitada por quem chama', () {
      // Os limites são parâmetros para o teste poder fixar uma faixa sem
      // depender da calibragem vigente.
      expect(
        GameBalanceEngine.calculateRewardedMoves(
          remainingTargets: 3,
          minMoves: 1,
          maxMoves: 5,
        ),
        5,
      );
    });
  });
}
```

- [ ] **Step 2: Rodar o teste e ver falhar**

Run: `flutter test test/features/game/domain/game_balance_engine_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'nine_fuse/features/game/domain/game_balance_engine.dart'` / `Undefined name 'kRewardedMinMoves'`.

- [ ] **Step 3: Acrescentar as constantes ao fim de `economy.dart`**

```dart
/// Movimentos pagos por **alvo restante** no anúncio de reforço de saldo.
///
/// O prêmio fixo que este número substitui era esmola numa fase a um alvo do
/// fim e insuficiente numa fase de cobertura com três pedras de pé — o jogador
/// assistia ao anúncio e perdia do mesmo jeito, que é o que ensina a não
/// assistir ao próximo.
const double kMovesPerTarget = 3.0;

/// Piso do prêmio. Abaixo disto o anúncio não muda desfecho nenhum, e um
/// prêmio que não muda o desfecho é pior do que não ter sido oferecido.
const int kRewardedMinMoves = 4;

/// Teto do prêmio. Sem ele uma fase de objetivo alto renderia meia fase nova
/// por um vídeo, e o limite de movimentos deixaria de significar alguma coisa.
const int kRewardedMaxMoves = 10;
```

- [ ] **Step 4: Criar `game_balance_engine.dart`**

```dart
import 'package:nine_fuse/features/game/domain/economy.dart';

/// A matemática de balanceamento das recompensas, fora do estado e fora da UI.
///
/// Dart puro, sem Flutter e sem Riverpod, pela mesma régua do `MatchEngine`:
/// o número que o jogo paga é regra, e regra se testa sem montar widget.
class GameBalanceEngine {
  const GameBalanceEngine._();

  /// Quantos movimentos o anúncio de reforço de saldo paga, dado o que a fase
  /// ainda pede.
  ///
  /// [remainingTargets] é uniforme para os três tipos de objetivo: peças de
  /// dígito a formar, coberturas a quebrar, coberturas restantes na limpeza
  /// total. Não há caso especial porque `objectiveTarget - objectiveProgress`
  /// já significa a mesma coisa nos três.
  ///
  /// O piso cobre o caso degenerado (objetivo cumprido ou contagem negativa
  /// por tabuleiro montado à mão): devolver zero ali pagaria nada por um
  /// anúncio assistido até o fim.
  static int calculateRewardedMoves({
    required int remainingTargets,
    int minMoves = kRewardedMinMoves,
    int maxMoves = kRewardedMaxMoves,
  }) {
    if (remainingTargets <= 0) return minMoves;
    return (remainingTargets * kMovesPerTarget).ceil().clamp(
      minMoves,
      maxMoves,
    );
  }
}
```

- [ ] **Step 5: Rodar o teste e ver passar**

Run: `flutter test test/features/game/domain/game_balance_engine_test.dart`
Expected: PASS — `+5: All tests passed!`

- [ ] **Step 6: Analisar e commitar**

```bash
flutter analyze
git add lib/features/game/domain/game_balance_engine.dart lib/features/game/domain/economy.dart test/features/game/domain/game_balance_engine_test.dart
git commit -m "feat: GameBalanceEngine calcula o prêmio de movimentos por alvo restante"
```

---

### Task 2: `GameState.rewardedMoves` — a fonte única

**Files:**
- Modify: `lib/features/game/providers/game_state.dart` (novo getter junto de `objectiveFraction`, por volta da linha 232)
- Test: `test/features/game/providers/pre_churn_test.dart` (acrescentar grupo)

**Interfaces:**
- Consumes: `GameBalanceEngine.calculateRewardedMoves` (Task 1).
- Produces: `int get GameState.rewardedMoves`.

- [ ] **Step 1: Escrever o teste que falha**

Acrescentar ao fim de `main()` em `test/features/game/providers/pre_churn_test.dart`, **antes** do último `}`:

```dart
  group('o prêmio acompanha o que a fase ainda pede', () {
    test('objetivo alto paga o teto', () {
      // `notifierWith` usa objetivo 99 por padrão: muito acima do teto, então
      // o prêmio é o máximo. É o caso que as fases geradas mais produzem.
      final notifier = notifierWith(moveLimit: 20);

      expect(notifier.state.rewardedMoves, kRewardedMaxMoves);
    });

    test('dois alvos restantes pagam seis', () {
      final notifier = notifierWith(moveLimit: 20, objective: 2);

      expect(notifier.state.rewardedMoves, 6);
    });

    test('um alvo restante paga o piso', () {
      final notifier = notifierWith(moveLimit: 20, objective: 1);

      expect(notifier.state.rewardedMoves, kRewardedMinMoves);
    });
  });
```

E acrescentar o import no topo do arquivo:

```dart
import 'package:nine_fuse/features/game/domain/economy.dart';
```

- [ ] **Step 2: Rodar o teste e ver falhar**

Run: `flutter test test/features/game/providers/pre_churn_test.dart`
Expected: FAIL — `The getter 'rewardedMoves' isn't defined for the class 'GameState'`.

- [ ] **Step 3: Implementar o getter**

Em `lib/features/game/providers/game_state.dart`, acrescentar logo abaixo de `objectiveFraction`:

```dart
  /// Quantos movimentos o anúncio de reforço de saldo paga **nesta fase**.
  ///
  /// Existe como getter — e não como cálculo na tela ou no crédito — porque o
  /// cartão anuncia o número **antes** de o anúncio rodar. Dois consumidores
  /// lendo lugares diferentes divergiriam no primeiro refactor, e a divergência
  /// apareceria como o jogo prometendo dez movimentos e pagando quatro.
  int get rewardedMoves => GameBalanceEngine.calculateRewardedMoves(
    remainingTargets: objectiveTarget - objectiveProgress,
  );
```

E o import no topo do arquivo:

```dart
import 'package:nine_fuse/features/game/domain/game_balance_engine.dart';
```

- [ ] **Step 4: Rodar o teste e ver passar**

Run: `flutter test test/features/game/providers/pre_churn_test.dart`
Expected: PASS — todos os testes do arquivo, incluindo os três novos.

- [ ] **Step 5: Analisar e commitar**

```bash
flutter analyze
git add lib/features/game/providers/game_state.dart test/features/game/providers/pre_churn_test.dart
git commit -m "feat: GameState.rewardedMoves como fonte única do prêmio de movimentos"
```

---

### Task 3: `grantBonusMoves` credita o valor dinâmico

**Files:**
- Modify: `lib/features/game/providers/game_notifier.dart:160` (assinatura e corpo de `grantBonusMoves`)
- Test: `test/features/game/providers/pre_churn_test.dart:134-152` (grupo "o que o anúncio paga")

**Interfaces:**
- Consumes: `GameState.rewardedMoves` (Task 2).
- Produces: `void GameNotifier.grantBonusMoves([int? amount])` — sem argumento, credita `state.rewardedMoves`.

- [ ] **Step 1: Reescrever o teste existente para falhar**

Em `test/features/game/providers/pre_churn_test.dart`, no grupo `'o que o anúncio paga'`, substituir o primeiro teste inteiro por:

```dart
    test('o prêmio soma ao saldo sem apagar as jogadas já feitas', () {
      final notifier = notifierWith(moveLimit: kPreChurnMovesLeft + 1);
      notifier.debugSetBoard(_boardWithTrio(5));
      _playTrio(notifier.swapTiles);

      final movesBefore = notifier.state.moves;
      final reward = notifier.state.rewardedMoves;
      notifier.grantBonusMoves();

      expect(notifier.state.movesLeft, kPreChurnMovesLeft + reward);
      expect(
        notifier.state.moves,
        movesBefore,
        reason: 'o prêmio apagou jogadas feitas em vez de somar ao limite',
      );
    });

    test('o prêmio creditado é o que o estado anunciava', () {
      // A garantia que o getter existe para dar: o número que o cartão mostra
      // e o número que entra em `bonusMoves` são o mesmo.
      final notifier = notifierWith(moveLimit: 20, objective: 2);
      notifier.debugSetBoard(_boardWithTrio(5));
      _playTrio(notifier.swapTiles);

      final announced = notifier.state.rewardedMoves;
      final bonusBefore = notifier.state.bonusMoves;
      notifier.grantBonusMoves();

      expect(announced, 6);
      expect(notifier.state.bonusMoves, bonusBefore + announced);
    });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/game/providers/pre_churn_test.dart`
Expected: FAIL no teste `'o prêmio creditado é o que o estado anunciava'` — `Expected: 6 Actual: 5` (o crédito ainda usa o `kPreChurnReward` fixo). O primeiro teste passa por acaso quando `rewardedMoves` for 10 e o fixo 5? Não: ele lê `reward` do estado, então também falha (`Expected: 12 Actual: 7`).

- [ ] **Step 3: Implementar**

Em `lib/features/game/providers/game_notifier.dart`, trocar a assinatura e a primeira linha do corpo de `grantBonusMoves`:

```dart
  /// Credita o prêmio do anúncio de reforço de saldo.
  ///
  /// Sem [amount], paga [GameState.rewardedMoves] — o mesmo número que o
  /// convite anunciou na tela. O parâmetro continua existindo para os testes
  /// fixarem um valor sem depender da calibragem vigente.
  ///
  /// Entra em [GameState.bonusMoves], e não descontando de `moves`, pela mesma
  /// razão do bônus do dígito máximo: `moves` é "quantas jogadas o jogador
  /// fez", e é isso que o cartão de fim de fase relata.
  ///
  /// A fase encerrada recusa. O cartão de desfecho já está no ar, e creditar
  /// movimentos aqui deixaria o jogador com saldo numa fase que acabou — sem
  /// contar que a regra anti-churn não vende nada na tela de derrota.
  void grantBonusMoves([int? amount]) {
    if (state.status != GameStatus.playing) return;
    state = state.copyWith(
      bonusMoves: state.bonusMoves + (amount ?? state.rewardedMoves),
      // O convite se fecha por ter sido pago, e não só por ter sido mostrado:
      // sem isto ele reabriria assim que o saldo voltasse ao limiar.
      movesOfferShown: true,
    );
  }
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/game/providers/pre_churn_test.dart`
Expected: PASS — todos.

- [ ] **Step 5: Analisar e commitar**

```bash
flutter analyze
git add lib/features/game/providers/game_notifier.dart test/features/game/providers/pre_churn_test.dart
git commit -m "feat: grantBonusMoves credita o prêmio dinâmico do DEM"
```

---

### Task 4: O convite anuncia o mesmo número, e `kPreChurnReward` some

**Files:**
- Modify: `lib/features/game/presentation/widgets/moves_offer_dialog.dart` (campo novo; linhas 110 e 125)
- Modify: `lib/features/game/presentation/screens/game_screen.dart:353` (passar `reward:`)
- Modify: `lib/features/game/providers/game_state.dart:30-36` (remover `kPreChurnReward`)
- Test: `test/features/game/presentation/moves_offer_test.dart:117`

**Interfaces:**
- Consumes: `GameState.rewardedMoves` (Task 2), `GameNotifier.grantBonusMoves()` (Task 3).
- Produces: `MovesOfferDialog({required int movesLeft, required int reward, required VoidCallback onGranted, required VoidCallback onDecline})`. `kPreChurnReward` deixa de existir.

- [ ] **Step 1: Reescrever o teste de widget para falhar**

Em `test/features/game/presentation/moves_offer_test.dart`, no teste `'assistir ao anúncio credita os movimentos e fecha o convite'`, substituir o corpo por:

```dart
    await pumpGame(tester, ad: () async => true);
    await reachThreshold(tester);

    final before = notifier.state.movesLeft;
    final reward = notifier.state.rewardedMoves;

    // O número que o cartão promete tem de ser o que o crédito paga: é a
    // divergência que `rewardedMoves` existe para impedir.
    expect(find.textContaining('$reward'), findsWidgets);

    await tester.tap(find.byKey(movesOfferWatchKey));
    await tester.pumpAndSettle();

    expect(notifier.state.movesLeft, before + reward);
    expect(find.byKey(movesOfferKey), findsNothing);
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/game/presentation/moves_offer_test.dart`
Expected: FAIL — `Expected: <12> Actual: <7>` (a fase de teste pede `count: 99`, então `rewardedMoves` é 10 e o crédito ainda é 5).

- [ ] **Step 3: Dar o campo `reward` ao diálogo**

Em `lib/features/game/presentation/widgets/moves_offer_dialog.dart`:

Acrescentar ao construtor e à classe:

```dart
  const MovesOfferDialog({
    super.key,
    required this.movesLeft,
    required this.reward,
    required this.onGranted,
    required this.onDecline,
  });
```

```dart
  /// Quantos movimentos o anúncio paga. Vem de `GameState.rewardedMoves`, e
  /// não de uma constante: o cartão não pode prometer um número diferente do
  /// que o crédito soma.
  final int reward;
```

Trocar as duas interpolações:

```dart
            l10n.movesOfferBody(widget.movesLeft, widget.reward),
```

```dart
            label: l10n.movesOfferWatch(widget.reward),
```

E remover o import de `game_state.dart` **apenas se** nada mais no arquivo o usar — o doc-comment da classe cita `kPreChurnMovesLeft`; trocar essa citação por texto simples (`o limiar de movimentos`) e remover o import.

- [ ] **Step 4: Passar o valor na tela**

Em `lib/features/game/presentation/screens/game_screen.dart`, no `MovesOfferDialog`:

```dart
                child: MovesOfferDialog(
                  movesLeft: state.movesLeft,
                  reward: state.rewardedMoves,
                  onGranted: () {
                    ref.read(gameProvider.notifier).grantBonusMoves();
                    setState(() => _movesOfferOpen = false);
                  },
                  onDecline: () => setState(() => _movesOfferOpen = false),
                ),
```

- [ ] **Step 5: Remover `kPreChurnReward`**

Em `lib/features/game/providers/game_state.dart`, apagar o doc-comment e a declaração:

```dart
/// Movimentos pagos pelo anúncio do reforço de saldo.
///
/// Cinco é mais do que os dois que restavam: ...
const int kPreChurnReward = 5;
```

Confirmar que não sobrou referência:

Run: `grep -rn "kPreChurnReward" lib test`
Expected: nenhuma saída.

- [ ] **Step 6: Rodar a suíte inteira**

Run: `flutter analyze && flutter test`
Expected: analyze sem issues; todos os testes passam.

- [ ] **Step 7: Commitar**

```bash
git add lib/features/game/presentation/widgets/moves_offer_dialog.dart lib/features/game/presentation/screens/game_screen.dart lib/features/game/providers/game_state.dart test/features/game/presentation/moves_offer_test.dart
git commit -m "feat: o convite de movimentos anuncia o prêmio dinâmico"
```

---

### Task 5: Registrar a decisão no CLAUDE.md

**Files:**
- Modify: `CLAUDE.md` (nova seção ao fim, antes de nada mais)

**Interfaces:**
- Consumes: tudo das Tasks 1-4.
- Produces: nada de código.

- [ ] **Step 1: Acrescentar a seção ao fim do `CLAUDE.md`**

```markdown
### Dynamic Extra Moves (DEM) ✅

**O prêmio do anúncio deixou de ser fixo porque um número fixo estava errado
nas duas pontas.** +5 numa fase a um alvo do fim é esmola confortável; +5 numa
fase de "limpe todas as pedras" com três coberturas de pé não compra a vitória —
o jogador assiste ao anúncio, perde mesmo assim, e aprende a não assistir ao
próximo. `GameBalanceEngine.calculateRewardedMoves` escala a
`kMovesPerTarget = 3.0` por alvo restante, entre `kRewardedMinMoves = 4` e
`kRewardedMaxMoves = 10`.

**`totalInitialTargets` foi removido da assinatura pedida no spec.** O corpo
nunca o lia. Parâmetro exigido e ignorado é mentira de contrato: o próximo
leitor suporia que a proporção "restante sobre total" pesa no cálculo. Se um
dia pesar, ele volta junto com a fórmula que o usa.

**`GameState.rewardedMoves` existe porque o cartão anuncia o número antes de o
anúncio rodar.** UI e crédito lendo lugares diferentes divergiriam no primeiro
refactor, e a divergência apareceria como o jogo prometendo dez movimentos e
pagando quatro. Um getter, dois consumidores. `grantBonusMoves()` sem argumento
lê o mesmo getter; o parâmetro opcional sobreviveu só para os testes fixarem
valor sem depender da calibragem.

**`remainingTargets` é `objectiveTarget - objectiveProgress`, sem caso
especial.** Os três `ObjectiveType` já significam a mesma coisa nessa conta:
peças de dígito a formar, coberturas a quebrar, coberturas restantes na limpeza
total.

**Um alvo restante paga o piso (4), e não 3.** `3.0 * 1` fica abaixo do piso, ou
seja o multiplicador só manda de dois alvos em diante. É consequência dos
números calibrados, não descuido — há teste travando o degrau para que trocá-lo
seja decisão.

**Isto é mudança de economia, não refactor.** O pior caso ficou **menos**
generoso que o +5 de antes (fase a um alvo do fim: 4). As fases de cobertura com
três unidades de pé saltaram para 9-10. Se a conversão do funil de movimentos
mudar, a causa está aqui. `kPreChurnReward` foi removido para não deixar um 5
morto competindo com o piso de 4; `kPreChurnMovesLeft` (o limiar que **abre** o
convite) não foi tocado — é ortogonal ao tamanho do prêmio.

**Nada do funil de anúncio mudou, e é o que atende a política do AdMob:**
opt-in por clique (`_watch` no `onPressed`), uma vez por tentativa
(`movesOfferShown`), crédito só quando o `Future<bool>` volta `true`, IDs de
teste em `core/ads/ad_ids.dart`. Continuam fora de escopo, por decisão: pagar
os movimentos com moedas e reabrir o cartão com o botão de anúncio desativado
numa segunda derrota.
```

- [ ] **Step 2: Commitar**

```bash
git add CLAUDE.md
git commit -m "docs: registra as decisões do Dynamic Extra Moves"
```

---

## Auto-revisão do plano

- **Cobertura do spec:** seção 1 (`GameBalanceEngine`) → Task 1; seção 2 (constantes) → Task 1; seção 3 (`rewardedMoves`) → Task 2; seção 4 (crédito) → Task 3, (UI + remoção de `kPreChurnReward`) → Task 4; testes 1-4 do spec → Tasks 1, 2, 3, 4 respectivamente; "consequência de economia" → Task 5.
- **Placeholders:** nenhum. Todo passo que muda código mostra o código.
- **Consistência de tipos:** `calculateRewardedMoves({remainingTargets, minMoves, maxMoves}) -> int` é usada com esses nomes nas Tasks 1 e 2; `rewardedMoves` é getter `int` nas Tasks 2, 3 e 4; `grantBonusMoves([int? amount])` é chamada sem argumento nas Tasks 3 e 4.
