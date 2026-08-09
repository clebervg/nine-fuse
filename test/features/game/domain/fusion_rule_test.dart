import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/fusion_rule.dart';

void main() {
  group('valueMultiplier', () {
    // Uma peça de V+1 custa três de V, então 3 peças de V que geram 1 de V+1
    // não criam valor: a conversão é neutra (1,0x). Qualquer regra precisa ser
    // lida contra essa referência.
    test('match-3 é neutro em todas as regras', () {
      for (final rule in const [
        NeutralFusion(),
        TieredFusion(),
        AggressiveFusion(),
      ]) {
        expect(
          rule.valueMultiplier(3),
          closeTo(1.0, 0.001),
          reason: rule.label,
        );
      }
    });

    test('a regra neutra destrói valor em combinações grandes', () {
      const rule = NeutralFusion();

      // 4 peças consumidas, 1 de V+1 (=3) produzida.
      expect(rule.valueMultiplier(4), closeTo(0.75, 0.001));
      expect(rule.valueMultiplier(5), closeTo(0.60, 0.001));
    });

    test('a regra graduada nunca destrói valor', () {
      const rule = TieredFusion();

      // V+1 mais V devolve exatamente o que 4 peças valiam.
      expect(rule.valueMultiplier(4), closeTo(1.0, 0.001));
      // V+2 vale 9 peças, contra 5 consumidas.
      expect(rule.valueMultiplier(5), closeTo(1.8, 0.001));
    });

    test('a regra agressiva multiplica valor de forma acentuada', () {
      const rule = AggressiveFusion();

      expect(rule.valueMultiplier(4), closeTo(2.25, 0.001));
      expect(rule.valueMultiplier(5), closeTo(3.6, 0.001));
    });

    test('graduada premia combinação grande sem chegar perto da agressiva', () {
      const tiered = TieredFusion();
      const aggressive = AggressiveFusion();

      expect(tiered.valueMultiplier(5), greaterThan(1.0));
      expect(
        tiered.valueMultiplier(5),
        lessThan(aggressive.valueMultiplier(5)),
      );
    });
  });

  group('outcome', () {
    test('neutra devolve sempre uma peça de V+1', () {
      const rule = NeutralFusion();

      expect(rule.outcome(length: 3, value: 4), [5]);
      expect(rule.outcome(length: 5, value: 4), [5]);
    });

    test('graduada devolve peça extra no match-4 e salto no match-5', () {
      const rule = TieredFusion();

      expect(rule.outcome(length: 3, value: 2), [3]);
      expect(rule.outcome(length: 4, value: 2), [3, 2]);
      expect(rule.outcome(length: 5, value: 2), [4]);
      expect(rule.outcome(length: 6, value: 2), [4]);
    });

    test('agressiva salta dois níveis e duplica no match-5', () {
      const rule = AggressiveFusion();

      expect(rule.outcome(length: 4, value: 1), [3]);
      expect(rule.outcome(length: 5, value: 1), [3, 3]);
    });

    test('a peça da fusão vem sempre em primeiro lugar', () {
      // O motor usa a primeira posição da lista como o ponto de interação.
      expect(const TieredFusion().outcome(length: 4, value: 5).first, 6);
    });
  });
}
