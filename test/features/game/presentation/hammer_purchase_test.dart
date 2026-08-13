import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_offer_dialog.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import 'package:nine_fuse/features/game/providers/wallet.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

void main() {
  /// Monta o convite sobre uma carteira com [coins] moedas.
  Future<WalletNotifier> pumpOffer(
    WidgetTester tester, {
    required int coins,
    required VoidCallback onGranted,
  }) async {
    final wallet = WalletNotifier(
      storage: InMemoryGameStorage(coins: coins),
    );
    await wallet.refresh();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [walletProvider.overrideWith((ref) => wallet)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: HammerOfferDialog(
              onGranted: onGranted,
              onDecline: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return wallet;
  }

  testWidgets('compra com saldo suficiente debita e entrega o martelo', (
    tester,
  ) async {
    var granted = 0;
    final wallet = await pumpOffer(
      tester,
      coins: kHammerCoinPrice + 30,
      onGranted: () => granted++,
    );

    await tester.tap(find.byKey(hammerOfferBuyKey));
    await tester.pumpAndSettle();

    expect(wallet.state.coins, 30);
    // Quem credita o martelo é o notifier da partida, pelo mesmo caminho do
    // anúncio — a caixa só avisa que foi pago.
    expect(granted, 1);
  });

  testWidgets('com saldo curto o botão de compra fica desabilitado', (
    tester,
  ) async {
    var granted = 0;
    final wallet = await pumpOffer(
      tester,
      coins: kHammerCoinPrice - 1,
      onGranted: () => granted++,
    );

    await tester.tap(find.byKey(hammerOfferBuyKey));
    await tester.pumpAndSettle();

    expect(wallet.state.coins, kHammerCoinPrice - 1);
    expect(granted, 0);
  });

  testWidgets('dois toques na compra antes do rebuild só debitam uma vez', (
    tester,
  ) async {
    var granted = 0;
    // Saldo para DUAS compras: é o caso em que `spendCoins` sozinho não barra
    // o segundo toque, porque o saldo continua cobrindo o preço depois do
    // primeiro débito. Só a trava de `_waiting` em `_buy` impede o segundo.
    final wallet = await pumpOffer(
      tester,
      coins: kHammerCoinPrice * 2 + 30,
      onGranted: () => granted++,
    );

    // Sem `pump` entre os dois toques: é a janela em que `canAfford` ainda
    // não foi reavaliado pelo rebuild do primeiro débito. Se `_buy` não travar
    // sozinho, os dois toques processam antes de o botão desabilitar.
    await tester.tap(find.byKey(hammerOfferBuyKey));
    await tester.tap(find.byKey(hammerOfferBuyKey));
    await tester.pumpAndSettle();

    expect(wallet.state.coins, kHammerCoinPrice + 30);
    expect(granted, 1);
  });

  testWidgets('o botão de anúncio continua funcionando sem moeda nenhuma', (
    tester,
  ) async {
    // O anúncio é o caminho principal de aquisição: a compra não pode tê-lo
    // substituído nem escondido.
    var granted = 0;
    await pumpOffer(tester, coins: 0, onGranted: () => granted++);

    expect(find.byKey(hammerOfferWatchKey), findsOneWidget);

    await tester.tap(find.byKey(hammerOfferWatchKey));
    await tester.pumpAndSettle();

    expect(granted, 1);
  });

  testWidgets(
    'saldo esvaziado por trás da UI deixa o botão de anúncio vivo depois da recusa',
    (tester) async {
      // Monta com saldo suficiente: o botão de compra nasce habilitado.
      var granted = 0;
      final wallet = await pumpOffer(
        tester,
        coins: kHammerCoinPrice,
        onGranted: () => granted++,
      );

      // Esvazia o saldo direto no notifier, sem deixar a UI rebuildar — é a
      // janela em que `canAfford` (calculado no último build) ainda diz que dá,
      // mas `spendCoins` (que lê o estado atual) vai recusar.
      wallet.spendCoins(kHammerCoinPrice);

      await tester.tap(find.byKey(hammerOfferBuyKey));
      await tester.pump();

      // A compra falhou (saldo já zerado por fora), mas a caixa não pode
      // travar: o botão do anúncio ainda tem de funcionar.
      await tester.tap(find.byKey(hammerOfferWatchKey));
      await tester.pumpAndSettle();

      expect(granted, 1);
    },
  );
}
