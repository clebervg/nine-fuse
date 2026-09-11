# Retenção (Daily Spin + Notificações Locais) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Um giro diário de recompensa (moedas/martelo/bomba/pincel) no Saga Map, com lembrete local de +24h, e um lembrete separado de inatividade (+72h) reagendado a cada abertura do app.

**Architecture:** Domínio puro (`daily_spin.dart`) decide elegibilidade e a tabela de prêmios; `GameStorage` ganha o timestamp do último giro (mesmo padrão de `readCoins`/`writeCoins`); uma camada `NotificationPort`/`NotificationService` isola o plugin nativo (sem teste automatizado da parte nativa, só da lógica de agendamento); o `DailySpinDialog` credita o prêmio direto via `GameStorage` (a mesma autoridade que `Wallet` já espelha) e depois pede um `refresh()` ao `walletProvider` para o header atualizar na hora; o funil de vídeo segue o padrão existente (`hammerAdProvider`/`coinAdProvider`): um provider de função que paga `true` sem rede, trocado por AdMob real só em `admobOverrides()`.

**Tech Stack:** Flutter/Dart, Riverpod (`flutter_riverpod`), `shared_preferences` (já em uso), `flutter_local_notifications` + `timezone` (novos), `google_mobile_ads` (já em uso, funil de vídeo).

## Global Constraints

- Nenhum teste automatizado para a classe concreta que fala com o plugin nativo (`LocalNotificationsPort`) — testar o plugin mediria o SDK, não o jogo (mesma régua de `AdMobRewardedPort`).
- O padrão de todo provider de anúncio **paga o jogador sem rede** por padrão; só `admobOverrides()` liga o SDK real.
- `flutter analyze` e `flutter test` devem terminar sem nenhum erro/warning novo e sem nenhum teste quebrado (baseline atual: suíte 100% verde).
- Toda string visível ao jogador vai por ARB (`lib/l10n/app_en.arb` e `app_pt.arb`), nunca hardcoded no widget.
- Nenhuma animação em loop infinito — toda `AnimationController` novo é finito (a suíte de widget usa `pumpAndSettle`, que trava com animação repetindo para sempre).
- Boosters (martelo/bomba/pincel) são inventário do **jogador**, não da fase: crédito fora de uma partida grava direto no `GameStorage`, do mesmo jeito que `Wallet.claimChapterChest` já credita moeda fora de partida.

---

### Task 1: Dependências novas no `pubspec.yaml`

**Files:**
- Modify: `pubspec.yaml`

**Interfaces:**
- Produces: os pacotes `flutter_local_notifications` e `timezone` disponíveis para import em todo o projeto.

- [ ] **Step 1: Adicionar as dependências**

Em `pubspec.yaml`, dentro do bloco `dependencies:` (ao lado de `google_mobile_ads: 9.0.0`), adicionar:

```yaml
  flutter_local_notifications: ^18.0.1
  timezone: ^0.9.4
```

- [ ] **Step 2: Rodar `flutter pub get`**

Run: `flutter pub get`
Expected: resolve sem conflito de versão (saída termina em "Got dependencies!").

- [ ] **Step 3: Build de sanidade do iOS (mesma armadilha já documentada para `google_mobile_ads`)**

Run: `flutter build ios --debug --no-codesign --simulator`
Expected: build completa sem erro de CocoaPods/módulo. Se falhar por causa do
`flutter_local_notifications`, ajustar a versão pinada em `pubspec.yaml` para a
série de patch anterior compatível e repetir este passo — não usar
`ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES` (já registrado no
`CLAUDE.md` como remédio que não resolve esse tipo de falha).

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: adiciona flutter_local_notifications e timezone"
```

---

### Task 2: Configuração nativa mínima (Android/iOS)

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `ios/Runner/Info.plist`

**Interfaces:**
- Produces: permissões e receivers necessários para o `flutter_local_notifications` agendar notificações e sobreviver a reboot.

- [ ] **Step 1: Android — permissões e receiver**

Em `android/app/src/main/AndroidManifest.xml`, dentro de `<manifest>` (fora de
`<application>`), garantir estas permissões (adicionar as que faltarem, ao
lado das que já existem para o AdMob):

```xml
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

Dentro de `<application>`, ao lado do `<meta-data>` do AdMob, adicionar os
receivers exigidos pelo plugin para reagendar após reboot/atualização do app:

```xml
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
```

- [ ] **Step 2: iOS — capacidade de notificação em foreground**

Em `ios/Runner/Info.plist`, dentro do `<dict>` raiz (ao lado das chaves do
AdMob), adicionar, se ainda não existir:

```xml
	<key>UIBackgroundModes</key>
	<array>
		<string>remote-notification</string>
	</array>
```

- [ ] **Step 3: Build de sanidade nas duas plataformas**

Run: `flutter build ios --debug --no-codesign --simulator && flutter build apk --debug`
Expected: ambos completam sem erro.

- [ ] **Step 4: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist
git commit -m "chore: permissões nativas para notificações locais"
```

---

### Task 3: `GameStorage` — timestamp do último giro

**Files:**
- Modify: `lib/features/game/providers/game_storage.dart`
- Test: `test/features/game/providers/game_storage_test.dart` (se não existir, criar)

**Interfaces:**
- Produces: `Future<DateTime?> readLastSpinTimestamp()` e
  `Future<void> writeLastSpinTimestamp(DateTime value)` na interface
  `GameStorage`, implementados em `PrefsGameStorage` e `InMemoryGameStorage`.

- [ ] **Step 1: Verificar se já existe teste de `GameStorage` para seguir o padrão**

Run: `find test -iname "*game_storage*"`
Expected: lista o arquivo se existir; se a busca vier vazia, o Step 2 cria um
novo arquivo do zero.

- [ ] **Step 2: Escrever o teste que falha, usando `InMemoryGameStorage`**

Em `test/features/game/providers/game_storage_test.dart` (criar o arquivo se
não existir, com este conteúdo mínimo caso seja novo; se já existir, só
adicionar o grupo abaixo ao arquivo existente):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';

void main() {
  group('InMemoryGameStorage.lastSpinTimestamp', () {
    test('começa nulo (nenhum giro ainda)', () async {
      final storage = InMemoryGameStorage();
      expect(await storage.readLastSpinTimestamp(), isNull);
    });

    test('grava e relê o mesmo instante', () async {
      final storage = InMemoryGameStorage();
      final now = DateTime.utc(2026, 9, 11, 12, 0, 0);

      await storage.writeLastSpinTimestamp(now);

      expect(await storage.readLastSpinTimestamp(), now);
    });
  });
}
```

