import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/widgets/coins_header_badge.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/presentation/screens/shop_screen.dart';
import 'package:nine_fuse/features/game/presentation/widgets/coin_sources_card.dart';
import 'package:nine_fuse/features/game/presentation/widgets/game_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_offer_dialog.dart'
    show coinAdProvider;
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import 'package:nine_fuse/features/game/providers/wallet.dart';

import '../../../support/localized.dart';

/// A Loja fora da partida: só moeda, preço do código, estoque persistido.
void main() {
  late InMemoryGameStorage storage;

  Future<WalletNotifier> pumpShop(
    WidgetTester tester, {
    required int coins,
    int hammers = 0,
    bool adPays = true,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    storage = InMemoryGameStorage(coins: coins, hammerCount: hammers);
    final wallet = WalletNotifier(storage: storage);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletProvider.overrideWith((ref) => wallet),
          coinAdProvider.overrideWithValue(() async => adPays),
        ],
        child: localizedApp(home: const ShopScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return wallet;
  }

  testWidgets('comprar debita as moedas e grava uma unidade no estoque', (
    tester,
  ) async {
    final wallet = await pumpShop(tester, coins: kHammerCoinPrice + 30);

    expect(find.text('Você tem 0'), findsNWidgets(3));

    await tester.tap(find.byKey(shopBuyKey(BoosterKind.hammer)));
    await tester.pumpAndSettle();

    expect(wallet.state.coins, 30);
    expect(storage.coins, 30);
    expect(storage.hammerCount, 1);
    expect(
      tester.widget<Text>(find.byKey(shopStockKey(BoosterKind.hammer))).data,
      'Você tem 1',
    );
  });

  testWidgets('bomba e pincel gravam cada um no seu estoque', (tester) async {
    await pumpShop(tester, coins: kBombCoinPrice + kBrushCoinPrice);

    await tester.tap(find.byKey(shopBuyKey(BoosterKind.bomb)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(shopBuyKey(BoosterKind.brush)));
    await tester.pumpAndSettle();

    expect(storage.bombCount, 1);
    expect(storage.brushCount, 1);
    expect(storage.hammerCount, 0);
    expect(storage.coins, 0);
  });

  testWidgets('sem saldo o botão fica desabilitado e nada muda', (
    tester,
  ) async {
    await pumpShop(tester, coins: kHammerCoinPrice - 1);

    final hammer = tester.widget<GameButton>(
      find.byKey(shopBuyKey(BoosterKind.hammer)),
    );
    expect(hammer.onPressed, isNull);
    // A bomba é a mais cara: com saldo abaixo do martelo, também apagada.
    expect(
      tester
          .widget<GameButton>(find.byKey(shopBuyKey(BoosterKind.bomb)))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(shopBuyKey(BoosterKind.hammer)));
    await tester.pumpAndSettle();

    expect(storage.coins, kHammerCoinPrice - 1);
    expect(storage.hammerCount, 0);
  });

  testWidgets('compra não respeita o teto dos prêmios gratuitos', (
    tester,
  ) async {
    // O teto vale para a roleta; aqui o jogador pagou pelo item.
    await pumpShop(tester, coins: kHammerCoinPrice, hammers: kMaxBoosterStock);

    await tester.tap(find.byKey(shopBuyKey(BoosterKind.hammer)));
    await tester.pumpAndSettle();

    expect(storage.hammerCount, kMaxBoosterStock + 1);
    expect(storage.coins, 0);
  });

  testWidgets('o vídeo credita moedas na carteira e no disco', (tester) async {
    final wallet = await pumpShop(tester, coins: 10);

    await tester.tap(find.byKey(shopWatchKey));
    await tester.pumpAndSettle();

    expect(wallet.state.coins, 10 + kCoinsPerRewardedAd);
    expect(storage.coins, 10 + kCoinsPerRewardedAd);
  });

  testWidgets('vídeo que não paga não credita nada', (tester) async {
    await pumpShop(tester, coins: 10, adPays: false);

    await tester.tap(find.byKey(shopWatchKey));
    await tester.pumpAndSettle();

    expect(storage.coins, 10);
  });

  testWidgets('mostra as fontes de moeda, e a pílula sem o +', (tester) async {
    await pumpShop(tester, coins: 0);

    expect(find.byKey(coinSourcesKey), findsOneWidget);
    expect(find.byKey(coinsHeaderBadgeKey), findsOneWidget);
    expect(find.byKey(coinsHeaderAddKey), findsNothing);
  });
}
