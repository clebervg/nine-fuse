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
