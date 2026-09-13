# Economia de Resgate, Boosters Pagos e Ritmo de Dificuldade — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adicionar um segundo convite de resgate (+5 movimentos) ao zerar o saldo na campanha, permitir comprar Bomba/Pincel direto no tabuleiro com moedas (Modo Fantasma, como o Martelo já faz), uma mini-loja no cartão de início de fase, e intercalar fases "hard" no gerador procedural a partir do nível 30.

**Architecture:** Segue os padrões já estabelecidos no projeto: mixins irmãos (`HammerBooster`/`BombBooster`/`BrushBooster`) para regra de boosters compartilhada entre campanha e Endless; diálogos "sibling" (copiados e adaptados, não generalizados) para cada convite de aquisição, seguindo a decisão de projeto já registrada de que mecânicas divergentes não devem ser fundidas num tipo genérico; `GameState`/`GameNotifier` continuam sendo a única fonte de verdade da partida, com a UI (`game_screen.dart`/`endless_screen.dart`) responsável por marcar convites como "mostrados". O gerador de fases (`level_generator.dart`) continua função pura sobre o número da fase.

**Tech Stack:** Dart / Flutter, Riverpod (`flutter_riverpod`), `flutter_test` + `flutter_riverpod` test helpers, ARB para l10n (pt/en).

## Global Constraints

- Toda mudança de economia usa constantes nomeadas em `lib/features/game/domain/economy.dart` — nunca literais soltos na UI/providers (regra já estabelecida no projeto).
- Nenhum item pago pode ser cobrado duas vezes por um único evento (mesma trava `_waiting`/`if (_waiting) return;` já usada em `HammerOfferDialog`).
- Boosters não gastam movimento e não geram evolução de número (regra já vigente para Martelo/Bomba/Pincel — não muda).
- `generateLevel(n)` continua função pura sobre `n` — sem estado de partida, sem histórico de jogo.
- `dart run tool/simulate_economy.dart --mode=generated` deve ser rodado para calibrar o limite de movimentos das fases hard antes de fechar a Task 8 — nunca escolher o número a olho.
- `flutter analyze` e `flutter test` devem estar verdes ao final de cada task.
- Textos de UI só existem via `AppLocalizations` (ARB pt + en) — nunca strings soltas nos widgets.
- Commits seguem o padrão observado no repositório (mensagem curta, foco no "porquê"), com a assinatura:
  `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`

---

## Parte A — Continue Offer (resgate ao zerar movimentos, só campanha)

### Task 1: `GameState.continueOfferShown` + `GameNotifier.grantContinueMoves`

**Files:**
- Modify: `lib/features/game/domain/economy.dart`
- Modify: `lib/features/game/providers/game_state.dart`
- Modify: `lib/features/game/providers/game_notifier.dart`
- Test: `test/features/game/providers/game_notifier_test.dart`
- Test: `test/features/game/providers/game_state_test.dart`

**Interfaces:**
- Consumes: `GameState` (`status`, `lossReason`, `bonusMoves`, `copyWith`), `LossReason.moveLimitReached` (já existe em `game_state.dart`).
- Produces: `const int kContinueBonusMoves = 5;` e `const int kContinueCoinPrice = 100;` em `economy.dart`; `GameState.continueOfferShown` (bool, default `false`); `GameState.shouldOfferContinue` (getter bool); `GameNotifier.grantContinueMoves()` (void); `GameNotifier.markContinueOfferShown()` (void).

- [ ] **Step 1: Escrever o teste de `shouldOfferContinue` e `grantContinueMoves`**

```dart
// test/features/game/providers/game_notifier_test.dart (novo grupo, no fim do arquivo)
group('Continue Offer', () {
  test('shouldOfferContinue é verdadeiro só quando perdeu por falta de movimentos e ainda não foi mostrado', () {
    final notifier = GameNotifier(storage: InMemoryGameStorage());
    notifier.startLevel(const GameLevel(
      number: 500,
      objective: Objective(digit: 9, count: 6),
      moveLimit: 1,
      spawnMin: 0,
      spawnMax: 3,
      obstacles: ObstacleLayout.none,
    ));
    // Uma troca qualquer que não forme combinação esgota o único movimento
    // sem cumprir o objetivo — usa o hint do motor para garantir uma troca
    // válida que não vença a fase (objetivo pede o dígito 9).
    final hint = notifier.state.hint!;
    notifier.swapTiles(hint.$1, hint.$2);

    expect(notifier.state.status, GameStatus.lost);
    expect(notifier.state.lossReason, LossReason.moveLimitReached);
    expect(notifier.state.shouldOfferContinue, isTrue);
  });

  test('grantContinueMoves credita +5 e revive a fase', () {
    final notifier = GameNotifier(storage: InMemoryGameStorage());
    notifier.startLevel(const GameLevel(
      number: 500,
      objective: Objective(digit: 9, count: 6),
      moveLimit: 1,
      spawnMin: 0,
      spawnMax: 3,
      obstacles: ObstacleLayout.none,
    ));
    final hint = notifier.state.hint!;
    notifier.swapTiles(hint.$1, hint.$2);
    expect(notifier.state.status, GameStatus.lost);

    notifier.grantContinueMoves();

    expect(notifier.state.status, GameStatus.playing);
    expect(notifier.state.lossReason, isNull);
    expect(notifier.state.bonusMoves, kContinueBonusMoves);
    expect(notifier.state.continueOfferShown, isTrue);
    expect(notifier.state.shouldOfferContinue, isFalse);
  });

  test('grantContinueMoves não faz nada se a fase não estiver perdida por falta de movimentos', () {
    final notifier = GameNotifier(storage: InMemoryGameStorage());
    notifier.startLevel(levelAt(1));
    notifier.grantContinueMoves();
    expect(notifier.state.status, GameStatus.playing);
    expect(notifier.state.bonusMoves, 0);
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/game/providers/game_notifier_test.dart`
Expected: FAIL — `shouldOfferContinue`, `grantContinueMoves`, `continueOfferShown`, `kContinueBonusMoves` não existem.

- [ ] **Step 3: Adicionar as constantes em `economy.dart`**

```dart
// lib/features/game/domain/economy.dart — no fim do arquivo

/// Movimentos pagos pelo resgate de derrota (Continue Offer).
///
/// Fixo, e não escalado por alvo restante como o [kMovesPerTarget] do
/// reforço de saldo pre-churn: este convite só aparece uma vez, depois da
/// fase já ter sido perdida — não há mais "quanto falta" para escalar contra,
/// só a decisão de tentar mais cinco movimentos ou aceitar a derrota.
const int kContinueBonusMoves = 5;

/// Preço em moedas do resgate de derrota, quando o jogador não quer assistir
/// ao vídeo. Mesmo preço do Martelo — mesma ordem de grandeza de "um item
/// avulso caro".
const int kContinueCoinPrice = 100;
```

- [ ] **Step 4: Adicionar `continueOfferShown` a `GameState`**

Em `lib/features/game/providers/game_state.dart`, no construtor (perto de `movesOfferShown`):

```dart
    this.movesOfferShown = false,
    this.continueOfferShown = false,
```

Novo campo, logo após `movesOfferShown`:

```dart
  /// O convite de resgate de derrota (Continue Offer) já foi mostrado nesta
  /// partida. Mesmo papel de [movesOfferShown]: sem a trava,
  /// [shouldOfferContinue] continuaria verdadeiro a cada nova checagem depois
  /// de recusado, e o convite reabriria sozinho.
  final bool continueOfferShown;
```

Novo getter, logo após `shouldOfferMoves`:

```dart
  /// A fase acabou de perder por falta de movimentos, e o jogador ainda não
  /// viu o resgate?
  ///
  /// Só [LossReason.moveLimitReached] — um tabuleiro travado
  /// ([LossReason.boardStuck]) não é resolvido por mais movimentos, e
  /// oferecer o resgate ali prometeria uma saída que ele não entrega.
  bool get shouldOfferContinue =>
      status == GameStatus.lost &&
      lossReason == LossReason.moveLimitReached &&
      !continueOfferShown;
```

`copyWith`: adicionar parâmetro `bool? continueOfferShown` e repassar
`continueOfferShown: continueOfferShown ?? this.continueOfferShown,`.
`operator ==` e `hashCode`: incluir `continueOfferShown` na lista, mesmo
padrão dos outros campos booleanos de convite.

- [ ] **Step 5: Adicionar `grantContinueMoves`/`markContinueOfferShown` a `GameNotifier`**

Em `lib/features/game/providers/game_notifier.dart`, logo após `grantBonusMoves()`:

```dart
  /// O convite de resgate de derrota (Continue Offer) abriu na tela.
  ///
  /// Quem marca é a UI, mesma razão de [markMovesOfferShown]: a regra sabe
  /// dizer que a fase justifica o resgate, só a tela sabe se o cartão chegou
  /// a subir.
  void markContinueOfferShown() {
    if (state.continueOfferShown) return;
    state = state.copyWith(continueOfferShown: true);
  }

  /// Credita o resgate de derrota: +[kContinueBonusMoves] movimentos, e
  /// revive a fase (volta a `playing`, sem motivo de derrota).
  ///
  /// Só surte efeito se [GameState.shouldOfferContinue] for verdadeiro no
  /// instante da chamada — mesma guarda que [grantBonusMoves] aplica contra
  /// double-crédito, aqui replicada porque o gatilho é o oposto (a fase
  /// **precisa** estar perdida por falta de movimentos, não em andamento).
  void grantContinueMoves() {
    if (state.status != GameStatus.lost ||
        state.lossReason != LossReason.moveLimitReached ||
        state.continueOfferShown) {
      return;
    }
    state = state.copyWith(
      status: GameStatus.playing,
      clearLossReason: true,
      bonusMoves: state.bonusMoves + kContinueBonusMoves,
      continueOfferShown: true,
    );
  }
```

- [ ] **Step 6: Rodar e ver passar**

