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
