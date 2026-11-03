import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/daily_ad_count.dart';
import 'package:nine_fuse/features/game/domain/daily_missions.dart';
import 'package:nine_fuse/features/game/domain/daily_reward.dart';
import 'package:nine_fuse/features/game/domain/daily_spin.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';
import 'package:nine_fuse/features/game/providers/daily_progress.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';

void main() {
  var now = DateTime(2026, 11, 3, 10);
  DateTime clock() => now;

  setUp(() => now = DateTime(2026, 11, 3, 10));

  group('DailyRewardNotifier', () {
    test('desligado sem armazenamento: nada disponível, nada pago', () async {
      final credit = InMemoryGameStorage();
      final notifier = DailyRewardNotifier(creditStorage: credit, clock: clock);
      expect(notifier.state.availableAt(now), isFalse);
      expect(await notifier.claim(), isNull);
      expect(credit.coins, 0);
    });

    test('coleta o dia 1, grava a sequência e não paga duas vezes', () async {
      final storage = InMemoryDailyProgressStorage();
      final credit = InMemoryGameStorage();
      final notifier = DailyRewardNotifier(
        storage: storage,
        creditStorage: credit,
        clock: clock,
      );
      await notifier.ready;
      expect(notifier.state.availableAt(now), isTrue);

      final payouts = await notifier.claim();
      expect(payouts, hasLength(1));
      expect(credit.coins, kDailyRewardCycle.first.first.amount);
      expect(storage.streak.claimedDays, 1);
      expect(storage.streak.lastClaimDay, localDayKey(now));

      expect(await notifier.claim(), isNull);
      expect(credit.coins, kDailyRewardCycle.first.first.amount);
    });

    test('booster do dia respeita o teto de estoque grátis', () async {
      // O dia do ciclo que paga um Martelo; com o estoque no teto ele vira
      // moeda. Achado na tabela, e não fixo: o ciclo é recalibrado.
      final hammerDay = kDailyRewardCycle.indexWhere(
        (prizes) => prizes.any((p) => p.type == SpinPrizeType.hammer),
      );
      final yesterday = DateTime(2026, 11, 2, 10);
      final storage = InMemoryDailyProgressStorage(
        streak: DailyStreak(
          lastClaimDay: localDayKey(yesterday),
          claimedDays: hammerDay,
        ),
      );
      final credit = InMemoryGameStorage()..hammerCount = kMaxBoosterStock;
      final notifier = DailyRewardNotifier(
        storage: storage,
        creditStorage: credit,
        clock: clock,
      );
      await notifier.ready;

      final payouts = (await notifier.claim())!;
      expect(payouts.single.credited, 0);
      expect(payouts.single.overflowCoins, kCoinsPerOverflowBooster);
      expect(credit.hammerCount, kMaxBoosterStock);
      expect(credit.coins, kCoinsPerOverflowBooster);
    });
  });

  group('MissionsNotifier', () {
    MissionsNotifier build(
      InMemoryDailyProgressStorage storage,
      InMemoryGameStorage credit, {
      int progress = 40,
    }) => MissionsNotifier(
      storage: storage,
      creditStorage: credit,
      clock: clock,
      campaignProgress: () => progress,
    );

    test('sorteia as missões do dia na primeira abertura e grava', () async {
      final storage = InMemoryDailyProgressStorage();
      final notifier = build(storage, InMemoryGameStorage());
      await notifier.ready;

      expect(notifier.state.day, localDayKey(now));
      expect(notifier.state.missions, hasLength(3));
      expect(storage.missions, notifier.state);
    });

    test('evento que chega antes do disco não se perde', () async {
      const kind = MissionKind.fusions;
      final saved = DailyMissions(
        day: localDayKey(now),
        missions: const [
          Mission(kind, 50, 40),
          Mission(MissionKind.winLevels, 1, 25),
          Mission(MissionKind.earnStars, 5, 50),
        ],
        progress: const [10, 0, 0],
        claimed: const [false, false, false],
      );
      final storage = InMemoryDailyProgressStorage(missions: saved);
      final notifier = build(storage, InMemoryGameStorage());

      notifier.record(kind, 5); // o disco ainda não respondeu
      await notifier.ready;

      expect(notifier.state.progress.first, 15);
      expect(storage.missions.progress.first, 15);
    });

    test('virar o dia troca as missões e zera o progresso', () async {
      final storage = InMemoryDailyProgressStorage();
      final notifier = build(storage, InMemoryGameStorage());
      await notifier.ready;
      final kind = notifier.state.missions.first.kind;
      notifier.record(kind, 1);

      now = DateTime(2026, 11, 4, 9);
      notifier.ensureToday();

      expect(notifier.state.day, localDayKey(now));
      expect(notifier.state.progress, everyElement(0));
    });

    test('coletar paga a moeda uma vez; as três pagam o bônus', () async {
      final storage = InMemoryDailyProgressStorage();
      final credit = InMemoryGameStorage();
      final notifier = build(storage, credit);
      await notifier.ready;

      final missions = notifier.state.missions;
      for (final mission in missions) {
        notifier.record(mission.kind, mission.target);
      }
      var expected = 0;
      for (int i = 0; i < missions.length; i++) {
        expect(await notifier.claim(i), missions[i].reward);
        expected += missions[i].reward;
        expect(await notifier.claim(i), isNull);
      }
      expect(credit.coins, expected);

      final bonus = await notifier.claimBonus();
      expect(bonus, isNotNull);
      expect(await notifier.claimBonus(), isNull);
      expect(storage.missions.bonusClaimed, isTrue);
    });

    test('desligado: registrar e coletar não fazem nada', () async {
      final notifier = MissionsNotifier(
        creditStorage: InMemoryGameStorage(),
        clock: clock,
        campaignProgress: () => 40,
      );
      notifier.record(MissionKind.fusions, 10);
      expect(notifier.state, DailyMissions.empty);
      expect(await notifier.claim(0), isNull);
    });
  });

  group('a partida informa as missões', () {
    test('uma jogada conta fusões; a vitória conta fase e estrelas', () {
      final events = <(MissionKind, int)>[];
      final notifier = GameNotifier(
        random: Random(1),
        storage: InMemoryGameStorage(),
        missions: (kind, amount) => events.add((kind, amount)),
      );
      // Objetivo de um 6 em fase folgada: a troca abaixo funde três 5 num 6
      // e vence na hora.
      notifier.startLevel(
        const GameLevel(
          number: 95,
          objective: Objective(digit: 6),
          moveLimit: 30,
        ),
      );

      var board = Board.empty();
      for (int row = 0; row < Board.boardSize; row++) {
        for (int col = 0; col < Board.boardSize; col++) {
          final position = Position(row: row, col: col);
          final value = switch ((row, col)) {
            (3, 0) || (3, 1) || (4, 2) => 5,
            _ => (row + col) % 3,
          };
          board = board.updateTile(
            position,
            Tile(id: 'm$row$col', value: value, position: position),
          );
        }
      }
      notifier.debugSetBoard(board);
      notifier.swapTiles(
        const Position(row: 4, col: 2),
        const Position(row: 3, col: 2),
      );

      int total(MissionKind kind) =>
          events.where((e) => e.$1 == kind).fold(0, (sum, e) => sum + e.$2);
      expect(total(MissionKind.fusions), greaterThanOrEqualTo(1));
      expect(total(MissionKind.useBoosters), 0);
      expect(total(MissionKind.winLevels), 1);
      // Uma jogada de 30: sobra muito, três estrelas.
      expect(total(MissionKind.earnStars), 3);
    });
  });
}
