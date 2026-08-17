import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/domain/game_balance_engine.dart';

void main() {
  group('quanto o anúncio de movimentos paga', () {
    test('objetivo já cumprido cai no piso, e não em zero', () {
      // Não deve acontecer (o convite exige objetivo em aberto), mas uma
      // fórmula que devolvesse zero transformaria um anúncio assistido em
      // prêmio nenhum — o pior desfecho possível para o funil.
      expect(
        GameBalanceEngine.calculateRewardedMoves(remainingTargets: 0),
        kRewardedMinMoves,
      );
      expect(
        GameBalanceEngine.calculateRewardedMoves(remainingTargets: -3),
        kRewardedMinMoves,
      );
    });

    test('um alvo restante ainda cai no piso', () {
      // 3.0 * 1 = 3, abaixo do piso de 4: o multiplicador só começa a mandar
      // de dois alvos em diante. É consequência dos números calibrados, e o
      // teste existe para que trocá-los seja uma decisão, não um acidente.
      expect(
        GameBalanceEngine.calculateRewardedMoves(remainingTargets: 1),
        kRewardedMinMoves,
      );
    });

    test('a faixa do meio escala a três movimentos por alvo', () {
      expect(GameBalanceEngine.calculateRewardedMoves(remainingTargets: 2), 6);
      expect(GameBalanceEngine.calculateRewardedMoves(remainingTargets: 3), 9);
    });

    test('o teto trava o prêmio antes de ele virar a fase inteira', () {
      expect(
        GameBalanceEngine.calculateRewardedMoves(remainingTargets: 4),
        kRewardedMaxMoves,
      );
      expect(
        GameBalanceEngine.calculateRewardedMoves(remainingTargets: 40),
        kRewardedMaxMoves,
      );
    });

    test('a faixa pode ser estreitada por quem chama', () {
      // Os limites são parâmetros para o teste poder fixar uma faixa sem
      // depender da calibragem vigente.
      expect(
        GameBalanceEngine.calculateRewardedMoves(
          remainingTargets: 3,
          minMoves: 1,
          maxMoves: 5,
        ),
        5,
      );
    });
  });
}
