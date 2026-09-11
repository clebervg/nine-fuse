/// Roleta diária de recompensa: elegibilidade por tempo e a tabela fixa de
/// prêmios. Dart puro — nenhuma dependência de Flutter, Riverpod ou
/// armazenamento, no mesmo espírito do resto de `domain/`.
library;

/// Elegível para girar se nunca girou (`lastSpin == null`) ou se já se
/// passaram 24h ou mais desde o último giro.
bool isSpinEligible(DateTime? lastSpin, DateTime now) {
  if (lastSpin == null) return true;
  return now.difference(lastSpin) >= const Duration(hours: 24);
}

/// O que uma fatia da roleta paga.
enum SpinPrizeType { coins, hammer, bomb, brush }

/// Um prêmio concreto: o tipo e a quantidade que ele credita.
class SpinPrize {
  const SpinPrize(this.type, this.amount);

  final SpinPrizeType type;
  final int amount;
}

/// As 8 fatias fixas da roleta, na ordem em que aparecem no desenho.
///
/// Moedas em 5 valores crescentes e uma unidade de cada booster existente —
/// nenhuma fatia "vazia", porque um giro que não paga nada é o tipo de
/// recurso que ensina o jogador a não girar mais.
const List<SpinPrize> kSpinWheelPrizes = [
  SpinPrize(SpinPrizeType.coins, 10),
  SpinPrize(SpinPrizeType.hammer, 1),
  SpinPrize(SpinPrizeType.coins, 25),
  SpinPrize(SpinPrizeType.bomb, 1),
  SpinPrize(SpinPrizeType.coins, 50),
  SpinPrize(SpinPrizeType.brush, 1),
  SpinPrize(SpinPrizeType.coins, 100),
  SpinPrize(SpinPrizeType.coins, 200),
];
