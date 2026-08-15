import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/presentation/widgets/game_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_offer_dialog.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import 'package:nine_fuse/features/game/providers/wallet.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

import '../../../support/localized.dart';

/// O funil de moedas dentro do convite de aquisição: assistir a um vídeo
/// credita o saldo, grava no disco e reacende o botão de compra na hora.
void main() {
  /// Monta o convite sobre uma carteira com [coins] moedas, com o anúncio de
  /// moedas respondendo [adPays]. Devolve o disco, para o teste conferir que a
  /// moeda sobreviveu à sessão.
  Future<InMemoryGameStorage> pumpOffer(
    WidgetTester tester, {
    required int coins,
    bool adPays = true,
  }) async {
    // Tela alta: o convite ganhou o cartão informativo e precisa caber inteiro
    // para os toques chegarem aos botões de baixo.
    tester.view.physicalSize = const Size(750, 1800);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final storage = InMemoryGameStorage(coins: coins);
    final wallet = WalletNotifier(storage: storage);
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
            body: SingleChildScrollView(
              child: HammerOfferDialog(onGranted: () {}, onDecline: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return storage;
  }

  testWidgets('o vídeo credita as moedas e grava no disco', (tester) async {
    final storage = await pumpOffer(tester, coins: 10);

    await tester.tap(find.byKey(hammerOfferEarnCoinsKey));
    await tester.pumpAndSettle();

    expect(storage.coins, 10 + kCoinsPerRewardedAd);
  });

  testWidgets('anúncio que não vem não credita nada', (tester) async {
    final storage = await pumpOffer(tester, coins: 10, adPays: false);

    await tester.tap(find.byKey(hammerOfferEarnCoinsKey));
    await tester.pumpAndSettle();

    expect(storage.coins, 10);
  });

  testWidgets('o crédito reabilita a compra no mesmo quadro', (tester) async {
    // Falta exatamente o que um vídeo paga: o botão de compra nasce
    // desabilitado e tem de acender sozinho depois do anúncio, sem o jogador
    // precisar fechar e reabrir a caixa.
    await pumpOffer(tester, coins: kHammerCoinPrice - kCoinsPerRewardedAd);

    GameButton buyButton() =>
        tester.widget<GameButton>(find.byKey(hammerOfferBuyKey));

    expect(buyButton().onPressed, isNull);

    await tester.tap(find.byKey(hammerOfferEarnCoinsKey));
    await tester.pumpAndSettle();

    expect(buyButton().onPressed, isNotNull);
  });

  testWidgets('o convite lista as três formas de ganhar moeda', (tester) async {
    await pumpOffer(tester, coins: 0);

    expect(find.byKey(coinSourcesKey), findsOneWidget);

    final l10n = l10nFor();
    for (final source in [
      l10n.coinSourcesStars,
      l10n.coinSourcesAds,
      l10n.coinSourcesChests,
    ]) {
      expect(find.text(source), findsOneWidget);
    }
  });
}
