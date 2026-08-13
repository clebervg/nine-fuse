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
