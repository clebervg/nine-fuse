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
