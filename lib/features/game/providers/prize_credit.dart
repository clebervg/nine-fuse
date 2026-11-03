import 'package:nine_fuse/features/game/domain/daily_spin.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';

/// O que um prêmio grátis pagou de fato.
///
/// [credited] pode ser menor que `prize.amount` num booster: o teto de
/// estoque dos prêmios grátis converte o excedente em [overflowCoins]. A tela
/// mostra os dois, para não anunciar um martelo que virou moeda.
typedef PrizePayout = ({SpinPrize prize, int credited, int overflowCoins});

/// Credita um prêmio grátis direto no disco — roleta, recompensa diária e
/// missões passam todas por aqui.
///
/// Grava no disco, e não na carteira em memória, porque os boosters não têm
/// dono fora de uma partida: quem chama relê a carteira depois
/// (`WalletNotifier.refresh`), o mesmo remédio que a roleta sempre usou.
/// Um lugar só garante que as três torneiras respeitem o mesmo teto.
Future<PrizePayout> creditPrize(GameStorage storage, SpinPrize prize) async {
  switch (prize.type) {
    case SpinPrizeType.coins:
      await storage.writeCoins(await storage.readCoins() + prize.amount);
      return (prize: prize, credited: prize.amount, overflowCoins: 0);
    case SpinPrizeType.hammer:
      return _creditBooster(
        storage,
        prize,
        storage.readHammerCount,
        storage.writeHammerCount,
      );
    case SpinPrizeType.bomb:
      return _creditBooster(
        storage,
        prize,
        storage.readBombCount,
        storage.writeBombCount,
      );
    case SpinPrizeType.brush:
      return _creditBooster(
        storage,
        prize,
        storage.readBrushCount,
        storage.writeBrushCount,
      );
  }
}

/// Booster de prêmio respeita o teto de estoque; o excedente vira moeda
/// (`capBoosterReward`), para o prêmio nunca "não pagar".
Future<PrizePayout> _creditBooster(
  GameStorage storage,
  SpinPrize prize,
  Future<int> Function() read,
  Future<void> Function(int) write,
) async {
  final current = await read();
  final credit = capBoosterReward(current: current, amount: prize.amount);
  await write(credit.count);
  if (credit.overflowCoins > 0) {
    await storage.writeCoins(await storage.readCoins() + credit.overflowCoins);
  }
  return (
    prize: prize,
    credited: credit.count - current,
    overflowCoins: credit.overflowCoins,
  );
}
