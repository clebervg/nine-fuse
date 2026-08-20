# Splash Screen Animada Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adicionar uma tela `SplashScreen` animada em Flutter, exibida entre a
splash nativa existente e `LevelSelectScreen`, usando o ícone já existente do
app (peça 9 dourada) com staging de entrada, power-up, idle e saída.

**Architecture:** Um único `StatefulWidget` com um `AnimationController` de
1800ms cuja timeline é fatiada em 4 estágios via frações do valor do
controller (sem `AnimationController`s adicionais nem Timers). Ao completar,
chama `onSplashComplete` (default: navega para `LevelSelectScreen`).
`main.dart` passa a apontar `MaterialApp.home` para `SplashScreen`.

**Tech Stack:** Flutter/Dart puro (sem pacote de animação novo — `AnimationController` +
`AnimatedBuilder`/`Transform`/`Opacity`, já usados em todo o resto do projeto).

## Global Constraints

- Não usar `Future.delayed` em widgets de UI; usar `AnimationController`
  (regra do `CLAUDE.md` do projeto).
- Nenhuma animação pode ficar em loop infinito — precisa de duração finita,
  senão `pumpAndSettle` trava a suíte (convenção já registrada no projeto).
- Não alterar a splash nativa (`flutter_native_splash`, `main.dart:24` e `:69`).
- Reaproveitar `assets/images/logo.png` (já registrado em `pubspec.yaml` via
  `assets/images/`), `AppColors` (`lib/core/constants/app_colors.dart`) e
  `AppFonts.display` (`lib/core/theme/app_fonts.dart`) — nenhum asset novo.
- Responsivo: tamanhos derivados de `MediaQuery`, sem pixels fixos para o
  logo/anéis.

---

### Task 1: `SplashScreen` widget com animação em estágios

**Files:**
- Create: `lib/features/game/presentation/screens/splash_screen.dart`
- Test: `test/features/game/presentation/splash_screen_test.dart`

**Interfaces:**
- Produces: `class SplashScreen extends StatefulWidget` com construtor
  `const SplashScreen({super.key, this.onSplashComplete})` e campo
  `final VoidCallback? onSplashComplete;`. Também exporta
  `const Duration kSplashDuration = Duration(milliseconds: 1800);` no topo do
  arquivo, usada pelo teste para controlar o `pump`.
- Consumes: `LevelSelectScreen` (`lib/features/game/presentation/screens/level_select_screen.dart`),
  `AppColors` (`lib/core/constants/app_colors.dart`), `AppFonts`
  (`lib/core/theme/app_fonts.dart`).

- [ ] **Step 1: Escrever o teste de callback customizado (sem navegação)**

Cria `test/features/game/presentation/splash_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/presentation/screens/level_select_screen.dart';
import 'package:nine_fuse/features/game/presentation/screens/splash_screen.dart';
import 'package:nine_fuse/features/game/providers/campaign_records.dart';
import 'package:nine_fuse/features/game/providers/endless_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';

import '../../../support/localized.dart';

void main() {
  testWidgets('chama onSplashComplete ao fim da animação, em vez de navegar',
      (tester) async {
    var completed = false;

    await tester.pumpWidget(
      localizedApp(
        home: SplashScreen(onSplashComplete: () => completed = true),
      ),
    );

    expect(completed, isFalse);

    await tester.pump(kSplashDuration);

    expect(completed, isTrue);
    expect(find.byType(LevelSelectScreen), findsNothing);
  });
}
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `flutter test test/features/game/presentation/splash_screen_test.dart`
Expected: FAIL — `Error: Target of URI doesn't exist:
'package:nine_fuse/features/game/presentation/screens/splash_screen.dart'`
(o arquivo ainda não existe).

- [ ] **Step 3: Criar `SplashScreen` com a timeline completa**

Cria `lib/features/game/presentation/screens/splash_screen.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/features/game/presentation/screens/level_select_screen.dart';

/// Duração total da animação de entrada da splash.
const Duration kSplashDuration = Duration(milliseconds: 1800);

