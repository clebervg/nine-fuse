import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/level_catalog.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';
import 'package:nine_fuse/features/game/domain/obstacle_debut.dart';

void main() {
  group('obstacleDebuts', () {
    // A estreia vem do catálogo, não de uma tabela à parte: se a campanha
    // artesanal mudar a fase em que o gelo entra, o aviso do mapa acompanha.
    test('cada cobertura estreia na fase em que o catálogo a põe primeiro', () {
      final debuts = obstacleDebuts();

      for (final debut in debuts) {
        expect(levelAt(debut.level).obstacles.countOf(debut.type), isPositive);
        for (int n = 1; n < debut.level; n++) {
          expect(
            levelAt(n).obstacles.countOf(debut.type),
            0,
            reason: '${debut.type} já aparecia na fase $n',
          );
        }
      }
      expect(debuts.map((d) => d.type).toSet(), {
        ObstacleType.ice,
        ObstacleType.glass,
        ObstacleType.stone,
        ObstacleType.chain,
      });
      // A corrente estreia no primeiro bloco gerado que a espalha.
      expect(
        debuts.singleWhere((d) => d.type == ObstacleType.chain).level,
        31,
      );
    });

    test('sai ordenada por fase', () {
      final levels = obstacleDebuts().map((d) => d.level).toList();
      expect(levels, [...levels]..sort());
    });

    test('tipo que nunca aparece não entra na lista', () {
      GameLevel fake(int n) => GameLevel(
        number: n,
        moveLimit: 10,
        spawnMin: 0,
        spawnMax: 3,
        objective: const Objective(digit: 4),
        obstacles: n == 4
            ? const ObstacleLayout(glass: 1)
            : ObstacleLayout.none,
      );

      expect(obstacleDebuts(levelOf: fake, searchLimit: 20), [
        (level: 4, type: ObstacleType.glass),
      ]);
    });
  });

  group('upcomingObstacleDebut', () {
    final debuts = obstacleDebuts();
    final first = debuts.first;

    test('avisa a estreia dentro da janela, incluindo a fase da vez', () {
      expect(upcomingObstacleDebut(first.level), first);
      expect(
        upcomingObstacleDebut(first.level - kObstacleDebutLookahead),
        first,
      );
    });

    test('fica quieto quando a estreia ainda está longe', () {
      expect(
        upcomingObstacleDebut(first.level - kObstacleDebutLookahead - 1),
        isNull,
      );
    });

    test('estreia já passada não é mais novidade', () {
      final last = debuts.last;
      expect(upcomingObstacleDebut(last.level + 1), isNull);
    });

    test('entre duas estreias na janela, avisa a mais próxima', () {
      // Gelo, vidro e pedra estreiam em fases seguidas na campanha artesanal.
      expect(upcomingObstacleDebut(debuts[1].level), debuts[1]);
    });
  });
}
