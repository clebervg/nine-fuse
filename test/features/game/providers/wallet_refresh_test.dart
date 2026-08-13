import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import 'package:nine_fuse/features/game/providers/wallet.dart';

void main() {
  test('refresh adota o martelo gasto durante a partida', () async {
    // A partida escreve direto no storage; o mapa estava fora de cena.
    final storage = InMemoryGameStorage(coins: 100, hammerCount: 3);
    final wallet = WalletNotifier(storage: storage);
    await wallet.refresh();

    expect(wallet.state.hammers, 3);

    storage.hammerCount = 2;
    await wallet.refresh();

    expect(wallet.state.hammers, 2);
    expect(wallet.state.coins, 100);
  });
}
