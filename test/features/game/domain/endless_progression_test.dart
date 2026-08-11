import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/endless_progression.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';

void main() {
  const progression = EndlessProgression();

  group('janela por degrau', () {
    test('desliza de 0-3 até 3-6', () {
      expect(
        [
          for (int s = 0; s <= EndlessProgression.lastStep; s++)
            (progression.spawnMinFor(s), progression.spawnMaxFor(s)),
        ],
        [(0, 3), (1, 4), (2, 5), (3, 6)],
      );
    });

    test('a janela tem sempre quatro valores', () {
      // Medido: uma janela larga dilui o fornecimento e o match-3 fica raro.
      // Alargar de 0-3 para 0-6 encurtou a partida de 274 para 90 movimentos.
      for (int s = 0; s <= EndlessProgression.lastStep; s++) {
        expect(
          progression.spawnMaxFor(s) - progression.spawnMinFor(s),
          3,
          reason: 'degrau $s',
        );
      }
    });

    test('nunca sorteia o dígito máximo', () {
      // Se o topo da escala caísse pronto do sorteio, explodiria sozinho e o
      // clímax do jogo viraria acidente.
      for (int s = 0; s <= EndlessProgression.lastStep; s++) {
        expect(
          progression.spawnMaxFor(s),
          lessThan(kMaxDigit),
          reason: 'degrau $s',
        );
      }
    });

    test('degrau fora da faixa é contido nas pontas', () {
      expect(progression.spawnMinFor(-5), 0);
      expect(progression.spawnMinFor(99), EndlessProgression.lastStep);
    });
  });

  group('promoção', () {
    test('exige criar dois níveis acima do topo da janela', () {
      expect(progression.promotionDigitFor(0), 5); // janela 0-3
      expect(progression.promotionDigitFor(1), 6); // janela 1-4
      expect(progression.promotionDigitFor(2), 7); // janela 2-5
      expect(progression.promotionDigitFor(3), 8); // janela 3-6
    });

    test('o dígito de promoção é sempre alcançável', () {
      for (int s = 0; s < EndlessProgression.lastStep; s++) {
        expect(
          progression.promotionDigitFor(s),
          lessThanOrEqualTo(kMaxDigit),
          reason: 'degrau $s pediria um dígito que não existe',
        );
      }
    });

    test('criar o dígito de promoção sobe um degrau', () {
      expect(progression.advance(step: 0, produced: [5]), 1);
      expect(progression.advance(step: 1, produced: [6]), 2);
    });

    test('criar dígito abaixo do de promoção não sobe', () {
      expect(progression.advance(step: 0, produced: [3, 4]), 0);
      expect(progression.advance(step: 1, produced: [5]), 1);
    });

    test('sobe no máximo um degrau por movimento', () {
      // Uma cascata pode produzir vários dígitos altos de uma vez; pular dois
      // degraus cortaria de golpe o fornecimento das peças baixas.
      expect(progression.advance(step: 0, produced: [5, 6, 7, 8]), 1);
    });

    test('não passa do último degrau', () {
      expect(
        progression.advance(
          step: EndlessProgression.lastStep,
          produced: [kMaxDigit],
        ),
        EndlessProgression.lastStep,
      );
    });

    test('sem nada produzido, fica no lugar', () {
      expect(progression.advance(step: 2, produced: const []), 2);
    });
  });

  group('obstáculos por degrau', () {
    test('o primeiro degrau começa limpo', () {
      // O jogador entra no Endless para bater recorde, não para decifrar uma
      // fase: a pressão do modo já vem da janela que sobe.
      expect(progression.obstaclesFor(EndlessProgression.firstStep),
          ObstacleLayout.none);
    });

    test('cada degrau acima do primeiro pede cobertura', () {
      for (int s = 1; s <= EndlessProgression.lastStep; s++) {
        expect(
          progression.obstaclesFor(s).isEmpty,
          isFalse,
          reason: 'degrau $s',
        );
      }
    });

    test('a cobertura endurece degrau a degrau', () {
      final totals = [
        for (int s = 0; s <= EndlessProgression.lastStep; s++)
          progression.obstaclesFor(s).total,
      ];

      for (int s = 1; s < totals.length; s++) {
        expect(
          totals[s],
          greaterThanOrEqualTo(totals[s - 1]),
          reason: 'degrau $s afrouxou',
        );
      }
      expect(totals.last, greaterThan(totals.first));
    });

    test('a pedra só entra no último degrau, onde o dígito máximo é possível', () {
      // Três impactos precisa da onda de choque como saída, e ela só é
      // realista com a janela no topo.
      for (int s = 0; s < EndlessProgression.lastStep; s++) {
        expect(progression.obstaclesFor(s).stone, 0, reason: 'degrau $s');
      }
      expect(
        progression.obstaclesFor(EndlessProgression.lastStep).stone,
        greaterThan(0),
      );
    });

    test('nenhum degrau cobre tabuleiro demais', () {
      for (int s = 0; s <= EndlessProgression.lastStep; s++) {
        expect(
          progression.obstaclesFor(s).total,
          lessThanOrEqualTo(8),
          reason: 'degrau $s',
        );
      }
    });

    test('degrau fora da faixa é contido nas pontas', () {
      expect(progression.obstaclesFor(-3), ObstacleLayout.none);
      expect(
        progression.obstaclesFor(99),
        progression.obstaclesFor(EndlessProgression.lastStep),
      );
    });
  });

  // O degrau não descreve a si mesmo em texto: a frase que o jogador lê é
  // montada na apresentação, a partir destes dois números. Guardá-la aqui
  // obrigaria o `domain` a conhecer `BuildContext`.
  test('o degrau expõe a faixa da vez como números', () {
    expect(progression.spawnMinFor(0), 0);
    expect(progression.spawnMaxFor(0), 3);
    expect(progression.spawnMinFor(3), 3);
    expect(progression.spawnMaxFor(3), 6);
  });
}