/// Tela de abertura animada, exibida uma única vez entre a splash nativa
/// (`flutter_native_splash`, ver `main.dart`) e o menu de fases.
///
/// Reaproveita o ícone já existente do app (a peça 9 dourada) em vez de criar
/// uma identidade visual nova — ver
/// `docs/superpowers/specs/2026-08-20-splash-screen-design.md`.
///
/// Toda a timeline roda num único `AnimationController`, fatiado em estágios
/// por fração do valor do controller (entrada, power-up, idle, saída) — não
/// em `Future.delayed` nem em controllers separados, e a duração é finita
/// para não travar `pumpAndSettle` em teste.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.onSplashComplete});

  /// Chamado quando a animação termina. Por padrão navega para
  /// [LevelSelectScreen]; testes podem substituir para observar o fim sem
  /// depender de navegação.
  final VoidCallback? onSplashComplete;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // Fronteiras dos estágios, como frações do controller (0..1) — ver spec.
  static const double _entranceEnd = 0.22;
  static const double _powerUpEnd = 0.44;
  static const double _idleEnd = 0.78;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: kSplashDuration)
      ..addStatusListener(_onStatusChanged)
      ..forward();
  }

  void _onStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final onComplete = widget.onSplashComplete;
    if (onComplete != null) {
      onComplete();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LevelSelectScreen()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Progresso (0..1) dentro da janela [start, end] do controller.
  double _stageT(double start, double end) {
    final t = _controller.value;
    if (t <= start) return 0;
    if (t >= end) return 1;
    return (t - start) / (end - start);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final entrance = Curves.easeOut.transform(_stageT(0, _entranceEnd));
    final powerUp = _stageT(_entranceEnd, _powerUpEnd);
    final idle = _stageT(_powerUpEnd, _idleEnd);
    final exit = _stageT(_idleEnd, 1.0);

    final logoScale = 0.7 + 0.3 * entrance;
    final logoOpacity = entrance;

    // Pisca 2x rápido dentro do estágio power-up, e assenta aceso.
    final glowOpacity = powerUp >= 1.0 ? 1.0 : math.sin(powerUp * math.pi * 4).abs();

    // Gira rápido e desacelera (ease-out) dentro do estágio power-up.
    final ringRotation = (1 - math.pow(1 - powerUp, 3)) * math.pi * 2;

    final exitScale = 1.0 + 0.15 * exit;
    final exitOpacity = 1.0 - exit;

    final size = MediaQuery.of(context).size;
    final logoSize = math.min(size.width, size.height) * 0.4;
    final haloSize = logoSize * 1.6;

    return Opacity(
      opacity: exitOpacity,
      child: Transform.scale(
        scale: exitScale,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: haloSize,
                height: haloSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.rotate(
                      angle: ringRotation,
                      child: _ring(haloSize, AppColors.digit5),
                    ),
                    Transform.rotate(
                      angle: -ringRotation * 0.6,
                      child: _ring(haloSize * 0.8, AppColors.digit4),
                    ),
                    Opacity(
                      opacity: glowOpacity,
                      child: Container(
                        width: logoSize * 1.1,
                        height: logoSize * 1.1,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.digit9.withOpacity(0.6),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                    ClipOval(
                      child: SizedBox(
                        width: logoSize,
                        height: logoSize,
                        child: Opacity(
                          opacity: logoOpacity,
                          child: Transform.scale(
                            scale: logoScale,
                            child: Image.asset('assets/images/logo.png'),
                          ),
                        ),
                      ),
                    ),
                    if (idle > 0 && idle < 1) _shimmer(logoSize, idle),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Opacity(
                opacity: powerUp.clamp(0.0, 1.0),
                child: const Text(
                  'NineFuse',
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: haloSize,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: idle,
                    minHeight: 4,
                    backgroundColor: AppColors.darkSurface,
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.digit9),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ring(double diameter, Color color) => Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: [
              color.withOpacity(0.0),
              color.withOpacity(0.8),
              color.withOpacity(0.0),
            ],
          ),
        ),
      );

  /// Faixa diagonal translúcida cruzando o logo uma vez, de fora a fora,
  /// durante o estágio idle.
  Widget _shimmer(double diameter, double idle) {
    final dx = (idle * 2 - 0.5) * diameter;
    return ClipOval(
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: diameter * 0.25,
              height: diameter * 2,
              color: Colors.white.withOpacity(0.12),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Rodar o teste do Step 1 e confirmar que passa**

Run: `flutter test test/features/game/presentation/splash_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Escrever o teste do caminho padrão (navegação real)**

Adiciona ao mesmo arquivo, dentro do `main()`, depois do teste já existente
(mesmo padrão de `ProviderContainer` com `InMemoryGameStorage` usado em
`test/features/game/presentation/level_select_screen_test.dart:69-90`, porque
`LevelSelectScreen` lê `endlessProvider`/`campaignProgressProvider`/
`campaignRecordsProvider`/`endlessHighScoreProvider`):

```dart
  testWidgets('navega para LevelSelectScreen ao fim da animação por padrão',
      (tester) async {
    final storage = InMemoryGameStorage();
    final container = ProviderContainer(
      overrides: [
        endlessProvider.overrideWith(
          (ref) => EndlessNotifier(storage: storage),
        ),
        campaignProgressProvider.overrideWith(
          (ref) => CampaignProgress(storage: storage),
        ),
        campaignRecordsProvider.overrideWith(
          (ref) => CampaignRecords(storage: storage),
        ),
        endlessHighScoreProvider.overrideWith(
          (ref) => EndlessHighScore(storage: storage),
        ),
      ],
    );
    addTearDown(container.dispose);

    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(home: const SplashScreen()),
      ),
    );

    expect(find.byType(LevelSelectScreen), findsNothing);

    await tester.pumpAndSettle();

    expect(find.byType(LevelSelectScreen), findsOneWidget);
  });
```

Se `EndlessNotifier` exigir um parâmetro `random:` nomeado (como em
`level_select_screen_test.dart:75-77`), ajustar a chamada para
`EndlessNotifier(random: Random(1), storage: storage)` e adicionar
`import 'dart:math';` no topo do arquivo de teste — confirmar a assinatura
correta lendo `lib/features/game/providers/endless_notifier.dart` antes de
rodar, já que essa assinatura pertence a um arquivo fora deste plano.

- [ ] **Step 6: Rodar a suíte completa do arquivo e confirmar que os dois testes passam**

Run: `flutter test test/features/game/presentation/splash_screen_test.dart`
Expected: PASS (2 testes)

- [ ] **Step 7: Rodar `flutter analyze` para garantir que não há warnings novos**

Run: `flutter analyze lib/features/game/presentation/screens/splash_screen.dart test/features/game/presentation/splash_screen_test.dart`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/features/game/presentation/screens/splash_screen.dart test/features/game/presentation/splash_screen_test.dart
git commit -m "feat: adiciona SplashScreen animada"
```

---

### Task 2: Ligar `SplashScreen` como tela inicial do app

**Files:**
- Modify: `lib/main.dart:120` (`home: const LevelSelectScreen()`)
- Test: `test/main_test.dart` (criar, se não existir um teste de `NineFuseApp`
  hoje — confirmar com `ls test/main_test.dart` antes de escrever; se já
  existir um teste de `NineFuseApp` em outro arquivo, adicionar o teste lá em
  vez de criar um novo arquivo)

**Interfaces:**
- Consumes: `SplashScreen` (`lib/features/game/presentation/screens/splash_screen.dart`,
  Task 1).

- [ ] **Step 1: Verificar se já existe teste cobrindo `NineFuseApp.home`**

Run: `grep -rn "NineFuseApp" test/`

Se o grep não retornar nada, criar `test/main_test.dart` no Step 2. Se
retornar um arquivo existente, adicionar o teste do Step 2 nesse arquivo em
vez de criar um novo.

- [ ] **Step 2: Escrever o teste que falha (home é SplashScreen, não
  LevelSelectScreen)**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/presentation/screens/level_select_screen.dart';
import 'package:nine_fuse/features/game/presentation/screens/splash_screen.dart';
import 'package:nine_fuse/main.dart';

void main() {
  testWidgets('abre em SplashScreen, não direto em LevelSelectScreen',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: NineFuseApp()),
    );

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(LevelSelectScreen), findsNothing);
  });
}
```

- [ ] **Step 3: Rodar o teste e confirmar que falha**

Run: `flutter test test/main_test.dart`
Expected: FAIL — `find.byType(SplashScreen)` não encontra nada, porque
`home:` ainda é `LevelSelectScreen`.

- [ ] **Step 4: Trocar a tela inicial em `main.dart`**

Em `lib/main.dart`, adicionar o import e trocar `home:`:

```dart
import 'package:nine_fuse/features/game/presentation/screens/splash_screen.dart';
```

E na linha 120, trocar:

```dart
      home: const LevelSelectScreen(),
```

por:

```dart
      home: const SplashScreen(),
```

Se `LevelSelectScreen` deixar de ser referenciada em `main.dart` depois dessa
troca, remover também o import agora não utilizado
(`import 'package:nine_fuse/features/game/presentation/screens/level_select_screen.dart';`).

- [ ] **Step 5: Rodar o teste do Step 2 e confirmar que passa**

Run: `flutter test test/main_test.dart`
Expected: PASS

- [ ] **Step 6: Rodar a suíte inteira para garantir que nada mais depende de
  `LevelSelectScreen` ser a tela inicial**

Run: `flutter test`
Expected: todos os testes passam (nenhuma regressão — nenhum teste hoje monta
`NineFuseApp` esperando `LevelSelectScreen` direto, mas confirmar é mais
barato que assumir).

- [ ] **Step 7: `flutter analyze` no repositório inteiro**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/main.dart test/main_test.dart
git commit -m "feat: abre o app pela SplashScreen animada"
```
