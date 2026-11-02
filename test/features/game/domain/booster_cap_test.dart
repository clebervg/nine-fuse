import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';

void main() {
  group('capBoosterReward', () {
    test('abaixo do teto credita tudo, sem moeda de troco', () {
      final credit = capBoosterReward(current: 2, amount: 1);
      expect(credit.count, 3);
      expect(credit.overflowCoins, 0);
    });

    test('chegar exatamente no teto ainda credita tudo', () {
      final credit = capBoosterReward(current: 4, amount: 1);
      expect(credit.count, kMaxBoosterStock);
      expect(credit.overflowCoins, 0);
    });

    test('cada unidade acima do teto vira kCoinsPerOverflowBooster', () {
      final credit = capBoosterReward(current: 4, amount: 3);
      expect(credit.count, kMaxBoosterStock);
      expect(credit.overflowCoins, 2 * kCoinsPerOverflowBooster);
    });

    test('estoque já cheio converte o prêmio inteiro', () {
      final credit = capBoosterReward(current: 5, amount: 1);
      expect(credit.count, 5);
      expect(credit.overflowCoins, kCoinsPerOverflowBooster);
    });

    test('estoque legado acima do teto não é cortado, só não cresce', () {
      final credit = capBoosterReward(current: 8, amount: 1);
      expect(credit.count, 8);
      expect(credit.overflowCoins, kCoinsPerOverflowBooster);
    });
  });
}
