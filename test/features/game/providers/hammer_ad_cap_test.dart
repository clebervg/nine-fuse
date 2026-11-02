import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/daily_ad_count.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/presentation/widgets/game_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_offer_dialog.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import 'package:nine_fuse/features/game/providers/hammer_ad_cap.dart';
import 'package:nine_fuse/features/game/providers/wallet.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Disco que falha em tudo do teto.
class _BrokenStorage extends InMemoryGameStorage {
  @override
  Future<DailyAdCount> readHammerAdGrants() async =>
      throw StateError('sem disco');

  @override
  Future<void> writeHammerAdGrants(DailyAdCount value) async =>
      throw StateError('sem disco');
}

void main() {
  final monday = DateTime(2026, 11, 2, 22, 30);
  final tuesday = DateTime(2026, 11, 3, 0, 5);

  group('HammerAdCap', () {
    test('conta os vídeos do dia e trava no teto', () async {
      final storage = InMemoryGameStorage();
      final cap = HammerAdCap(storage: storage, now: () => monday);
      await cap.refresh();

      for (int i = 0; i < kMaxHammerAdsPerDay - 1; i++) {
        cap.recordGrant();
      }
      expect(cap.reachedToday, isFalse);

      cap.recordGrant();
      expect(cap.reachedToday, isTrue);
      // Persistido com a data: sobrevive a fechar o jogo.
      expect(
        storage.hammerAdGrants,
        DailyAdCount(day: localDayKey(monday), count: kMaxHammerAdsPerDay),
      );
    });

    test('o dia virou: o teto zera, inclusive com o app aberto', () async {
      var now = monday;
      final storage = InMemoryGameStorage(
        hammerAdGrants: DailyAdCount(
          day: localDayKey(monday),
          count: kMaxHammerAdsPerDay,
        ),
      );
      final cap = HammerAdCap(storage: storage, now: () => now);
      await cap.refresh();
      expect(cap.reachedToday, isTrue);

      now = tuesday;
      expect(cap.usedToday, 0);
      expect(cap.reachedToday, isFalse);

      cap.recordGrant();
      expect(storage.hammerAdGrants.day, localDayKey(tuesday));
      expect(storage.hammerAdGrants.count, 1);
    });

    test('o contador gravado ontem lido hoje vale zero', () async {
      final storage = InMemoryGameStorage(
        hammerAdGrants: DailyAdCount(day: localDayKey(monday), count: 3),
      );
      final cap = HammerAdCap(storage: storage, now: () => tuesday);
      await cap.refresh();

      expect(cap.usedToday, 0);
    });

    test('leitura com falha vale zero e não trava o vídeo', () async {
      final cap = HammerAdCap(storage: _BrokenStorage(), now: () => monday);
      await cap.refresh();

      expect(cap.usedToday, 0);
      expect(cap.reachedToday, isFalse);
      // Gravar também falha em silêncio: o crédito em memória vale.
      cap.recordGrant();
      expect(cap.usedToday, 1);
    });

    test('leitura velha não devolve vídeo ao teto', () async {
      final storage = InMemoryGameStorage();
      final cap = HammerAdCap(storage: storage, now: () => monday);
      cap.recordGrant();
      cap.recordGrant();
      // O disco ainda tinha o valor de antes (escrita assíncrona).
      storage.hammerAdGrants = DailyAdCount(day: localDayKey(monday), count: 1);

      await cap.refresh();
      expect(cap.usedToday, 2);
    });
  });

  group('convite do martelo', () {
    Future<void> pumpOffer(
      WidgetTester tester, {
      required HammerAdCap cap,
      required VoidCallback onGranted,
      int coins = kHammerCoinPrice,
    }) async {
      tester.view.physicalSize = const Size(750, 1800);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final wallet = WalletNotifier(storage: InMemoryGameStorage(coins: coins));
      await wallet.refresh();
      await cap.refresh();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            walletProvider.overrideWith((ref) => wallet),
            hammerAdCapProvider.overrideWith((ref) => cap),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            home: Scaffold(
              body: SingleChildScrollView(
                child: HammerOfferDialog(
                  onGranted: onGranted,
                  onDecline: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('o vídeo assistido conta para o teto do dia', (tester) async {
      final cap = HammerAdCap(
        storage: InMemoryGameStorage(),
        now: () => monday,
      );
      var granted = 0;
      await pumpOffer(tester, cap: cap, onGranted: () => granted++);

      await tester.tap(find.byKey(hammerOfferWatchKey));
      await tester.pumpAndSettle();

      expect(granted, 1);
      expect(cap.usedToday, 1);
    });

    testWidgets('no teto o vídeo fica desligado e a compra com moeda segue', (
      tester,
    ) async {
      final cap = HammerAdCap(
        storage: InMemoryGameStorage(
          hammerAdGrants: DailyAdCount(
            day: localDayKey(monday),
            count: kMaxHammerAdsPerDay,
          ),
        ),
        now: () => monday,
      );
      var granted = 0;
      await pumpOffer(tester, cap: cap, onGranted: () => granted++);

      expect(find.text('Volte amanhã para mais vídeos'), findsOneWidget);
      final watch = tester.widget<GameButton>(find.byKey(hammerOfferWatchKey));
      expect(watch.onPressed, isNull);

      await tester.tap(find.byKey(hammerOfferWatchKey), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(granted, 0);

      // A moeda não tem teto: quem paga com o que juntou não drena nada.
      await tester.tap(find.byKey(hammerOfferBuyKey));
      await tester.pumpAndSettle();
      expect(granted, 1);
      expect(cap.usedToday, kMaxHammerAdsPerDay);
    });
  });
}
