# Dynamic Extra Moves (DEM) — reforço de saldo proporcional ao objetivo

Data: 2026-08-15

## Problema

O convite de reforço de saldo (`MovesOfferDialog`, gatilho pre-churn) concede
**+5 movimentos fixos**, independentemente do que a fase ainda pede. Numa fase
de dígito a um alvo do fim, cinco movimentos são esmola confortável; numa fase
de "limpe todas as pedras" com três coberturas de pé, cinco movimentos não
compram a vitória — o jogador assiste ao anúncio e perde do mesmo jeito, que é
o pior desfecho possível para um funil de recompensa.

## O que já existe e **não** muda

O funil atual já atende as regras de política do AdMob que o pedido lista, e
nenhuma delas é tocada aqui:

- **Opt-in explícito.** O anúncio só é pedido no `onPressed` do botão
  (`_watch` em `moves_offer_dialog.dart`). Nada dispara sozinho.
- **Uma vez por tentativa.** `GameState.movesOfferShown` é travado por
  `markMovesOfferShown()` (a tela) e por `grantBonusMoves()` (o crédito). Ele
  vive na partida, então recomeçar a fase devolve o convite.
- **Crédito só no callback de recompensa.** `movesAdProvider` devolve
  `Future<bool>`; `false` (fechado antes do fim, ou falha de carga) não credita
  e mantém a caixa aberta.
- **IDs de teste.** `core/ads/ad_ids.dart` segue nos IDs oficiais de teste do
  Google.

Fora de escopo por decisão explícita: pagar os movimentos com moedas
(`100 🪙`) e reabrir o cartão com o botão de anúncio desativado numa segunda
derrota. Hoje o cartão simplesmente não reabre, e isso é suficiente.

## Desenho

### 1. `GameBalanceEngine` — domínio, Dart puro

Arquivo novo: `lib/features/game/domain/game_balance_engine.dart`.

```dart
class GameBalanceEngine {
  static int calculateRewardedMoves({
    required int remainingTargets,
    int minMoves = kRewardedMinMoves,
    int maxMoves = kRewardedMaxMoves,
  }) {
    if (remainingTargets <= 0) return minMoves;
    return (remainingTargets * kMovesPerTarget).ceil().clamp(minMoves, maxMoves);
  }
}
```

Sem Flutter e sem Riverpod, pela mesma régua do `MatchEngine`: a matemática de
balanceamento é testável sem montar widget.

**`totalInitialTargets` foi removido da assinatura do spec original.** O corpo
nunca o lia. Um parâmetro exigido e ignorado é mentira de contrato — o próximo
leitor suporia que a proporção "restante sobre total" pesa no cálculo, e ela
não pesa. Se um dia pesar, ele volta com a fórmula que o usa.

### 2. Constantes em `domain/economy.dart`

`kMovesPerTarget = 3.0`, `kRewardedMinMoves = 4`, `kRewardedMaxMoves = 10`.
Vão para onde `kCoinsPerStar` e `kHammerCoinPrice` já moram, porque são números
de calibragem e vão ser recalibrados — espalhá-los como literais transformaria
o próximo ajuste em caça ao número mágico.

### 3. `GameState.rewardedMoves` — fonte única

```dart
int get rewardedMoves => GameBalanceEngine.calculateRewardedMoves(
      remainingTargets: objectiveTarget - objectiveProgress,
    );
```

`objectiveTarget - objectiveProgress` é uniforme para os três `ObjectiveType`:
peças de dígito a formar, coberturas a quebrar, coberturas restantes na
limpeza total. Não há caso especial a escrever.

O getter existe porque **o cartão anuncia o número antes de o anúncio rodar**.
UI e crédito lendo lugares diferentes divergiriam no primeiro refactor, e a
divergência apareceria como o jogo prometendo dez movimentos e pagando quatro.

### 4. Crédito e UI

- `GameNotifier.grantBonusMoves([int? amount])`: sem argumento, credita
  `state.rewardedMoves`. O parâmetro opcional continua para os testes fixarem um
  valor. As guardas atuais (fase encerrada recusa; `movesOfferShown` vira
  `true`) ficam intactas.
- `MovesOfferDialog` ganha `required this.reward`, alimentado pela `game_screen`
  com `state.rewardedMoves`, e os dois `kPreChurnReward` interpolados no texto
  (`movesOfferBody`, `movesOfferWatch`) passam a usá-lo.
- `kPreChurnReward` é **removido**. Mantê-lo deixaria um 5 morto ao lado de um
  piso de 4, e o próximo leitor não saberia qual vale.
- `kPreChurnMovesLeft` não muda: o limiar que **abre** o convite é ortogonal ao
  tamanho do prêmio.

## Testes

1. **Unitário da fórmula** (`test/features/game/domain/game_balance_engine_test.dart`):
   `0` e negativo → 4; `1` → 4 (piso, `3.0` seria menos); `2` → 6; `3` → 9;
   `4` e acima → 10 (teto).
2. **Notifier**: numa fase com N alvos restantes, `grantBonusMoves()` soma
   exatamente `state.rewardedMoves` a `bonusMoves`; fase encerrada segue
   recusando.
3. **Widget**: o número no texto do cartão é o mesmo que `bonusMoves` recebe
   depois do anúncio — é a divergência que o getter existe para impedir.
4. Os testes existentes que afirmam contra `kPreChurnReward`
   (`pre_churn_test.dart:144`, `moves_offer_test.dart:117`) passam a afirmar
   contra `state.rewardedMoves`.

## Consequência de economia, registrada de propósito

Isto não é refactor. Com `minMoves = 4`, o **pior caso fica menos generoso** que
o +5 de hoje (fase a um alvo do fim: 4 em vez de 5). Em compensação as fases de
cobertura com três unidades de pé saltam para 9–10. O saldo líquido é mover a
generosidade de onde ela não decidia nada para onde ela decide — mas é mudança
de balanceamento, e se o funil de anúncio de movimentos mudar de conversão
depois disto, a causa está aqui.
