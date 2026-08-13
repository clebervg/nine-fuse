# Economia de Moedas — Plano de Implementação (Fase A)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dar ao NineFuse uma economia de moedas fechada — estrelas novas pagam, martelos custam, e o baú de fim de capítulo paga uma vez.

**Architecture:** O disco (`GameStorage`) continua sendo a autoridade única do saldo, como já é para martelos e recorde. Um `Wallet` (StateNotifier) é o rosto desse saldo para as telas que vivem **fora** de uma partida — o mapa da saga não tem `GameState`, então não alcança nem moeda nem martelo pelo caminho atual. Dentro de uma fase nada muda: a regra do martelo segue consumindo de `GameState.hammerCount`, que já é relido do disco a cada `startLevel`.

**Tech Stack:** Dart / Flutter, Riverpod (`StateNotifierProvider`), `shared_preferences`, `flutter_test`.

## Global Constraints

- Toda persistência nova entra nas **duas** implementações de `GameStorage`: `PrefsGameStorage` e `InMemoryGameStorage`. Um teste que instancia o fake sem o campo novo não compila, e é assim que se descobre o esquecimento.
- **Falha de leitura ou escrita nunca propaga.** Segue a regra já registrada na interface: `debugPrint` e segue o jogo. Perder saldo é ruim; travar o jogo é pior.
- Todo texto visível novo entra em `lib/l10n/app_pt.arb` **e** `lib/l10n/app_en.arb`, e o `flutter gen-l10n` roda antes de o teste passar. `test/l10n/english_screens_test.dart` pega o que faltar.
- Valores da economia: `kCoinsPerStar = 10`, `kHammerCoinPrice = 100`, `kChapterChestReward = 200`. Sempre pelas constantes, nunca literais espalhados.
- Nenhuma animação em repetição infinita em nada que esta fase toque — `pumpAndSettle` nunca terminaria e derrubaria a suíte de widget.
- Commits em português, no padrão do repositório (`feat:`, `test:`, `refactor:`).

---

## File Structure

- **Criar** `lib/features/game/domain/economy.dart` — as três constantes. Domínio puro, sem import de Flutter.
- **Criar** `lib/features/game/providers/wallet.dart` — `Wallet` (estado imutável) + `WalletNotifier` + `walletProvider`.
- **Criar** `test/features/game/providers/wallet_test.dart` — máquina de saldo, em Dart puro.
- **Modificar** `lib/features/game/providers/game_storage.dart` — duas chaves novas nas três classes (interface, Prefs, InMemory).
- **Modificar** `lib/features/game/presentation/screens/game_screen.dart:126` — a torneira, no mesmo ponto onde `record()` já é chamado.
- **Modificar** `lib/features/game/presentation/widgets/hammer_offer_dialog.dart` — o ralo, como segunda ação.
- **Modificar** `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb` — textos da compra.
- **Criar** `test/features/game/presentation/hammer_purchase_test.dart` — o ralo pela UI.

---

### Task 1: Persistência de moedas e baús reclamados

**Files:**
- Create: `lib/features/game/domain/economy.dart`
- Modify: `lib/features/game/providers/game_storage.dart:14-32` (interface), `:38-41` (chaves), `:109-120` (fake)
- Test: `test/features/game/providers/game_storage_test.dart` (criar se não existir)

**Interfaces:**
- Consumes: nada.
- Produces: `kCoinsPerStar`, `kHammerCoinPrice`, `kChapterChestReward` (todos `const int`); `GameStorage.readCoins() -> Future<int>`, `writeCoins(int) -> Future<void>`, `readClaimedChests() -> Future<Set<int>>`, `writeClaimedChests(Set<int>) -> Future<void>`; `InMemoryGameStorage({int coins, Set<int> claimedChests})` com os campos públicos `coins` e `claimedChests`.

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/features/game/providers/game_storage_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';

