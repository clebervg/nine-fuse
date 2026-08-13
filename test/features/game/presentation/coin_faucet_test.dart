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
