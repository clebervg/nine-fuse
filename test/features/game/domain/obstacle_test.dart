import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';

void main() {
  const origin = Position(row: 0, col: 0);

  Tile plain() => const Tile(id: 't0', value: 3, position: origin);

  group('ObstacleType', () {
    test('cada obstáculo tem a resistência prevista no design', () {
      expect(ObstacleType.none.hitPoints, 0);
      expect(ObstacleType.ice.hitPoints, 1);
      expect(ObstacleType.glass.hitPoints, 2);
      expect(ObstacleType.stone.hitPoints, 3);
    });
  });

  group('Tile com obstáculo', () {
    test('nasce livre', () {
      expect(plain().obstacle, ObstacleType.none);
      expect(plain().obstacleHp, 0);
      expect(plain().isBlocked, isFalse);
    });

    test('withObstacle aplica a resistência cheia do tipo', () {
      final blocked = plain().withObstacle(ObstacleType.glass);

      expect(blocked.obstacle, ObstacleType.glass);
      expect(blocked.obstacleHp, 2);
      expect(blocked.isBlocked, isTrue);
      // O dígito por baixo continua intacto.
      expect(blocked.value, 3);
    });

    test('o gelo derrete no primeiro impacto', () {
      final melted = plain().withObstacle(ObstacleType.ice).damageObstacle();

      expect(melted.obstacle, ObstacleType.none);
      expect(melted.obstacleHp, 0);
      expect(melted.isBlocked, isFalse);
    });

    test('o vidro trinca antes de quebrar', () {
      final cracked = plain().withObstacle(ObstacleType.glass).damageObstacle();

      expect(cracked.obstacle, ObstacleType.glass);
      expect(cracked.obstacleHp, 1);
      expect(cracked.isDamaged, isTrue);

      expect(cracked.damageObstacle().obstacle, ObstacleType.none);
    });

    test('a pedra aguenta três impactos', () {
      var tile = plain().withObstacle(ObstacleType.stone);

      tile = tile.damageObstacle();
      expect(tile.obstacleHp, 2);
      tile = tile.damageObstacle();
      expect(tile.obstacleHp, 1);
      tile = tile.damageObstacle();
      expect(tile.obstacle, ObstacleType.none);
    });

    test('bater numa peça livre não faz nada', () {
      expect(plain().damageObstacle(), plain());
    });

    test('a identidade entra na igualdade', () {
      expect(
        plain().withObstacle(ObstacleType.ice),
        isNot(plain().withObstacle(ObstacleType.stone)),
      );
      expect(plain().withObstacle(ObstacleType.ice), isNot(plain()));
    });
  });
}
