import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/daily_missions.dart';

void main() {
  group('missionsForDay', () {
    test('é determinístico pela data', () {
      expect(
        missionsForDay('2026-11-03', campaignProgress: 40),
        missionsForDay('2026-11-03', campaignProgress: 40),
      );
    });

    test('três missões, de três tipos diferentes, em vários dias', () {
      for (int d = 1; d <= 60; d++) {
        final key =
            '2026-${(d ~/ 28 + 1).toString().padLeft(2, '0')}-'
            '${(d % 28 + 1).toString().padLeft(2, '0')}';
        for (final progress in [0, 5, 40]) {
          final missions = missionsForDay(key, campaignProgress: progress);
          expect(missions, hasLength(3), reason: '$key $progress');
          expect(
            missions.map((m) => m.kind).toSet(),
            hasLength(3),
            reason: '$key $progress',
          );
        }
      }
    });

    test('dias diferentes variam as missões', () {
      final variants = {
        for (int d = 1; d <= 28; d++)
          missionsForDay(
            '2026-11-${d.toString().padLeft(2, '0')}',
            campaignProgress: 40,
          ).map((m) => m.kind.name).join(','),
      };
      expect(variants.length, greaterThan(5));
    });

    test('antes da fase 10 não pede 9, Nova nem cobertura', () {
      const advanced = {
        MissionKind.createNines,
        MissionKind.triggerNova,
        MissionKind.breakObstacles,
      };
      for (int d = 1; d <= 28; d++) {
        final missions = missionsForDay(
          '2026-11-${d.toString().padLeft(2, '0')}',
          campaignProgress: kAdvancedMissionsFromProgress - 1,
        );
        for (final mission in missions) {
          expect(advanced.contains(mission.kind), isFalse, reason: '$mission');
        }
      }
    });
  });

  group('DailyMissions', () {
    const day = '2026-11-03';
    final base = DailyMissions(
      day: day,
      missions: const [
        Mission(MissionKind.fusions, 10, 25),
        Mission(MissionKind.winLevels, 2, 40),
        Mission(MissionKind.triggerNova, 1, 70),
      ],
      progress: const [0, 0, 0],
      claimed: const [false, false, false],
    );

    test('o progresso soma por tipo e para no alvo', () {
      final after = base
          .record(MissionKind.fusions, 7)
          .record(MissionKind.fusions, 7)
          .record(MissionKind.winLevels, 1);
      expect(after.progress, [10, 1, 0]);
      expect(after.canClaim(0), isTrue);
      expect(after.canClaim(1), isFalse);
      expect(after.claimableCount, 1);
    });

    test('quantidade zero não muda nada (nem cria estado novo)', () {
      expect(identical(base.record(MissionKind.fusions, 0), base), isTrue);
    });

    test('coletar uma vez só; o bônus exige as três coletadas', () {
      var state = base
          .record(MissionKind.fusions, 10)
          .record(MissionKind.winLevels, 2)
          .record(MissionKind.triggerNova, 1);
      expect(state.claimableCount, 3);

      state = state.claim(0);
      expect(state.claimed, [true, false, false]);
      expect(identical(state.claim(0), state), isTrue);
      expect(state.canClaimBonus, isFalse);

      state = state.claim(1).claim(2);
      expect(state.canClaimBonus, isTrue);
      expect(state.claimableCount, 1);

      state = state.claimBonus();
      expect(state.bonusClaimed, isTrue);
      expect(state.claimableCount, 0);
    });

    test('missão coletada não conta mais progresso', () {
      final state = base.record(MissionKind.fusions, 10).claim(0);
      expect(state.record(MissionKind.fusions, 5).progress[0], 10);
    });

    test('grava e lê de volta o mesmo estado', () {
      final state = base.record(MissionKind.fusions, 4).claim(0);
      expect(DailyMissions.decode(state.encode()), state);
    });

    test('gravação corrompida vale como vazio', () {
      expect(DailyMissions.decode(null), DailyMissions.empty);
      expect(DailyMissions.decode('{lixo'), DailyMissions.empty);
      expect(
        DailyMissions.decode('{"day":"x","missions":[]}'),
        DailyMissions.empty,
      );
    });

    test('o bônus é um booster e é o mesmo o dia todo', () {
      expect(missionsBonusFor(day), missionsBonusFor(day));
    });
  });
}