- [ ] **Step 3: Rodar e confirmar que falha (métodos ainda não existem)**

Run: `flutter test test/features/game/providers/game_storage_test.dart`
Expected: FAIL com erro de compilação, "The method
'readLastSpinTimestamp' isn't defined" (ou equivalente).

- [ ] **Step 4: Implementar na interface e nas duas classes**

Em `lib/features/game/providers/game_storage.dart`, dentro de
`abstract interface class GameStorage`, adicionar (ao lado dos métodos de
`readCoins`/`writeCoins`):

```dart
  /// Instante do último giro da roleta diária concedido.
  ///
  /// `null` significa "nunca girou" — o mesmo tratamento que o resto do
  /// inventário do jogador dá a "nada salvo": elegível de cara, sem exigir
  /// migração nem valor de fachada.
  Future<DateTime?> readLastSpinTimestamp();
  Future<void> writeLastSpinTimestamp(DateTime value);
```

Em `PrefsGameStorage`, adicionar a chave (ao lado de `_coinsKey`) e os dois
métodos (guardando como `millisecondsSinceEpoch`, mesma técnica que o resto do
arquivo usa para inteiros):

```dart
  static const String _lastSpinKey = 'daily_spin_last_timestamp';
```

```dart
  @override
  Future<DateTime?> readLastSpinTimestamp() async {
    final millis = (await SharedPreferences.getInstance()).getInt(
      _lastSpinKey,
    );
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  @override
  Future<void> writeLastSpinTimestamp(DateTime value) async =>
      (await SharedPreferences.getInstance()).setInt(
        _lastSpinKey,
        value.toUtc().millisecondsSinceEpoch,
      );
```

Em `InMemoryGameStorage`, adicionar o campo ao construtor e os dois métodos:

```dart
    this.lastSpinTimestamp,
```

(no parâmetro nomeado do construtor, ao lado de `this.prunedBelow = 0,`)

```dart
  DateTime? lastSpinTimestamp;
```

(como campo, ao lado de `int prunedBelow;`)

```dart
  @override
  Future<DateTime?> readLastSpinTimestamp() async => lastSpinTimestamp;

  @override
  Future<void> writeLastSpinTimestamp(DateTime value) async =>
      lastSpinTimestamp = value;
```

- [ ] **Step 5: Rodar e confirmar que passa**

Run: `flutter test test/features/game/providers/game_storage_test.dart`
Expected: PASS (2 testes).

- [ ] **Step 6: Corrigir os três fakes que implementam `GameStorage` diretamente**

Adicionar a interface muda a implementação obrigatória em toda classe que
`implements GameStorage` (Dart exige todos os membros). Três arquivos de
teste têm uma `_BrokenStorage` que implementa a interface inteira lançando
`StateError` em cada método — sem este passo, a suíte inteira para de
compilar a partir daqui:

- `test/features/game/providers/campaign_records_test.dart`
- `test/features/game/presentation/endless_screen_test.dart`
- `test/features/game/presentation/level_select_screen_test.dart`

Em cada um dos três arquivos, dentro da classe `_BrokenStorage`, adicionar
(seguindo o estilo de erro já usado por cada arquivo — `StateError('sem
disco')` ou `StateError('disco indisponível')`, conforme o que já está
escrito ali):

```dart
  @override
  Future<DateTime?> readLastSpinTimestamp() async =>
      throw StateError('sem disco');

  @override
  Future<void> writeLastSpinTimestamp(DateTime value) async =>
      throw StateError('sem disco');
```

- [ ] **Step 7: Rodar a suíte inteira de `game_storage` e providers relacionados, garantindo 0 regressão**

Run: `flutter test test/features/game/providers/ test/features/game/presentation/endless_screen_test.dart test/features/game/presentation/level_select_screen_test.dart`
Expected: PASS, sem nenhum teste quebrado.

- [ ] **Step 8: Commit**

```bash
git add lib/features/game/providers/game_storage.dart test/features/game/providers/game_storage_test.dart test/features/game/providers/campaign_records_test.dart test/features/game/presentation/endless_screen_test.dart test/features/game/presentation/level_select_screen_test.dart
git commit -m "feat: GameStorage grava o timestamp do último giro diário"
```

---

### Task 4: Domínio puro — elegibilidade e tabela de prêmios

**Files:**
- Create: `lib/features/game/domain/daily_spin.dart`
- Test: `test/features/game/domain/daily_spin_test.dart`

**Interfaces:**
- Consumes: nada (Dart puro, sem dependência de Flutter/Riverpod/storage).
- Produces:
  - `bool isSpinEligible(DateTime? lastSpin, DateTime now)`
  - `enum SpinPrizeType { coins, hammer, bomb, brush }`
  - `class SpinPrize { final SpinPrizeType type; final int amount; const SpinPrize(this.type, this.amount); }`
  - `const List<SpinPrize> kSpinWheelPrizes` (8 elementos, ordem fixa)

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/features/game/domain/daily_spin_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/daily_spin.dart';

