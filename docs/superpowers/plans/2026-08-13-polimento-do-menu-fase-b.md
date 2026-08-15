# Polimento do Menu e AppIcon — Plano de Implementação (Fase B)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dar ao mapa da campanha e ao ícone do app o acabamento que a Fase A já sustenta por baixo — barra de recursos com o saldo real, Endless compacto, fundo com atmosfera, baú de fim de capítulo que paga, e um ícone que sobrevive a papel de parede escuro.

**Architecture:** Nenhuma regra nova. Tudo aqui consome o que a Fase A entregou (`walletProvider`, `claimChapterChest`) e o que o mapa já tem (`SagaGeometry`, `_PathPainter`, `CampaignRecords`). O trabalho é de composição e pintura: um widget novo por responsabilidade, montados pela `LevelSelectScreen`.

**Tech Stack:** Dart / Flutter, Riverpod, `CustomPainter`, `flutter_test` + `matchesGoldenFile`, `rsvg-convert` + `flutter_launcher_icons`.

## Global Constraints

- **Nenhuma animação em repetição infinita.** Toda animação nova é finita e descansa em repouso. Uma animação que nunca termina faz `pumpAndSettle` nunca retornar e derruba a suíte de widget inteira. É a mesma razão pela qual o aro da mira dá duas batidas e para, e pela qual o contador de movimentos pulsa uma vez por jogada.
- **Nada de `Opacity` nem `FadeTransition` novos dentro de `TileWidget` ou dos widgets do tabuleiro.** A suíte usa esses dois tipos como marcadores de outros efeitos. Fora do tabuleiro (mapa, HUD, cartões) eles são livres — `EndlessHighlight` já usa `Opacity` na raiz hoje.
- **Semente fixa em toda partícula ou textura procedural** (`Random(42)` ou equivalente declarado). Sem ela o desenho muda a cada rebuild e nenhum golden se sustenta.
- Todo texto visível novo entra em `lib/l10n/app_pt.arb` **e** `lib/l10n/app_en.arb`, com `flutter gen-l10n` rodado. `test/l10n/english_screens_test.dart` pega o que faltar.
- Valores da economia sempre pelas constantes de `lib/features/game/domain/economy.dart`, nunca literais.
- **Chaves de teste existentes são contrato.** `endlessCardKey`, `endlessRecordKey`, `endlessCallToActionKey`, `totalStarsKey` e `chapterLabelKey` devem continuar existindo e continuar apontando para algo tocável/legível equivalente. Mudança de layout não pode quebrar teste de regra — a falha diria a coisa errada sobre o que mudou.
- Comentários e mensagens de commit em português. O projeto comenta o **porquê** das decisões e o que aconteceria de outro jeito, não o quê do código.
- **O golden `test/features/game/presentation/goldens/saga_map.png` vai mudar de propósito.** Ele é regerado na Task 8 e a imagem nova é olhada antes de ser aceita — nunca aprovada no escuro.

## Decisões já tomadas, que este plano não reabre

- **Gradiente do fundo:** `#0B0813 → #161129`. O segundo pedido trazia `#0D0B18 → #1A152E`; a diferença é imperceptível e divergir de um desenho fechado custa mais do que vale.
- **O `+` fica só no martelo.** Moeda é status puro: não há atalho que gere moeda, e um `+` que não leva a lugar nenhum reproduz o contador inútil que a Fase A evitou.
- **Um baú só, no fim da trilha**, referente ao último capítulo. Um baú após a fase 6 exigiria abrir espaço no meio da `SagaGeometry`, o que é reestruturação de trilha e não polimento.
- **O `9` do logo é corrigido junto com a ampliação.** Ele lê como `g` (a perna varre de cima-direita para baixo-esquerda, que é cauda de `g`); ampliar 160% sem corrigir só amplia o defeito.

---

## File Structure

- **Criar** `lib/features/game/presentation/widgets/saga_backdrop.dart` — fundo do mapa: gradiente, grade fosca e partículas estáticas. Uma responsabilidade: atmosfera, sem toque.
- **Criar** `lib/features/game/presentation/widgets/user_resources_bar.dart` — moedas, martelos e o badge de estrelas.
- **Criar** `lib/features/game/presentation/widgets/chapter_chest.dart` — o nó do baú, com seus três estados.
- **Modificar** `lib/features/game/presentation/widgets/campaign_header.dart` — perde o contador de estrelas (migra para a barra), fica com nome do capítulo e barra de progresso.
- **Modificar** `lib/features/game/presentation/widgets/endless_highlight.dart` — vira pílula de 56pt.
- **Modificar** `lib/features/game/presentation/widgets/saga_map.dart` — trilha em três camadas, trecho não conquistado pontilhado, e o baú no lugar do rótulo "Em Breve".
- **Modificar** `lib/features/game/presentation/screens/level_select_screen.dart` — compõe tudo.
- **Modificar** `assets/images/logo.svg` — forma do `9`, anel como moldura, filtro de glow.
- **Modificar** `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb`.

---

### Task 1: Fundo do mapa — gradiente, grade e partículas

**Files:**
- Create: `lib/features/game/presentation/widgets/saga_backdrop.dart`
- Modify: `lib/features/game/presentation/screens/level_select_screen.dart:145-152` (o `Scaffold` e o `AppBar`)
- Test: `test/features/game/presentation/saga_backdrop_test.dart`

**Interfaces:**
- Consumes: nada.
- Produces: `SagaBackdrop({required Widget child})`; `const Key sagaBackdropKey = Key('saga_backdrop')`.

- [ ] **Step 1: Escrever o teste que falha**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/presentation/widgets/saga_backdrop.dart';

