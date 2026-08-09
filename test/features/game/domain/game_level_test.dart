import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';

void main() {
  group('Objective', () {
    // O objetivo carrega **dado**, não frase: o texto que o jogador lê sai
    // de `AppLocalizations` na camada de apresentação. O `debugLabel` que
    // sobrou é de desenvolvedor — vai para o `toString()` e para o relatório
    // do simulador, que roda fora de qualquer árvore de widgets.
    test('carrega dígito e quantidade, não a frase', () {
      const one = Objective(digit: 5);
      expect(one.digit, 5);
      expect(one.count, 1);

      const many = Objective(digit: 5, count: 3);
      expect(many.count, 3);
    });

    test('o rótulo de depuração distingue singular de plural', () {
      expect(const Objective(digit: 5).debugLabel, 'Crie um 5');
      expect(const Objective(digit: 5, count: 3).debugLabel, 'Crie 3 peças 5');
    });

    test('igualdade é por valor', () {
      expect(
        const Objective(digit: 5, count: 2),
        const Objective(digit: 5, count: 2),
      );
      expect(const Objective(digit: 5), isNot(const Objective(digit: 6)));
    });
  });

  group('catálogo da campanha', () {
    test('tem dez fases numeradas em sequência a partir de 1', () {
      expect(kCampaign, hasLength(10));

      for (int i = 0; i < kCampaign.length; i++) {
        expect(kCampaign[i].number, i + 1);
      }
    });

    // Esta é a invariante que um assert const não conseguiria checar.
    test('o dígito do objetivo está sempre acima da janela de spawn', () {
      for (final level in kCampaign) {
        expect(
          level.objective.digit,
          greaterThan(level.spawnMax),
          reason:
              'fase ${level.number}: o alvo cairia pronto do topo, '
              'e a fase viraria sorte em vez de plano',
        );
      }
    });

    test('nenhum objetivo passa do dígito máximo', () {
      for (final level in kCampaign) {
        expect(
          level.objective.digit,
          lessThanOrEqualTo(kMaxDigit),
          reason: 'fase ${level.number}',
        );
      }
    });

    test('a janela de spawn é válida e nunca estreita demais', () {
      for (final level in kCampaign) {
        expect(
          level.spawnMin,
          lessThan(level.spawnMax),
          reason: 'fase ${level.number}',
        );
        // O motor precisa de 3 valores para nunca ficar sem candidato ao
        // montar um tabuleiro sem combinação pronta.
        expect(
          level.spawnMax - level.spawnMin,
          greaterThanOrEqualTo(2),
          reason: 'fase ${level.number}',
        );
      }
    });

    test('a campanha termina no dígito máximo', () {
      expect(kCampaign.last.objective.digit, kMaxDigit);
    });

    test('o dígito pedido nunca diminui', () {
      var previous = 0;

      for (final level in kCampaign) {
        expect(
          level.objective.digit,
          greaterThanOrEqualTo(previous),
          reason: 'fase ${level.number}',
        );
        previous = level.objective.digit;
      }
    });

    test('a campanha sobe, admitindo respiro de no máximo um degrau', () {
      // "Subida" é a distância entre o topo da janela de spawn e o alvo: quantos
      // níveis de fusão o jogador precisa escalar. A curva não precisa ser
      // monotônica — a fase 7 é de propósito mais fácil que a 6, porque vem
      // depois da primeira fase longa e estreia a janela de spawn subindo.
      // O que não se admite é a dificuldade desabar.
      var hardestSoFar = 0;

      for (final level in kCampaign) {
        final climb = level.objective.digit - level.spawnMax;

        expect(
          climb,
          greaterThanOrEqualTo(hardestSoFar - 1),
          reason:
              'fase ${level.number} cai mais de um degrau abaixo do '
              'ponto mais difícil até aqui ($hardestSoFar)',
        );

        if (climb > hardestSoFar) hardestSoFar = climb;
      }

      // E o pico tem de estar no fim, não no meio.
      final finalClimb =
          kCampaign.last.objective.digit - kCampaign.last.spawnMax;
      expect(
        finalClimb,
        hardestSoFar,
        reason: 'a última fase deveria ser a mais exigente',
      );
    });

    test('a janela de spawn só sobe ao longo da campanha', () {
      var previous = kCampaign.first.spawnMin;

      for (final level in kCampaign) {
        expect(
          level.spawnMin,
          greaterThanOrEqualTo(previous),
          reason: 'fase ${level.number}',
        );
        previous = level.spawnMin;
      }
    });

    test('todo limite de movimentos é positivo e cabe numa sessão curta', () {
      for (final level in kCampaign) {
        expect(level.moveLimit, greaterThan(0), reason: 'fase ${level.number}');
        // Acima de ~60 movimentos a sessão deixa de ser de 1-3 minutos.
        expect(
          level.moveLimit,
          lessThanOrEqualTo(60),
          reason: 'fase ${level.number} ficaria longa demais',
        );
      }
    });

    test('as primeiras fases são curtas, para ensinar rápido', () {
      expect(kCampaign.first.moveLimit, lessThanOrEqualTo(10));
      expect(kCampaign.first.objective.count, 1);
    });

    test('as fases que ensinam algo novo têm dica', () {
      // Não é obrigatório em toda fase, mas a primeira precisa.
      expect(kCampaign.first.teaches, isNotNull);
      expect(kCampaign.last.teaches, isNotNull);
    });
  });
}