Run: `flutter test test/features/game/providers/game_notifier_test.dart test/features/game/providers/game_state_test.dart`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lib/features/game/domain/economy.dart lib/features/game/providers/game_state.dart lib/features/game/providers/game_notifier.dart test/features/game/providers/game_notifier_test.dart test/features/game/providers/game_state_test.dart
git commit -m "$(cat <<'EOF'
feat: adiciona regra do resgate de derrota (Continue Offer)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: `ContinueOfferDialog` (widget) com anúncio e compra por moeda

**Files:**
- Create: `lib/features/game/presentation/widgets/continue_offer_dialog.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_pt.arb`
- Test: `test/features/game/presentation/widgets/continue_offer_dialog_test.dart`

**Interfaces:**
- Consumes: `GameDialog`, `GameButton` (de `game_dialog.dart`), `AppColors`, `walletProvider` (`wallet.dart`), `kContinueCoinPrice`/`kContinueBonusMoves` (economy.dart), `CoinSourcesCard` (`coin_sources_card.dart`).
- Produces: `continueAdProvider` (`Provider<Future<bool> Function()>`, padrão paga sempre `true`), `ContinueOfferDialog` (widget, `onGranted: VoidCallback`, `onDecline: VoidCallback`), chaves `continueOfferKey`, `continueOfferWatchKey`, `continueOfferBuyKey`, `continueOfferDeclineKey`.

- [ ] **Step 1: Escrever o teste do widget (anúncio credita, recusa não credita, compra debita e credita)**

```dart
// test/features/game/presentation/widgets/continue_offer_dialog_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/presentation/widgets/continue_offer_dialog.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import 'package:nine_fuse/features/game/providers/wallet.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

Widget _wrap(Widget child, {List<Override> overrides = const []}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('assistir ao anúncio credita o resgate', (tester) async {
    var granted = false;
    await tester.pumpWidget(_wrap(
      ContinueOfferDialog(onGranted: () => granted = true, onDecline: () {}),
    ));

    await tester.tap(find.byKey(continueOfferWatchKey));
    await tester.pumpAndSettle();

    expect(granted, isTrue);
  });

  testWidgets('recusar não credita', (tester) async {
    var granted = false;
    var declined = false;
    await tester.pumpWidget(_wrap(
      ContinueOfferDialog(
        onGranted: () => granted = true,
        onDecline: () => declined = true,
      ),
    ));

    await tester.tap(find.byKey(continueOfferDeclineKey));
    await tester.pumpAndSettle();

    expect(granted, isFalse);
    expect(declined, isTrue);
  });

  testWidgets('comprar por moedas debita a carteira e credita o resgate', (tester) async {
    final storage = InMemoryGameStorage()..coins = kContinueCoinPrice;
    var granted = false;
    await tester.pumpWidget(_wrap(
      ContinueOfferDialog(onGranted: () => granted = true, onDecline: () {}),
      overrides: [
        walletProvider.overrideWith((ref) => WalletNotifier(storage: storage)),
      ],
    ));
    await tester.pump();

    await tester.tap(find.byKey(continueOfferBuyKey));
    await tester.pump();

    expect(granted, isTrue);
    expect(storage.coins, 0);
  });

  testWidgets('botão de compra fica desabilitado sem saldo', (tester) async {
    final storage = InMemoryGameStorage()..coins = 0;
    await tester.pumpWidget(_wrap(
      const ContinueOfferDialog(onGranted: _noop, onDecline: _noop),
      overrides: [
        walletProvider.overrideWith((ref) => WalletNotifier(storage: storage)),
      ],
    ));
    await tester.pump();

    final button = tester.widget<GameButton>(
      find.byKey(continueOfferBuyKey),
    );
    expect(button.onPressed, isNull);
  });
}

void _noop() {}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/game/presentation/widgets/continue_offer_dialog_test.dart`
Expected: FAIL — arquivo `continue_offer_dialog.dart` não existe.

- [ ] **Step 3: Adicionar as chaves de l10n (pt e en)**

Em `lib/l10n/app_en.arb`, logo após o bloco `hammerOfferEarnedCoins`:

```json
  "continueOfferTitle": "Out of moves",
  "continueOfferBody": "Watch a short ad or spend coins to get {bonus} extra moves and keep going.",
  "@continueOfferBody": {
    "placeholders": { "bonus": { "type": "int" } }
  },
  "continueOfferWatch": "WATCH AD (+{bonus})",
  "@continueOfferWatch": {
    "placeholders": { "bonus": { "type": "int" } }
  },
  "continueOfferBuy": "Buy for {price} 🪙",
  "@continueOfferBuy": {
    "placeholders": { "price": { "type": "int" } }
  },
  "continueOfferDecline": "GIVE UP",
  "continueOfferFailed": "No ad available right now.",
  "continueOfferNoCoins": "Not enough coins",
  "continueOfferBalance": "You have {coins} 🪙",
  "@continueOfferBalance": {
    "placeholders": { "coins": { "type": "int" } }
  },
```

Em `lib/l10n/app_pt.arb`, mesmas chaves (sem os blocos `@...`, que só existem no arquivo-modelo `en`):

```json
  "continueOfferTitle": "Sem movimentos",
  "continueOfferBody": "Assista a um anúncio curto ou gaste moedas para ganhar {bonus} movimentos extras e continuar.",
  "continueOfferWatch": "ASSISTIR (+{bonus})",
  "continueOfferBuy": "Comprar por {price} 🪙",
  "continueOfferDecline": "DESISTIR",
  "continueOfferFailed": "Nenhum anúncio disponível agora.",
  "continueOfferNoCoins": "Moedas insuficientes",
  "continueOfferBalance": "Você tem {coins} 🪙",
```

Run: `flutter gen-l10n`

- [ ] **Step 4: Criar `ContinueOfferDialog`, copiando o padrão de `HammerOfferDialog` (anúncio + compra), sem o funil de "ganhar moedas assistindo vídeo" (não pedido aqui — o resgate já é o próprio funil)**

```dart
// lib/features/game/presentation/widgets/continue_offer_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/presentation/widgets/coin_sources_card.dart';
import 'package:nine_fuse/features/game/presentation/widgets/game_dialog.dart';
import 'package:nine_fuse/features/game/providers/wallet.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Chave do cartão de resgate de derrota.
const Key continueOfferKey = Key('continue_offer');
const Key continueOfferWatchKey = Key('continue_offer_watch');
const Key continueOfferBuyKey = Key('continue_offer_buy');
const Key continueOfferDeclineKey = Key('continue_offer_decline');

/// Como o jogo pede o anúncio premiado que paga o resgate de derrota.
///
/// Unidade própria (não `movesAdProvider`/`hammerAdProvider`): é por unidade
/// que a rede reporta receita, e este funil é distinto dos outros dois —
/// paga na **derrota**, não pre-churn. Mesmo padrão: paga o jogador enquanto
/// não há SDK ligado.
final continueAdProvider = Provider<Future<bool> Function()>(
  (ref) => () async => true,
);

/// Convite de resgate, aberto quando a fase acabou de ser perdida por falta
/// de movimentos. Aceitar qualquer uma das duas opções revive a fase (volta a
/// `playing`) — é `GameNotifier.grantContinueMoves` quem faz isso.
class ContinueOfferDialog extends ConsumerStatefulWidget {
  const ContinueOfferDialog({
    super.key,
    required this.onGranted,
    required this.onDecline,
  });

  final VoidCallback onGranted;
  final VoidCallback onDecline;

  @override
  ConsumerState<ContinueOfferDialog> createState() => _ContinueOfferDialogState();
}

class _ContinueOfferDialogState extends ConsumerState<ContinueOfferDialog> {
  bool _waiting = false;
  bool _failed = false;

  Future<void> _watch() async {
    if (_waiting) return;
    setState(() {
      _waiting = true;
      _failed = false;
    });

    final granted = await ref.read(continueAdProvider)();
    if (!mounted) return;

    if (granted) {
      widget.onGranted();
      return;
    }

    setState(() {
      _waiting = false;
      _failed = true;
    });
  }

  void _buy() {
    if (_waiting) return;
    setState(() => _waiting = true);
    if (!ref.read(walletProvider.notifier).spendCoins(kContinueCoinPrice)) {
      setState(() => _waiting = false);
      return;
    }
    widget.onGranted();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wallet = ref.watch(walletProvider);
    final canAfford = wallet.canAfford(kContinueCoinPrice);

    return GameDialog(
      cardKey: continueOfferKey,
      title: l10n.continueOfferTitle,
      accent: AppColors.digit1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.replay_circle_filled_rounded, color: AppColors.digit1, size: 44),
          const SizedBox(height: 12),
          Text(
            l10n.continueOfferBody(kContinueBonusMoves),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
          if (_failed) ...[
            const SizedBox(height: 10),
            Text(
              l10n.continueOfferFailed,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.digit0, fontSize: 13),
            ),
          ],
          const SizedBox(height: 18),
          GameButton(
            key: continueOfferWatchKey,
            label: l10n.continueOfferWatch(kContinueBonusMoves),
            color: AppColors.digit1,
            icon: Icons.play_circle_fill_rounded,
            onPressed: _watch,
          ),
          const SizedBox(height: 10),
          GameButton(
            key: continueOfferBuyKey,
            label: l10n.continueOfferBuy(kContinueCoinPrice),
            color: canAfford ? AppColors.digit3 : AppColors.darkSurface,
            foreground: canAfford ? Colors.black : Colors.white38,
            icon: Icons.shopping_bag_rounded,
            onPressed: canAfford ? _buy : null,
          ),
          const SizedBox(height: 6),
          Text(
            canAfford
                ? l10n.continueOfferBalance(wallet.coins)
                : '${l10n.continueOfferNoCoins} · ${l10n.continueOfferBalance(wallet.coins)}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: canAfford ? Colors.white54 : Colors.white38,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          const CoinSourcesCard(),
          const SizedBox(height: 10),
          GameButton(
            key: continueOfferDeclineKey,
            label: l10n.continueOfferDecline,
            color: AppColors.darkSurface,
            foreground: Colors.white70,
            onPressed: widget.onDecline,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Rodar e ver passar**

Run: `flutter test test/features/game/presentation/widgets/continue_offer_dialog_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/features/game/presentation/widgets/continue_offer_dialog.dart lib/l10n/app_en.arb lib/l10n/app_pt.arb test/features/game/presentation/widgets/continue_offer_dialog_test.dart
git commit -m "$(cat <<'EOF'
feat: adiciona ContinueOfferDialog (resgate de derrota)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Ligar o `ContinueOfferDialog` ao `GameScreen` (campanha)

