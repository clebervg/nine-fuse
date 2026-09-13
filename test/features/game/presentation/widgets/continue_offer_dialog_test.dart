import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/presentation/widgets/continue_offer_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/game_dialog.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import 'package:nine_fuse/features/game/providers/wallet.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

Widget _wrap(Widget child, {List<Override> overrides = const []}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: Center(child: child))),
  ),
);

void main() {
  // O convite vive dentro de um `SingleChildScrollView` na tela do jogo (ver
  // `_OutcomeOverlay`); sem essa moldura e sem uma janela de teste maior, o
  // `CoinSourcesCard` estoura a altura padrão do teste (mesma armadilha já
  // registrada em `hammer_purchase_test.dart`).
  testWidgets('assistir ao anúncio credita o resgate', (tester) async {
    tester.view.physicalSize = const Size(750, 1800);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    var granted = false;
    await tester.pumpWidget(_wrap(
      ContinueOfferDialog(onGranted: () => granted = true, onDecline: () {}),
    ));

    await tester.tap(find.byKey(continueOfferWatchKey));
    await tester.pumpAndSettle();

    expect(granted, isTrue);
  });

  testWidgets('recusar não credita', (tester) async {
    tester.view.physicalSize = const Size(750, 1800);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    var granted = false;
    var declined = false;
    await tester.pumpWidget(_wrap(
      ContinueOfferDialog(
        onGranted: () => granted = true,
        onDecline: () => declined = true,
      ),
    ));

    await tester.tap(find.byKey(continueOfferDeclineKey));
    await tester.pumpAndSettle();

    expect(granted, isFalse);
    expect(declined, isTrue);
  });

  testWidgets('comprar por moedas debita a carteira e credita o resgate', (tester) async {
    tester.view.physicalSize = const Size(750, 1800);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final storage = InMemoryGameStorage()..coins = kContinueCoinPrice;
    final wallet = WalletNotifier(storage: storage);
    await wallet.refresh();
    var granted = false;
    await tester.pumpWidget(_wrap(
      ContinueOfferDialog(onGranted: () => granted = true, onDecline: () {}),
      overrides: [
        walletProvider.overrideWith((ref) => wallet),
      ],
    ));
    await tester.pump();

    await tester.tap(find.byKey(continueOfferBuyKey));
    await tester.pump();

    expect(granted, isTrue);
    expect(storage.coins, 0);
  });

  testWidgets('botão de compra fica desabilitado sem saldo', (tester) async {
    tester.view.physicalSize = const Size(750, 1800);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final storage = InMemoryGameStorage()..coins = 0;
    final wallet = WalletNotifier(storage: storage);
    await wallet.refresh();
    await tester.pumpWidget(_wrap(
      const ContinueOfferDialog(onGranted: _noop, onDecline: _noop),
      overrides: [
        walletProvider.overrideWith((ref) => wallet),
      ],
    ));
    await tester.pump();

    final button = tester.widget<GameButton>(
      find.byKey(continueOfferBuyKey),
    );
    expect(button.onPressed, isNull);
  });
}

void _noop() {}
