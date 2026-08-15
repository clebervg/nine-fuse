import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/widgets/coins_header_badge.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_offer_dialog.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import 'package:nine_fuse/features/game/providers/wallet.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

import '../../support/localized.dart';

/// A pílula de saldo do header: mostra o que o jogador tem, reage ao crédito
/// sem trocar de tela, e abre a loja pelo `+`.
void main() {
  Future<WalletNotifier> pumpBadge(
    WidgetTester tester, {
    required int coins,
    int hammers = 0,
    int? showHammers,
    bool adPays = true,
  }) async {
    // A loja é alta: o cartão de fontes de moeda e os dois botões precisam
    // caber para os toques chegarem.
    tester.view.physicalSize = const Size(750, 1800);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final wallet = WalletNotifier(
      storage: InMemoryGameStorage(coins: coins, hammerCount: hammers),
    );
    await wallet.refresh();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletProvider.overrideWith((ref) => wallet),
          coinAdProvider.overrideWithValue(() async => adPays),
        ],
        child: MaterialApp(
          locale: kTestLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            appBar: AppBar(actions: [CoinsHeaderBadge(hammers: showHammers)]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return wallet;
  }

  testWidgets('saldo zero aparece, em vez de a pílula sumir', (tester) async {
    await pumpBadge(tester, coins: 0);

    expect(find.byKey(coinsHeaderBadgeKey), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('o martelo só entra quando pedido', (tester) async {
    await pumpBadge(tester, coins: 250, hammers: 3);

    // Sem `hammers`, a pílula é só de moedas: dentro de uma partida quem manda
    // no estoque é o `GameState`, e dois números do mesmo item se
    // contradiriam.
    expect(find.text('250'), findsOneWidget);
    expect(find.text('3'), findsNothing);

    await pumpBadge(tester, coins: 250, hammers: 3, showHammers: 3);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('o crédito aparece sem trocar de tela', (tester) async {
    final wallet = await pumpBadge(tester, coins: 40);

    wallet.creditCoins(10);
    await tester.pump();

    expect(find.text('50'), findsOneWidget);
  });

  testWidgets('o + abre a loja, e o vídeo credita ali mesmo', (tester) async {
    final wallet = await pumpBadge(tester, coins: 0);

    await tester.tap(find.byKey(coinsHeaderAddKey));
    await tester.pumpAndSettle();
    expect(find.byKey(coinStoreKey), findsOneWidget);

    await tester.tap(find.byKey(coinStoreWatchKey));
    await tester.pumpAndSettle();

    expect(wallet.state.coins, kCoinsPerRewardedAd);
    // A caixa não fecha ao pagar: quem veio buscar moeda costuma querer mais de
    // uma, e devolvê-lo à tela anterior o obrigaria a reabrir a loja.
    expect(find.byKey(coinStoreKey), findsOneWidget);

    await tester.tap(find.byKey(coinStoreCloseKey));
    await tester.pumpAndSettle();
    expect(find.byKey(coinStoreKey), findsNothing);
  });
}
