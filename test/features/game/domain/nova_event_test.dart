import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/nova_event.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';
import 'package:nine_fuse/features/game/domain/position.dart';

void main() {
  group('NovaEvent', () {
    test('guarda os campos como passados', () {
      const at = Position(row: 3, col: 3);
      final event = NovaEvent(
        at: at,
        tier: 1,
        obstacleHits: const [
          ObstacleHit(
            position: Position(row: 3, col: 2),
            type: ObstacleType.ice,
            remainingHp: 0,
          ),
        ],
        clearedTiles: {const Position(row: 3, col: 3)},
        promoted: {const Position(row: 2, col: 3): 5},
      );

      expect(event.at, at);
      expect(event.tier, 1);
      expect(event.obstacleHits, hasLength(1));
      expect(event.clearedTiles, contains(const Position(row: 3, col: 3)));
      expect(event.promoted[const Position(row: 2, col: 3)], 5);
    });
  });

  group('novaScoreForTier', () {
    test('tier 1 vale kNovaScoreTier1', () {
      expect(novaScoreForTier(1), kNovaScoreTier1);
    });

    test('tier 2 vale kNovaScoreTier2', () {
      expect(novaScoreForTier(2), kNovaScoreTier2);
    });

    test('tier 3 vale kNovaScoreTier3', () {
      expect(novaScoreForTier(3), kNovaScoreTier3);
    });
  });
}
