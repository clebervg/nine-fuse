import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/daily_ad_count.dart';
import 'package:nine_fuse/features/game/domain/daily_reward.dart';
import 'package:nine_fuse/features/game/domain/daily_spin.dart';

DateTime day(int d, {int hour = 10}) => DateTime(2026, 11, d, hour);

void main() {
  test('o ciclo tem 7 dias e o dia 7 é o maior', () {
    expect(kDailyRewardCycle, hasLength(7));
    int coins(List<SpinPrize> prizes) => prizes
        .where((p) => p.type == SpinPrizeType.coins)
        .fold(0, (sum, p) => sum + p.amount);
    final last = coins(kDailyRewardCycle.last);
    for (final prizes in kDailyRewardCycle.take(6)) {
      expect(coins(prizes), lessThan(last));
    }
  });

  test('quem nunca coletou recebe o dia 1', () {
    final status = dailyRewardStatus(DailyStreak.none, day(3));
    expect(status.available, isTrue);
    expect(status.cycleDay, 0);
    expect(status.streakAfterClaim, 1);
  });

  test('coletar marca hoje e não deixa coletar de novo no mesmo dia', () {
    final after = claimDailyReward(DailyStreak.none, day(3))!;
    expect(
      after,
      DailyStreak(lastClaimDay: localDayKey(day(3)), claimedDays: 1),
    );
    expect(claimDailyReward(after, day(3, hour: 23)), isNull);
    final status = dailyRewardStatus(after, day(3, hour: 23));
    expect(status.available, isFalse);
    expect(status.cycleDay, 0);
  });

  test('voltar no dia seguinte continua a sequência', () {
    var streak = DailyStreak.none;
    for (int d = 1; d <= 5; d++) {
      streak = claimDailyReward(streak, day(d))!;
    }
    expect(streak.claimedDays, 5);
    final status = dailyRewardStatus(streak, day(6));
    expect(status.cycleDay, 5);
    expect(status.streakAfterClaim, 6);
  });

  test('pular um dia recomeça do dia 1', () {
    var streak = claimDailyReward(DailyStreak.none, day(1))!;
    streak = claimDailyReward(streak, day(2))!;
    final status = dailyRewardStatus(streak, day(4));
    expect(status.cycleDay, 0);
    expect(status.streakAfterClaim, 1);
  });

  test('depois do dia 7 o ciclo de prêmios recomeça, a sequência não', () {
    var streak = DailyStreak.none;
    for (int d = 1; d <= 7; d++) {
      streak = claimDailyReward(streak, day(d))!;
    }
    final status = dailyRewardStatus(streak, day(8));
    expect(status.cycleDay, 0);
    expect(status.streakAfterClaim, 8);
  });

  test('a véspera vem do calendário, não de 24 h (horário de verão)', () {
    // 00:30 do dia 4: "agora menos 24 h" cairia no dia 3 de qualquer jeito,
    // mas o teste trava a régua — a véspera do dia 4 é sempre o dia 3.
    expect(previousDayKey(DateTime(2026, 11, 4, 0, 30)), localDayKey(day(3)));
    expect(previousDayKey(DateTime(2026, 3, 1, 12)), '2026-02-28');
  });
}