**Files:**
- Modify: `lib/features/game/presentation/screens/game_screen.dart`
- Test: `test/features/game/presentation/game_screen_test.dart`

**Interfaces:**
- Consumes: `state.shouldOfferContinue`, `notifier.markContinueOfferShown()`, `notifier.grantContinueMoves()`, `ContinueOfferDialog` (Task 2), `_OutcomeOverlay` (já existe no arquivo).
- Produces: nada novo exportado — só wiring de tela.

- [ ] **Step 1: Escrever o teste de integração (sobe sobre o cartão de derrota, recusar revela o cartão, aceitar revive a fase)**

```dart
// test/features/game/presentation/game_screen_test.dart — novo grupo no fim
group('Continue Offer', () {
  testWidgets('perder por falta de movimentos abre o resgate sobre o cartão de derrota', (tester) async {
    await _pumpGameScreenAtLevel(tester, moveLimit: 1); // helper já existente no arquivo, reaproveitado
    final hint = _notifierFrom(tester).state.hint!;
    _notifierFrom(tester).swapTiles(hint.$1, hint.$2);
    await tester.pumpAndSettle();

    expect(find.byKey(continueOfferKey), findsOneWidget);
    expect(find.byKey(levelOutcomeKey), findsNothing);
  });

  testWidgets('recusar revela o cartão de derrota', (tester) async {
    await _pumpGameScreenAtLevel(tester, moveLimit: 1);
    final hint = _notifierFrom(tester).state.hint!;
    _notifierFrom(tester).swapTiles(hint.$1, hint.$2);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(continueOfferDeclineKey));
    await tester.pumpAndSettle();

    expect(find.byKey(continueOfferKey), findsNothing);
    expect(find.byKey(levelOutcomeKey), findsOneWidget);
  });

  testWidgets('assistir ao anúncio revive a fase e some o resgate', (tester) async {
    await _pumpGameScreenAtLevel(tester, moveLimit: 1);
    final hint = _notifierFrom(tester).state.hint!;
    _notifierFrom(tester).swapTiles(hint.$1, hint.$2);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(continueOfferWatchKey));
    await tester.pumpAndSettle();

    expect(find.byKey(continueOfferKey), findsNothing);
    expect(find.byKey(levelOutcomeKey), findsNothing);
    expect(_notifierFrom(tester).state.status, GameStatus.playing);
  });
});
```

*(Nota ao implementador: verifique se `_pumpGameScreenAtLevel`/`_notifierFrom`/`levelOutcomeKey` já existem como helpers no arquivo de teste — o padrão do arquivo já monta fases customizadas para os testes de `MovesOfferDialog`/`HammerOfferDialog`; reaproveite o helper existente ao invés de recriar, ajustando apenas o `moveLimit`.)*

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/game/presentation/game_screen_test.dart`
Expected: FAIL — `continueOfferKey` não é encontrado (dialog não wired).

- [ ] **Step 3: Adicionar o estado local e o wiring em `game_screen.dart`**

Perto de `_movesOfferOpen`/`_endlessSuggestionOpen`, no topo da classe State:

```dart
  /// Mesmo motivo de `_movesOfferOpen`: `shouldOfferContinue` também é
  /// consumido por quem chama `grantContinueMoves` (que já muda o status para
  /// `playing` e apaga a condição), então só a tela sabe se o cartão chegou a
  /// subir.
  bool _continueOfferOpen = false;
```

No `ref.listen`, junto ao bloco de `_movesOfferOpen`/`runId` (reset ao trocar de partida):

```dart
      if (previous != null && next.runId != previous.runId) {
        setState(() {
          _ready = false;
          _movesOfferOpen = false;
          _continueOfferOpen = false;
          _endlessSuggestionOpen = false;
        });
      }
```

E, próximo ao bloco de `shouldOfferMoves` (o convite de resgate não depende de `_ready`: a fase já perdeu, o cartão de início não está mais no caminho):

```dart
      if (!_continueOfferOpen && next.shouldOfferContinue) {
        _continueOfferOpen = true;
        ref.read(gameProvider.notifier).markContinueOfferShown();
      }
```

No `Stack` de overlays, **antes** do `if (state.isOver)` que abre `LevelOutcomeCard` (o resgate precede o cartão de derrota na ordem de leitura, mas nunca convivem — aceitar revive a fase e `state.isOver` vira falso no mesmo estado):

```dart
            if (_continueOfferOpen && state.shouldOfferContinue)
              _OutcomeOverlay(
                child: ContinueOfferDialog(
                  onGranted: () {
                    ref.read(gameProvider.notifier).grantContinueMoves();
                    setState(() => _continueOfferOpen = false);
                  },
                  onDecline: () => setState(() => _continueOfferOpen = false),
                ),
              ),
```

Adicionar o import:

```dart
import 'package:nine_fuse/features/game/presentation/widgets/continue_offer_dialog.dart';
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/game/presentation/game_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Rodar a suíte inteira e o analyzer**

Run: `flutter analyze && flutter test`
Expected: 0 issues, todos os testes verdes.

- [ ] **Step 6: Commit**

```bash
git add lib/features/game/presentation/screens/game_screen.dart test/features/game/presentation/game_screen_test.dart
git commit -m "$(cat <<'EOF'
feat: liga o resgate de derrota (Continue Offer) à tela da campanha

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Parte B — Dreno de moedas nos boosters (Bomba, Pincel, Martelo)

### Task 4: Modo Fantasma para a Bomba (`pendingTarget` em `BombState`)

**Files:**
- Modify: `lib/features/game/providers/bomb_booster.dart`
- Modify: `lib/features/game/domain/economy.dart`
- Test: `test/features/game/providers/bomb_booster_test.dart`

**Interfaces:**
- Consumes: `BombState`, `MatchEngine.smashArea`, `GameStorage.readBombCount`/`writeBombCount`.
- Produces: `BombState.pendingTarget` (`Position?`); `BombBooster.grantBomb({int count = 1})` passa a bater no alvo pendente (mesma assinatura, comportamento estendido); `kBombCoinPrice` em `economy.dart`.

- [ ] **Step 1: Escrever o teste (mirar sem estoque guarda o alvo; `grantBomb` credita e explode o alvo guardado)**

```dart
// test/features/game/providers/bomb_booster_test.dart — novo grupo no fim
group('Modo Fantasma', () {
  test('mirar sem estoque guarda o alvo pendente, sem explodir', () {
    final harness = _BombTestNotifier(); // classe de teste já existente no arquivo, implementando BombBooster
    harness.setBoard(_boardWithTileAt(const Position(row: 2, col: 2), value: 3));
    harness.toggleBombTargeting();
    harness.useBomb(const Position(row: 2, col: 2));

    expect(harness.bomb.pendingTarget, const Position(row: 2, col: 2));
    expect(harness.bomb.count, 0);
    expect(harness.boardAfter.getTileAt(const Position(row: 2, col: 2)), isNotNull);
  });

  test('grantBomb credita e explode o alvo pendente', () {
    final harness = _BombTestNotifier();
    harness.setBoard(_boardWithTileAt(const Position(row: 2, col: 2), value: 3));
    harness.toggleBombTargeting();
    harness.useBomb(const Position(row: 2, col: 2));

    harness.grantBomb();

    expect(harness.bomb.count, 0); // creditou 1 e já gastou no golpe
    expect(harness.bomb.pendingTarget, isNull);
    expect(harness.boardAfter.getTileAt(const Position(row: 2, col: 2)), isNull);
  });
});
```

*(Nota ao implementador: `bomb_booster_test.dart` já tem um harness `_BombTestNotifier`/equivalente implementando o mixin para os testes existentes de `useBomb`/`toggleBombTargeting` — reaproveite-o; adicione `setBoard`/`boardAfter` se ainda não existirem, seguindo o mesmo padrão que `hammer_booster_test.dart` já usa para o Modo Fantasma do Martelo.)*

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/game/providers/bomb_booster_test.dart`
Expected: FAIL — `BombState.pendingTarget` não existe.

- [ ] **Step 3: Adicionar `kBombCoinPrice` em `economy.dart`**

```dart
/// Preço avulso da Bomba em moedas.
///
/// Mais cara que Martelo e Pincel (100): a Bomba afeta uma área 3x3 inteira
/// de uma vez, não uma célula única — o preço reflete o poder, não só a
/// categoria "booster avulso".
const int kBombCoinPrice = 150;
```

- [ ] **Step 4: Adicionar `pendingTarget` a `BombState` e o Modo Fantasma a `BombBooster`**

Em `BombState`: adicionar campo `pendingTarget` (mesmo padrão de `HammerState`):

```dart
  const BombState({
    this.count = 0,
    this.isTargeting = false,
    this.strike,
    this.strikes = 0,
    this.pendingTarget,
  });

  // ... (após `strikes`)

  /// Centro da área escolhido no Modo Fantasma, à espera da bomba.
  final Position? pendingTarget;

  BombState copyWith({
    int? count,
    bool? isTargeting,
    (Position, Map<Position, int>)? strike,
    int? strikes,
    Position? pendingTarget,
    bool clearPendingTarget = false,
  }) => BombState(
    count: count ?? this.count,
    isTargeting: isTargeting ?? this.isTargeting,
    strike: strike ?? this.strike,
    strikes: strikes ?? this.strikes,
    pendingTarget: clearPendingTarget ? null : (pendingTarget ?? this.pendingTarget),
  );
```

