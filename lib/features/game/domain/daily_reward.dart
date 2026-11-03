/// Recompensa diária com sequência de dias (o "calendário de 7 dias").
///
/// Regra pura, sem relógio nem disco: quem chama passa o dia local de hoje e
/// o estado gravado, e recebe de volta qual dia do ciclo está liberado. É o
/// mesmo desenho de `isSpinEligible` e `DailyAdCount`, e pelo mesmo motivo —
/// teste de regra de calendário não pode depender da hora em que a suíte roda.
library;

import 'package:flutter/foundation.dart';
import 'package:nine_fuse/features/game/domain/daily_ad_count.dart';
import 'package:nine_fuse/features/game/domain/daily_spin.dart';

/// Os prêmios de cada dia do ciclo, do dia 1 ao 7.
///
/// Reaproveita [SpinPrize] em vez de um tipo novo: moeda e os três boosters
/// são exatamente o que a roleta já paga, e o crédito (com o teto de estoque
/// dos prêmios grátis) já existe para ela.
///
/// A curva sobe devagar e o dia 7 é o salto: é ele que dá ao jogador motivo
/// para não quebrar a sequência no dia 5. Somado, o ciclo paga 150 moedas, um
/// Martelo e uma Bomba por semana — menos que um capítulo em três estrelas
/// mais o baú (250), para a sequência ser um bônus, não a fonte principal.
const List<List<SpinPrize>> kDailyRewardCycle = [
  [SpinPrize(SpinPrizeType.coins, 10)],
  [SpinPrize(SpinPrizeType.coins, 15)],
  [SpinPrize(SpinPrizeType.coins, 20)],
  [SpinPrize(SpinPrizeType.hammer, 1)],
  [SpinPrize(SpinPrizeType.coins, 25)],
  [SpinPrize(SpinPrizeType.coins, 30)],
  [SpinPrize(SpinPrizeType.bomb, 1), SpinPrize(SpinPrizeType.coins, 50)],
];

/// O que fica gravado entre aberturas do app.
@immutable
class DailyStreak {
  const DailyStreak({required this.lastClaimDay, required this.claimedDays});

  /// Nunca coletou nada.
  static const DailyStreak none = DailyStreak(lastClaimDay: '', claimedDays: 0);

  /// Dia local (`localDayKey`) da última coleta.
  final String lastClaimDay;

  /// Quantos dias seguidos o jogador já coletou na sequência atual. Pode
  /// passar de 7: o ciclo de prêmios recomeça, a sequência continua contando.
  final int claimedDays;

  @override
  bool operator ==(Object other) =>
      other is DailyStreak &&
      other.lastClaimDay == lastClaimDay &&
      other.claimedDays == claimedDays;

  @override
  int get hashCode => Object.hash(lastClaimDay, claimedDays);

  @override
  String toString() => 'DailyStreak($lastClaimDay, $claimedDays dias)';
}

/// Como está a recompensa de hoje.
typedef DailyRewardStatus = ({
  /// Hoje ainda não foi coletado.
  bool available,

  /// O dia do ciclo (0 a 6) que hoje paga — ou que já pagou, se coletado.
  int cycleDay,

  /// Quantos dias a sequência terá **depois** de coletar hoje (ou tem, se já
  /// coletou). É o número que a tela mostra: "Dia 4".
  int streakAfterClaim,
});

/// O dia local anterior a [day], como chave de [localDayKey].
///
/// Pelo calendário, e não subtraindo 24 h: na virada do horário de verão um
/// dia tem 23 ou 25 horas, e "agora menos 24 h" pode cair no mesmo dia.
String previousDayKey(DateTime now) {
  final local = now.toLocal();
  return localDayKey(DateTime(local.year, local.month, local.day - 1));
}

/// A recompensa de hoje, dado o que está gravado.
///
/// - Coletou hoje: nada disponível; mostra o dia que já pagou.
/// - Coletou ontem: a sequência continua no dia seguinte do ciclo.
/// - Qualquer outro caso (nunca coletou, ou pulou um dia): volta ao dia 1.
///   Perder a sequência é o que dá peso a ela — sem isso, voltar todo dia e
///   voltar uma vez por semana pagariam igual.
DailyRewardStatus dailyRewardStatus(DailyStreak streak, DateTime now) {
  final today = localDayKey(now);

  if (streak.lastClaimDay == today && streak.claimedDays > 0) {
    return (
      available: false,
      cycleDay: (streak.claimedDays - 1) % kDailyRewardCycle.length,
      streakAfterClaim: streak.claimedDays,
    );
  }

  final continues = streak.lastClaimDay == previousDayKey(now);
  final nextStreak = continues ? streak.claimedDays + 1 : 1;
  return (
    available: true,
    cycleDay: (nextStreak - 1) % kDailyRewardCycle.length,
    streakAfterClaim: nextStreak,
  );
}

/// O estado a gravar depois de coletar hoje. Nulo se hoje já foi coletado —
/// é por esse nulo que um toque duplo não paga duas vezes.
DailyStreak? claimDailyReward(DailyStreak streak, DateTime now) {
  final status = dailyRewardStatus(streak, now);
  if (!status.available) return null;
  return DailyStreak(
    lastClaimDay: localDayKey(now),
    claimedDays: status.streakAfterClaim,
  );
}
