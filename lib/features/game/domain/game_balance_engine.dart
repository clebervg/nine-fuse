import 'package:nine_fuse/features/game/domain/economy.dart';

/// A matemática de balanceamento das recompensas, fora do estado e fora da UI.
///
/// Dart puro, sem Flutter e sem Riverpod, pela mesma régua do `MatchEngine`:
/// o número que o jogo paga é regra, e regra se testa sem montar widget.
class GameBalanceEngine {
  const GameBalanceEngine._();

  /// Quantos movimentos o anúncio de reforço de saldo paga, dado o que a fase
  /// ainda pede.
  ///
  /// [remainingTargets] é uniforme para os três tipos de objetivo: peças de
  /// dígito a formar, coberturas a quebrar, coberturas restantes na limpeza
  /// total. Não há caso especial porque `objectiveTarget - objectiveProgress`
  /// já significa a mesma coisa nos três.
  ///
  /// O piso cobre o caso degenerado (objetivo cumprido ou contagem negativa
  /// por tabuleiro montado à mão): devolver zero ali pagaria nada por um
  /// anúncio assistido até o fim.
  static int calculateRewardedMoves({
    required int remainingTargets,
    int minMoves = kRewardedMinMoves,
    int maxMoves = kRewardedMaxMoves,
  }) {
    if (remainingTargets <= 0) return minMoves;
    return (remainingTargets * kMovesPerTarget).ceil().clamp(
      minMoves,
      maxMoves,
    );
  }
}