Atualizar `==`/`hashCode` para incluir `pendingTarget` (mesmo padrão de `HammerState`).

Em `BombBooster`, substituir `toggleBombTargeting`/`useBomb`/`grantBomb` para replicar exatamente o Modo Fantasma do Martelo:

```dart
  void toggleBombTargeting() {
    if (!acceptsBomb) return;

    if (bomb.isTargeting) {
      cancelBombTargeting();
      return;
    }

    // Modo Fantasma: entra em mira mesmo com estoque zero — mesma regra do
    // Martelo. `useBomb` é quem decide, na hora do toque, se explode de
    // verdade ou só guarda o alvo.
    targetingFeedback();
    writeBomb(bomb.copyWith(isTargeting: true));
    onBombTargetingStarted();
  }

  void cancelBombTargeting() {
    writeBomb(bomb.copyWith(isTargeting: false, clearPendingTarget: true));
  }

  void useBomb(Position pos) {
    if (bombEngine == null || !acceptsBomb) return;

    if (!Board.contains(pos) || bombBoard.getTileAt(pos) == null) {
      rejectionFeedback();
      return;
    }

    if (bomb.count <= 0) {
      writeBomb(bomb.copyWith(pendingTarget: pos));
      return;
    }

    _strikeArea(pos);
  }

  /// Credita bombas e, se havia alvo escolhido no Modo Fantasma, explode nele.
  void grantBomb({int count = 1}) {
    _setBombCount(bomb.count + count);

    final pending = bomb.pendingTarget;
    if (pending == null || bombEngine == null || !acceptsBomb) return;

    if (bombBoard.getTileAt(pending) == null) {
      cancelBombTargeting();
      return;
    }

    _strikeArea(pending);
  }

  void _strikeArea(Position pos) {
    final engine = bombEngine!;
    final board = bombBoard;

    final destroyed = <Position, int>{
      for (int row = pos.row - 1; row <= pos.row + 1; row++)
        for (int col = pos.col - 1; col <= pos.col + 1; col++)
          if (Board.contains(Position(row: row, col: col)))
            if (board.getTileAt(Position(row: row, col: col)) case final tile?)
              Position(row: row, col: col): tile.value,
    };

    final resolution = engine.smashArea(board, pos);
    if (resolution == null) {
      rejectionFeedback();
      return;
    }

    strikeFeedback();
    _setBombCount(bomb.count - 1);
    writeBomb(
      bomb.copyWith(
        isTargeting: false,
        clearPendingTarget: true,
        strike: (pos, destroyed),
        strikes: bomb.strikes + 1,
      ),
    );

    playBombResolution(engine, resolution);
  }
```

Remover o corpo antigo de `useBomb` (que fazia a checagem `bomb.count <= 0` antes mesmo de mirar) — ele é substituído pelo bloco acima. `_setBombCount` continua igual.

- [ ] **Step 5: Rodar e ver passar**

Run: `flutter test test/features/game/providers/bomb_booster_test.dart`
Expected: PASS (incluindo os testes pré-existentes do arquivo, que não devem quebrar).

- [ ] **Step 6: Commit**

```bash
git add lib/features/game/providers/bomb_booster.dart lib/features/game/domain/economy.dart test/features/game/providers/bomb_booster_test.dart
git commit -m "$(cat <<'EOF'
feat: adiciona Modo Fantasma à Bomba (mira sem estoque)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Modo Fantasma para o Pincel (`pendingTarget` em `BrushState`)

**Files:**
- Modify: `lib/features/game/providers/brush_booster.dart`
- Modify: `lib/features/game/domain/economy.dart`
- Test: `test/features/game/providers/brush_booster_test.dart`

**Interfaces:**
- Consumes: `BrushState`, `MatchEngine.paintTile`, `GameStorage.readBrushCount`/`writeBrushCount`.
- Produces: `BrushState.pendingTarget` (`Position?`); `BrushBooster.grantBrush({int count = 1})` passa a pintar o alvo pendente; `kBrushCoinPrice` em `economy.dart`.

- [ ] **Step 1: Escrever o teste (mesmo par de casos da Task 4, adaptado ao Pincel)**

```dart
// test/features/game/providers/brush_booster_test.dart — novo grupo no fim
group('Modo Fantasma', () {
  test('mirar sem estoque guarda o alvo pendente, sem pintar', () {
    final harness = _BrushTestNotifier();
    harness.setBoard(_boardWithTileAt(const Position(row: 1, col: 1), value: 2));
    harness.toggleBrushTargeting();
    harness.usePaint(const Position(row: 1, col: 1));

    expect(harness.brush.pendingTarget, const Position(row: 1, col: 1));
    expect(harness.brush.count, 0);
    expect(harness.boardAfter.getTileAt(const Position(row: 1, col: 1))!.value, 2);
  });

  test('grantBrush credita e pinta o alvo pendente', () {
    final harness = _BrushTestNotifier();
    harness.setBoard(_boardWithTileAt(const Position(row: 1, col: 1), value: 2));
    harness.toggleBrushTargeting();
    harness.usePaint(const Position(row: 1, col: 1));

    harness.grantBrush();

    expect(harness.brush.count, 0);
    expect(harness.brush.pendingTarget, isNull);
    expect(harness.boardAfter.getTileAt(const Position(row: 1, col: 1))!.value, 3);
  });
});
```

*(Nota ao implementador: siga o mesmo harness já existente em `brush_booster_test.dart`, análogo ao de `bomb_booster_test.dart`.)*

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/game/providers/brush_booster_test.dart`
Expected: FAIL — `BrushState.pendingTarget` não existe.

- [ ] **Step 3: Adicionar `kBrushCoinPrice` em `economy.dart`**

```dart
/// Preço avulso do Pincel em moedas. Mesma ordem do Martelo (100): afeta uma
/// célula só, sem a área da Bomba.
const int kBrushCoinPrice = 100;
```

- [ ] **Step 4: Adicionar `pendingTarget` a `BrushState` e o Modo Fantasma a `BrushBooster`**

Em `BrushState`:

```dart
  const BrushState({this.count = 0, this.isTargeting = false, this.pendingTarget});

  // ...

  /// Peça escolhida no Modo Fantasma, à espera do pincel.
  final Position? pendingTarget;

  BrushState copyWith({int? count, bool? isTargeting, Position? pendingTarget, bool clearPendingTarget = false}) =>
      BrushState(
        count: count ?? this.count,
        isTargeting: isTargeting ?? this.isTargeting,
        pendingTarget: clearPendingTarget ? null : (pendingTarget ?? this.pendingTarget),
      );
```

Atualizar `==`/`hashCode` para incluir `pendingTarget`.

Em `BrushBooster`:

```dart
  void toggleBrushTargeting() {
    if (!acceptsBrush) return;

    if (brush.isTargeting) {
      cancelBrushTargeting();
      return;
    }

    targetingFeedback();
    writeBrush(brush.copyWith(isTargeting: true));
    onBrushTargetingStarted();
  }

  void cancelBrushTargeting() {
    writeBrush(brush.copyWith(isTargeting: false, clearPendingTarget: true));
  }

  void usePaint(Position pos) {
    if (brushEngine == null || !acceptsBrush) return;

    if (brush.count <= 0) {
      writeBrush(brush.copyWith(pendingTarget: pos));
      return;
    }

    _paint(pos);
  }

  void grantBrush({int count = 1}) {
    _setBrushCount(brush.count + count);

    final pending = brush.pendingTarget;
    if (pending == null || brushEngine == null || !acceptsBrush) return;

    _paint(pending);
  }

  void _paint(Position pos) {
    final engine = brushEngine!;
    final resolution = engine.paintTile(brushBoard, pos);
    if (resolution == null) {
      rejectionFeedback();
      writeBrush(brush.copyWith(clearPendingTarget: true));
      return;
    }

    paintFeedback();
    _setBrushCount(brush.count - 1);
    writeBrush(brush.copyWith(isTargeting: false, clearPendingTarget: true));

    playBrushResolution(engine, resolution);
  }
```

Nota: como `paintTile` recusa peça já no dígito máximo/peça especial/casa vazia, uma mira pendente sobre um alvo que ficou inválido enquanto o anúncio rodava (o mesmo caso que `grantHammer` trata) simplesmente falha a pintura sem cobrar de novo — o Pincel já foi creditado por `grantBrush`, e é isso que o teste da Task 5 confere (não há reembolso: o item entrou no estoque, só a mira falhou, mesma régua do Martelo quando o alvo sume do tabuleiro).

- [ ] **Step 5: Rodar e ver passar**

