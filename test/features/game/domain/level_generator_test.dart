import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/level_generator.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';

void main() {
  group('LevelGenerator', () {
    test('respeita as invariantes de GameLevel de 11 a 1000', () {
      for (int n = kHandcraftedLevels + 1; n <= 1000; n++) {
        final level = generateLevel(n);

        expect(level.number, n, reason: 'fase $n');
        expect(level.spawnMax - level.spawnMin, kSpawnWidth - 1,
            reason: 'fase $n: janela de largura fixa');
        expect(level.spawnMin, greaterThanOrEqualTo(0), reason: 'fase $n');
        expect(level.spawnMax, lessThan(kMaxDigit), reason: 'fase $n');
        expect(level.moveLimit, greaterThan(0), reason: 'fase $n');
        expect(level.objective.count, greaterThanOrEqualTo(1), reason: 'fase $n');
      }
    });

    test('o dígito-alvo fica sempre acima da janela de sorteio', () {
      // Se o alvo cai pronto do topo, a fase vira sorte em vez de plano.
      for (int n = kHandcraftedLevels + 1; n <= 1000; n++) {
        final level = generateLevel(n);
        if (level.objective.type != ObjectiveType.reachDigit) continue;

        expect(level.objective.digit, greaterThan(level.spawnMax),
            reason: 'fase $n');
        expect(level.objective.digit, lessThanOrEqualTo(kMaxDigit),
            reason: 'fase $n');
      }
    });

    test('objetivo de cobertura sempre pede uma cobertura que a fase espalha',
        () {
      // Pedir pedra numa fase sem pedra é fabricar uma fase impossível.
      for (int n = kHandcraftedLevels + 1; n <= 1000; n++) {
        final level = generateLevel(n);
        if (!level.objective.isObstacleGoal) continue;

        expect(level.obstacles.countOf(level.objective.obstacle),
            greaterThanOrEqualTo(level.objective.count),
            reason: 'fase $n pede ${level.objective.debugLabel}');
      }
    });

    test('é determinístico', () {
      for (final n in [11, 47, 250, 999]) {
        final a = generateLevel(n);
        final b = generateLevel(n);
        expect(a.objective, b.objective, reason: 'fase $n');
        expect(a.moveLimit, b.moveLimit, reason: 'fase $n');
        expect(a.spawnMin, b.spawnMin, reason: 'fase $n');
        expect(a.obstacles.total, b.obstacles.total, reason: 'fase $n');
      }
    });

    test('a fase 11 é o arquétipo mais fácil, para não haver degrau na costura',
        () {
      // A 10 é o clímax do conteúdo artesanal. Se a 11 chegar mais dura que
      // ela, o jogador lê a continuação como parede.
      final first = generateLevel(kHandcraftedLevels + 1);

      expect(first.objective.type, ObjectiveType.reachDigit);
      expect(first.objective.count, 1);
      expect(first.objective.digit, first.spawnMax + 1);
    });

    test('nunca devolve o 0 à janela de sorteio', () {
      // O 0 parar de cair é conquista da fase 7; devolvê-lo regride a sensação
      // de progresso.
      for (int n = kHandcraftedLevels + 1; n <= 1000; n++) {
        expect(generateLevel(n).spawnMin, greaterThanOrEqualTo(2),
            reason: 'fase $n');
      }
    });

    test('recusa número de fase artesanal', () {
      expect(() => generateLevel(10), throwsA(isA<AssertionError>()));
    });
  });
}