void main() {
  group('InMemoryGameStorage', () {
    test('guarda e devolve o saldo de moedas', () async {
      final storage = InMemoryGameStorage(coins: 40);

      expect(await storage.readCoins(), 40);

      await storage.writeCoins(130);
      expect(await storage.readCoins(), 130);
    });

    test('guarda os baús já reclamados', () async {
      final storage = InMemoryGameStorage();

      expect(await storage.readClaimedChests(), isEmpty);

      await storage.writeClaimedChests({1, 2});
      expect(await storage.readClaimedChests(), {1, 2});
    });

    test('devolve uma cópia dos baús, não a coleção interna', () async {
      // Sem a cópia, quem lê pode mutar o estado guardado pelas costas do
      // storage — o mesmo cuidado que `readLevelRecords` já toma com o mapa.
      final storage = InMemoryGameStorage(claimedChests: {1});

      (await storage.readClaimedChests()).add(2);

      expect(await storage.readClaimedChests(), {1});
    });
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/features/game/providers/game_storage_test.dart`
Expected: FAIL na compilação — `No named parameter with the name 'coins'` e `The method 'readCoins' isn't defined`.

- [ ] **Step 3: Criar as constantes da economia**

Criar `lib/features/game/domain/economy.dart`:

```dart
/// Os números da economia de moedas, num lugar só.
///
/// Ficam nomeados porque vão ser recalibrados: espalhá-los como literais pela
/// UI e pelos providers transformaria o próximo ajuste de balanceamento em caça
/// ao número mágico.
library;

/// Moedas por estrela **nova**.
///
/// Só estrela nova paga: `CampaignRecords.record()` já devolve o ganho com as
/// que o jogador tinha descontadas, então refazer a fase 1 não farma.
const int kCoinsPerStar = 10;

/// Preço de um Martelo de Fusão em moedas.
///
/// Deliberadamente caro: a campanha inteira com três estrelas em tudo rende 300
/// moedas, mais 200 por baú de capítulo. O anúncio recompensado continua sendo o
/// caminho principal de aquisição — a moeda é o consolo de quem não quer vê-lo,
/// não um substituto.
const int kHammerCoinPrice = 100;

/// O que o baú de fim de capítulo paga, uma única vez por capítulo.
const int kChapterChestReward = 200;
```

- [ ] **Step 4: Estender a interface e as duas implementações**

Em `lib/features/game/providers/game_storage.dart`, dentro de `abstract interface class GameStorage`, após `writeHammerCount`:

```dart
  /// Moedas em carteira.
  ///
  /// Como o martelo, é do **jogador** e não da fase. Diferente dele, nenhuma
  /// regra de partida a consome: quem gasta é o convite de aquisição.
  Future<int> readCoins();
  Future<void> writeCoins(int coins);

  /// Números dos capítulos cujo baú já foi reclamado.
  ///
  /// Guardar quem **já pagou** é o que impede o baú de repagar a cada visita ao
  /// mapa. É um conjunto, e não um contador, porque capítulos podem ser
  /// fechados fora de ordem quando a campanha crescer.
  Future<Set<int>> readClaimedChests();
  Future<void> writeClaimedChests(Set<int> chapters);
```

Em `PrefsGameStorage`, junto das outras chaves:

```dart
  static const String _coinsKey = 'wallet_coins';
  static const String _chestsKey = 'campaign_chests_claimed';
```

E os quatro métodos, depois de `writeHammerCount`:

```dart
  @override
  Future<int> readCoins() async =>
      (await SharedPreferences.getInstance()).getInt(_coinsKey) ?? 0;

  @override
  Future<void> writeCoins(int coins) async =>
      (await SharedPreferences.getInstance()).setInt(_coinsKey, coins);

  /// Os baús vão como lista de strings porque é o que o `SharedPreferences`
  /// oferece de coleção. A conversão para `Set<int>` acontece aqui, para o
  /// resto do app nunca ver o formato do disco.
  @override
  Future<Set<int>> readClaimedChests() async {
    final raw = (await SharedPreferences.getInstance()).getStringList(
      _chestsKey,
    );
    if (raw == null) return const {};

    return raw
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
  }

  @override
  Future<void> writeClaimedChests(Set<int> chapters) async =>
      (await SharedPreferences.getInstance()).setStringList(
        _chestsKey,
        chapters.map((chapter) => '$chapter').toList(),
      );
```

Em `InMemoryGameStorage`, o construtor e os campos:

```dart
class InMemoryGameStorage implements GameStorage {
  InMemoryGameStorage({
    this.campaignProgress = 0,
    this.highScore = 0,
    this.hammerCount = 0,
    this.coins = 0,
    Set<int>? claimedChests,
    Map<int, LevelRecord>? levelRecords,
  }) : claimedChests = claimedChests ?? {},
       levelRecords = levelRecords ?? {};

  int campaignProgress;
  int highScore;
  int hammerCount;
  int coins;
  Set<int> claimedChests;
  Map<int, LevelRecord> levelRecords;
```

E os quatro métodos, junto dos outros:

```dart
  @override
  Future<int> readCoins() async => coins;

  @override
  Future<void> writeCoins(int value) async => coins = value;

  @override
  Future<Set<int>> readClaimedChests() async => Set.of(claimedChests);

  @override
  Future<void> writeClaimedChests(Set<int> chapters) async =>
      claimedChests = Set.of(chapters);
```

- [ ] **Step 5: Rodar o teste e a suíte inteira**

Run: `flutter test test/features/game/providers/game_storage_test.dart`
Expected: PASS, 3 testes.

Run: `flutter test`
Expected: toda a suíte passa. Qualquer outro fake de storage no projeto que implemente `GameStorage` à mão vai falhar em compilar por faltar os quatro métodos — se isso acontecer, adicione os métodos lá também; é exatamente o alarme que a interface existe para dar.

- [ ] **Step 6: Commit**

```bash
git add lib/features/game/domain/economy.dart lib/features/game/providers/game_storage.dart test/features/game/providers/game_storage_test.dart
git commit -m "feat: persiste moedas e baús reclamados no GameStorage"
```

---

### Task 2: O `Wallet` — saldo para as telas fora de partida

**Files:**
- Create: `lib/features/game/providers/wallet.dart`
- Test: `test/features/game/providers/wallet_test.dart`

**Interfaces:**
- Consumes: `kHammerCoinPrice`, `kChapterChestReward` (Task 1); `GameStorage` com os quatro métodos novos (Task 1).
- Produces: classe `Wallet` com `coins`, `hammers`, `claimedChests`, `canAfford(int price) -> bool`, `hasClaimedChest(int chapter) -> bool`; `WalletNotifier` com `refresh() -> Future<void>`, `creditCoins(int amount) -> void`, `spendCoins(int price) -> bool`, `claimChapterChest(int chapter) -> bool`; `walletProvider` (`StateNotifierProvider<WalletNotifier, Wallet>`); construtor `WalletNotifier({GameStorage? storage})`.

- [ ] **Step 1: Escrever os testes que falham**

Criar `test/features/game/providers/wallet_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import 'package:nine_fuse/features/game/providers/wallet.dart';

/// Storage que estoura em tudo, para o caminho de falha.
class _BrokenStorage extends InMemoryGameStorage {
  @override
  Future<int> readCoins() async => throw StateError('disco fora');

  @override
  Future<void> writeCoins(int coins) async => throw StateError('disco fora');

  @override
  Future<Set<int>> readClaimedChests() async => throw StateError('disco fora');
}

void main() {
  group('WalletNotifier', () {
    test('lê o saldo salvo ao ser criado', () async {
      final storage = InMemoryGameStorage(coins: 250, hammerCount: 2);
      final wallet = WalletNotifier(storage: storage);

      await wallet.refresh();

      expect(wallet.state.coins, 250);
      expect(wallet.state.hammers, 2);
    });

    test('creditar soma ao saldo e grava', () async {
      final storage = InMemoryGameStorage(coins: 10);
      final wallet = WalletNotifier(storage: storage);
      await wallet.refresh();

      wallet.creditCoins(30);

      expect(wallet.state.coins, 40);
      await Future<void>.delayed(Duration.zero);
      expect(storage.coins, 40);
    });

    test('gastar com saldo suficiente debita exatamente o preço', () async {
      final storage = InMemoryGameStorage(coins: kHammerCoinPrice + 5);
      final wallet = WalletNotifier(storage: storage);
      await wallet.refresh();

      expect(wallet.spendCoins(kHammerCoinPrice), isTrue);
      expect(wallet.state.coins, 5);
    });

    test('gastar com saldo curto não debita nada', () async {
      final storage = InMemoryGameStorage(coins: kHammerCoinPrice - 1);
      final wallet = WalletNotifier(storage: storage);
      await wallet.refresh();

      expect(wallet.spendCoins(kHammerCoinPrice), isFalse);
      expect(wallet.state.coins, kHammerCoinPrice - 1);
    });

    test('o baú de um capítulo paga uma vez só', () async {
      final storage = InMemoryGameStorage();
      final wallet = WalletNotifier(storage: storage);
      await wallet.refresh();

      expect(wallet.claimChapterChest(1), isTrue);
      expect(wallet.state.coins, kChapterChestReward);

      // Segunda tentativa: o mapa é revisitado toda vez que o jogador volta de
      // uma fase, e um baú que repaga transforma a visita em torneira infinita.
      expect(wallet.claimChapterChest(1), isFalse);
      expect(wallet.state.coins, kChapterChestReward);
    });

    test('baús de capítulos diferentes pagam cada um', () async {
      final wallet = WalletNotifier(storage: InMemoryGameStorage());
      await wallet.refresh();

      expect(wallet.claimChapterChest(1), isTrue);
      expect(wallet.claimChapterChest(2), isTrue);
      expect(wallet.state.coins, kChapterChestReward * 2);
    });

    test('falha de disco vale como saldo vazio, sem propagar', () async {
      final wallet = WalletNotifier(storage: _BrokenStorage());

      await expectLater(wallet.refresh(), completes);
      expect(wallet.state.coins, 0);

      // Gravação que estoura também não pode derrubar a jogada.
      expect(() => wallet.creditCoins(50), returnsNormally);
      expect(wallet.state.coins, 50);
    });

    test('leitura que chega atrasada não apaga um crédito recente', () async {
      // Mesmo remédio de `HammerBooster.refreshHammers`: o disco pode responder
      // depois de o saldo já ter mudado em memória, e adotá-lo apagaria moedas
      // recém-creditadas.
      final storage = InMemoryGameStorage(coins: 10);
      final wallet = WalletNotifier(storage: storage);
      await wallet.refresh();

      final pending = wallet.refresh();
      wallet.creditCoins(100);
      await pending;

      expect(wallet.state.coins, 110);
    });
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/features/game/providers/wallet_test.dart`
Expected: FAIL na compilação — `Target of URI doesn't exist: 'package:nine_fuse/features/game/providers/wallet.dart'`.

- [ ] **Step 3: Implementar o `Wallet`**

Criar `lib/features/game/providers/wallet.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';

/// O que o jogador tem, visto de fora de uma partida.
@immutable
class Wallet {
  const Wallet({
    this.coins = 0,
    this.hammers = 0,
    this.claimedChests = const <int>{},
  });

  final int coins;

  /// Espelho do estoque de martelos, para o mapa poder mostrá-lo.
  ///
  /// Não é uma segunda fonte de verdade: a autoridade é o disco, e dentro de uma
  /// fase quem consome continua sendo `GameState.hammerCount`, que já é relido a
  /// cada `startLevel`. Este campo existe porque o mapa da saga vive **fora** de
  /// qualquer partida e não tem `GameState` de onde ler.
  final int hammers;

  final Set<int> claimedChests;

  bool canAfford(int price) => coins >= price;

  bool hasClaimedChest(int chapter) => claimedChests.contains(chapter);

  Wallet copyWith({int? coins, int? hammers, Set<int>? claimedChests}) => Wallet(
    coins: coins ?? this.coins,
    hammers: hammers ?? this.hammers,
    claimedChests: claimedChests ?? this.claimedChests,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Wallet &&
          coins == other.coins &&
          hammers == other.hammers &&
          setEquals(claimedChests, other.claimedChests);

  @override
  int get hashCode =>
      Object.hash(coins, hammers, Object.hashAllUnordered(claimedChests));

  @override
  String toString() => 'Wallet($coins moedas, $hammers martelos)';
}

/// Lê e move o saldo do jogador.
class WalletNotifier extends StateNotifier<Wallet> {
  WalletNotifier({GameStorage? storage})
    : _storage = storage ?? const PrefsGameStorage(),
      super(const Wallet());

  final GameStorage _storage;

  /// Relê tudo do disco.
  ///
  /// Chamado ao abrir o mapa e ao voltar de uma fase, e não só no construtor:
  /// uma partida pode ter gasto ou ganho martelo enquanto o mapa estava fora de
  /// cena. É o mesmo remédio de `EndlessHighScore.refresh` e de
  /// `HammerBooster.refreshHammers`.
  ///
  /// Uma leitura que chega depois de o saldo ter mudado em memória é
  /// descartada: o disco está velho, e adotá-lo apagaria moedas recém-creditadas.
  Future<void> refresh() async {
    final before = state;
    try {
      final coins = await _storage.readCoins();
      final hammers = await _storage.readHammerCount();
      final chests = await _storage.readClaimedChests();
      if (!mounted || state != before) return;

      state = Wallet(coins: coins, hammers: hammers, claimedChests: chests);
    } catch (error, stack) {
      debugPrint('Falha ao ler a carteira: $error\n$stack');
    }
  }

  void creditCoins(int amount) {
    if (amount <= 0) return;
    state = state.copyWith(coins: state.coins + amount);
    _persistCoins();
  }

  /// Debita [price] se houver saldo. Devolve se a compra aconteceu.
  ///
  /// Não credita nada em troca: quem entrega o item é quem chamou. Misturar as
  /// duas coisas aqui obrigaria a carteira a conhecer todo item comprável.
  bool spendCoins(int price) {
    if (!state.canAfford(price)) return false;

    state = state.copyWith(coins: state.coins - price);
    _persistCoins();
    return true;
  }

  /// Paga o baú de [chapter], uma vez só. Devolve se pagou agora.
  bool claimChapterChest(int chapter) {
    if (state.hasClaimedChest(chapter)) return false;

    final chests = {...state.claimedChests, chapter};
    state = state.copyWith(
      coins: state.coins + kChapterChestReward,
      claimedChests: chests,
    );
    _persistCoins();
    _persistChests(chests);
    return true;
  }

  /// A gravação é assíncrona e o estado não a espera: travar a UI até o disco
  /// responder seria pagar latência de I/O numa troca de tela. Falha de escrita
  /// custa o saldo na próxima abertura, não a ação de agora.
  Future<void> _persistCoins() async {
    try {
      await _storage.writeCoins(state.coins);
    } catch (error, stack) {
      debugPrint('Falha ao gravar as moedas: $error\n$stack');
    }
  }

  Future<void> _persistChests(Set<int> chests) async {
    try {
      await _storage.writeClaimedChests(chests);
    } catch (error, stack) {
      debugPrint('Falha ao gravar os baús reclamados: $error\n$stack');
    }
  }
}

final walletProvider = StateNotifierProvider<WalletNotifier, Wallet>(
  (ref) => WalletNotifier(),
);
```

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `flutter test test/features/game/providers/wallet_test.dart`
Expected: PASS, 8 testes.

- [ ] **Step 5: Commit**

```bash
git add lib/features/game/providers/wallet.dart test/features/game/providers/wallet_test.dart
git commit -m "feat: carteira de moedas com persistência e baús reclamados"
```

---

### Task 3: A torneira — estrelas novas pagam moedas

**Files:**
- Modify: `lib/features/game/presentation/screens/game_screen.dart:115-136`
- Test: `test/features/game/presentation/coin_faucet_test.dart` (criar)

**Interfaces:**
- Consumes: `walletProvider`, `WalletNotifier.creditCoins` (Task 2); `kCoinsPerStar` (Task 1).
- Produces: nada de novo — só liga o retorno de `CampaignRecords.record()` à carteira.

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/features/game/presentation/coin_faucet_test.dart`. O teste chama a carteira e os registros diretamente, sem montar a tela: a regra em jogo é "estrela nova paga", e ela não depende de pixel nenhum.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/providers/campaign_records.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import 'package:nine_fuse/features/game/providers/wallet.dart';

void main() {
  group('torneira de moedas', () {
    late CampaignRecords records;
    late WalletNotifier wallet;

    setUp(() {
      records = CampaignRecords(storage: InMemoryGameStorage());
      wallet = WalletNotifier(storage: InMemoryGameStorage());
    });

    /// O que a tela faz na vitória, reduzido à regra.
    void win(int level, {required int stars, int score = 100}) {
      final gained = records.record(level, stars: stars, score: score);
      wallet.creditCoins(gained * kCoinsPerStar);
    }

    test('a primeira vitória paga por todas as estrelas', () {
      win(1, stars: 3);

      expect(wallet.state.coins, 3 * kCoinsPerStar);
    });

    test('rejogar com a mesma nota não paga de novo', () {
      win(1, stars: 3);
      win(1, stars: 3);

      // É o abuso óbvio: refazer a fase 1 em looping. O desconto vem de graça
      // porque `record()` já devolve só o ganho.
      expect(wallet.state.coins, 3 * kCoinsPerStar);
    });

    test('rejogar melhor paga só a diferença', () {
      win(1, stars: 1);
      win(1, stars: 3);

      expect(wallet.state.coins, 3 * kCoinsPerStar);
    });

    test('rejogar pior não tira moedas', () {
      win(1, stars: 3);
      win(1, stars: 1);

      expect(wallet.state.coins, 3 * kCoinsPerStar);
    });
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/features/game/presentation/coin_faucet_test.dart`
Expected: FAIL na compilação — `wallet.dart` existe (Task 2), mas `economy.dart` só será encontrado se a Task 1 foi feita. Se as duas foram feitas, este teste **passa de primeira**: ele descreve a composição de duas peças que já existem. Nesse caso o valor dele é de regressão — siga para o Step 3, que é onde a tela realmente muda.

- [ ] **Step 3: Ligar a torneira na tela**

Em `lib/features/game/presentation/screens/game_screen.dart`, adicionar o import:

```dart
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/providers/wallet.dart';
```

E dentro do `ref.listen(gameProvider, ...)`, logo após a atribuição de `_chapterStarsGained` (linha ~135), acrescentar:

```dart
        // A torneira da economia. Paga pelo ganho, e não pelas estrelas da
        // partida: `record()` já descontou as que o jogador tinha, então
        // rejogar a fase 1 em looping rende zero e nenhuma regra anti-farm
        // precisa existir.
        ref
            .read(walletProvider.notifier)
            .creditCoins(_chapterStarsGained * kCoinsPerStar);
```

- [ ] **Step 4: Rodar os testes**

Run: `flutter test test/features/game/presentation/coin_faucet_test.dart`
Expected: PASS, 4 testes.

Run: `flutter test test/features/game/presentation/game_screen_test.dart`
Expected: PASS — a tela ganhou uma leitura de provider, e nenhum teste existente muda de comportamento.

- [ ] **Step 5: Commit**

```bash
git add lib/features/game/presentation/screens/game_screen.dart test/features/game/presentation/coin_faucet_test.dart
git commit -m "feat: estrelas novas creditam moedas na carteira"
```

---

### Task 4: O ralo — comprar martelo com moedas

**Files:**
- Modify: `lib/features/game/presentation/widgets/hammer_offer_dialog.dart`
- Modify: `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb`
- Test: `test/features/game/presentation/hammer_purchase_test.dart` (criar)

**Interfaces:**
- Consumes: `walletProvider`, `WalletNotifier.spendCoins` (Task 2); `kHammerCoinPrice` (Task 1); `HammerOfferDialog.onGranted` (já existe).
- Produces: `const Key hammerOfferBuyKey = Key('hammer_offer_buy')`; textos `hammerOfferBuy(price)` e `hammerOfferNoCoins`.

**Nota de desenho:** a compra **não credita o martelo**. Ela debita a moeda e chama `onGranted`, que é o mesmo caminho do anúncio — e é `GameNotifier.grantHammer` quem credita e bate no alvo guardado. Creditar aqui também daria dois martelos por uma compra.

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/features/game/presentation/hammer_purchase_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/presentation/widgets/game_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_offer_dialog.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import 'package:nine_fuse/features/game/providers/wallet.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

void main() {
  /// Monta o convite sobre uma carteira com [coins] moedas.
  Future<WalletNotifier> pumpOffer(
    WidgetTester tester, {
    required int coins,
    required VoidCallback onGranted,
  }) async {
    final wallet = WalletNotifier(
      storage: InMemoryGameStorage(coins: coins),
    );
    await wallet.refresh();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [walletProvider.overrideWith((ref) => wallet)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: HammerOfferDialog(
              onGranted: onGranted,
              onDecline: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return wallet;
  }

  testWidgets('compra com saldo suficiente debita e entrega o martelo', (
    tester,
  ) async {
    var granted = 0;
    final wallet = await pumpOffer(
      tester,
      coins: kHammerCoinPrice + 30,
      onGranted: () => granted++,
    );

    await tester.tap(find.byKey(hammerOfferBuyKey));
    await tester.pumpAndSettle();

    expect(wallet.state.coins, 30);
    // Quem credita o martelo é o notifier da partida, pelo mesmo caminho do
    // anúncio — a caixa só avisa que foi pago.
    expect(granted, 1);
  });

  testWidgets('com saldo curto o botão de compra fica desabilitado', (
    tester,
  ) async {
    var granted = 0;
    final wallet = await pumpOffer(
      tester,
      coins: kHammerCoinPrice - 1,
      onGranted: () => granted++,
    );

    await tester.tap(find.byKey(hammerOfferBuyKey));
    await tester.pumpAndSettle();

    expect(wallet.state.coins, kHammerCoinPrice - 1);
    expect(granted, 0);
  });

  testWidgets('o botão de anúncio continua funcionando sem moeda nenhuma', (
    tester,
  ) async {
    // O anúncio é o caminho principal de aquisição: a compra não pode tê-lo
    // substituído nem escondido.
    var granted = 0;
    await pumpOffer(tester, coins: 0, onGranted: () => granted++);

    expect(find.byKey(hammerOfferWatchKey), findsOneWidget);

    await tester.tap(find.byKey(hammerOfferWatchKey));
    await tester.pumpAndSettle();

    expect(granted, 1);
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/features/game/presentation/hammer_purchase_test.dart`
Expected: FAIL — `Undefined name 'hammerOfferBuyKey'`.

- [ ] **Step 3: Adicionar os textos**

Em `lib/l10n/app_pt.arb`:

```json
  "hammerOfferBuy": "Comprar por {price} 🪙",
  "@hammerOfferBuy": {
    "description": "Botão que troca moedas por um Martelo de Fusão.",
    "placeholders": { "price": { "type": "int" } }
  },
  "hammerOfferNoCoins": "Moedas insuficientes",
  "@hammerOfferNoCoins": {
    "description": "Explica por que o botão de compra está desabilitado."
  },
```

Em `lib/l10n/app_en.arb`:

```json
  "hammerOfferBuy": "Buy for {price} 🪙",
  "@hammerOfferBuy": {
    "description": "Button that trades coins for a Fusion Hammer.",
    "placeholders": { "price": { "type": "int" } }
  },
  "hammerOfferNoCoins": "Not enough coins",
  "@hammerOfferNoCoins": {
    "description": "Explains why the buy button is disabled."
  },
```

Run: `flutter gen-l10n`
Expected: sem erros; `lib/l10n/app_localizations.dart` ganha os dois métodos.

- [ ] **Step 4: Implementar a compra**

Em `hammer_offer_dialog.dart`, adicionar os imports:

```dart
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/providers/wallet.dart';
```

Adicionar a chave, junto das outras:

```dart
/// Chave do botão que troca moedas por martelo.
const Key hammerOfferBuyKey = Key('hammer_offer_buy');
```

No `_HammerOfferDialogState`, adicionar o método:

```dart
  /// Troca moedas por um martelo.
  ///
  /// Debita e delega a entrega ao mesmo `onGranted` do anúncio: quem credita o
  /// item e bate no alvo guardado é `GameNotifier.grantHammer`. Creditar aqui
  /// também renderia dois martelos por uma compra.
  void _buy() {
    if (_waiting) return;
    if (!ref.read(walletProvider.notifier).spendCoins(kHammerCoinPrice)) return;

    widget.onGranted();
  }
```

No `build`, ler a carteira logo após o `l10n`:

```dart
    final wallet = ref.watch(walletProvider);
    final canAfford = wallet.canAfford(kHammerCoinPrice);
```

E inserir o botão de compra **entre** o de anúncio e o de recusa, com o aviso de saldo curto:

```dart
          const SizedBox(height: 10),
          GameButton(
            key: hammerOfferBuyKey,
            label: l10n.hammerOfferBuy(kHammerCoinPrice),
            color: canAfford ? AppColors.digit3 : AppColors.darkSurface,
            foreground: canAfford ? Colors.black : Colors.white38,
            icon: Icons.shopping_bag_rounded,
            // Nulo desabilita o botão, e é o que o teste de saldo curto afirma:
            // um botão que aceita o toque e não faz nada é pior do que um
            // botão apagado, porque o jogador não sabe se falhou ou foi cobrado.
            onPressed: canAfford ? _buy : null,
          ),
          if (!canAfford) ...[
            const SizedBox(height: 6),
            Text(
              l10n.hammerOfferNoCoins,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
```

**`GameButton` precisa aprender a ficar desabilitado.** Hoje `onPressed` é
`VoidCallback` não-anulável (`game_dialog.dart:228`), e um botão desabilitado é
um caso que o design system tem de cobrir de qualquer forma. Três edições
cirúrgicas em `game_dialog.dart`:

Linha 228 — tornar anulável:

```dart
  final VoidCallback? onPressed;
```

No `_GameButtonState`, adicionar o getter junto de `_pressed`:

```dart
  /// Sem callback o botão é decorativo: não afunda e não anuncia ação.
  bool get _enabled => widget.onPressed != null;
```

E o `GestureDetector` (linhas 289-293) passa a guardar os três gestos, senão o
botão desabilitado ainda afundaria ao toque — prometendo uma ação que não vem:

```dart
      child: GestureDetector(
        onTapDown: (_) {
          if (!_enabled) return;
          setState(() => _pressed = true);
        },
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onPressed,
```

O `Semantics` de cima ganha `enabled: _enabled`, para o leitor de tela não
oferecer um botão que não responde.

- [ ] **Step 5: Rodar os testes**

Run: `flutter test test/features/game/presentation/hammer_purchase_test.dart`
Expected: PASS, 3 testes.

Run: `flutter test test/features/game/presentation/hammer_booster_test.dart test/l10n`
Expected: PASS — o convite ganhou um botão, e nenhum teste existente aponta para posição.

- [ ] **Step 6: Commit**

```bash
git add lib/features/game/presentation/widgets/hammer_offer_dialog.dart lib/features/game/presentation/widgets/game_dialog.dart lib/l10n test/features/game/presentation/hammer_purchase_test.dart
git commit -m "feat: comprar Martelo de Fusão com moedas no convite de aquisição"
```

---

### Task 5: Reconciliar a carteira ao voltar de uma partida

**Files:**
- Modify: `lib/features/game/presentation/screens/level_select_screen.dart:44-52` (o `initState`, junto do `refresh()` do recorde) e o `.then(...)` do retorno do Endless (`:179-185`)
- Test: `test/features/game/providers/wallet_refresh_test.dart` (criar)

**Interfaces:**
- Consumes: `walletProvider`, `WalletNotifier.refresh` (Task 2).
- Produces: nada. É o ponto que impede o mapa de mostrar saldo velho.

**Por que existe:** a partida gasta e ganha martelo escrevendo direto no `GameStorage` (`HammerBooster._persistHammers`). O mapa fica fora de cena enquanto isso. Sem reler ao voltar, a barra de recursos mostraria o saldo de antes da fase — o mesmo problema que `EndlessHighScore.refresh` já resolve para o recorde, e pelo mesmo motivo.

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/features/game/providers/wallet_refresh_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import 'package:nine_fuse/features/game/providers/wallet.dart';

void main() {
  test('refresh adota o martelo gasto durante a partida', () async {
    // A partida escreve direto no storage; o mapa estava fora de cena.
    final storage = InMemoryGameStorage(coins: 100, hammerCount: 3);
    final wallet = WalletNotifier(storage: storage);
    await wallet.refresh();

    expect(wallet.state.hammers, 3);

    storage.hammerCount = 2;
    await wallet.refresh();

    expect(wallet.state.hammers, 2);
    expect(wallet.state.coins, 100);
  });
}
```

- [ ] **Step 2: Rodar e confirmar o comportamento**

Run: `flutter test test/features/game/providers/wallet_refresh_test.dart`
Expected: PASS — a Task 2 já implementou `refresh()`. Este teste trava o contrato de que ele **adota** o disco quando nada mudou em memória, que é o oposto do descarte da leitura atrasada. Os dois casos convivem, e é por isso que ambos têm teste.

- [ ] **Step 3: Chamar o refresh na tela do mapa**

Em `level_select_screen.dart`, adicionar o import:

```dart
import 'package:nine_fuse/features/game/providers/wallet.dart';
```

No `initState`, junto do `refresh()` do recorde que já existe:

```dart
    // O mapa fica fora de cena enquanto a fase roda, e a fase gasta e ganha
    // martelo escrevendo direto no disco. Sem reler, a barra de recursos
    // mostraria o saldo de antes da partida.
    ref.read(walletProvider.notifier).refresh();
```

E no `.then(...)` do retorno do Endless, ao lado do `endlessHighScoreProvider`:

```dart
                            ref.read(walletProvider.notifier).refresh();
```

E em `_openLevel` (`level_select_screen.dart:247-256`), que já tem um `.then`
recentralizando o mapa na volta — a carteira entra na mesma guarda de `mounted`:

```dart
  void _openLevel(GameLevel level, CampaignProgress unlocked) {
    if (!unlocked.isUnlocked(level)) return;

    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => GameScreen(level: level)))
        .then((_) {
          // Ao voltar, reposiciona o mapa na fase da vez — que pode ser outra.
          if (!mounted) return;
          _centerOnCurrentLevel();
          // A fase pode ter gasto martelo e ganho moeda por estrela nova.
          ref.read(walletProvider.notifier).refresh();
        });
  }
```

**O que este `refresh` conserta é o martelo, não a moeda.** A torneira da Task 3
credita direto no `walletProvider`, que é o mesmo objeto que o mapa observa — as
moedas chegam em memória sozinhas. Já o martelo é gasto e creditado por
`HammerBooster`, que escreve **só no disco**: sem reler, a barra mostraria o
estoque de antes da fase. Vale a pena ter isso claro ao revisar o teste da Task
5, que é justamente sobre o martelo.

- [ ] **Step 4: Rodar a suíte do mapa**

Run: `flutter test test/features/game/presentation/level_select_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/game/presentation/screens/level_select_screen.dart test/features/game/providers/wallet_refresh_test.dart
git commit -m "feat: relê a carteira ao voltar de uma partida para o mapa"
```

---

### Task 6: Fechamento da Fase A

**Files:**
- Modify: `CLAUDE.md` (seção de registro de evolução)

**Interfaces:**
- Consumes: tudo das Tasks 1-5.
- Produces: nada de código.

- [ ] **Step 1: Rodar a análise estática**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Rodar a suíte inteira**

Run: `flutter test`
Expected: todos passam. Se algum golden falhar, **pare e investigue** — a Fase A não muda pixel nenhum, então um golden quebrado aqui é regressão de verdade, não expectativa desatualizada.

- [ ] **Step 3: Registrar no CLAUDE.md**

Acrescentar uma seção "### Economia de Moedas ✅ Concluída" seguindo o estilo do arquivo — decisões e o **porquê** delas, não lista de arquivos. Cobrir no mínimo: por que só estrela nova paga (`record()` já devolve o ganho, e é o que dispensa regra anti-farm); por que a carteira existe apesar de o martelo morar no `GameState` (o mapa não tem `GameState`, e o disco continua sendo a autoridade única); por que `spendCoins` não credita o item (dois martelos por uma compra); e por que o baú guarda quem já pagou.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: registra as decisões da economia de moedas"
```

---

## O que NÃO entra nesta fase

- **A `UserResourcesBar`, a pílula do Endless, o fundo com gradiente, o nó do baú e o AppIcon** são a Fase B, que ganha plano próprio. A Fase A entrega uma economia funcionando e testada, sem nada na tela além do botão de compra — é software que funciona sozinho, que é o critério para uma fase existir.
- **O `ObstacleOverlay`** não é tocado, por decisão registrada no spec.
- **Os três itens de gameplay do pedido original** (spacing do booster, `BackdropFilter` da mira, gradiente dos cards) já estão implementados; reimplementá-los produziria diff sem mudança de comportamento.
- **O cap de 3 martelos/dia** da regra de AdMob continua fora, como já estava.