void main() {
  final now = DateTime.utc(2026, 9, 11, 12, 0, 0);

  group('isSpinEligible', () {
    test('nunca girou (null) é sempre elegível', () {
      expect(isSpinEligible(null, now), isTrue);
    });

    test('menos de 24h desde o último giro não é elegível', () {
      final lastSpin = now.subtract(const Duration(hours: 23, minutes: 59));
      expect(isSpinEligible(lastSpin, now), isFalse);
    });

    test('exatamente 24h já é elegível', () {
      final lastSpin = now.subtract(const Duration(hours: 24));
      expect(isSpinEligible(lastSpin, now), isTrue);
    });

    test('mais de 24h é elegível', () {
      final lastSpin = now.subtract(const Duration(hours: 25));
      expect(isSpinEligible(lastSpin, now), isTrue);
    });
  });

  group('kSpinWheelPrizes', () {
    test('tem exatamente 8 fatias', () {
      expect(kSpinWheelPrizes, hasLength(8));
    });

    test('tem 5 fatias de moeda com os valores esperados', () {
      final coinAmounts = kSpinWheelPrizes
          .where((prize) => prize.type == SpinPrizeType.coins)
          .map((prize) => prize.amount)
          .toList();
      expect(coinAmounts, [10, 25, 50, 100, 200]);
    });

    test('tem uma fatia de cada booster, valendo 1 unidade', () {
      for (final type in [
        SpinPrizeType.hammer,
        SpinPrizeType.bomb,
        SpinPrizeType.brush,
      ]) {
        final matches = kSpinWheelPrizes.where((prize) => prize.type == type);
        expect(matches, hasLength(1));
        expect(matches.single.amount, 1);
      }
    });
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/features/game/domain/daily_spin_test.dart`
Expected: FAIL — `Target of URI doesn't exist:
'package:nine_fuse/features/game/domain/daily_spin.dart'`.

- [ ] **Step 3: Implementar**

Criar `lib/features/game/domain/daily_spin.dart`:

```dart
/// Roleta diária de recompensa: elegibilidade por tempo e a tabela fixa de
/// prêmios. Dart puro — nenhuma dependência de Flutter, Riverpod ou
/// armazenamento, no mesmo espírito do resto de `domain/`.
library;

/// Elegível para girar se nunca girou (`lastSpin == null`) ou se já se
/// passaram 24h ou mais desde o último giro.
bool isSpinEligible(DateTime? lastSpin, DateTime now) {
  if (lastSpin == null) return true;
  return now.difference(lastSpin) >= const Duration(hours: 24);
}

/// O que uma fatia da roleta paga.
enum SpinPrizeType { coins, hammer, bomb, brush }

/// Um prêmio concreto: o tipo e a quantidade que ele credita.
class SpinPrize {
  const SpinPrize(this.type, this.amount);

  final SpinPrizeType type;
  final int amount;
}

/// As 8 fatias fixas da roleta, na ordem em que aparecem no desenho.
///
/// Moedas em 5 valores crescentes e uma unidade de cada booster existente —
/// nenhuma fatia "vazia", porque um giro que não paga nada é o tipo de
/// recurso que ensina o jogador a não girar mais.
const List<SpinPrize> kSpinWheelPrizes = [
  SpinPrize(SpinPrizeType.coins, 10),
  SpinPrize(SpinPrizeType.hammer, 1),
  SpinPrize(SpinPrizeType.coins, 25),
  SpinPrize(SpinPrizeType.bomb, 1),
  SpinPrize(SpinPrizeType.coins, 50),
  SpinPrize(SpinPrizeType.brush, 1),
  SpinPrize(SpinPrizeType.coins, 100),
  SpinPrize(SpinPrizeType.coins, 200),
];
```

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `flutter test test/features/game/domain/daily_spin_test.dart`
Expected: PASS (7 testes).

- [ ] **Step 5: Commit**

```bash
git add lib/features/game/domain/daily_spin.dart test/features/game/domain/daily_spin_test.dart
git commit -m "feat: domínio da roleta diária (elegibilidade e tabela de prêmios)"
```

---

### Task 5: `NotificationPort` + `NotificationService` (testáveis) e `LocalNotificationsPort` (real, sem teste)

**Files:**
- Create: `lib/core/notifications/notification_port.dart`
- Create: `lib/core/notifications/notification_service.dart`
- Create: `lib/core/notifications/local_notifications_port.dart`
- Test: `test/core/notifications/notification_service_test.dart`

**Interfaces:**
- Consumes: nada de outras tasks.
- Produces:
  - `abstract interface class NotificationPort` com
    `Future<void> scheduleDailySpinReminder(DateTime at)`,
    `Future<void> scheduleInactivityReminder(DateTime at)`,
    `Future<void> cancelAll()`.
  - `class NotificationService` com construtor
    `NotificationService({required NotificationPort port, DateTime Function() now = DateTime.now})`,
    método `Future<void> onDailySpinCompleted()` e
    `Future<void> onAppOpened()`.
  - `class LocalNotificationsPort implements NotificationPort` (real, sem
    teste).

- [ ] **Step 1: Escrever a porta**

Criar `lib/core/notifications/notification_port.dart`:

```dart
/// Como o jogo agenda lembretes locais, sem amarrar o resto do código ao
/// plugin nativo.
///
/// A interface existe pela mesma razão de `RewardedAdPort`: testar a
/// orquestração (quando agendar o quê) não deve exigir canal de plataforma. A
/// implementação real (`LocalNotificationsPort`) não tem teste — testá-la
/// mediria o plugin, não o jogo.
abstract interface class NotificationPort {
  /// Lembrete de que a roleta diária está disponível de novo.
  Future<void> scheduleDailySpinReminder(DateTime at);

  /// Lembrete de inatividade: o jogador não abriu o app há um tempo.
  Future<void> scheduleInactivityReminder(DateTime at);

  /// Cancela todos os lembretes agendados.
  Future<void> cancelAll();
}
```

- [ ] **Step 2: Escrever o teste do serviço, que falha (porta fake local ao teste)**

Criar `test/core/notifications/notification_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/notifications/notification_port.dart';
import 'package:nine_fuse/core/notifications/notification_service.dart';

class FakeNotificationPort implements NotificationPort {
  DateTime? dailySpinAt;
  DateTime? inactivityAt;
  int cancelCalls = 0;

  @override
  Future<void> scheduleDailySpinReminder(DateTime at) async {
    dailySpinAt = at;
  }

  @override
  Future<void> scheduleInactivityReminder(DateTime at) async {
    inactivityAt = at;
  }

  @override
  Future<void> cancelAll() async {
    cancelCalls++;
  }
}

void main() {
  final fixedNow = DateTime.utc(2026, 9, 11, 12, 0, 0);

  test('onDailySpinCompleted agenda o lembrete para +24h', () async {
    final port = FakeNotificationPort();
    final service = NotificationService(port: port, now: () => fixedNow);

    await service.onDailySpinCompleted();

    expect(port.dailySpinAt, fixedNow.add(const Duration(hours: 24)));
  });

  test('onAppOpened agenda o lembrete de inatividade para +72h', () async {
    final port = FakeNotificationPort();
    final service = NotificationService(port: port, now: () => fixedNow);

    await service.onAppOpened();

    expect(port.inactivityAt, fixedNow.add(const Duration(hours: 72)));
  });

  test('onAppOpened chamado de novo empurra o lembrete para frente', () async {
    final port = FakeNotificationPort();
    var current = fixedNow;
    final service = NotificationService(port: port, now: () => current);

    await service.onAppOpened();
    expect(port.inactivityAt, fixedNow.add(const Duration(hours: 72)));

    current = fixedNow.add(const Duration(hours: 10));
    await service.onAppOpened();
    expect(port.inactivityAt, current.add(const Duration(hours: 72)));
  });
}
```

- [ ] **Step 3: Rodar e confirmar que falha**

Run: `flutter test test/core/notifications/notification_service_test.dart`
Expected: FAIL — `notification_service.dart` ainda não existe.

- [ ] **Step 4: Implementar o serviço**

Criar `lib/core/notifications/notification_service.dart`:

```dart
import 'package:nine_fuse/core/notifications/notification_port.dart';

/// Sabe **quando** agendar cada lembrete; a porta sabe **como**.
///
/// `now` é injetável para o teste não depender do relógio real — mesmo
/// padrão de qualquer serviço deste projeto que precisa de tempo
/// determinístico.
class NotificationService {
  NotificationService({required NotificationPort port, DateTime Function() now = DateTime.now})
    : _port = port,
      _now = now;

  final NotificationPort _port;
  final DateTime Function() _now;

  /// Chamado ao terminar um giro da roleta diária: o próximo giro libera em
  /// 24h, e é isso que o lembrete anuncia.
  Future<void> onDailySpinCompleted() =>
      _port.scheduleDailySpinReminder(_now().add(const Duration(hours: 24)));

  /// Chamado toda vez que o app abre: reagenda o lembrete de inatividade
  /// para 72h a partir de agora, empurrando qualquer agendamento anterior.
  /// Abrir o app é o próprio sinal de que o jogador está ativo — a
  /// notificação só dispara se ele realmente ficar 72h sem voltar.
  Future<void> onAppOpened() =>
      _port.scheduleInactivityReminder(_now().add(const Duration(hours: 72)));
}
```

- [ ] **Step 5: Rodar e confirmar que passa**

Run: `flutter test test/core/notifications/notification_service_test.dart`
Expected: PASS (3 testes).

- [ ] **Step 6: Implementar a porta real (sem teste)**

Criar `lib/core/notifications/local_notifications_port.dart`:

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:nine_fuse/core/notifications/notification_port.dart';

/// Fala com o plugin de verdade.
///
/// Sem teste automatizado, de propósito: exercitar isto mediria o SDK
/// (`flutter_local_notifications`), não a lógica do jogo — a mesma régua já
/// aplicada a `AdMobRewardedPort`. `NotificationService` é quem carrega toda a
/// lógica testável.
class LocalNotificationsPort implements NotificationPort {
  LocalNotificationsPort() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  /// ID fixo por tipo de lembrete: agendar de novo **substitui**, nunca
  /// acumula uma segunda notificação do mesmo tipo pendente.
  static const int _dailySpinNotificationId = 1;
  static const int _inactivityNotificationId = 2;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();

    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  @override
  Future<void> scheduleDailySpinReminder(DateTime at) async {
    await _ensureInitialized();
    await _plugin.zonedSchedule(
      _dailySpinNotificationId,
      'A roleta diária está pronta!',
      'Volte para girar e ganhar sua recompensa de hoje.',
      tz.TZDateTime.from(at, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_spin',
          'Roleta Diária',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  Future<void> scheduleInactivityReminder(DateTime at) async {
    await _ensureInitialized();
    await _plugin.zonedSchedule(
      _inactivityNotificationId,
      'Sentimos sua falta!',
      'Seus números estão esperando por você no NineFuse.',
      tz.TZDateTime.from(at, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'inactivity',
          'Lembrete de Inatividade',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  Future<void> cancelAll() async {
    await _ensureInitialized();
    await _plugin.cancelAll();
  }
}
```

- [ ] **Step 7: Build de sanidade (o plugin real entra em compilação, mesmo sem teste)**

Run: `flutter analyze lib/core/notifications/`
Expected: sem erro.

- [ ] **Step 8: Commit**

```bash
git add lib/core/notifications/ test/core/notifications/
git commit -m "feat: NotificationService e porta de notificações locais"
```

---

### Task 6: Ads — quarta unidade e provider da roleta

**Files:**
- Modify: `lib/core/ads/ad_ids.dart`
- Modify: `lib/core/ads/ad_providers.dart`

**Interfaces:**
- Consumes: `RewardedAdService`, `rewardedAdPortProvider` (já existentes em
  `ad_providers.dart`); `AdIds` (já existente).
- Produces: `AdIds.spinRewarded` (String), `spinAdServiceProvider`
  (`Provider<RewardedAdService>`), `spinAdServiceProvider` incluído em
  `preloadRewardedAds` e em `admobOverrides()`.

- [ ] **Step 1: `AdIds.spinRewarded`**

Em `lib/core/ads/ad_ids.dart`, adicionar, ao lado de `coinsRewarded`:

```dart
  /// Unidade do anúncio que paga o giro extra da roleta diária.
  ///
  /// Separada das outras três pela mesma razão de sempre: é por unidade que a
  /// rede reporta receita, e cada funil precisa ser distinguível.
  static String get spinRewarded => _rewarded;
```

- [ ] **Step 2: `spinAdServiceProvider` e inclusão no preload/overrides**

Em `lib/core/ads/ad_providers.dart`, adicionar, ao lado de
`coinAdServiceProvider`:

```dart
/// Serviço do anúncio que paga o giro extra da roleta diária.
final spinAdServiceProvider = Provider<RewardedAdService>((ref) {
  final service = RewardedAdService(
    port: ref.watch(rewardedAdPortProvider),
    unitId: AdIds.spinRewarded,
  );
  ref.onDispose(service.dispose);
  return service;
});
```

Dentro de `preloadRewardedAds`, adicionar a linha:

```dart
  ref.read(spinAdServiceProvider).preload();
```

Dentro de `admobOverrides()`, adicionar ao final da lista (o provider de
função `spinAdProvider` em si é criado na Task 8, dentro do widget do
diálogo — este override só existe depois daquela task; adicionar aqui a
linha comentada abaixo, e destravá-la de fato na Task 8):

```dart
  spinAdProvider.overrideWith((ref) => ref.watch(spinAdServiceProvider).show),
```

Import necessário no topo do arquivo (`daily_spin_dialog.dart` ainda não
existe até a Task 8 — este import só compila depois de completar aquela
task; se rodar `flutter analyze` agora e falhar por causa deste import, é
esperado e será resolvido na Task 8, então **não rode analyze isolado desta
task** — o Step de verificação abaixo já contempla isso):

```dart
import 'package:nine_fuse/features/game/presentation/widgets/daily_spin_dialog.dart';
```

- [ ] **Step 3: Verificar que a suíte de ads/regressão ainda depende da Task 8**

Este arquivo só volta a compilar depois que `daily_spin_dialog.dart` existir
(Task 8). Não rodar `flutter analyze`/`flutter test` ao final desta task
isoladamente — o primeiro checkpoint verde que inclui esta mudança é o final
da Task 8. Deixar isso anotado no commit.

- [ ] **Step 4: Commit**

```bash
git add lib/core/ads/ad_ids.dart lib/core/ads/ad_providers.dart
git commit -m "feat: quarta unidade de anúncio (spinRewarded) e serviço da roleta

Depende de daily_spin_dialog.dart (Task 8) para compilar; build só volta a
ficar verde ao final daquela task."
```

---

### Task 7: ARB — textos do Daily Spin

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_pt.arb`

**Interfaces:**
- Produces: chaves geradas em `AppLocalizations` (via `flutter gen-l10n`,
  automático no build por causa de `generate: true` no `pubspec.yaml`):
  `dailySpinTitle`, `dailySpinSubtitle`, `dailySpinSpinButton`,
  `dailySpinWatchAgainButton`, `dailySpinCloseButton`,
  `dailySpinPrizeWon`, `dailySpinComeBackIn` (com placeholder `hours` int).

- [ ] **Step 1: Adicionar as chaves em `app_en.arb`**

Em `lib/l10n/app_en.arb`, adicionar (em qualquer ponto do objeto JSON, ao
lado das chaves de `hammerOffer*`):

```json
  "dailySpinTitle": "Daily Spin",
  "dailySpinSubtitle": "Spin the wheel for a free daily prize!",
  "dailySpinSpinButton": "SPIN",
  "dailySpinWatchAgainButton": "Spin Again (Watch Ad)",
  "dailySpinCloseButton": "CLOSE",
  "dailySpinPrizeWon": "You won {prize}!",
  "@dailySpinPrizeWon": {
    "placeholders": { "prize": { "type": "String" } }
  },
  "dailySpinComeBackIn": "Come back in {hours}h for your next spin",
  "@dailySpinComeBackIn": {
    "placeholders": { "hours": { "type": "int" } }
  },
```

- [ ] **Step 2: Adicionar as mesmas chaves em `app_pt.arb`**

Em `lib/l10n/app_pt.arb`:

```json
  "dailySpinTitle": "Roleta Diária",
  "dailySpinSubtitle": "Gire a roleta e ganhe um prêmio grátis hoje!",
  "dailySpinSpinButton": "GIRAR",
  "dailySpinWatchAgainButton": "Girar de Novo (Assistir Vídeo)",
  "dailySpinCloseButton": "FECHAR",
  "dailySpinPrizeWon": "Você ganhou {prize}!",
  "dailySpinComeBackIn": "Volte em {hours}h para o próximo giro",
```

(As chaves `@dailySpinPrizeWon`/`@dailySpinComeBackIn` só precisam ser
declaradas uma vez, em `app_en.arb`, que é o arquivo-modelo — `app_pt.arb`
não repete os metadados de placeholder, seguindo o padrão já existente no
projeto para as outras chaves com placeholder.)

- [ ] **Step 3: Gerar as localizações e verificar**

Run: `flutter gen-l10n`
Expected: termina sem erro; `lib/l10n/app_localizations_en.dart` e
`app_localizations_pt.dart` ganham os getters/métodos novos.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/
git commit -m "feat: textos ARB do Daily Spin (pt/en)"
```

---

### Task 8: `DailySpinDialog` — providers, crédito de prêmio e UI

**Files:**
- Create: `lib/features/game/presentation/widgets/daily_spin_dialog.dart`
- Test: `test/features/game/presentation/widgets/daily_spin_dialog_test.dart`

**Interfaces:**
- Consumes:
  - `GameStorage` (Task 3): `readLastSpinTimestamp`, `writeLastSpinTimestamp`,
    `readCoins`/`writeCoins`, `readHammerCount`/`writeHammerCount`,
    `readBombCount`/`writeBombCount`, `readBrushCount`/`writeBrushCount`.
  - `isSpinEligible`, `SpinPrize`, `SpinPrizeType`, `kSpinWheelPrizes`
    (Task 4).
  - `NotificationService.onDailySpinCompleted()` (Task 5).
  - `walletProvider` (`WalletNotifier.refresh()`, já existente em
    `lib/features/game/providers/wallet.dart`).
- Produces:
  - `dailySpinStorageProvider` (`Provider<GameStorage>`, default
    `const PrefsGameStorage()`, overridável em teste).
  - `notificationPortProvider` (`Provider<NotificationPort>`, default
    `LocalNotificationsPort()`, overridável em teste).
  - `notificationServiceProvider` (`Provider<NotificationService>`).
  - `dailySpinClockProvider` (`Provider<DateTime Function()>`, default
    `DateTime.now`).
  - `dailySpinPrizeIndexProvider` (`Provider<int Function()>`, default
    `() => Random().nextInt(kSpinWheelPrizes.length)` — o ponto de injeção
    que o teste de widget usa para forçar um prêmio determinístico).
  - `spinAdProvider` (`Provider<Future<bool> Function()>`, mesmo padrão de
    `hammerAdProvider`/`coinAdProvider`: paga `true` sem rede).
  - `dailySpinEligibleProvider` (`FutureProvider<bool>`, lido pela
    `LevelSelectScreen` na Task 9).
  - Widget `DailySpinDialog` (`ConsumerStatefulWidget` — precisa de
    `AnimationController`, o que exige `State`; é o mesmo motivo pelo qual
    `HammerOfferDialog` também é `ConsumerStatefulWidget` apesar de o pedido
    falar em "ConsumerWidget").
  - `const Key dailySpinKey`, `const Key dailySpinSpinButtonKey`,
    `const Key dailySpinWatchAgainButtonKey`,
    `const Key dailySpinCloseButtonKey`.

- [ ] **Step 1: Escrever o teste de widget que falha**

Criar `test/features/game/presentation/widgets/daily_spin_dialog_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/notifications/notification_port.dart';
import 'package:nine_fuse/core/notifications/notification_service.dart';
import 'package:nine_fuse/features/game/domain/daily_spin.dart';
import 'package:nine_fuse/features/game/presentation/widgets/daily_spin_dialog.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

class FakeNotificationPort implements NotificationPort {
  DateTime? dailySpinAt;

  @override
  Future<void> scheduleDailySpinReminder(DateTime at) async {
    dailySpinAt = at;
  }

  @override
  Future<void> scheduleInactivityReminder(DateTime at) async {}

  @override
  Future<void> cancelAll() async {}
}

Widget _wrap(Widget child, List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  ),
);

void main() {
  testWidgets('girar credita a fatia sorteada em moedas e grava o timestamp', (
    tester,
  ) async {
    final storage = InMemoryGameStorage(coins: 5);
    final fakePort = FakeNotificationPort();
    final fixedNow = DateTime.utc(2026, 9, 11, 12, 0, 0);
    // Índice 0 de `kSpinWheelPrizes` é `SpinPrize(SpinPrizeType.coins, 10)`.
    const forcedIndex = 0;

    await tester.pumpWidget(
      _wrap(const DailySpinDialog(), [
        dailySpinStorageProvider.overrideWithValue(storage),
        notificationPortProvider.overrideWithValue(fakePort),
        dailySpinClockProvider.overrideWithValue(() => fixedNow),
        dailySpinPrizeIndexProvider.overrideWithValue(() => forcedIndex),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(dailySpinSpinButtonKey));
    await tester.pumpAndSettle();

    expect(storage.coins, 15);
    expect(storage.lastSpinTimestamp, fixedNow);
    expect(fakePort.dailySpinAt, fixedNow.add(const Duration(hours: 24)));
  });

  testWidgets('girar credita a fatia sorteada em martelo, sem tocar moeda', (
    tester,
  ) async {
    final storage = InMemoryGameStorage(coins: 5, hammerCount: 2);
    final fakePort = FakeNotificationPort();
    final fixedNow = DateTime.utc(2026, 9, 11, 12, 0, 0);
    // Índice 1 de `kSpinWheelPrizes` é `SpinPrize(SpinPrizeType.hammer, 1)`.
    const forcedIndex = 1;

    await tester.pumpWidget(
      _wrap(const DailySpinDialog(), [
        dailySpinStorageProvider.overrideWithValue(storage),
        notificationPortProvider.overrideWithValue(fakePort),
        dailySpinClockProvider.overrideWithValue(() => fixedNow),
        dailySpinPrizeIndexProvider.overrideWithValue(() => forcedIndex),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(dailySpinSpinButtonKey));
    await tester.pumpAndSettle();

    expect(storage.hammerCount, 3);
    expect(storage.coins, 5);
    expect(storage.lastSpinTimestamp, fixedNow);
  });

  testWidgets('não elegível mostra a contagem de espera e não gira', (
    tester,
  ) async {
    final fixedNow = DateTime.utc(2026, 9, 11, 12, 0, 0);
    final storage = InMemoryGameStorage(
      coins: 5,
      lastSpinTimestamp: fixedNow.subtract(const Duration(hours: 1)),
    );
    final fakePort = FakeNotificationPort();

    await tester.pumpWidget(
      _wrap(const DailySpinDialog(), [
        dailySpinStorageProvider.overrideWithValue(storage),
        notificationPortProvider.overrideWithValue(fakePort),
        dailySpinClockProvider.overrideWithValue(() => fixedNow),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(dailySpinSpinButtonKey), findsNothing);
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/features/game/presentation/widgets/daily_spin_dialog_test.dart`
Expected: FAIL — `daily_spin_dialog.dart` ainda não existe.

- [ ] **Step 3: Implementar `DailySpinDialog` e os providers**

Criar `lib/features/game/presentation/widgets/daily_spin_dialog.dart`:

```dart
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/notifications/local_notifications_port.dart';
import 'package:nine_fuse/core/notifications/notification_port.dart';
import 'package:nine_fuse/core/notifications/notification_service.dart';
import 'package:nine_fuse/features/game/domain/daily_spin.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import 'package:nine_fuse/features/game/providers/wallet.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Chave da caixa da roleta diária.
const Key dailySpinKey = Key('daily_spin');

/// Chave do botão de girar.
const Key dailySpinSpinButtonKey = Key('daily_spin_spin_button');

/// Chave do botão de girar de novo assistindo a um vídeo.
const Key dailySpinWatchAgainButtonKey = Key('daily_spin_watch_again_button');

/// Chave do botão de fechar.
const Key dailySpinCloseButtonKey = Key('daily_spin_close_button');

/// De onde vem o `GameStorage` usado pela roleta diária.
///
/// Provider próprio (e não uma instância direta) para o teste poder trocar
/// por `InMemoryGameStorage` sem tocar disco — mesmo padrão de
/// `rewardedAdPortProvider`.
final dailySpinStorageProvider = Provider<GameStorage>(
  (ref) => const PrefsGameStorage(),
);

/// De onde vem a porta de notificações locais. Real por padrão; o teste troca
/// por uma porta fake.
final notificationPortProvider = Provider<NotificationPort>(
  (ref) => LocalNotificationsPort(),
);

/// O serviço que decide quando agendar cada lembrete.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(port: ref.watch(notificationPortProvider)),
);

/// O relógio que a roleta diária usa. Injetável para o teste não depender do
/// instante real.
final dailySpinClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Como a roleta escolhe o índice sorteado em [kSpinWheelPrizes].
///
/// Provider de função, e não uma chamada direta a `Random`, pela mesma razão
/// de `hammerAdProvider`: é o ponto em que o teste força um resultado
/// determinístico sem precisar simular a animação até um ângulo exato.
final dailySpinPrizeIndexProvider = Provider<int Function()>(
  (ref) => () => Random().nextInt(kSpinWheelPrizes.length),
);

/// Como o jogo pede o anúncio premiado que libera um giro extra.
///
/// Mesmo padrão de `hammerAdProvider`/`coinAdProvider`: paga o jogador sem
/// rede nenhuma por padrão. Quem liga o AdMob de verdade é `admobOverrides()`.
final spinAdProvider = Provider<Future<bool> Function()>(
  (ref) => () async => true,
);

/// Se o jogador já pode girar a roleta hoje.
///
/// `FutureProvider` porque a resposta depende de uma leitura de disco — a
/// tela que decide se abre o diálogo automaticamente, e o ícone que mostra
/// disponibilidade, leem daqui em vez de duplicar a consulta.
final dailySpinEligibleProvider = FutureProvider<bool>((ref) async {
  final storage = ref.watch(dailySpinStorageProvider);
  final now = ref.watch(dailySpinClockProvider)();
  final lastSpin = await storage.readLastSpinTimestamp();
  return isSpinEligible(lastSpin, now);
});

String _prizeLabel(AppLocalizations l10n, SpinPrize prize) {
  switch (prize.type) {
    case SpinPrizeType.coins:
      return '${prize.amount} 🪙';
    case SpinPrizeType.hammer:
      return '${prize.amount} 🔨';
    case SpinPrizeType.bomb:
      return '${prize.amount} 💣';
    case SpinPrizeType.brush:
      return '${prize.amount} 🖌️';
  }
}

/// A roleta de recompensa diária, em frosted glass.
///
/// Fica em `showDialog` — não num `Positioned.fill` de algum `Stack` de
/// partida —, pela mesma razão já registrada para a loja de moedas do header:
/// não há tabuleiro nenhum a proteger no Saga Map, e os pontos de entrada
/// (auto-abertura + ícone manual) vivem em telas diferentes que não têm
/// motivo para hospedar a mesma máquina de estado cada uma.
class DailySpinDialog extends ConsumerStatefulWidget {
  const DailySpinDialog({super.key});

  @override
  ConsumerState<DailySpinDialog> createState() => _DailySpinDialogState();
}

class _DailySpinDialogState extends ConsumerState<DailySpinDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;
  SpinPrize? _wonPrize;
  bool _spinning = false;
  bool _watchOfferUsed = false;

  @override
  void initState() {
    super.initState();
    // Finito: gira até o alvo e para. Nada de repetição — a suíte de widget
    // usa `pumpAndSettle`, que trava com animação em loop.
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _spin({required bool countsAsDailySpin}) async {
    if (_spinning) return;
    setState(() => _spinning = true);

    final index = ref.read(dailySpinPrizeIndexProvider)();
    final prize = kSpinWheelPrizes[index];

    await _spinController.forward(from: 0);

    final storage = ref.read(dailySpinStorageProvider);
    await _creditPrize(storage, prize);

    if (countsAsDailySpin) {
      final now = ref.read(dailySpinClockProvider)();
      await storage.writeLastSpinTimestamp(now);
      await ref.read(notificationServiceProvider).onDailySpinCompleted();
      ref.invalidate(dailySpinEligibleProvider);
    }

    // O crédito já foi para o disco; o header (moedas/martelo) só reflete o
    // saldo novo depois de reler — mesmo remédio de `EndlessHighScore.refresh`.
    await ref.read(walletProvider.notifier).refresh();

    if (!mounted) return;
    setState(() {
      _wonPrize = prize;
      _spinning = false;
    });
  }

  Future<void> _creditPrize(GameStorage storage, SpinPrize prize) async {
    switch (prize.type) {
      case SpinPrizeType.coins:
        await storage.writeCoins(await storage.readCoins() + prize.amount);
      case SpinPrizeType.hammer:
        await storage.writeHammerCount(
          await storage.readHammerCount() + prize.amount,
        );
      case SpinPrizeType.bomb:
        await storage.writeBombCount(
          await storage.readBombCount() + prize.amount,
        );
      case SpinPrizeType.brush:
        await storage.writeBrushCount(
          await storage.readBrushCount() + prize.amount,
        );
    }
  }

  Future<void> _watchAgain() async {
    if (_watchOfferUsed) return;
    final granted = await ref.read(spinAdProvider)();
    if (!mounted || !granted) return;

    setState(() {
      _watchOfferUsed = true;
      _wonPrize = null;
    });
    await _spin(countsAsDailySpin: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final eligibleAsync = ref.watch(dailySpinEligibleProvider);

    return Dialog(
      key: dailySpinKey,
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.16),
                  AppColors.darkSurface.withValues(alpha: 0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
            ),
            child: eligibleAsync.when(
              loading: () => const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => _WaitContent(hoursLeft: 24, l10n: l10n),
              data: (eligible) {
                if (!eligible && _wonPrize == null) {
                  return _WaitContent(hoursLeft: 24, l10n: l10n);
                }
                return _spinContent(l10n);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _spinContent(AppLocalizations l10n) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        l10n.dailySpinTitle,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        l10n.dailySpinSubtitle,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
      ),
      const SizedBox(height: 20),
      RotationTransition(
        turns: Tween<double>(begin: 0, end: 4).animate(
          CurvedAnimation(parent: _spinController, curve: Curves.easeOutCubic),
        ),
        child: Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const SweepGradient(
              colors: [
                AppColors.digit9,
                AppColors.digit9Deep,
                AppColors.digit9,
              ],
            ),
            border: Border.all(color: Colors.white, width: 3),
          ),
        ),
      ),
      const SizedBox(height: 20),
      if (_wonPrize != null) ...[
        Text(
          l10n.dailySpinPrizeWon(_prizeLabel(l10n, _wonPrize!)),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        if (!_watchOfferUsed)
          OutlinedButton(
            key: dailySpinWatchAgainButtonKey,
            onPressed: _spinning ? null : _watchAgain,
            child: Text(l10n.dailySpinWatchAgainButton),
          ),
        TextButton(
          key: dailySpinCloseButtonKey,
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(l10n.dailySpinCloseButton),
        ),
      ] else
        ElevatedButton(
          key: dailySpinSpinButtonKey,
          onPressed: _spinning ? null : () => _spin(countsAsDailySpin: true),
          child: Text(l10n.dailySpinSpinButton),
        ),
    ],
  );
}

class _WaitContent extends StatelessWidget {
  const _WaitContent({required this.hoursLeft, required this.l10n});

  final int hoursLeft;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        l10n.dailySpinTitle,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        l10n.dailySpinComeBackIn(hoursLeft),
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
      ),
      const SizedBox(height: 16),
      TextButton(
        key: dailySpinCloseButtonKey,
        onPressed: () => Navigator.of(context).maybePop(),
        child: Text(l10n.dailySpinCloseButton),
      ),
    ],
  );
}
```

- [ ] **Step 4: Voltar à Task 6 e destravar o override**

Em `lib/core/ads/ad_providers.dart`, confirmar que a linha
`spinAdProvider.overrideWith(...)` dentro de `admobOverrides()` agora
compila (o import de `daily_spin_dialog.dart` já resolve).

- [ ] **Step 5: Rodar o teste e confirmar que passa**

Run: `flutter test test/features/game/presentation/widgets/daily_spin_dialog_test.dart`
Expected: PASS (3 testes).

- [ ] **Step 6: Rodar `flutter analyze` no projeto inteiro**

Run: `flutter analyze`
Expected: nenhum erro novo (avisos pré-existentes documentados no `CLAUDE.md`,
como o de `tool_tmp/probe124.dart`, continuam fora de escopo).

- [ ] **Step 7: Commit**

```bash
git add lib/features/game/presentation/widgets/daily_spin_dialog.dart lib/core/ads/ad_providers.dart test/features/game/presentation/widgets/daily_spin_dialog_test.dart
git commit -m "feat: DailySpinDialog credita prêmio, agenda lembrete e libera giro extra por vídeo"
```

---

### Task 9: Integração em `LevelSelectScreen` e no boot do app

**Files:**
- Modify: `lib/features/game/presentation/screens/level_select_screen.dart`
- Test: modificar/estender
  `test/features/game/presentation/level_select_screen_test.dart`
  (localizar o arquivo existente; se o nome for outro, usar
  `find test -iname "*level_select*"` para achá-lo)

**Interfaces:**
- Consumes: `DailySpinDialog`, `dailySpinEligibleProvider`,
  `notificationServiceProvider` (Task 8), `walletProvider` (já existente).
- Produces: ícone de roleta na `AppBar` de `LevelSelectScreen`, abertura
  automática do `DailySpinDialog` quando elegível, chamada de
  `notificationService.onAppOpened()` no primeiro frame da tela.

- [ ] **Step 1: Localizar o teste existente da tela e ler seu topo**

Run: `find test -iname "*level_select*"`

Ler as primeiras 40 linhas do arquivo encontrado para replicar o helper de
`ProviderScope`/overrides já usado ali (provavelmente monta
`walletProvider.overrideWith(...)` com `InMemoryGameStorage`).

- [ ] **Step 2: Escrever os dois testes novos, que falham**

Adicionar ao arquivo de teste encontrado (usando o mesmo helper de
montagem que os testes vizinhos já usam — substituir `pumpLevelSelectScreen`
abaixo pelo nome real do helper local, mantendo os mesmos overrides que ele já
aplica e adicionando os da roleta):

```dart
  testWidgets(
    'abre o Daily Spin automaticamente quando o jogador está elegível',
    (tester) async {
      final storage = InMemoryGameStorage(); // nunca girou -> elegível
      await pumpLevelSelectScreen(
        tester,
        extraOverrides: [
          dailySpinStorageProvider.overrideWithValue(storage),
          notificationPortProvider.overrideWithValue(FakeNotificationPort()),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byKey(dailySpinKey), findsOneWidget);
    },
  );

  testWidgets(
    'não abre o Daily Spin automaticamente quando não elegível, mas o ícone continua acessível',
    (tester) async {
      final now = DateTime.utc(2026, 9, 11, 12, 0, 0);
      final storage = InMemoryGameStorage(lastSpinTimestamp: now);
      await pumpLevelSelectScreen(
        tester,
        extraOverrides: [
          dailySpinStorageProvider.overrideWithValue(storage),
          notificationPortProvider.overrideWithValue(FakeNotificationPort()),
          dailySpinClockProvider.overrideWithValue(() => now),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byKey(dailySpinKey), findsNothing);
      expect(find.byKey(levelSelectDailySpinIconKey), findsOneWidget);

      await tester.tap(find.byKey(levelSelectDailySpinIconKey));
      await tester.pumpAndSettle();

      expect(find.byKey(dailySpinKey), findsOneWidget);
    },
  );
```

Se o arquivo de teste ainda não tiver um `FakeNotificationPort` importado,
importar de `test/core/notifications/notification_service_test.dart`
**não é possível** (arquivos de teste não se importam entre si neste
projeto) — duplicar a classe mínima localmente no arquivo de teste da tela,
igual à definida na Task 8:

```dart
class FakeNotificationPort implements NotificationPort {
  @override
  Future<void> scheduleDailySpinReminder(DateTime at) async {}

  @override
  Future<void> scheduleInactivityReminder(DateTime at) async {}

  @override
  Future<void> cancelAll() async {}
}
```

- [ ] **Step 3: Rodar e confirmar que falha**

Run: `flutter test test/features/game/presentation/level_select_screen_test.dart`
Expected: FAIL — `levelSelectDailySpinIconKey` e o comportamento de
auto-abertura ainda não existem.

- [ ] **Step 4: Implementar na tela**

Em `lib/features/game/presentation/screens/level_select_screen.dart`,
adicionar os imports:

```dart
import 'package:nine_fuse/features/game/presentation/widgets/daily_spin_dialog.dart';
```

Adicionar a chave do ícone, ao lado de `kPathRevealDuration`:

```dart
/// Chave do ícone de atalho da roleta diária, na AppBar.
const Key levelSelectDailySpinIconKey = Key('level_select_daily_spin_icon');
```

Dentro de `_LevelSelectScreenState`, no `initState`, no mesmo
`addPostFrameCallback` que já existe, adicionar (depois de
`ref.read(walletProvider.notifier).refresh();`):

```dart
      // O app acabou de abrir (ou voltar ao primeiro plano nesta tela, que é
      // a home de fato): reagenda o lembrete de inatividade sempre para a
      // frente a partir de agora.
      ref.read(notificationServiceProvider).onAppOpened();

      final eligible = await ref.read(dailySpinEligibleProvider.future);
      if (!mounted || !eligible) return;
      _openDailySpin();
```

(o `addPostFrameCallback` recebe um callback síncrono hoje — trocar sua
assinatura para `async` é necessário; o callback em si já não devolve valor
usado por ninguém, então virar `async` não quebra nenhum chamador).

Adicionar o método:

```dart
  void _openDailySpin() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const DailySpinDialog(),
    );
  }
```

No `AppBar.actions`, ao lado de `CoinsHeaderBadge`, adicionar o ícone:

```dart
          IconButton(
            key: levelSelectDailySpinIconKey,
            icon: const Icon(Icons.casino, color: Colors.white),
            onPressed: _openDailySpin,
          ),
```

- [ ] **Step 5: Rodar e confirmar que passa**

Run: `flutter test test/features/game/presentation/level_select_screen_test.dart`
Expected: PASS, incluindo os dois testes novos.

- [ ] **Step 6: Rodar a suíte inteira**

Run: `flutter analyze && flutter test`
Expected: `flutter analyze` sem erro novo; `flutter test` 100% verde, sem
nenhuma regressão em relação à contagem de testes anterior a este plano.

- [ ] **Step 7: Commit**

```bash
git add lib/features/game/presentation/screens/level_select_screen.dart test/features/game/presentation/level_select_screen_test.dart
git commit -m "feat: Daily Spin no Saga Map (auto-abertura, ícone de atalho, reagendamento de inatividade)"
```

---

## Verificação final

- [ ] Run: `flutter analyze`
  Expected: 0 erros novos (avisos pré-existentes documentados no
  `CLAUDE.md` continuam fora de escopo).
- [ ] Run: `flutter test`
  Expected: 100% verde, sem regressão em relação à contagem de testes antes
  deste plano.
- [ ] Confirmar visualmente (não há golden novo previsto neste plano, mas se
  algum golden pré-existente do Saga Map ou da AppBar quebrar por causa do
  ícone novo — `saga_map.png` ou equivalente —, regerá-lo é esperado: um
  ícone novo na `AppBar` é mudança de pixel, mesmo padrão já registrado no
  `CLAUDE.md` para o badge de moedas).
