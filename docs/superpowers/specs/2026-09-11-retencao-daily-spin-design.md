# Retenção de Jogadores: Daily Spin + Notificações Locais

## Objetivo
Aumentar retenção via (1) roleta de recompensa diária e (2) notificações locais
de lembrete (giro diário +24h, inatividade +72h).

## Decisões confirmadas
- "Home" = `LevelSelectScreen` (Saga Map) — não existe `HomeScreen` no projeto;
  não será criada uma tela nova para isso.
- Prêmios da roleta (8 fatias fixas): 5 de moedas em valores variados
  (10/25/50/100/200) + 1 martelo + 1 bomba + 1 pincel — reaproveitando o
  inventário já existente (`Wallet.coins`, `hammerCount`, `bombCount`,
  `brushCount`).
- Botão "Girar Novamente (Assistir Vídeo)" faz parte desta entrega, via novo
  `spinAdProvider`, no mesmo padrão de `hammerAdProvider`/`coinAdProvider`
  (paga `true` sem rede em teste; AdMob real entra só em `admobOverrides()`
  no `main`).
- `NotificationService` fica atrás de uma interface fina e testável
  (`NotificationPort`), com a implementação real (`flutter_local_notifications`)
  sem teste automatizado — mesma régua já aplicada a `AdMobRewardedPort`:
  testar o plugin nativo mediria o SDK, não o jogo.
- A notificação de inatividade (+72h) é **reagendada a cada abertura do app**,
  não apenas na primeira instalação.

## Componentes

### 1. `GameStorage`
Novos métodos, no mesmo padrão de `readCoins`/`writeCoins`:
- `Future<DateTime?> readLastSpinTimestamp()`
- `Future<void> writeLastSpinTimestamp(DateTime value)`

Implementados em `PrefsGameStorage` (chave `SharedPreferences`, timestamp
serializado como `millisecondsSinceEpoch`) e `InMemoryGameStorage` (campo em
memória, para teste).

### 2. `lib/features/game/domain/daily_spin.dart` (Dart puro)
- `bool isSpinEligible(DateTime? lastSpin, DateTime now)`: elegível se
  `lastSpin == null` ou `now.difference(lastSpin) >= const Duration(hours: 24)`.
- `enum SpinPrizeType { coins, hammer, bomb, brush }`
- `class SpinPrize { final SpinPrizeType type; final int amount; }`
- `const List<SpinPrize> kSpinWheelPrizes` — as 8 fatias fixas, na ordem em
  que aparecem na roleta (moedas: 10, 25, 50, 100, 200; depois martelo, bomba,
  pincel — 1 unidade cada).

Nenhuma lógica de Flutter/Riverpod aqui — mesma disciplina de todo o resto do
`domain/`.

### 3. Notificações
`lib/core/notifications/notification_port.dart`:
```dart
abstract interface class NotificationPort {
  Future<void> scheduleDailySpinReminder(DateTime at);
  Future<void> scheduleInactivityReminder(DateTime at);
  Future<void> cancelAll();
}
```
`lib/core/notifications/local_notifications_port.dart`: implementação real
com `flutter_local_notifications` (inicialização + agendamento com IDs fixos
por tipo, para que reagendar substitua em vez de acumular). Sem teste
unitário.

`lib/core/notifications/notification_service.dart`: orquestra `NotificationPort`
+ um `Clock`-like (`DateTime Function()`, injetável para teste):
- `Future<void> onDailySpinCompleted()` → agenda `scheduleDailySpinReminder(now + 24h)`.
- `Future<void> onAppOpened()` → agenda `scheduleInactivityReminder(now + 72h)`.

Testável com uma `FakeNotificationPort` que apenas grava as chamadas.

### 4. Ads
`lib/core/ads/ad_providers.dart` ganha `spinAdProvider`, ao lado de
`hammerAdProvider`/`coinAdProvider`, mesmo padrão (retorna `true` sem rede;
trocado por AdMob real em `admobOverrides()`). `AdIds` ganha
`spinRewarded` como quarta unidade — mesmo motivo já registrado para
`coinsRewarded`: unidades diferentes por funil, nunca reaproveitar o ID de
outro.

### 5. `DailySpinDialog`
`lib/features/game/presentation/widgets/daily_spin_dialog.dart`, `ConsumerWidget`
com estado local para o ângulo de rotação (`AnimationController`, finita —
mesma armadilha já registrada para `HammerAim`/`StrikeShake`: nada de
animação em loop).

Fluxo:
1. Botão "Girar" sorteia um índice em `kSpinWheelPrizes`, anima a rotação até
   parar na fatia sorteada, credita o prêmio:
   - moeda → `walletProvider.creditCoins`
   - martelo/bomba/pincel → mesmo caminho de crédito que `grantHammer` já usa
     para os boosters existentes.
2. Grava `writeLastSpinTimestamp(now)` e chama
   `notificationService.onDailySpinCompleted()`.
3. Mostra o prêmio ganho e, uma única vez por sessão do dialog, o botão
   "Girar Novamente (Assistir Vídeo)" — que consome `spinAdProvider`; se
   `true`, libera novo giro sem gastar a elegibilidade diária de novo (o
   timestamp não é reescrito por esse giro extra, só o primeiro giro do dia
   grava o timestamp).
4. Fechar o dialog (manual ou automático) não reabre sozinho até o próximo
   dia elegível.

Visual: frosted glass (`BackdropFilter` + gradientes), sem asset 3D dedicado
— fora de escopo por decisão explícita.

### 6. Integração em `LevelSelectScreen`
- No `initState`/primeiro `build` pós-frame: lê elegibilidade
  (`isSpinEligible` + `readLastSpinTimestamp`) e abre `DailySpinDialog`
  automaticamente se elegível — mesmo padrão dos overlays já existentes na
  tela (`Positioned.fill` sobre o conteúdo).
- Ícone de roleta na `AppBar`, ao lado de `CoinsHeaderBadge`, sempre visível;
  abre o mesmo dialog manualmente. Quando não elegível, o dialog abre em modo
  "aguarde" (mostra o tempo restante), sem girar.

### 7. Reagendamento de inatividade no boot
No ponto em que o app já faz `preloadRewardedAds` (bootstrap), chama
`notificationService.onAppOpened()`.

## Testes
- `test/features/game/domain/daily_spin_test.dart`: elegibilidade
  (`null`, <24h, exatamente 24h, >24h).
- `test/core/notifications/notification_service_test.dart`: com
  `FakeNotificationPort`, confere que `onDailySpinCompleted`/`onAppOpened`
  chamam o método certo com o horário certo (clock injetado).
- `test/features/game/presentation/widgets/daily_spin_dialog_test.dart`:
  girar credita o prêmio certo no `walletProvider`/booster esperado, sem
  duplicar crédito, e grava o timestamp.
- `flutter analyze` e `flutter test` sem regressão (baseline: 760+ testes
  verdes, conforme registrado no `CLAUDE.md`).

## Fora de escopo (decisão explícita)
- Teste automatizado do plugin nativo `flutter_local_notifications` — mediria
  o SDK, não o jogo.
- Cap de frequência de "girar de novo" por dia (ex.: máx N vídeos) — pode
  entrar depois, mesmo espírito do cap de 3 martelos/dia ainda não
  implementado.
- Animação 3D "glossy" de verdade — frosted glass simples via `BackdropFilter`.
- `HomeScreen` dedicada — usa-se o Saga Map existente.