Run: `flutter test test/features/game/providers/brush_booster_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/features/game/providers/brush_booster.dart lib/features/game/domain/economy.dart test/features/game/providers/brush_booster_test.dart
git commit -m "$(cat <<'EOF'
feat: adiciona Modo Fantasma ao Pincel (mira sem estoque)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: `GameState`/`GameNotifier` expõem `pendingBombTarget`/`pendingBrushTarget`

**Files:**
- Modify: `lib/features/game/providers/game_state.dart`
- Test: `test/features/game/providers/game_state_test.dart`

**Interfaces:**
- Consumes: `BombState.pendingTarget`, `BrushState.pendingTarget` (Tasks 4/5).
- Produces: `GameState.pendingBombTarget` (`Position?` getter), `GameState.pendingBrushTarget` (`Position?` getter).

- [ ] **Step 1: Escrever o teste**

```dart
// test/features/game/providers/game_state_test.dart
test('pendingBombTarget e pendingBrushTarget espelham o estado dos boosters', () {
  final state = GameState.initial().copyWith(
    bomb: const BombState(pendingTarget: Position(row: 1, col: 1)),
    brush: const BrushState(pendingTarget: Position(row: 2, col: 2)),
  );
  expect(state.pendingBombTarget, const Position(row: 1, col: 1));
  expect(state.pendingBrushTarget, const Position(row: 2, col: 2));
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/game/providers/game_state_test.dart`
Expected: FAIL — getters não existem.

- [ ] **Step 3: Adicionar os getters em `game_state.dart`**

Logo após `int get bombStrikes => bomb.strikes;`:

```dart
  Position? get pendingBombTarget => bomb.pendingTarget;
```

Logo após `bool get isBrushTargeting => brush.isTargeting;`:

```dart
  Position? get pendingBrushTarget => brush.pendingTarget;
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/game/providers/game_state_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/game/providers/game_state.dart test/features/game/providers/game_state_test.dart
git commit -m "$(cat <<'EOF'
feat: expõe pendingBombTarget/pendingBrushTarget em GameState

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: `BombOfferDialog` e `BrushOfferDialog` (widgets, sibling de `HammerOfferDialog`)

**Files:**
- Create: `lib/features/game/presentation/widgets/bomb_offer_dialog.dart`
- Create: `lib/features/game/presentation/widgets/brush_offer_dialog.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_pt.arb`
- Test: `test/features/game/presentation/widgets/bomb_offer_dialog_test.dart`
- Test: `test/features/game/presentation/widgets/brush_offer_dialog_test.dart`

**Interfaces:**
- Consumes: `kBombCoinPrice`/`kBrushCoinPrice` (Tasks 4/5), `walletProvider`, `GameDialog`/`GameButton`, `CoinSourcesCard`.
- Produces: `BombOfferDialog` (widget, `onGranted`/`onDecline`), `bombOfferKey`/`bombOfferWatchKey`/`bombOfferBuyKey`/`bombOfferDeclineKey`, `bombAdProvider`; `BrushOfferDialog` análogo com prefixo `brush`.

- [ ] **Step 1: Escrever os testes (mesmos 4 casos da Task 2, por widget)**

```dart
// test/features/game/presentation/widgets/bomb_offer_dialog_test.dart
// Mesma estrutura do continue_offer_dialog_test.dart (Task 2), trocando:
// - import para bomb_offer_dialog.dart
// - chaves para bombOffer*
// - kContinueCoinPrice -> kBombCoinPrice
// - provider para bombAdProvider
```

```dart
// test/features/game/presentation/widgets/brush_offer_dialog_test.dart
// Mesma estrutura, chaves brushOffer*, provider brushAdProvider, kBrushCoinPrice.
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/game/presentation/widgets/bomb_offer_dialog_test.dart test/features/game/presentation/widgets/brush_offer_dialog_test.dart`
Expected: FAIL — arquivos não existem.

- [ ] **Step 3: Adicionar as chaves de l10n (pt e en)**

Em `lib/l10n/app_en.arb`, após as chaves de `continueOffer*` da Task 2:

```json
  "bombOfferTitle": "Out of bombs",
  "bombOfferBody": "Watch a short ad and blast the 3x3 area you picked.",
  "bombOfferWatch": "WATCH AD",
  "bombOfferBuy": "Buy for {price} 🪙",
  "@bombOfferBuy": { "placeholders": { "price": { "type": "int" } } },
  "bombOfferDecline": "NOT NOW",
  "bombOfferFailed": "No ad available right now.",
  "bombOfferNoCoins": "Not enough coins",
  "bombOfferBalance": "You have {coins} 🪙",
  "@bombOfferBalance": { "placeholders": { "coins": { "type": "int" } } },
  "brushOfferTitle": "Out of brushes",
  "brushOfferBody": "Watch a short ad and raise the piece you picked by one.",
  "brushOfferWatch": "WATCH AD",
  "brushOfferBuy": "Buy for {price} 🪙",
  "@brushOfferBuy": { "placeholders": { "price": { "type": "int" } } },
  "brushOfferDecline": "NOT NOW",
  "brushOfferFailed": "No ad available right now.",
  "brushOfferNoCoins": "Not enough coins",
  "brushOfferBalance": "You have {coins} 🪙",
  "@brushOfferBalance": { "placeholders": { "coins": { "type": "int" } } },
```

Em `lib/l10n/app_pt.arb`:

```json
  "bombOfferTitle": "Sem bombas",
  "bombOfferBody": "Assista a um anúncio curto e destrua a área 3x3 escolhida.",
  "bombOfferWatch": "ASSISTIR ANÚNCIO",
  "bombOfferBuy": "Comprar por {price} 🪙",
  "bombOfferDecline": "AGORA NÃO",
  "bombOfferFailed": "Nenhum anúncio disponível agora.",
  "bombOfferNoCoins": "Moedas insuficientes",
  "bombOfferBalance": "Você tem {coins} 🪙",
  "brushOfferTitle": "Sem pincéis",
  "brushOfferBody": "Assista a um anúncio curto e eleve em 1 a peça escolhida.",
  "brushOfferWatch": "ASSISTIR ANÚNCIO",
  "brushOfferBuy": "Comprar por {price} 🪙",
  "brushOfferDecline": "AGORA NÃO",
  "brushOfferFailed": "Nenhum anúncio disponível agora.",
  "brushOfferNoCoins": "Moedas insuficientes",
  "brushOfferBalance": "Você tem {coins} 🪙",
```

Run: `flutter gen-l10n`

- [ ] **Step 4: Criar `BombOfferDialog`, copiando `ContinueOfferDialog` (Task 2) e trocando os nomes/ícone/cor**

```dart
// lib/features/game/presentation/widgets/bomb_offer_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/presentation/widgets/coin_sources_card.dart';
import 'package:nine_fuse/features/game/presentation/widgets/game_dialog.dart';
import 'package:nine_fuse/features/game/providers/wallet.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

const Key bombOfferKey = Key('bomb_offer');
const Key bombOfferWatchKey = Key('bomb_offer_watch');
const Key bombOfferBuyKey = Key('bomb_offer_buy');
const Key bombOfferDeclineKey = Key('bomb_offer_decline');

/// Unidade própria de anúncio para a Bomba — mesma razão de todas as outras:
/// é por unidade que a rede reporta receita.
final bombAdProvider = Provider<Future<bool> Function()>(
  (ref) => () async => true,
);

/// Convite de aquisição da Bomba, aberto quando o jogador mira sem estoque —
/// sibling de `HammerOfferDialog`/`ContinueOfferDialog`, e não uma
/// generalização: mesma decisão de projeto já aplicada aos mixins de
/// booster (mecânicas divergem, telas ficam separadas).
class BombOfferDialog extends ConsumerStatefulWidget {
  const BombOfferDialog({super.key, required this.onGranted, required this.onDecline});

  final VoidCallback onGranted;
  final VoidCallback onDecline;

  @override
  ConsumerState<BombOfferDialog> createState() => _BombOfferDialogState();
}

class _BombOfferDialogState extends ConsumerState<BombOfferDialog> {
  bool _waiting = false;
  bool _failed = false;

  Future<void> _watch() async {
    if (_waiting) return;
    setState(() {
      _waiting = true;
      _failed = false;
    });

    final granted = await ref.read(bombAdProvider)();
    if (!mounted) return;

    if (granted) {
      widget.onGranted();
      return;
    }

    setState(() {
      _waiting = false;
      _failed = true;
    });
  }

  void _buy() {
    if (_waiting) return;
    setState(() => _waiting = true);
    if (!ref.read(walletProvider.notifier).spendCoins(kBombCoinPrice)) {
      setState(() => _waiting = false);
      return;
    }
    widget.onGranted();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wallet = ref.watch(walletProvider);
    final canAfford = wallet.canAfford(kBombCoinPrice);

    return GameDialog(
      cardKey: bombOfferKey,
      title: l10n.bombOfferTitle,
      accent: AppColors.digit0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.gps_fixed_rounded, color: AppColors.digit0, size: 44),
          const SizedBox(height: 12),
          Text(
            l10n.bombOfferBody,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
          if (_failed) ...[
            const SizedBox(height: 10),
            Text(
              l10n.bombOfferFailed,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.digit0, fontSize: 13),
            ),
          ],
          const SizedBox(height: 18),
          GameButton(
            key: bombOfferWatchKey,
            label: l10n.bombOfferWatch,
            color: AppColors.digit0,
            icon: Icons.play_circle_fill_rounded,
            onPressed: _watch,
          ),
          const SizedBox(height: 10),
          GameButton(
            key: bombOfferBuyKey,
            label: l10n.bombOfferBuy(kBombCoinPrice),
            color: canAfford ? AppColors.digit3 : AppColors.darkSurface,
            foreground: canAfford ? Colors.black : Colors.white38,
            icon: Icons.shopping_bag_rounded,
            onPressed: canAfford ? _buy : null,
          ),
          const SizedBox(height: 6),
          Text(
            canAfford
                ? l10n.bombOfferBalance(wallet.coins)
                : '${l10n.bombOfferNoCoins} · ${l10n.bombOfferBalance(wallet.coins)}',
            textAlign: TextAlign.center,
            style: TextStyle(color: canAfford ? Colors.white54 : Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 14),
          const CoinSourcesCard(),
          const SizedBox(height: 10),
          GameButton(
            key: bombOfferDeclineKey,
            label: l10n.bombOfferDecline,
            color: AppColors.darkSurface,
            foreground: Colors.white70,
            onPressed: widget.onDecline,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Criar `BrushOfferDialog`, mesmo padrão, prefixo `brush`, `kBrushCoinPrice`, cor `AppColors.digit5`, ícone `Icons.brush_rounded`**

```dart
// lib/features/game/presentation/widgets/brush_offer_dialog.dart
// Idêntico a bomb_offer_dialog.dart, com:
//   - const Key brushOfferKey = Key('brush_offer'); (e watch/buy/decline)
//   - final brushAdProvider = Provider<Future<bool> Function()>((ref) => () async => true);
//   - class BrushOfferDialog ... _BrushOfferDialogState
//   - kBrushCoinPrice em vez de kBombCoinPrice
//   - l10n.brushOffer* em vez de l10n.bombOffer*
//   - accent: AppColors.digit5, ícone: Icons.brush_rounded
```

- [ ] **Step 6: Rodar e ver passar**

Run: `flutter test test/features/game/presentation/widgets/bomb_offer_dialog_test.dart test/features/game/presentation/widgets/brush_offer_dialog_test.dart`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lib/features/game/presentation/widgets/bomb_offer_dialog.dart lib/features/game/presentation/widgets/brush_offer_dialog.dart lib/l10n/app_en.arb lib/l10n/app_pt.arb test/features/game/presentation/widgets/bomb_offer_dialog_test.dart test/features/game/presentation/widgets/brush_offer_dialog_test.dart
git commit -m "$(cat <<'EOF'
feat: adiciona os convites de aquisição da Bomba e do Pincel

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Ligar os convites de Bomba/Pincel a `game_screen.dart` e `endless_screen.dart`

**Files:**
- Modify: `lib/features/game/presentation/screens/game_screen.dart`
- Modify: `lib/features/game/presentation/screens/endless_screen.dart`
- Test: `test/features/game/presentation/game_screen_test.dart`
- Test: `test/features/game/presentation/endless_screen_test.dart`

**Interfaces:**
- Consumes: `state.pendingBombTarget`/`pendingBrushTarget` (Task 6), `BombOfferDialog`/`BrushOfferDialog` (Task 7), `notifier.grantBomb`/`grantBrush`/`cancelBombTargeting`/`cancelBrushTargeting` (já existem).
- Produces: nada novo exportado — só wiring.

- [ ] **Step 1: Escrever os testes de integração (mirar sem estoque abre o convite; a camada de mira não aparece por cima do convite; anúncio credita e explode/pinta o alvo)**

```dart
// test/features/game/presentation/game_screen_test.dart — novo grupo
group('Convites de Bomba e Pincel', () {
  testWidgets('mirar a bomba sem estoque abre o convite de aquisição', (tester) async {
    await _pumpGameScreen(tester); // helper existente
    final notifier = _notifierFrom(tester);
    notifier.toggleBombTargeting();
    final target = _firstOccupiedCell(notifier.state.board);
    notifier.useBomb(target);
    await tester.pumpAndSettle();

    expect(find.byKey(bombOfferKey), findsOneWidget);
    // A camada de mira não compete com o modal.
    expect(find.byKey(hammerTargetingLayerKey), findsNothing);
  });

  testWidgets('assistir ao anúncio da bomba explode o alvo guardado', (tester) async {
    await _pumpGameScreen(tester);
    final notifier = _notifierFrom(tester);
    notifier.toggleBombTargeting();
    final target = _firstOccupiedCell(notifier.state.board);
    notifier.useBomb(target);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(bombOfferWatchKey));
    await tester.pumpAndSettle();

    expect(find.byKey(bombOfferKey), findsNothing);
    expect(notifier.state.board.getTileAt(target), isNull);
  });

  testWidgets('mirar o pincel sem estoque abre o convite de aquisição', (tester) async {
    await _pumpGameScreen(tester);
    final notifier = _notifierFrom(tester);
    notifier.toggleBrushTargeting();
    final target = _firstOccupiedCell(notifier.state.board);
    notifier.usePaint(target);
    await tester.pumpAndSettle();

    expect(find.byKey(brushOfferKey), findsOneWidget);
  });
});
```

*(Nota ao implementador: `_firstOccupiedCell`/`hammerTargetingLayerKey` — verifique os helpers já usados pelos testes existentes de Martelo no mesmo arquivo e reaproveite; `HammerTargetingLayer` provavelmente já expõe uma chave própria usada pelos testes de mira do Martelo.)*

Espelhar o mesmo grupo em `endless_screen_test.dart` (sem o `MovesOfferDialog`/`ContinueOfferDialog`, que não existem no Endless).

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/game/presentation/game_screen_test.dart test/features/game/presentation/endless_screen_test.dart`
Expected: FAIL — `bombOfferKey`/`brushOfferKey` nunca aparecem.

- [ ] **Step 3: Ajustar as camadas de mira em `game_screen.dart` para sair de cena quando há alvo pendente**

Trocar:

```dart
            if (state.isBombTargeting)
              HammerTargetingLayer(
                boardKey: _boardKey,
                areaRadius: 1,
                onCell: notifier.useBomb,
                onCancel: notifier.cancelBombTargeting,
              ),
```

por:

```dart
            if (state.isBombTargeting && state.pendingBombTarget == null)
              HammerTargetingLayer(
                boardKey: _boardKey,
                areaRadius: 1,
                onCell: notifier.useBomb,
                onCancel: notifier.cancelBombTargeting,
              ),
```

E, de forma análoga:

```dart
            if (state.isBrushTargeting && state.pendingBrushTarget == null)
              HammerTargetingLayer(
                boardKey: _boardKey,
                onCell: notifier.usePaint,
                onCancel: notifier.cancelBrushTargeting,
              ),
```

- [ ] **Step 4: Adicionar os dois convites ao `Stack` de overlays, ao lado do de Martelo**

Logo após o bloco `if (state.pendingHammerTarget != null && !state.isOver) ...`:

```dart
            if (state.pendingBombTarget != null && !state.isOver)
              _OutcomeOverlay(
                child: BombOfferDialog(
                  onGranted: notifier.grantBomb,
                  onDecline: notifier.cancelBombTargeting,
                ),
              ),
            if (state.pendingBrushTarget != null && !state.isOver)
              _OutcomeOverlay(
                child: BrushOfferDialog(
                  onGranted: notifier.grantBrush,
                  onDecline: notifier.cancelBrushTargeting,
                ),
              ),
```

Ajustar a guarda do `MovesOfferDialog` (que já checa `state.pendingHammerTarget == null`) para também checar os dois novos alvos pendentes, senão os dois convites empilhariam:

```dart
            if (_movesOfferOpen &&
                !state.isOver &&
                state.pendingHammerTarget == null &&
                state.pendingBombTarget == null &&
                state.pendingBrushTarget == null)
```

Adicionar os imports:

```dart
import 'package:nine_fuse/features/game/presentation/widgets/bomb_offer_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/brush_offer_dialog.dart';
```

- [ ] **Step 5: Repetir os Steps 3-4 em `endless_screen.dart`** (mesmas mudanças de mira, mesmos dois blocos de convite adicionados ao `Stack`, mesmos imports; o Endless não tem `MovesOfferDialog` para ajustar).

- [ ] **Step 6: Rodar e ver passar**

Run: `flutter test test/features/game/presentation/game_screen_test.dart test/features/game/presentation/endless_screen_test.dart`
Expected: PASS

- [ ] **Step 7: Rodar a suíte inteira e o analyzer**

Run: `flutter analyze && flutter test`
Expected: 0 issues, todos os testes verdes. Se algum golden quebrar por causa da árvore de widgets (não deveria — os convites só aparecem sob condição nova), regenerar com `flutter test --update-goldens` e conferir visualmente o diff antes de commitar.

- [ ] **Step 8: Commit**

```bash
git add lib/features/game/presentation/screens/game_screen.dart lib/features/game/presentation/screens/endless_screen.dart test/features/game/presentation/game_screen_test.dart test/features/game/presentation/endless_screen_test.dart
git commit -m "$(cat <<'EOF'
feat: liga os convites de aquisição de Bomba e Pincel às telas de jogo

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Parte C — Mini-loja no cartão de início de fase

### Task 9: Botões de compra avulsa (Martelo/Bomba/Pincel) em `LevelStartDialog`

**Files:**
- Modify: `lib/features/game/presentation/widgets/level_start_dialog.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_pt.arb`
- Test: `test/features/game/presentation/level_start_dialog_test.dart`

**Interfaces:**
- Consumes: `walletProvider`, `kHammerCoinPrice`/`kBombCoinPrice`/`kBrushCoinPrice`, `GameButton`.
- Produces: `LevelStartDialog` ganha uma seção nova (sem mudar a assinatura pública — lê `walletProvider`/os notifiers de booster diretamente via `Consumer`, como `CoinsHeaderBadge` já faz).

**Nota de contexto:** há um diff não commitado neste arquivo (adição de `onClose`/`levelStartCloseKey`) — não relacionado a esta task. Edite preservando essas mudanças; não as reverta.

- [ ] **Step 1: Escrever o teste (cada botão compra o item correspondente, e fica desabilitado sem saldo)**

```dart
// test/features/game/presentation/level_start_dialog_test.dart — novo grupo
group('Mini-loja de boosters', () {
  testWidgets('comprar Martelo debita a carteira e credita o inventário', (tester) async {
    final storage = InMemoryGameStorage()..coins = kHammerCoinPrice;
    await tester.pumpWidget(_wrapLevelStart(
      storage: storage,
    ));
    await tester.pump();

    await tester.tap(find.byKey(levelStartBuyHammerKey));
    await tester.pump();

    expect(storage.coins, 0);
    expect(storage.hammerCount, 1);
  });

  testWidgets('comprar Bomba debita a carteira e credita o inventário', (tester) async {
    final storage = InMemoryGameStorage()..coins = kBombCoinPrice;
    await tester.pumpWidget(_wrapLevelStart(storage: storage));
    await tester.pump();

    await tester.tap(find.byKey(levelStartBuyBombKey));
    await tester.pump();

    expect(storage.coins, 0);
    expect(storage.bombCount, 1);
  });

  testWidgets('comprar Pincel debita a carteira e credita o inventário', (tester) async {
    final storage = InMemoryGameStorage()..coins = kBrushCoinPrice;
    await tester.pumpWidget(_wrapLevelStart(storage: storage));
    await tester.pump();

    await tester.tap(find.byKey(levelStartBuyBrushKey));
    await tester.pump();

    expect(storage.coins, 0);
    expect(storage.brushCount, 1);
  });

  testWidgets('botões ficam desabilitados sem saldo suficiente', (tester) async {
    final storage = InMemoryGameStorage()..coins = 0;
    await tester.pumpWidget(_wrapLevelStart(storage: storage));
    await tester.pump();

    for (final key in [levelStartBuyHammerKey, levelStartBuyBombKey, levelStartBuyBrushKey]) {
      final button = tester.widget<GameButton>(find.byKey(key));
      expect(button.onPressed, isNull, reason: '$key deveria estar desabilitado');
    }
  });
});
```

*(Nota ao implementador: crie o helper `_wrapLevelStart({required InMemoryGameStorage storage})` no topo do arquivo, sobrepondo `walletProvider` com `WalletNotifier(storage: storage)` — mesmo padrão dos outros testes de compra já escritos nas Tasks 2/7 — e passando o mesmo `storage` para o `PrefsGameStorage`/equivalente que o inventário de boosters usa, se o teste existente do arquivo já tiver esse padrão de setup; do contrário, verifique como os testes de `HammerOfferDialog` isolam o inventário e replique.)*

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/game/presentation/level_start_dialog_test.dart`
Expected: FAIL — chaves `levelStartBuyHammerKey`/etc. não existem.

- [ ] **Step 3: Adicionar as chaves de l10n (pt e en)**

Em `lib/l10n/app_en.arb`:

```json
  "levelStartShopHammer": "Hammer",
  "levelStartShopBomb": "Bomb",
  "levelStartShopBrush": "Brush",
  "levelStartShopBuy": "{price} 🪙",
  "@levelStartShopBuy": { "placeholders": { "price": { "type": "int" } } },
```

Em `lib/l10n/app_pt.arb`:

```json
  "levelStartShopHammer": "Martelo",
  "levelStartShopBomb": "Bomba",
  "levelStartShopBrush": "Pincel",
  "levelStartShopBuy": "{price} 🪙",
```

Run: `flutter gen-l10n`

- [ ] **Step 4: Adicionar a seção de mini-loja ao `LevelStartDialog`**

Converter `LevelStartDialog` para observar `walletProvider` (se ainda não for um `ConsumerWidget`) e adicionar, dentro do `child: Column(...)` existente, após o conteúdo atual e antes do botão "JOGAR":

```dart
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _BoosterShopButton(
                buttonKey: levelStartBuyHammerKey,
                label: l10n.levelStartShopHammer,
                icon: Icons.gavel_rounded,
                price: kHammerCoinPrice,
                canAfford: wallet.canAfford(kHammerCoinPrice),
                onBuy: () {
                  if (ref.read(walletProvider.notifier).spendCoins(kHammerCoinPrice)) {
                    ref.read(gameProvider.notifier).grantHammer();
                  }
                },
              ),
              _BoosterShopButton(
                buttonKey: levelStartBuyBombKey,
                label: l10n.levelStartShopBomb,
                icon: Icons.gps_fixed_rounded,
                price: kBombCoinPrice,
                canAfford: wallet.canAfford(kBombCoinPrice),
                onBuy: () {
                  if (ref.read(walletProvider.notifier).spendCoins(kBombCoinPrice)) {
                    ref.read(gameProvider.notifier).grantBomb();
                  }
                },
              ),
              _BoosterShopButton(
                buttonKey: levelStartBuyBrushKey,
                label: l10n.levelStartShopBrush,
                icon: Icons.brush_rounded,
                price: kBrushCoinPrice,
                canAfford: wallet.canAfford(kBrushCoinPrice),
                onBuy: () {
                  if (ref.read(walletProvider.notifier).spendCoins(kBrushCoinPrice)) {
                    ref.read(gameProvider.notifier).grantBrush();
                  }
                },
              ),
            ],
          ),
```

*(Nota ao implementador: `LevelStartDialog` é usado tanto pela campanha quanto pelo Endless — verifique se o widget já recebe o notifier certo via `gameProvider`/parâmetro, ou se precisa de um parâmetro `boosterNotifier` injetável para funcionar nas duas telas, seguindo o padrão já usado alhures no arquivo para diferenciar campanha/Endless, se houver.)*

Adicionar o widget auxiliar privado no fim do arquivo:

```dart
class _BoosterShopButton extends StatelessWidget {
  const _BoosterShopButton({
    required this.buttonKey,
    required this.label,
    required this.icon,
    required this.price,
    required this.canAfford,
    required this.onBuy,
  });

  final Key buttonKey;
  final String label;
  final IconData icon;
  final int price;
  final bool canAfford;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Icon(icon, color: canAfford ? Colors.white70 : Colors.white24, size: 22),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 4),
        GameButton(
          key: buttonKey,
          label: l10n.levelStartShopBuy(price),
          color: canAfford ? AppColors.digit3 : AppColors.darkSurface,
          foreground: canAfford ? Colors.black : Colors.white38,
          onPressed: canAfford ? onBuy : null,
        ),
      ],
    );
  }
}
```

Adicionar as chaves e imports no topo do arquivo:

```dart
const Key levelStartBuyHammerKey = Key('level_start_buy_hammer');
const Key levelStartBuyBombKey = Key('level_start_buy_bomb');
const Key levelStartBuyBrushKey = Key('level_start_buy_brush');
```

```dart
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/providers/wallet.dart';
```

- [ ] **Step 5: Rodar e ver passar**

Run: `flutter test test/features/game/presentation/level_start_dialog_test.dart`
Expected: PASS

- [ ] **Step 6: Rodar a suíte inteira, o analyzer e regenerar goldens se a árvore do cartão mudou**

Run: `flutter analyze && flutter test`
Expected: 0 issues. Se `level_start.png`/golden equivalente quebrar (a seção nova muda a altura do cartão), regenerar com `flutter test --update-goldens --plain-name level_start` e inspecionar visualmente antes de commitar.

- [ ] **Step 7: Commit**

```bash
git add lib/features/game/presentation/widgets/level_start_dialog.dart lib/l10n/app_en.arb lib/l10n/app_pt.arb test/features/game/presentation/level_start_dialog_test.dart
git commit -m "$(cat <<'EOF'
feat: adiciona mini-loja de boosters ao cartão de início de fase

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Parte D — Ritmo de dificuldade: fases hard no gerador procedural

### Task 10: `_isHardLevel` e o multiplicador de movimentos (-25%)

**Files:**
- Modify: `lib/features/game/domain/level_generator.dart`
- Test: `test/features/game/domain/level_generator_test.dart`

**Interfaces:**
- Consumes: `_blockOf`, `_positionOf`, `kBlockSize`, `_movesFor` (já existentes).
- Produces: `const int kHardLevelStart = 30;`, `const double kHardMoveMultiplier = 0.75;`, função `bool isHardLevel(int number)` (pública — o gerador de UI/testes de calibragem vai precisar dela em Tasks futuras e nos testes desta), aplicada dentro de `_movesFor`.

- [ ] **Step 1: Escrever o teste**

```dart
// test/features/game/domain/level_generator_test.dart — novo grupo no fim
group('Fases hard', () {
  test('isHardLevel é falso antes da fase 30', () {
    for (var n = kHandcraftedLevels + 1; n < kHardLevelStart; n++) {
      expect(isHardLevel(n), isFalse, reason: 'fase $n');
    }
  });

  test('isHardLevel marca exatamente 1 fase a cada kBlockSize a partir da 30', () {
    final hardInRange = [
      for (var n = kHardLevelStart; n < kHardLevelStart + kBlockSize * 5; n++)
        if (isHardLevel(n)) n,
    ];
    expect(hardInRange.length, 5);
    // Espaçadas por kBlockSize.
    for (var i = 1; i < hardInRange.length; i++) {
      expect(hardInRange[i] - hardInRange[i - 1], kBlockSize);
    }
  });

  test('fase hard tem limite de movimentos ~25% menor que a fase equivalente não-hard do mesmo bloco', () {
    final hardLevel = [
      for (var n = kHardLevelStart; n < kHardLevelStart + kBlockSize * 3; n++)
        if (isHardLevel(n)) n,
    ].first;
    final hard = generateLevel(hardLevel);
    final notHard = generateLevel(hardLevel - 1); // vizinha, mesmo bloco, não-hard

    expect(hard.moveLimit, lessThan(notHard.moveLimit));
    expect(hard.moveLimit, greaterThanOrEqualTo(kMinMoveLimit));
  });

  test('fase hard nunca cai abaixo do piso de movimentos, mesmo em blocos distantes', () {
    for (var block = 40; block < 60; block++) {
      final number = kHandcraftedLevels + 1 + block * kBlockSize + (kBlockSize - 2);
      if (!isHardLevel(number)) continue;
      final level = generateLevel(number);
      expect(level.moveLimit, greaterThanOrEqualTo(kMinMoveLimit));
    }
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/game/domain/level_generator_test.dart`
Expected: FAIL — `isHardLevel`/`kHardLevelStart` não existem.

- [ ] **Step 3: Implementar em `level_generator.dart`**

Adicionar as constantes, perto de `kMinMoveLimit`:

```dart
/// A partir de qual fase o gerador começa a intercalar fases "hard".
///
/// 30 é o pedido original: as fases artesanais (1-10) e os primeiros dois
/// blocos gerados (11-30) continuam sem variação de intensidade — o jogador
/// ainda está aprendendo o ritmo normal da campanha gerada.
const int kHardLevelStart = 30;

/// O quanto o limite de movimentos encolhe numa fase hard, em relação ao
/// que a fórmula normal (aperto por bloco + ritmo) já calculou para aquele
/// número. 0,75 é o "-25%" pedido.
///
/// Aplicado **depois** do aperto por bloco e do ritmo senoidal, e **antes**
/// do piso de projeto ([kMinMoveLimit]/[kHeavyDigitMoveFloor]) — a fase hard
/// nunca fica mais curta que o piso que já vale para qualquer fase.
const double kHardMoveMultiplier = 0.75;

/// A fase [number] é uma fase "hard"?
///
/// Um degrau fixo por bloco (a penúltima posição, [kBlockSize] - 2) a partir
/// de [kHardLevelStart]: dá exatamente uma fase hard a cada [kBlockSize]
/// fases, sem precisar de um contador à parte — reaproveita a mesma
/// aritmética de bloco/posição que [_objectiveFor] já usa. A penúltima
/// posição, e não a última: a última já é o fecho de bloco ("limpe tudo"),
/// que tem seu próprio arquétipo fixo e não deveria carregar as duas
/// intensificações ao mesmo tempo.
bool isHardLevel(int number) {
  if (number < kHardLevelStart) return false;
  return _positionOf(number) == kBlockSize - 2;
}
```

Em `_movesFor`, aplicar o multiplicador depois do `paced` e antes do cálculo do piso:

```dart
  final paced = base * tighteningFactor * _pacingFactor(number);
  final hardened = isHardLevel(number) ? paced * kHardMoveMultiplier : paced;

  final distance = objective.type == ObjectiveType.reachDigit
      ? objective.digit! - _averageBoardTileLevel(spawnMax)
      : 0.0;
  final floor = _moveFloorFor(objective, distance: distance);
  final result = hardened.floor();
  return result < floor ? floor : result;
```

`_movesFor` precisa de `number` no escopo — já recebe `required int number` como parâmetro (confirmar na assinatura existente; se não tiver, `generateLevel` já o repassa).

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/game/domain/level_generator_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/game/domain/level_generator.dart test/features/game/domain/level_generator_test.dart
git commit -m "$(cat <<'EOF'
feat: adiciona fases hard ao gerador procedural (-25% movimentos)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 11: Densidade dobrada de obstáculos nas fases hard

**Files:**
- Modify: `lib/features/game/domain/level_generator.dart`
- Test: `test/features/game/domain/level_generator_test.dart`

**Interfaces:**
- Consumes: `_obstaclesFor(block)` (existente), `isHardLevel` (Task 10), `ObstacleLayout`.
- Produces: `_obstaclesFor` ganha um parâmetro `{bool hard = false}`; chamadas em `generateLevel`/`_finalObjectiveFor` passam `hard: isHardLevel(number)`.

- [ ] **Step 1: Escrever o teste**

```dart
group('Densidade de obstáculos em fases hard', () {
  test('fase hard tem o dobro de cada tipo de obstáculo do bloco, respeitando o teto', () {
    final hardLevel = [
      for (var n = kHardLevelStart; n < kHardLevelStart + kBlockSize * 3; n++)
        if (isHardLevel(n)) n,
    ].first;
    final hard = generateLevel(hardLevel);
    final notHard = generateLevel(hardLevel - 1);

    expect(hard.obstacles.total, greaterThan(notHard.obstacles.total));
    expect(hard.obstacles.total, lessThanOrEqualTo(kMaxObstacles));
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/game/domain/level_generator_test.dart`
Expected: FAIL — a fase hard ainda tem a mesma densidade da vizinha.

- [ ] **Step 3: Implementar**

Alterar a assinatura de `_obstaclesFor`:

```dart
ObstacleLayout _obstaclesFor(int block, {bool hard = false}) {
  final ice = (2 + block % 3).clamp(1, 4);
  final glass = (1 + block ~/ 2).clamp(1, 3);
  final stone = (block ~/ 3).clamp(0, 3);

  // Fase hard: camada dupla — dobra cada tipo presente antes do teto. Só
  // dobra o que já existe (multiplicar zero continua zero); o teto de
  // tabuleiro é o mesmo de qualquer fase, então o corte por baixo (menos
  // gelo primeiro) segue valendo igual.
  final doubledIce = hard ? ice * 2 : ice;
  final doubledGlass = hard ? glass * 2 : glass;
  final doubledStone = hard ? stone * 2 : stone;

  var trimmedIce = doubledIce;
  var total = doubledIce + doubledGlass + doubledStone;
  while (total > kMaxObstacles && trimmedIce > 1) {
    trimmedIce--;
    total--;
  }

  return ObstacleLayout(ice: trimmedIce, glass: doubledGlass, stone: doubledStone);
}
```

Atualizar as três chamadas existentes de `_obstaclesFor(block)`:

```dart
// generateLevel
final obstacles = _obstaclesFor(block, hard: isHardLevel(number));

// _finalObjectiveFor
final obstacles = _obstaclesFor(block, hard: isHardLevel(number));
```

(A terceira chamada, dentro de `_avoidRepetition`/`_varied`, recebe `obstacles` já calculado como parâmetro — não chama `_obstaclesFor` de novo; conferir no arquivo que não há uma quarta chamada esquecida.)

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/game/domain/level_generator_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/game/domain/level_generator.dart test/features/game/domain/level_generator_test.dart
git commit -m "$(cat <<'EOF'
feat: dobra a densidade de obstáculos nas fases hard

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 12: Calibragem via `simulate_economy.dart` e registro no CLAUDE.md

**Files:**
- Modify: `tool/simulate_economy.dart`
- Modify: `/Users/cleber/projects/nine_fuse/CLAUDE.md`

**Interfaces:**
- Consumes: `isHardLevel`, `generateLevel` (Tasks 10/11).
- Produces: novo modo `--mode=hard` no simulador (compara cada fase hard contra a vizinha não-hard do mesmo bloco).

- [ ] **Step 1: Localizar o dispatch de `--mode` em `tool/simulate_economy.dart`** (grep por `--mode=generated` para achar o `switch`/`if` que seleciona o modo) e adicionar um novo branch `hard` que:
  - Itera os primeiros ~15 números hard (`isHardLevel(n)`) a partir de `kHardLevelStart`.
  - Para cada um, roda o bot guloso (reaproveitando a mesma função de simulação que `--mode=generated` já usa) tanto na fase hard quanto na vizinha `n - 1` (não-hard), com o mesmo número de partidas (200, mesma disciplina das calibragens anteriores).
  - Imprime uma tabela: fase | objetivo | movimentos hard | vitórias hard % | movimentos vizinho | vitórias vizinho %.

*(Nota ao implementador: siga exatamente o formato de saída e a estrutura de loop que `--mode=generated` já usa nesse arquivo — não reinventar o formato da tabela.)*

- [ ] **Step 2: Rodar a calibragem**

Run: `dart run tool/simulate_economy.dart --mode=hard --games=200`
Expected: uma tabela com ~15 linhas. Confira que nenhuma fase hard mede 0% — se alguma medir, é sinal de que `kHardMoveMultiplier` (0,75) é agressivo demais combinado com a densidade dobrada de obstáculo para aquele arquétipo específico; documente o achado, mas **não** ajuste a constante nesta task sem antes registrar o número medido (mesma disciplina de todas as calibragens anteriores do projeto: medir antes de mexer).

- [ ] **Step 3: Registrar o resultado no CLAUDE.md**, seguindo o formato das seções de calibragem já existentes (tabela + explicação do "porquê"), incluindo a tabela obtida no Step 2 e uma nota indicando que fases >200 hard, quando aplicável, são as que a leitura de produto do spec associa ao uso esperado de Bomba/Pincel (sem enforcement de código).

- [ ] **Step 4: Commit**

```bash
git add tool/simulate_economy.dart CLAUDE.md
git commit -m "$(cat <<'EOF'
docs: calibra e registra as fases hard do gerador procedural

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Parte E — Verificação final

### Task 13: Suíte completa, analyzer e revisão de goldens

**Files:** nenhum (task de verificação).

- [ ] **Step 1: Rodar o analyzer**

Run: `flutter analyze`
Expected: `No issues found!` (ou só o `info` pré-existente de `tool_tmp/probe124.dart`, já registrado como fora de escopo em uma task anterior do projeto — não introduzir nenhum problema novo).

- [ ] **Step 2: Rodar a suíte inteira**

Run: `flutter test`
Expected: todos os testes verdes, incluindo os das Tasks 1-12 e a suíte pré-existente.

- [ ] **Step 3: Conferir visualmente qualquer golden regenerado nas Tasks 8/9** (dock/telas de jogo, cartão de início) — abrir os `.png` alterados e confirmar que a mudança é exatamente a esperada (novos convites/botões, nada mais).

- [ ] **Step 4: Rodar o jogo e exercitar manualmente os três fluxos-chave** (usar a skill/agent de `run` se disponível neste projeto, ou `flutter run` local):
  1. Perder uma fase por falta de movimentos → resgate aparece → aceitar ou recusar.
  2. Mirar a Bomba/Pincel sem estoque → convite de compra aparece → comprar com moeda funciona.
  3. Comprar um booster na mini-loja do cartão de início.

- [ ] **Step 5: Commit final, se houver ajustes desta verificação**

```bash
git add -A
git commit -m "$(cat <<'EOF'
test: ajustes finais de verificação da economia de resgate e boosters

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review

**Cobertura do spec:**
- Seção 1 (Continue Offer) → Tasks 1-3.
- Seção 2 (dreno de moedas nos boosters) → Tasks 4-8 (Bomba/Pincel Modo Fantasma + convite; Martelo já tinha o funil, só falta nada extra).
- Seção 3 (loja pré-jogo/in-game) → Task 9 (pré-jogo); in-game já coberto pelo Modo Fantasma das Tasks 4-8.
- Seção 4 (ritmo de dificuldade) → Tasks 10-12.
- Seção 5 (testes) → Task 13, e cada task individual já roda `flutter analyze`/`flutter test` como parte do próprio ciclo.

**Achado durante o planejamento, fora do escopo original do spec:** Bomba e Pincel já existiam quase inteiramente implementados no código (mixins, mecânica no `MatchEngine`, UI de mira e dock) — o que faltava, e é o que as Tasks 4-8 entregam, era exclusivamente o funil de aquisição paga (Modo Fantasma + convite + preço), que o próprio código já documentava como "não pedido ainda". Isso não estava nem no CLAUDE.md consultado durante o brainstorming nem na spec (escrita antes desta exploração mais profunda) — a spec pediu para "implementar" os dois boosters do zero, mas grande parte já existia. O plano reflete o estado real do código, não a suposição da spec.
