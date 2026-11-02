import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/daily_spin.dart';
import 'package:nine_fuse/features/game/presentation/widgets/daily_spin_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/prize_wheel.dart';

void main() {
  group('targetTurnsFor', () {
    const jitters = [-kWheelMaxJitter, -0.15, 0.0, 0.15, kWheelMaxJitter];

    test('a fatia sorteada para sob o ponteiro, para todo índice e jitter', () {
      for (final count in [kSpinWheelPrizes.length, 6, 12]) {
        for (var index = 0; index < count; index++) {
          for (final jitter in jitters) {
            final turns = targetTurnsFor(index, count, jitter: jitter);
            expect(
              sliceUnderPointer(turns, count),
              index,
              reason: 'count=$count index=$index jitter=$jitter',
            );
          }
        }
      }
    });

    test('o jitter desloca a parada dentro da fatia, sem passar de 30%', () {
      const count = 8;
      for (var index = 0; index < count; index++) {
        for (final jitter in jitters) {
          final turns = targetTurnsFor(index, count, jitter: jitter);
          // Posição do ponteiro no referencial da roda, em fatias.
          final pointer = (-turns % 1.0) * count;
          var offset = pointer - index;
          if (offset > count / 2) offset -= count;
          if (offset < -count / 2) offset += count;
          expect(offset.abs(), lessThanOrEqualTo(kWheelMaxJitter + 1e-9));
          expect(offset, closeTo(jitter, 1e-9));
        }
      }
    });

    test('dá pelo menos 5 voltas completas, também a partir de um repouso', () {
      for (final from in [0.0, 5.3, 11.875]) {
        for (var index = 0; index < 8; index++) {
          final turns = targetTurnsFor(index, 8, jitter: 0.2, from: from);
          expect(turns - from, greaterThanOrEqualTo(kWheelFullTurns));
          expect(turns - from, lessThan(kWheelFullTurns + 2));
          expect(sliceUnderPointer(turns, 8), index);
        }
      }
    });
  });

  test('dividersPassed conta uma divisória por fatia a cada volta', () {
    expect(dividersPassed(0, 8), 0);
    expect(dividersPassed(1, 8), 8);
    expect(dividersPassed(5, 8) - dividersPassed(0, 8), 40);
  });

  test('formatSpinCountdown formata HH:MM:SS e não fica negativo', () {
    expect(
      formatSpinCountdown(const Duration(hours: 23, minutes: 59, seconds: 12)),
      '23:59:12',
    );
    expect(formatSpinCountdown(const Duration(seconds: 5)), '00:00:05');
    expect(formatSpinCountdown(const Duration(seconds: -3)), '00:00:00');
  });
}
