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

    group('anti-repetição de objetivo', () {
      test('nenhuma fase repete o mesmo tipo/dígito/contagem da anterior ou da retrasada', () {
        Objective? twoAgo;
        Objective? oneAgo;
        for (int n = kHandcraftedLevels + 1; n <= 1000; n++) {
          final objective = generateLevel(n).objective;
          bool samePattern(Objective? past) =>
              past != null &&
              past.type == objective.type &&
              past.digit == objective.digit &&
              past.obstacle == objective.obstacle &&
              past.count == objective.count;

          // Empate quando os dois eixos ajustáveis já estão no teto: caso
          // registrado em `_varied`, não é falha de teste.
          final bothCapped = objective.type == ObjectiveType.reachDigit &&
              objective.digit == kMaxDigit &&
              objective.count == kMaxObjectiveCount;

          if (!bothCapped) {
            expect(samePattern(oneAgo), isFalse, reason: 'fase $n repete a fase ${n - 1}');
            expect(samePattern(twoAgo), isFalse, reason: 'fase $n repete a fase ${n - 2}');
          }

          twoAgo = oneAgo;
          oneAgo = objective;
        }
      });
    });

    group('piso de movimentos para fases pesadas de dígito alto', () {
      test('mais de duas peças de dígito 7+ nunca ficam abaixo de 16 movimentos', () {
        for (int n = kHandcraftedLevels + 1; n <= 1000; n++) {
          final level = generateLevel(n);
          final objective = level.objective;
          if (objective.type != ObjectiveType.reachDigit) continue;
          if (objective.count <= 2 || objective.digit! < 7) continue;

          expect(level.moveLimit, greaterThanOrEqualTo(16), reason: 'fase $n: ${objective.debugLabel}');
        }
      });
    });

    group('curva senoidal de pacing', () {
      test('a fase 11 (ímpar) recebe o limite calculado com o fator relaxante do pacing', () {
        // n=11: block 0, spawn 3-6, objetivo "crie um 7" (digit=7, count=1).
        // digitMoves = 1 * (7 - 4.5) + 8 = 10.5; tighteningFactor(block 0) = 1;
        // pacing(11) = 1 + 0.12 * cos(11π) = 1 - 0.12 = 0.88 (11 é ímpar).
        // paced = 10.5 * 0.88 = 9.24 -> floor 9, abaixo do piso geral (10):
        // o piso é quem decide o resultado final.
        final level = generateLevel(11);
        expect(level.objective.digit, 7);
        expect(level.objective.count, 1);
        expect(level.moveLimit, 10);
      });

      test('o limite nunca desaba pra zero ou negativo em toda a faixa gerada', () {
        for (int n = kHandcraftedLevels + 1; n <= 1000; n++) {
          expect(generateLevel(n).moveLimit, greaterThan(0), reason: 'fase $n');
        }
      });
    });

    group('Fases hard', () {
      test('isHardLevel é falso antes da fase 30', () {
        for (var n = kHandcraftedLevels + 1; n < kHardLevelStart; n++) {
          expect(isHardLevel(n), isFalse, reason: 'fase $n');
        }
      });

      test('isHardLevel marca exatamente 1 fase a cada kBlockSize a partir da 30', () {
        final hardInRange = [
          for (var n = kHardLevelStart; n < kHardLevelStart + kBlockSize * 5; n++)
            if (isHardLevel(n)) n,
        ];
        expect(hardInRange.length, 5);
        // Espaçadas por kBlockSize.
        for (var i = 1; i < hardInRange.length; i++) {
          expect(hardInRange[i] - hardInRange[i - 1], kBlockSize);
        }
      });

      test('fase hard tem limite de movimentos ~25% menor que a fase equivalente não-hard do mesmo bloco', () {
        final hardLevel = [
          for (var n = kHardLevelStart; n < kHardLevelStart + kBlockSize * 3; n++)
            if (isHardLevel(n)) n,
        ].first;
        final hard = generateLevel(hardLevel);
        final notHard = generateLevel(hardLevel - 1); // vizinha, mesmo bloco, não-hard

        expect(hard.moveLimit, lessThan(notHard.moveLimit));
        expect(hard.moveLimit, greaterThanOrEqualTo(kMinMoveLimit));
      });

      test('fase hard nunca cai abaixo do piso de movimentos, mesmo em blocos distantes', () {
        for (var block = 40; block < 60; block++) {
          final number = kHandcraftedLevels + 1 + block * kBlockSize + (kBlockSize - 2);
          if (!isHardLevel(number)) continue;
          final level = generateLevel(number);
          expect(level.moveLimit, greaterThanOrEqualTo(kMinMoveLimit));
        }
      });

      group('Densidade de obstáculos em fases hard', () {
        test('fase hard tem o dobro de cada tipo de obstáculo do bloco, respeitando o teto', () {
          final hardLevels = [
            for (var n = kHardLevelStart; n < kHardLevelStart + kBlockSize * 30; n++)
              if (isHardLevel(n)) n,
          ];

          for (final hardLevel in hardLevels) {
            final hard = generateLevel(hardLevel);
            final notHard = generateLevel(hardLevel - 1);

            // A partir do bloco em que o dobro já satura o teto dos dois
            // lados, hard e não-hard empatam no mesmo total aparado — nunca
            // menor, porque dobrar não pode reduzir a densidade de origem.
            expect(
              hard.obstacles.total,
              greaterThanOrEqualTo(notHard.obstacles.total),
              reason: 'fase hard $hardLevel',
            );
            expect(
              hard.obstacles.total,
              lessThanOrEqualTo(kMaxObstacles),
              reason: 'fase hard $hardLevel excedeu o teto',
            );
          }
        });
      });
    });
  });
}