void main() {
  testWidgets('envolve o filho e o mantém tocável', (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SagaBackdrop(
          child: Center(
            child: GestureDetector(
              onTap: () => taps++,
              child: const Text('alvo'),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(sagaBackdropKey), findsOneWidget);

    // A grade e as partículas ficam atrás e dentro de `IgnorePointer`: se
    // consumissem o gesto, o mapa inteiro pararia de responder ao toque.
    await tester.tap(find.text('alvo'));
    expect(taps, 1);
  });

  testWidgets('a textura não muda entre rebuilds', (tester) async {
    // Semente fixa. Sem ela a grade e as partículas dançam a cada quadro
    // reconstruído e nenhum golden do mapa se sustenta.
    await tester.pumpWidget(
      const MaterialApp(home: SagaBackdrop(child: SizedBox.expand())),
    );

    final first = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byKey(sagaBackdropKey),
        matching: find.byType(CustomPaint),
      ).first,
    ).painter;

    await tester.pumpWidget(
      const MaterialApp(home: SagaBackdrop(child: SizedBox.expand())),
    );

    final second = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byKey(sagaBackdropKey),
        matching: find.byType(CustomPaint),
      ).first,
    ).painter;

    // Dois painters de mesma configuração têm de se declarar equivalentes,
    // senão cada rebuild repinta uma textura diferente.
    expect(second!.shouldRepaint(first!), isFalse);
  });

  testWidgets('não estoura em tela estreita', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: SagaBackdrop(child: SizedBox.expand()),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/features/game/presentation/saga_backdrop_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../saga_backdrop.dart'`.

- [ ] **Step 3: Implementar o fundo**

Criar `lib/features/game/presentation/widgets/saga_backdrop.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Chave do fundo do mapa.
const Key sagaBackdropKey = Key('saga_backdrop');

/// Fundo do mapa da campanha: gradiente profundo, grade fosca e partículas.
///
/// O preto chapado que estava aqui não é neutro, é ausente: ele faz a trilha
/// colorida flutuar sobre nada. O gradiente dá profundidade e a grade dá
/// escala — sem elas o mapa parece um diagrama, não um lugar.
class SagaBackdrop extends StatelessWidget {
  const SagaBackdrop({super.key, required this.child});

  final Widget child;

  /// Extremos do gradiente vertical.
  static const Color _top = Color(0xFF0B0813);
  static const Color _bottom = Color(0xFF161129);

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: sagaBackdropKey,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_top, _bottom],
      ),
    ),
    child: Stack(
      children: [
        // A textura é **fixa**, e não rola com a trilha. Rolando junto ela
        // viraria movimento parasita competindo com o único elemento que deve
        // puxar o olho, que é o pin da fase da vez.
        //
        // `IgnorePointer` porque ela cobre a tela inteira: sem isso, o mapa
        // pararia de receber toque e nenhuma fase abriria.
        const Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _TexturePainter())),
        ),
        child,
      ],
    ),
  );
}

/// Grade fosca e partículas suspensas.
///
/// As duas coisas moram no mesmo painter porque são a mesma decisão visual
/// (atmosfera de fundo) e nunca aparecem separadas — dois painters empilhados
/// custariam duas passadas de pintura pelo mesmo efeito.
class _TexturePainter extends CustomPainter {
  const _TexturePainter();

  /// Espaçamento da grade.
  static const double _cell = 32;

  /// Quantas partículas suspensas.
  static const int _particles = 26;

  /// Semente fixa: a textura tem de ser a mesma em todo rebuild, senão a
  /// grade e os pontos dançam de quadro em quadro e o golden do mapa nunca
  /// fecha. É a mesma regra já aplicada às trincas dos obstáculos e às
  /// faíscas da explosão.
  static const int _seed = 42;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.022);

    for (double x = 0; x <= size.width; x += _cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y <= size.height; y += _cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Partículas: pontos claros de raio e alfa variados, sem movimento. O
    // pedido falava de "transparência de partículas"; animá-las custaria a
    // suíte de widget inteira e ganharia pouco num fundo que o olho não olha.
    final random = math.Random(_seed);
    for (int i = 0; i < _particles; i++) {
      final center = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      final radius = 0.7 + random.nextDouble() * 1.6;

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Colors.white.withValues(
            alpha: 0.05 + random.nextDouble() * 0.07,
          ),
      );
    }
  }

  /// A textura não depende de nada: dois painters iguais nunca precisam
  /// repintar um sobre o outro.
  @override
  bool shouldRepaint(_TexturePainter old) => false;
}
```

- [ ] **Step 4: Ligar na tela**

Em `level_select_screen.dart`, o `Scaffold` (linha ~145) troca a cor chapada pelo fundo, e o `AppBar` fica transparente — mantê-lo em `AppColors.darkSurface` cortaria o gradiente em dois logo no topo:

```dart
    return Scaffold(
      // Transparente: quem pinta é o `SagaBackdrop`, e uma cor aqui apareceria
      // como uma faixa por baixo dele nas bordas.
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).appTitle),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SagaBackdrop(
        child: SafeArea(
          child: Column(
```

Fechar o `SagaBackdrop` no fim do `body`. **Cuidado:** o `Scaffold` transparente mostra o que está atrás dele; se o resultado piscar branco em transição de rota, envolva o `Scaffold` num `ColoredBox(color: SagaBackdrop._top)` — mas só se acontecer, e exponha a cor como `SagaBackdrop.topColor` em vez de duplicar o literal.

- [ ] **Step 5: Rodar os testes**

Run: `flutter test test/features/game/presentation/saga_backdrop_test.dart test/features/game/presentation/level_select_screen_test.dart`
Expected: os três novos passam; os 11 do mapa continuam passando.

- [ ] **Step 6: Commit**

```bash
git add lib/features/game/presentation/widgets/saga_backdrop.dart lib/features/game/presentation/screens/level_select_screen.dart test/features/game/presentation/saga_backdrop_test.dart
git commit -m "feat: fundo do mapa com gradiente, grade fosca e partículas fixas"
```

---

### Task 2: `UserResourcesBar` — moedas, martelos e o badge de estrelas

**Files:**
- Create: `lib/features/game/presentation/widgets/user_resources_bar.dart`
- Modify: `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb`
- Test: `test/features/game/presentation/user_resources_bar_test.dart`

**Interfaces:**
- Consumes: `walletProvider`, `Wallet.coins`, `Wallet.hammers` (Fase A); `kCampaignStarTotal`; `hammerOfferKey` e `HammerOfferDialog` (já existem).
- Produces: `UserResourcesBar({required int totalStars, required int starTotal, required VoidCallback onAddHammer})`; chaves `userResourcesBarKey`, `coinCounterKey`, `hammerCounterKey`, `addHammerKey`, e `totalStarsKey` **migrada** para cá.

**Nota de contrato:** `totalStarsKey` sai de `campaign_header.dart` e passa a viver aqui (Task 3 remove o antigo). Os dois não podem coexistir — um `findsOneWidget` em `totalStarsKey` viraria `findsNWidgets(2)` e derrubaria teste existente. Faça as Tasks 2 e 3 em sequência, sem rodar a suíte inteira entre elas esperando verde.

- [ ] **Step 1: Adicionar os textos**

Em `lib/l10n/app_pt.arb`:

```json
  "coinsSemantics": "{count, plural, =1{1 moeda} other{{count} moedas}}",
  "@coinsSemantics": {
    "description": "Saldo de moedas, lido por leitor de tela.",
    "placeholders": { "count": { "type": "int" } }
  },
  "hammersSemantics": "{count, plural, =0{Nenhum martelo} =1{1 martelo} other{{count} martelos}}",
  "@hammersSemantics": {
    "description": "Estoque de martelos, lido por leitor de tela.",
    "placeholders": { "count": { "type": "int" } }
  },
  "addHammerSemantics": "Conseguir mais martelos",
  "@addHammerSemantics": {
    "description": "Botão + ao lado do estoque de martelos."
  },
```

Em `lib/l10n/app_en.arb`:

```json
  "coinsSemantics": "{count, plural, =1{1 coin} other{{count} coins}}",
  "@coinsSemantics": {
    "description": "Coin balance, read by screen readers.",
    "placeholders": { "count": { "type": "int" } }
  },
  "hammersSemantics": "{count, plural, =0{No hammers} =1{1 hammer} other{{count} hammers}}",
  "@hammersSemantics": {
    "description": "Hammer stock, read by screen readers.",
    "placeholders": { "count": { "type": "int" } }
  },
  "addHammerSemantics": "Get more hammers",
  "@addHammerSemantics": {
    "description": "The + button next to the hammer stock."
  },
```

Run: `flutter gen-l10n`
Expected: sem erros.

- [ ] **Step 2: Escrever o teste que falha**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/presentation/widgets/user_resources_bar.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import 'package:nine_fuse/features/game/providers/wallet.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

void main() {
  Future<void> pumpBar(
    WidgetTester tester, {
    int coins = 0,
    int hammers = 0,
    int totalStars = 0,
    VoidCallback? onAddHammer,
  }) async {
    final wallet = WalletNotifier(
      storage: InMemoryGameStorage(coins: coins, hammerCount: hammers),
    );
    await wallet.refresh();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [walletProvider.overrideWith((ref) => wallet)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: UserResourcesBar(
              totalStars: totalStars,
              starTotal: 30,
              onAddHammer: onAddHammer ?? () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('mostra o saldo real de moedas e martelos', (tester) async {
    await pumpBar(tester, coins: 250, hammers: 2, totalStars: 23);

    expect(find.text('250'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('23/30'), findsOneWidget);
  });

  testWidgets('o + do martelo chama o pedido de aquisição', (tester) async {
    var asked = 0;
    await pumpBar(tester, hammers: 0, onAddHammer: () => asked++);

    await tester.tap(find.byKey(addHammerKey));
    await tester.pumpAndSettle();

    expect(asked, 1);
  });

  testWidgets('a moeda não tem botão de atalho', (tester) async {
    // Decisão de projeto: não há caminho que gere moeda por atalho, e um `+`
    // que não leva a lugar nenhum é o contador inútil que a Fase A evitou.
    await pumpBar(tester, coins: 100);

    expect(
      find.descendant(
        of: find.byKey(coinCounterKey),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
  });

  testWidgets('não estoura em tela estreita com números grandes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpBar(tester, coins: 999999, hammers: 99, totalStars: 30);

    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 3: Rodar e confirmar que falha**

Run: `flutter test test/features/game/presentation/user_resources_bar_test.dart`
Expected: FAIL — arquivo `user_resources_bar.dart` não existe.

- [ ] **Step 4: Implementar a barra**

Criar `lib/features/game/presentation/widgets/user_resources_bar.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/features/game/providers/wallet.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Chave da barra de recursos.
const Key userResourcesBarKey = Key('user_resources_bar');

/// Chave do contador de moedas.
const Key coinCounterKey = Key('coin_counter');

/// Chave do contador de martelos.
const Key hammerCounterKey = Key('hammer_counter');

/// Chave do botão que pede mais martelos.
const Key addHammerKey = Key('add_hammer');

/// Chave do contador de estrelas totais.
///
/// Mora aqui, e não mais no `CampaignHeader`: o contador é status do jogador,
/// e status do jogador agora tem uma barra própria. O nome da chave não muda
/// porque os testes que a usam continuam perguntando a mesma coisa.
const Key totalStarsKey = Key('total_stars');

/// O que o jogador tem, no topo do mapa.
///
/// Moeda e martelo vêm do `walletProvider` e não do `GameState`: o mapa vive
/// fora de qualquer partida, e um `GameState` só existe dentro de uma.
class UserResourcesBar extends ConsumerWidget {
  const UserResourcesBar({
    super.key,
    required this.totalStars,
    required this.starTotal,
    required this.onAddHammer,
  });

  final int totalStars;
  final int starTotal;

  /// O jogador quer mais martelos. Quem abre o convite é a tela.
  final VoidCallback onAddHammer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final wallet = ref.watch(walletProvider);

    return Row(
      key: userResourcesBarKey,
      children: [
        _Counter(
          key: coinCounterKey,
          icon: Icons.monetization_on_rounded,
          color: AppColors.digit3,
          value: '${wallet.coins}',
          semanticLabel: l10n.coinsSemantics(wallet.coins),
        ),
        const SizedBox(width: 8),
        _Counter(
          key: hammerCounterKey,
          icon: Icons.gavel_rounded,
          color: AppColors.digit4,
          value: '${wallet.hammers}',
          semanticLabel: l10n.hammersSemantics(wallet.hammers),
          onAdd: onAddHammer,
          addSemanticLabel: l10n.addHammerSemantics,
        ),
        const Spacer(),
        // O badge de estrelas fica em `Flexible`: numa tela de 320pt os dois
        // contadores mais ele não cabem lado a lado sem alguém ceder, e quem
        // cede é o que tem texto mais previsível.
        Flexible(
          child: _StarBadge(totalStars: totalStars, starTotal: starTotal),
        ),
      ],
    );
  }
}

/// Um recurso: ícone, número e, opcionalmente, o `+` que pede mais.
class _Counter extends StatelessWidget {
  const _Counter({
    super.key,
    required this.icon,
    required this.color,
    required this.value,
    required this.semanticLabel,
    this.onAdd,
    this.addSemanticLabel,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String semanticLabel;

  /// Nulo significa "este recurso não tem atalho de aquisição" — o caso da
  /// moeda, que não é comprável nem ganhável por botão.
  final VoidCallback? onAdd;
  final String? addSemanticLabel;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(8, 5, onAdd == null ? 10 : 4, 5),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      color: Colors.black.withValues(alpha: 0.35),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: semanticLabel,
          excludeSemantics: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 5),
              Text(
                value,
                maxLines: 1,
                style: const TextStyle(
                  fontFamily: AppFonts.display,
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        if (onAdd case final add?) ...[
          const SizedBox(width: 4),
          Semantics(
            button: true,
            label: addSemanticLabel,
            excludeSemantics: true,
            child: InkWell(
              key: addHammerKey,
              onTap: add,
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.add_rounded, color: color, size: 17),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// O contador de estrelas, como pílula de brilho metálico.
///
/// A forma mudou porque a informação mudou de vizinhança: ao lado de dois
/// contadores de recurso, um número solto com legenda pequena se lia como um
/// terceiro recurso gastável. A pílula dourada o separa — estrela não se gasta.
class _StarBadge extends StatelessWidget {
  const _StarBadge({required this.totalStars, required this.starTotal});

  final int totalStars;
  final int starTotal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Semantics(
      key: totalStarsKey,
      label: l10n.starsSemantics(totalStars, starTotal),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3A2E12), Color(0xFF6B5416)],
          ),
          border: Border.all(color: AppColors.digit3.withValues(alpha: 0.65)),
          boxShadow: [
            BoxShadow(
              color: AppColors.digit3.withValues(alpha: 0.20),
              blurRadius: 14,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, color: AppColors.digit3, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '$totalStars/$starTotal',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppFonts.display,
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Rodar o teste**

Run: `flutter test test/features/game/presentation/user_resources_bar_test.dart`
Expected: PASS, 4 testes. A suíte inteira **vai falhar** neste ponto por `totalStarsKey` duplicada — é esperado e a Task 3 resolve.

- [ ] **Step 6: Commit**

```bash
git add lib/features/game/presentation/widgets/user_resources_bar.dart lib/l10n test/features/game/presentation/user_resources_bar_test.dart
git commit -m "feat: barra de recursos do mapa com moedas, martelos e badge de estrelas"
```

---

### Task 3: `CampaignHeader` entrega o contador e a tela monta a barra

**Files:**
- Modify: `lib/features/game/presentation/widgets/campaign_header.dart` (remover `_Stat`, `totalStarsKey` e os parâmetros de estrela)
- Modify: `lib/features/game/presentation/screens/level_select_screen.dart:159-189`
- Test: `test/features/game/presentation/level_select_screen_test.dart` (acrescentar casos)

**Interfaces:**
- Consumes: `UserResourcesBar`, `totalStarsKey`, `addHammerKey` (Task 2); `HammerOfferDialog`, `hammerOfferKey` (já existem); `walletProvider`.
- Produces: `CampaignHeader({required CampaignChapter chapter, required int totalStars, required int starTotal})` **mantém** a assinatura — a barra de progresso continua medindo estrelas, então ele ainda precisa dos números; o que sai é só o contador visual e a chave.

- [ ] **Step 1: Ensinar o teste a sobrescrever a carteira**

`level_select_screen_test.dart` monta a tela com `pumpSelect(tester)` sobre um `ProviderContainer` cujos overrides são declarados no `setUp` (linha ~66), todos apontando para um único `InMemoryGameStorage storage` compartilhado. **`walletProvider` não está na lista** — sem ele o `WalletNotifier` cai no `PrefsGameStorage` e tenta o `SharedPreferences` real, que em teste puro falha e vira saldo zero. Todo teste de saldo passaria a afirmar `0`.

Acrescente o override, junto dos outros:

```dart
        // Sem este override a carteira leria o armazenamento real do
        // dispositivo: a falha é engolida por `debugPrint` e o saldo aparece
        // como zero, então um teste de saldo passaria afirmando o número
        // errado em vez de falhar.
        walletProvider.overrideWith((ref) => WalletNotifier(storage: storage)),
```

`pumpSelect` também fixa a tela em 1200×2600, o que serve à maioria dos testes mas atropela qualquer um que queira medir outra proporção. Dê a ele um tamanho opcional, preservando o padrão atual:

```dart
  Future<void> pumpSelect(
    WidgetTester tester, {
    Size size = const Size(1200, 2600),
  }) async {
    tester.view.physicalSize = size;
```

- [ ] **Step 2: Escrever os testes que falham**

O saldo entra mexendo no `storage` compartilhado **antes** de montar, porque é ele que o override lê:

```dart
    testWidgets('a barra de recursos aparece no topo, com saldo', (
      tester,
    ) async {
      storage.coins = 140;
      storage.hammerCount = 3;

      await pumpSelect(tester);

      expect(find.byKey(userResourcesBarKey), findsOneWidget);
      expect(find.text('140'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('o contador de estrelas existe uma única vez', (tester) async {
      // Ele migrou do cabeçalho para a barra. Se as duas cópias sobrarem, todo
      // teste que procura a chave passa a achar duas e a falha aponta para o
      // lugar errado.
      await pumpSelect(tester);

      expect(find.byKey(totalStarsKey), findsOneWidget);
    });

    testWidgets('o + do martelo abre o convite de aquisição', (tester) async {
      await pumpSelect(tester);

      await tester.tap(find.byKey(addHammerKey));
      await tester.pumpAndSettle();

      expect(find.byKey(hammerOfferKey), findsOneWidget);
    });
```

**Atenção ao `refresh()`:** a `LevelSelectScreen` chama `walletProvider.notifier.refresh()` no `initState`, e a leitura é assíncrona. O `pumpAndSettle` de dentro de `pumpSelect` cobre isso, mas se um teste de saldo vier vazio, é aí que está — não no widget.

- [ ] **Step 3: Rodar e confirmar que falha**

Run: `flutter test test/features/game/presentation/level_select_screen_test.dart`
Expected: FAIL — a barra não está montada na tela, e `totalStarsKey` acha dois widgets.

- [ ] **Step 4: Enxugar o `CampaignHeader`**

Em `campaign_header.dart`: apagar a constante `totalStarsKey`, apagar a classe `_Stat` inteira, e trocar o `Row` do topo pelo título sozinho:

```dart
      child: Column(
        children: [
          // Só o nome do capítulo: o contador de estrelas migrou para a
          // `UserResourcesBar`, onde fica junto dos outros números que
          // descrevem o jogador. O que sobra aqui é a identidade do trecho
          // da campanha em que ele está.
          Text(
            l10n.chapterTitle(chapter),
            key: chapterLabelKey,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppFonts.display,
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
```

A barra de progresso e o resto do `build` ficam como estão. `totalStars` e `starTotal` continuam sendo parâmetros — é o que a barra mede.

Se algum import ficar sem uso (`l10n_labels.dart`, `AppColors`), remova-o: `flutter analyze` reclama de import morto.

- [ ] **Step 5: Montar a barra na tela**

Em `level_select_screen.dart`, acima do `CampaignHeader`:

```dart
                  UserResourcesBar(
                    totalStars: records.totalStars,
                    starTotal: kCampaignStarTotal,
                    onAddHammer: _openHammerOffer,
                  ),
                  const SizedBox(height: 10),
                  CampaignHeader(
```

E o método que abre o convite. **Ele não tem alvo para golpear** — o jogador está no mapa, não numa fase —, então o crédito é puro estoque:

```dart
  /// Abre o convite de aquisição de martelo a partir do mapa.
  ///
  /// Aqui não há alvo nem tabuleiro: o martelo entra como estoque e o jogador
  /// o gasta quando quiser, na fase que quiser. É o mesmo convite da partida,
  /// e é de propósito — dois modais para o mesmo item ensinariam que são dois
  /// itens.
  void _openHammerOffer() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => HammerOfferDialog(
        onGranted: () {
          Navigator.of(dialogContext).pop();
          // Sem partida no ar, o crédito é do inventário e nada mais
          // acontece. Quem grava é o wallet; o `refresh` seguinte confirma.
          ref.read(walletProvider.notifier).grantHammerFromMap();
        },
        onDecline: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }
```

**Isto exige um método novo no `WalletNotifier`** — a Fase A não tinha caminho para creditar martelo fora de uma partida, porque quem creditava era o `HammerBooster`. Acrescente em `wallet.dart`:

```dart
  /// Credita um martelo com nenhuma partida no ar.
  ///
  /// O caminho da partida passa por `HammerBooster.grantHammer`, que também
  /// bate no alvo guardado. A partir do mapa não há alvo nem tabuleiro, então
  /// o crédito é só estoque — e tem de ir ao disco por aqui, senão o martelo
  /// pago desapareceria ao abrir a próxima fase, que relê o disco.
  void grantHammerFromMap({int count = 1}) {
    if (count <= 0) return;

    state = state.copyWith(hammers: state.hammers + count);
    _persistHammers();
  }

  Future<void> _persistHammers() async {
    try {
      await _storage.writeHammerCount(state.hammers);
    } catch (error, stack) {
      debugPrint('Falha ao gravar o inventário de martelos: $error\n$stack');
    }
  }
```

E um teste para ele em `wallet_test.dart`:

```dart
    test('creditar martelo a partir do mapa grava no disco', () async {
      final storage = InMemoryGameStorage(hammerCount: 1);
      final wallet = WalletNotifier(storage: storage);
      await wallet.refresh();

      wallet.grantHammerFromMap();

      expect(wallet.state.hammers, 2);
      await Future<void>.delayed(Duration.zero);
      // Sem a gravação, a próxima fase releria o disco e o martelo pago
      // sumiria.
      expect(storage.hammerCount, 2);
    });
```

- [ ] **Step 6: Rodar os testes**

Run: `flutter test test/features/game/presentation/level_select_screen_test.dart test/features/game/providers/wallet_test.dart test/features/game/presentation/user_resources_bar_test.dart`
Expected: todos passam.

Run: `flutter test`
Expected: a suíte inteira volta ao verde — em particular os testes que usavam `totalStarsKey`, que agora acham a chave na barra.

- [ ] **Step 7: Commit**

```bash
git add lib/features/game/presentation/widgets/campaign_header.dart lib/features/game/presentation/screens/level_select_screen.dart lib/features/game/providers/wallet.dart test/features/game/presentation/level_select_screen_test.dart test/features/game/providers/wallet_test.dart
git commit -m "feat: o mapa monta a barra de recursos e pode comprar martelo fora da fase"
```

---

### Task 4: O Endless vira pílula

**Files:**
- Modify: `lib/features/game/presentation/widgets/endless_highlight.dart`
- Test: `test/features/game/presentation/endless_pill_test.dart`

**Interfaces:**
- Consumes: nada novo.
- Produces: `EndlessHighlight` com a **mesma** assinatura de hoje (`isUnlocked`, `unlockedAt`, `highScore`, `onTap`) e as três chaves preservadas: `endlessCardKey`, `endlessRecordKey`, `endlessCallToActionKey`.

**A migração de chave que importa:** hoje `endlessCallToActionKey` está num `GameButton` de linha própria. A pílula não tem espaço para ele, então a chave migra para o **chevron tocável** à direita. É por ela que um teste existente abre o Endless — sem a migração, uma mudança de layout quebraria um teste de regra e a falha diria a coisa errada.

- [ ] **Step 1: Escrever o teste que falha**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/presentation/widgets/endless_highlight.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

void main() {
  Future<void> pumpPill(
    WidgetTester tester, {
    required bool isUnlocked,
    int highScore = 1240,
    VoidCallback? onTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: EndlessHighlight(
            isUnlocked: isUnlocked,
            unlockedAt: 5,
            highScore: highScore,
            onTap: onTap ?? () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('cabe em 56pt de altura', (tester) async {
    // O cartão antigo gastava ~150pt antes de a trilha começar. A altura é o
    // ponto da mudança: é ela que devolve o centro da tela ao mapa.
    await pumpPill(tester, isUnlocked: true);

    final size = tester.getSize(find.byKey(endlessCardKey));
    expect(size.height, lessThanOrEqualTo(56));
  });

  testWidgets('destravada mostra o recorde e abre pelo chevron', (
    tester,
  ) async {
    var opened = 0;
    await pumpPill(tester, isUnlocked: true, onTap: () => opened++);

    expect(find.byKey(endlessRecordKey), findsOneWidget);

    await tester.tap(find.byKey(endlessCallToActionKey));
    await tester.pumpAndSettle();
    expect(opened, 1);
  });

  testWidgets('travada não abre nem mostra recorde', (tester) async {
    var opened = 0;
    await pumpPill(tester, isUnlocked: false, onTap: () => opened++);

    expect(find.byKey(endlessRecordKey), findsNothing);

    await tester.tap(find.byKey(endlessCardKey), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(opened, 0);
  });

  testWidgets('não estoura em tela estreita com recorde longo', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpPill(tester, isUnlocked: true, highScore: 9999999);

    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/features/game/presentation/endless_pill_test.dart`
Expected: FAIL no primeiro teste — a altura atual passa de 56pt.

- [ ] **Step 3: Reescrever como pílula**

Substituir o `build` de `EndlessHighlight` por uma linha única de altura fixa. Mantenha o `Opacity` da raiz para o estado travado (já existia, e este widget não é do tabuleiro), o `_handleTap` com `SystemSound`, e o `Container` com `endlessCardKey`:

```dart
  /// Altura fixa da pílula.
  ///
  /// Fixa e não intrínseca: a pílula divide o topo com a barra de recursos e o
  /// cabeçalho, e um elemento que cresce com o texto empurraria a trilha para
  /// baixo em cada idioma diferente.
  static const double height = 56;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Opacity(
      opacity: isUnlocked ? 1 : 0.55,
      child: Container(
        key: endlessCardKey,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFF2B1B4D), Color(0xFF11324A)],
          ),
          border: Border.all(
            color: isUnlocked
                ? AppColors.digit3.withValues(alpha: 0.75)
                : AppColors.darkBorder,
            width: 1.5,
          ),
          boxShadow: isUnlocked
              ? [
                  BoxShadow(
                    color: AppColors.digit3.withValues(alpha: 0.18),
                    blurRadius: 16,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              isUnlocked
                  ? Icons.workspace_premium_rounded
                  : Icons.lock_outline_rounded,
              color: isUnlocked ? AppColors.digit3 : Colors.white38,
              size: 24,
            ),
            const SizedBox(width: 10),
            // O título e o estado dividem a linha: numa pílula não há espaço
            // para duas linhas de texto, então o recorde vira o subtítulo do
            // próprio nome do modo.
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.endlessHighlightTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppFonts.display,
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  if (isUnlocked)
                    Text(
                      l10n.endlessBestScore(highScore),
                      key: endlessRecordKey,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.digit3,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else
                    Text(
                      l10n.endlessLockedHint(unlockedAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11.5,
                      ),
                    ),
                ],
              ),
            ),
            if (isUnlocked)
              // A chave migra do `GameButton` para cá: é por ela que o teste
              // abre o Endless, e a pílula não tem linha para um botão.
              Semantics(
                button: true,
                label: l10n.endlessCta,
                child: InkWell(
                  key: endlessCallToActionKey,
                  onTap: _handleTap,
                  borderRadius: BorderRadius.circular(999),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.digit3,
                      size: 26,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
```

O toque na pílula inteira continua abrindo o modo quando destravada — envolva o `Container` num `GestureDetector(onTap: isUnlocked ? _handleTap : null)`, ou mantenha o `Material`/`InkWell` de hoje ajustado ao novo raio. O import de `game_dialog.dart` provavelmente fica sem uso: remova-o.

- [ ] **Step 4: Rodar os testes**

Run: `flutter test test/features/game/presentation/endless_pill_test.dart test/features/game/presentation/level_select_screen_test.dart`
Expected: os 4 novos passam; os testes existentes que abrem o Endless por `endlessCallToActionKey` e `endlessCardKey` continuam passando.

- [ ] **Step 5: Commit**

```bash
git add lib/features/game/presentation/widgets/endless_highlight.dart test/features/game/presentation/endless_pill_test.dart
git commit -m "feat: Modo Recorde como pílula compacta, devolvendo a tela à trilha"
```

---

### Task 5: A trilha em três camadas

**Files:**
- Modify: `lib/features/game/presentation/widgets/saga_map.dart:339-399` (o `paint` de `_PathPainter`)
- Test: `test/features/game/presentation/saga_trail_test.dart`

**Interfaces:**
- Consumes: `SagaGeometry`, `AppColors.digit2`, `AppColors.digit7`.
- Produces: nada público — só muda a pintura.

**O que muda, e por quê:** hoje o trecho conquistado é um traço único de 14px com gradiente, e o trecho **jogável mas não conquistado** é um traço sólido de alfa 0.07 que percorre o mapa inteiro. O sólido cinza é justamente o que faz o caminho parecer apagado, competindo com o colorido. Passa a pontilhado, reusando o `_drawDashed` que já existe. Assim a gramática se unifica: **só o conquistado é sólido**, e travado e projetado se leem igual. O ganho é subtrativo.

O conquistado ganha três camadas: um traço largo desfocado (a luz que sangra), o corpo opaco, e um fio branco central — é o fio que faz a linha parecer energizada em vez de pintada.

- [ ] **Step 1: Escrever o teste que falha**

Teste de pintura verifica **quantas** operações de traço acontecem, o que é o que distingue uma camada de três:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/presentation/widgets/saga_map.dart';

void main() {
  Future<void> pumpTrail(WidgetTester tester, {required int progress}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SagaMapWidget(
              levels: kCampaign,
              progress: progress,
              starsOf: (_) => 3,
              onTapLevel: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('pinta em progresso parcial, com as três camadas ativas', (
    tester,
  ) async {
    // Progresso parcial é o único estado em que tudo coexiste: as três camadas
    // do conquistado, o pontilhado do trecho jogável que falta, e o pontilhado
    // dos nós projetados. É onde um `extractPath` mal calculado estoura.
    //
    // O veredito **visual** das três camadas é o golden da Task 8. Aqui não há
    // como afirmá-las sem um dublê de `Canvas` que conte `drawPath`, e o
    // projeto não tem esse dublê — construí-lo custaria mais do que o golden
    // entrega.
    await pumpTrail(tester, progress: 5);

    expect(tester.takeException(), isNull);
  });

  testWidgets('pinta sem exceção em progresso zero e completo', (tester) async {
    // Zero: nenhuma camada conquistada, só pontilhado. Completo: nenhum
    // pontilhado de trecho jogável, só o projetado. Os dois extremos são onde
    // um `extractPath` mal calculado estoura.
    await pumpTrail(tester, progress: 0);
    expect(tester.takeException(), isNull);

    await pumpTrail(tester, progress: kCampaign.last.number);
    expect(tester.takeException(), isNull);
  });
}
```

**Nota honesta ao implementador:** este teste é fraco de propósito — ele guarda contra exceção nos extremos, e o veredito visual das três camadas é o golden da Task 8. Não invente uma asserção de contagem de `drawPath` interceptando o `Canvas`: o projeto não tem esse dublê, e construí-lo custaria mais do que o golden entrega. Se você achar um jeito limpo de afirmar as três camadas, ótimo; se não, deixe assim e diga isso no relatório.

- [ ] **Step 2: Rodar e ver o estado atual**

Run: `flutter test test/features/game/presentation/saga_trail_test.dart`
Expected: PASS (a pintura atual já não estoura). O vermelho desta task é visual, e aparece na Task 8 quando o golden for comparado.

- [ ] **Step 3: Reescrever a pintura**

Em `_PathPainter.paint`, substituir o `track` sólido e o traço único do conquistado:

```dart
    final path = _fullPath();
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;

    // O trecho jogável ainda não conquistado passa a pontilhado, como o
    // projetado. Antes era um traço sólido de alfa 0.07 percorrendo o mapa
    // inteiro, e era ele que fazia o caminho parecer apagado: dois sólidos
    // concorrendo, um colorido e um cinza. Agora **só o conquistado é
    // sólido**, e "travado" e "por vir" se leem igual.
    _drawDashed(
      canvas,
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.09),
    );

    final segments = geometry.levelCount - 1;
    var doneSegments = clearedUpTo.clamp(0, segments).toDouble();

    if (revealTo != null && revealTo! > 0) {
      final target = revealTo!.clamp(0, segments).toDouble();
      doneSegments = math.min(doneSegments, target - 1 + revealProgress);
    }

    if (doneSegments <= 0) return;

    final done = metric.extractPath(0, metric.length * doneSegments / segments);
    final shader = const LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [AppColors.digit2, AppColors.digit7],
    ).createShader(Offset.zero & size);

    // Três camadas, de trás para frente. Nenhuma é dispensável: sem o halo a
    // linha não ilumina o fundo, sem o corpo ela não tem cor, e sem o fio
    // central ela parece pintada em vez de energizada.
    canvas.drawPath(
      done,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..strokeCap = StrokeCap.round
        ..shader = shader
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );

    canvas.drawPath(
      done,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..shader = shader,
    );

    canvas.drawPath(
      done,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.5),
    );
```

`shouldRepaint` não muda: as três camadas derivam dos mesmos campos já declarados.

- [ ] **Step 4: Rodar os testes**

Run: `flutter test test/features/game/presentation/saga_trail_test.dart test/features/game/presentation/saga_map_test.dart test/features/game/presentation/saga_map_pulse_test.dart`
Expected: PASS. O golden `saga_map_golden_test.dart` **vai falhar** — é esperado e a Task 8 o regenera. Não regenere agora: o fundo e o baú ainda vão mudar, e regerar duas vezes esconde uma das mudanças.

- [ ] **Step 5: Commit**

```bash
git add lib/features/game/presentation/widgets/saga_map.dart test/features/game/presentation/saga_trail_test.dart
git commit -m "feat: trilha da saga em três camadas, com o trecho travado pontilhado"
```

---

### Task 6: O nó do baú no fim da trilha

**Files:**
- Create: `lib/features/game/presentation/widgets/chapter_chest.dart`
- Modify: `lib/features/game/presentation/widgets/saga_map.dart:201-233` (`_comingSoonLabel` sai) e a lista de `children` do `Stack`
- Modify: `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb`
- Test: `test/features/game/presentation/chapter_chest_test.dart`

**Interfaces:**
- Consumes: `walletProvider`, `Wallet.hasClaimedChest`, `WalletNotifier.claimChapterChest`, `kChapterChestReward` (Fase A); `SagaGeometry`; `kChapters`.
- Produces: `ChapterChest({required int chapter, required int reward, required bool isUnlocked, required bool isClaimed, required VoidCallback onClaim})`; chaves `chapterChestKey`, `chapterChestClaimKey`. `SagaMapWidget` ganha o parâmetro `chestSlot` (um `Widget?`), montado pela tela.

**Por que a tela monta o baú, e não o mapa:** `SagaMapWidget` é `StatelessWidget` sem `ref`, e ler o wallet aqui o tornaria um `ConsumerWidget` só por causa de um nó decorativo. A tela já lê `campaignProgressProvider` e `walletProvider`; ela passa o widget pronto, e o mapa só o posiciona. O mapa continua responsável pela **geometria** — que é a única coisa que ele sabe e a tela não.

- [ ] **Step 1: Adicionar os textos**

Em `app_pt.arb`:

```json
  "chestLocked": "Conclua o Capítulo {chapter}",
  "@chestLocked": {
    "description": "Dica sob o baú trancado no fim da trilha.",
    "placeholders": { "chapter": { "type": "int" } }
  },
  "chestReady": "Recompensa liberada!",
  "@chestReady": { "description": "O baú pode ser aberto." },
  "chestClaimed": "Recompensa recebida",
  "@chestClaimed": { "description": "O baú já foi aberto." },
  "chestRewardSemantics": "Baú do Capítulo {chapter}, {amount} moedas",
  "@chestRewardSemantics": {
    "description": "Descrição do baú para leitor de tela.",
    "placeholders": {
      "chapter": { "type": "int" },
      "amount": { "type": "int" }
    }
  },
```

Em `app_en.arb`:

```json
  "chestLocked": "Finish Chapter {chapter}",
  "@chestLocked": {
    "description": "Hint under the locked chest at the end of the trail.",
    "placeholders": { "chapter": { "type": "int" } }
  },
  "chestReady": "Reward unlocked!",
  "@chestReady": { "description": "The chest can be opened." },
  "chestClaimed": "Reward collected",
  "@chestClaimed": { "description": "The chest was already opened." },
  "chestRewardSemantics": "Chapter {chapter} chest, {amount} coins",
  "@chestRewardSemantics": {
    "description": "Chest description for screen readers.",
    "placeholders": {
      "chapter": { "type": "int" },
      "amount": { "type": "int" }
    }
  },
```

Run: `flutter gen-l10n`

**O `chapterComingSoon` fica no `.arb`**, sem uso por enquanto: removê-lo é mudança de tradução para ganhar nada, e ele volta a servir no dia em que houver um capítulo 3 anunciado.

- [ ] **Step 2: Escrever o teste que falha**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/presentation/widgets/chapter_chest.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

void main() {
  Future<void> pumpChest(
    WidgetTester tester, {
    required bool isUnlocked,
    required bool isClaimed,
    VoidCallback? onClaim,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: ChapterChest(
              chapter: 2,
              reward: kChapterChestReward,
              isUnlocked: isUnlocked,
              isClaimed: isClaimed,
              onClaim: onClaim ?? () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('trancado mostra o prêmio e não aceita toque', (tester) async {
    // O prêmio visível é o que transforma o cadeado em promessa. Um baú que
    // não diz o que tem dentro é só um enfeite trancado.
    var claims = 0;
    await pumpChest(
      tester,
      isUnlocked: false,
      isClaimed: false,
      onClaim: () => claims++,
    );

    expect(find.text('${kChapterChestReward}'), findsOneWidget);

    await tester.tap(find.byKey(chapterChestKey), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(claims, 0);
  });

  testWidgets('liberado aceita o toque uma vez', (tester) async {
    var claims = 0;
    await pumpChest(
      tester,
      isUnlocked: true,
      isClaimed: false,
      onClaim: () => claims++,
    );

    await tester.tap(find.byKey(chapterChestClaimKey));
    await tester.pumpAndSettle();

    expect(claims, 1);
  });

  testWidgets('já recebido não aceita toque', (tester) async {
    var claims = 0;
    await pumpChest(
      tester,
      isUnlocked: true,
      isClaimed: true,
      onClaim: () => claims++,
    );

    expect(find.byKey(chapterChestClaimKey), findsNothing);

    await tester.tap(find.byKey(chapterChestKey), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(claims, 0);
  });

  testWidgets('a animação de destaque termina', (tester) async {
    // `pumpAndSettle` acima já garantiria isso, mas o caso liberado é o que
    // tem animação: uma repetição infinita aqui derrubaria toda a suíte de
    // widget do projeto, e o teste existe para nomear o motivo.
    await pumpChest(tester, isUnlocked: true, isClaimed: false);

    expect(tester.hasRunningAnimations, isFalse);
  });
}
```

- [ ] **Step 3: Rodar e confirmar que falha**

Run: `flutter test test/features/game/presentation/chapter_chest_test.dart`
Expected: FAIL — `chapter_chest.dart` não existe.

- [ ] **Step 4: Implementar o baú**

Criar `lib/features/game/presentation/widgets/chapter_chest.dart`. Três estados: trancado (cadeado + prêmio fosco), liberado (dourado, com um brilho que **dá duas batidas e descansa**) e recebido (baú aberto, apagado).

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Chave do nó do baú.
const Key chapterChestKey = Key('chapter_chest');

/// Chave da área tocável que reclama a recompensa.
const Key chapterChestClaimKey = Key('chapter_chest_claim');

/// O baú de fim de capítulo, no topo da trilha.
///
/// Substitui o rótulo "Capítulo N: Em Breve!". O texto era honesto mas inerte:
/// dizia que não havia mais nada e não dava motivo para voltar. O baú diz a
/// mesma coisa (o capítulo seguinte não existe ainda) **e** dá um objetivo ao
/// trecho que existe — fechar o capítulo tem prêmio, e o prêmio está à vista.
class ChapterChest extends StatefulWidget {
  const ChapterChest({
    super.key,
    required this.chapter,
    required this.reward,
    required this.isUnlocked,
    required this.isClaimed,
    required this.onClaim,
  });

  final int chapter;

  /// Moedas que o baú paga.
  final int reward;

  /// Todas as fases do capítulo foram vencidas.
  final bool isUnlocked;

  /// Já foi aberto — e não pode pagar de novo.
  final bool isClaimed;

  final VoidCallback onClaim;

  @override
  State<ChapterChest> createState() => _ChapterChestState();
}

class _ChapterChestState extends State<ChapterChest>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine;

  /// Duas batidas e descansa aceso.
  ///
  /// Finita de propósito: uma animação em repetição faria `pumpAndSettle`
  /// nunca terminar e derrubaria a suíte de widget inteira. É a mesma decisão
  /// do aro pulsante da mira do martelo.
  static const int _beats = 2;

  @override
  void initState() {
    super.initState();
    _shine = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    if (widget.isUnlocked && !widget.isClaimed) _shine.forward();
  }

  @override
  void didUpdateWidget(ChapterChest old) {
    super.didUpdateWidget(old);
    // Liberar o baú durante a sessão (o jogador voltou de vencer a última fase
    // do capítulo) tem de acender o brilho — senão o prêmio abre sem que nada
    // na tela diga que algo mudou.
    final becameReady =
        widget.isUnlocked && !widget.isClaimed && (old.isClaimed || !old.isUnlocked);
    if (becameReady) _shine.forward(from: 0);
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  bool get _canClaim => widget.isUnlocked && !widget.isClaimed;

  void _claim() {
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
    widget.onClaim();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = _canClaim ? AppColors.digit3 : Colors.white38;

    final chest = AnimatedBuilder(
      animation: _shine,
      builder: (context, child) {
        // Duas batidas: o seno completo duas vezes no curso do controlador, e
        // o valor final volta a zero, deixando o baú aceso em repouso.
        final beat = _canClaim
            ? (0.5 + 0.5 * math.sin(_shine.value * _beats * 2 * math.pi))
            : 0.0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.black.withValues(alpha: 0.4),
            border: Border.all(color: accent.withValues(alpha: 0.7), width: 2),
            boxShadow: _canClaim
                ? [
                    BoxShadow(
                      color: AppColors.digit3.withValues(
                        alpha: 0.18 + 0.22 * beat,
                      ),
                      blurRadius: 18 + 10 * beat,
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.isClaimed
                ? Icons.inventory_2_rounded
                : (widget.isUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded),
            color: accent,
            size: 30,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.monetization_on_rounded,
                color: accent,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                '${widget.reward}',
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  color: _canClaim ? Colors.white : Colors.white54,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.isClaimed
                ? l10n.chestClaimed
                : (widget.isUnlocked
                      ? l10n.chestReady
                      : l10n.chestLocked(widget.chapter)),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.display,
              color: _canClaim
                  ? AppColors.digit3
                  : Colors.white.withValues(alpha: 0.38),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );

    return Semantics(
      key: chapterChestKey,
      label: l10n.chestRewardSemantics(widget.chapter, widget.reward),
      excludeSemantics: true,
      button: _canClaim,
      child: _canClaim
          ? InkWell(
              key: chapterChestClaimKey,
              onTap: _claim,
              borderRadius: BorderRadius.circular(18),
              child: chest,
            )
          : chest,
    );
  }
}
```

Adicione `import 'dart:math' as math;` no topo.

- [ ] **Step 5: Trocar o rótulo pelo baú no mapa**

Em `saga_map.dart`: apagar `_comingSoonLabel` e o import de `AppLocalizations` se ficar sem uso; acrescentar o parâmetro e o posicionamento:

```dart
  /// O baú de fim de capítulo, montado pela tela.
  ///
  /// Vem pronto de fora porque depende do saldo do jogador, e o mapa é
  /// `StatelessWidget` sem `ref`: torná-lo `ConsumerWidget` por causa de um nó
  /// decorativo espalharia a leitura de carteira por dentro do desenho da
  /// trilha. O que o mapa sabe e a tela não é **onde** o nó cabe.
  final Widget? chestSlot;
```

E no `Stack`, no lugar da chamada a `_comingSoonLabel`:

```dart
              if (chestSlot case final chest?)
                Positioned(
                  left: 0,
                  right: 0,
                  // Acima do último nó projetado, com folga para não encostar
                  // no círculo — a mesma âncora que o rótulo usava.
                  top:
                      geometry.centerOf(geometry.lastIndex).dy -
                      SagaGeometry.pinSize * 1.4,
                  child: Center(child: chest),
                ),
```

Na `LevelSelectScreen`, montar o baú e ligar o crédito:

```dart
                        chestSlot: ChapterChest(
                          chapter: kChapters.last.number,
                          reward: kChapterChestReward,
                          isUnlocked: progress >= kChapters.last.lastLevel,
                          isClaimed: wallet.hasClaimedChest(
                            kChapters.last.number,
                          ),
                          onClaim: () => ref
                              .read(walletProvider.notifier)
                              .claimChapterChest(kChapters.last.number),
                        ),
```

`wallet` sai de `ref.watch(walletProvider)` — a tela já vai ter essa leitura por causa da barra de recursos; **não faça uma segunda**.

- [ ] **Step 6: Rodar os testes**

Run: `flutter test test/features/game/presentation/chapter_chest_test.dart test/features/game/presentation/saga_map_test.dart test/features/game/presentation/level_select_screen_test.dart`
Expected: os 4 novos passam; os do mapa continuam passando. Se algum teste procurava o texto "Em Breve", ele vai falhar — atualize-o para procurar o baú, e diga isso no relatório.

- [ ] **Step 7: Commit**

```bash
git add lib/features/game/presentation/widgets/chapter_chest.dart lib/features/game/presentation/widgets/saga_map.dart lib/features/game/presentation/screens/level_select_screen.dart lib/l10n test/features/game/presentation/chapter_chest_test.dart
git commit -m "feat: baú de fim de capítulo no lugar do rótulo Em Breve"
```

---

### Task 7: AppIcon — corrigir o `9`, promover o anel e adicionar glow

> **SUPERADA depois de executada.** Os steps abaixo foram cumpridos e a arte
> resultante (anel como moldura, `9` geométrico, halo ciano) foi **substituída
> em seguida** por um conceito novo: uma peça 3D do jogo com o dígito, decidido
> pelo dono do produto. O que sobrevive desta task é o diagnóstico do glifo —
> a régua de anatomia e os becos sem saída (`g`, `q`, `a`) estão consolidados
> no `CLAUDE.md`, seção "AppIcon: peça 3D com o `9`". Não reexecute os steps:
> eles descrevem uma arte que não existe mais.

**Files:**
- Modify: `assets/images/logo.svg`
- Regenerate: `assets/images/logo.png`, `assets/icon/*`, ícones nativos de Android e iOS
- Test: nenhum automatizado (ver nota)

**Interfaces:**
- Consumes: nada.
- Produces: `logo.svg` como fonte da verdade, já é.

**Por que não há teste:** `logo.svg` não é renderizado em lugar nenhum do app (`grep` por `SvgPicture` em `lib/` volta vazio) — é exclusivamente a origem do ícone. Nenhum golden depende dele, e um teste de imagem de ícone mediria o `rsvg-convert`, não o jogo. A verificação é visual e está no Step 5.

- [x] **Step 1: Corrigir a forma do `9`**

O glifo atual (`logo.svg`, os dois `<path>` dentro do `<g filter="url(#drop-shadow)">`) tem uma perna que varre de cima-direita para baixo-**esquerda**, terminando em `M 175 376`. Essa é a cauda de um `g`, não o descendente de um `9`. No tamanho atual passa como ambiguidade; ampliado 160% o erro fica inequívoco.

Substituir os dois paths por um `9` geométrico: bowl de r=92 centrado em (250,186), contra-forma de r=38 aberta com `fill-rule="evenodd"`, e descendente **reto** de 50px de largura descendo pela borda direita do bowl até y=424, com pé quase quadrado (r=10).

Duas alternativas foram descartadas, e vale não repeti-las:
- Bowl grande (r=104) com descendente curto lê como **`q`** — o descendente parece perna solta em vez de continuação do bowl.
- Descendente com flexão para a esquerda no pé volta a ler como **`g`**, que é exatamente o defeito sendo corrigido.

O que resolve é bowl compacto com descendente proporcionalmente longo, e contra-forma pequena o bastante para o traço do bowl ter peso.

- [x] **Step 2: Promover o anel a moldura**

Escalar só o símbolo era geometricamente impossível: o `9` a 160% mede 352px de altura e o anel tem 290px de diâmetro (`r=145`) — o símbolo transbordaria o anel e desfaria a composição. As duas mudanças são uma decisão só.

O `<circle>` do anel passa a `r="212"` com `stroke-width="18"`, junto à borda, funcionando como moldura em vez de contorno do símbolo. As quatro partículas se reposicionam nos cantos que a moldura deixa livres.

- [x] **Step 3: Adicionar o filtro de glow**

Um filtro novo, `nine-glow`, aplicado ao grupo do `9`, empilhando três efeitos:

```xml
    <filter id="nine-glow" x="-50%" y="-50%" width="200%" height="200%">
      <!-- Dilata o alfa antes de desfocar: sem isso o halo nasce dentro da
           silhueta e o desfoque só amolece a borda, em vez de vazar luz. -->
      <feMorphology in="SourceAlpha" operator="dilate" radius="6" result="fat"/>
      <feGaussianBlur in="fat" stdDeviation="12" result="halo"/>
      <feFlood flood-color="#00E5FF" flood-opacity="0.85" result="tint"/>
      <feComposite in="tint" in2="halo" operator="in" result="glow"/>
      <feDropShadow dx="0" dy="14" stdDeviation="12" flood-color="#000000"
                   flood-opacity="0.7" result="grounded"/>
      <feMerge>
        <feMergeNode in="glow"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
```

Os dois últimos efeitos são complementares e **nenhum é dispensável**: o halo ciano é o que salva o ícone em papel de parede **escuro** — o caso que o `drop-shadow` atual não cobre, porque sombra sobre fundo escuro é invisível — e a sombra é o que salva em papel de parede **claro**. Um só dos dois falharia em metade dos aparelhos.

- [x] **Step 4: Regenerar**

```bash
cd /Users/cleber/projects/nine_fuse
rsvg-convert -w 1024 -h 1024 assets/images/logo.svg -o assets/images/logo.png
dart run flutter_launcher_icons
```

O `pubspec` **não muda**: `image_path` e `adaptive_icon_foreground` continuam apontando para `assets/images/logo.png`, porque a composição foi escolhida contra a máscara circular do ícone adaptativo.

- [x] **Step 5: Verificar visualmente, e é obrigatório**

Abra `assets/images/logo.png` e confira, nesta ordem:

1. **O glifo lê como `9`?** Se você hesitar entre `9` e `g`, ele falhou — refaça o descendente antes de seguir.
2. **A margem interna sumiu sem cortar nada?** Renderize sob um recorte circular de 66% (a máscara do ícone adaptativo do Android) e confirme que nem o `9` nem o anel são decepados.
3. **O halo aparece sobre fundo escuro?** Ponha o PNG sobre um retângulo `#0A0910` e confirme que a silhueta se separa.

Diga no relatório o que você viu em cada um dos três. "Regenerei os ícones" não é verificação.

- [x] **Step 6: Commit**

```bash
git add assets/images/logo.svg assets/images/logo.png assets/icon android/app/src/main/res ios/Runner/Assets.xcassets
git commit -m "feat: AppIcon com o 9 corrigido, anel como moldura e halo ciano"
```

---

### Task 8: Fechamento — goldens, responsividade e registro

**Files:**
- Modify: `test/features/game/presentation/goldens/saga_map.png` (regerado)
- Modify: `test/features/game/presentation/level_select_screen_test.dart` (testes de proporção)
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes: tudo das Tasks 1-7.

- [ ] **Step 1: Testes de responsividade**

Acrescentar em `level_select_screen_test.dart` — as duas proporções extremas que o pedido nomeia:

```dart
    for (final (name, size) in const [
      ('iPhone SE', Size(320, 568)),
      ('iPhone Pro Max', Size(430, 932)),
    ]) {
      testWidgets('o mapa não estoura em $name', (tester) async {
        // Sem mexer em `tester.view` aqui: `pumpSelect` já faz isso, com o
        // `addTearDown(tester.view.reset)` junto. Fixar o tamanho duas vezes
        // funcionaria, mas espalharia a responsabilidade por dois lugares.

        // Saldo grande e campanha completa: é o estado que ocupa mais
        // largura na barra de recursos e acende o baú ao mesmo tempo.
        storage.coins = 999999;
        storage.hammerCount = 99;
        storage.campaignProgress = kCampaign.last.number;

        // O tamanho vai pelo parâmetro que a Task 3 acrescentou a
        // `pumpSelect`: ele fixa 1200x2600 por padrão, e sem o parâmetro
        // atropelaria justamente a proporção que este teste quer medir.
        await pumpSelect(tester, size: size);

        expect(tester.takeException(), isNull);
      });
    }
```

Run: `flutter test test/features/game/presentation/level_select_screen_test.dart`
Expected: PASS. Se estourar, o culpado provável é a barra de recursos em 320pt — o remédio é o `Flexible` do badge, não encolher fonte.

- [ ] **Step 2: Regenerar o golden do mapa**

```bash
flutter test --update-goldens test/features/game/presentation/saga_map_golden_test.dart
```

- [ ] **Step 3: Olhar a imagem nova, e é obrigatório**

Abra `test/features/game/presentation/goldens/saga_map.png` e confirme, item por item: o gradiente do fundo com a grade fosca; a trilha conquistada com halo, corpo e fio central; o trecho travado pontilhado; o baú no topo. **Não aceite a imagem sem olhar** — um golden regenerado no escuro registra como correto qualquer regressão que tenha entrado junto.

Se algo estiver errado, volte à task responsável em vez de aceitar o golden.

- [ ] **Step 4: Verificação completa**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: tudo passa.

- [ ] **Step 5: Registrar no `CLAUDE.md`**

Acrescentar `### Polimento do Menu e AppIcon ✅ Concluída`, no estilo do arquivo (prosa, negrito abrindo cada parágrafo, o **porquê** e o que aconteceria de outro jeito). Cobrir no mínimo:

- Por que o contador de estrelas mudou de casa e de forma (ao lado de dois recursos gastáveis, um número solto se lia como um terceiro).
- Por que a moeda não tem `+` e o martelo tem.
- Por que a pílula tem altura **fixa** e não intrínseca.
- Por que a chave `endlessCallToActionKey` migrou para o chevron (é por ela que um teste de regra abre o modo).
- Por que **só o conquistado é sólido** na trilha, e que o ganho foi subtrativo.
- Por que o baú substituiu um texto honesto, e por que ele é montado pela tela e posicionado pelo mapa.
- Por que a textura do fundo é estática com semente fixa, e por que o brilho do baú dá duas batidas — a armadilha do `pumpAndSettle`, pela terceira vez no projeto.
- Que o `9` do logo lia como `g`, e que corrigir a forma e promover o anel eram a mesma decisão que ampliar.
- Que `chapterComingSoon` continua no `.arb` sem uso, de propósito.

- [ ] **Step 6: Commit**

```bash
git add test CLAUDE.md
git commit -m "test: goldens e responsividade do mapa; docs: registra o polimento do menu"
```

---

## O que NÃO entra nesta fase

- **Um baú por capítulo.** Só o do último capítulo existe. Um baú após a fase 6 exigiria abrir espaço no meio da `SagaGeometry`, o que é reestruturação de trilha.
- **`ObstacleOverlay`.** A translucidez das coberturas é a mecânica funcionando, não defeito de renderização — decisão registrada duas vezes no `CLAUDE.md`.
- **Os três itens de gameplay do pedido original** (spacing do booster, `BackdropFilter` da mira, gradiente dos cards de métrica): já estavam implementados antes da Fase A.
- **Intersticiais, cap de 3 martelos/dia, No-Ads Pass e Bônus Diário VIP.** Continuam fora, como já estavam.
- **SFX.** Não há motor de áudio no projeto; o baú usa som de sistema e tato, como o resto.
