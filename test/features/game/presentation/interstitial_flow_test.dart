import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/ads/ad_providers.dart';
import 'package:nine_fuse/core/ads/interstitial_ad_service.dart';
import 'package:nine_fuse/core/notifications/notification_port.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/presentation/screens/game_screen.dart';
import 'package:nine_fuse/features/game/presentation/screens/level_select_screen.dart';
import 'package:nine_fuse/features/game/presentation/widgets/daily_spin_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/level_start_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/moves_offer_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/board_grid_widget.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_state.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';

import '../../../support/localized.dart';

class _FakeAd implements InterstitialAdHandle {
  _FakeAd(this.onShow);

  final VoidCallback onShow;

  @override
  Future<void> show() async => onShow();

  @override
  void dispose() {}
}

/// Rede com estoque infinito, que conta quantos anúncios foram ao ar.
class _CountingPort implements InterstitialAdPort {
  int shows = 0;

  @override
  Future<InterstitialAdHandle?> load(String unitId) async =>
      _FakeAd(() => shows++);
}

/// Notifier de verdade, com um atalho para a derrota: o que se mede aqui é a
/// regra da saída, não como se perde uma fase.
class _Notifier extends GameNotifier {
  _Notifier() : super(random: Random(42), storage: InMemoryGameStorage());

  void forceLoss() => state = state.copyWith(status: GameStatus.lost);
}

class _FakeNotificationPort implements NotificationPort {
  @override
  Future<void> scheduleDailySpinReminder(DateTime at) async {}

  @override
  Future<void> scheduleInactivityReminder(DateTime at) async {}

  @override
  Future<void> cancelAll() async {}
}

void main() {
  late _Notifier notifier;
  late InMemoryGameStorage storage;
  late _CountingPort port;

  setUp(() {
    notifier = _Notifier();
    storage = InMemoryGameStorage(lastSpinTimestamp: DateTime.now());
    port = _CountingPort();
  });

  /// Sem o intervalo de 45 s: o relógio de jogo do teste não anda sozinho, e
  /// o que se mede aqui é **onde** o anúncio pode sair, não quando.
  List<Override> overrides() => [
    gameProvider.overrideWith((ref) => notifier),
    campaignProgressProvider.overrideWith(
      (ref) => CampaignProgress(storage: storage),
    ),
    notificationPortProvider.overrideWithValue(_FakeNotificationPort()),
    dailySpinStorageProvider.overrideWithValue(storage),
    interstitialAdServiceProvider.overrideWith(
      (ref) => InterstitialAdService(
        port: port,
        unitId: 'teste',
        minPlayTime: Duration.zero,
      ),
    ),
  ];

  (Position, Position)? matchingSwap() {
    final engine = notifier.engine!;
    final board = notifier.state.board;
    for (final (a, b) in engine.candidateSwaps(board)) {
      if (engine.swapCreatesMatch(board, a, b)) return (a, b);
    }
    return null;
  }

  Future<void> winFirstLevel(WidgetTester tester) async {
    await tester.tap(find.byKey(startLevelKey));
    await tester.pumpAndSettle();
    for (
      int i = 0;
      i < 20 && notifier.state.status == GameStatus.playing;
      i++
    ) {
      if (find.byKey(movesOfferDeclineKey).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(movesOfferDeclineKey));
        await tester.pumpAndSettle();
      }
      final pair = matchingSwap();
      if (pair == null) break;
      await tester.tap(find.byKey(tileKey(pair.$1)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(tileKey(pair.$2)));
      await tester.pumpAndSettle();
    }
    expect(notifier.state.status, GameStatus.won);
  }

  Future<void> pumpGame(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: localizedApp(home: GameScreen(level: kCampaign.first)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('"próxima fase" depois da vitória mostra o intersticial', (
    tester,
  ) async {
    storage.campaignProgress = 10;
    await pumpGame(tester);
    await winFirstLevel(tester);

    await tester.tap(find.byKey(const Key('next_level')));
    await tester.pumpAndSettle();

    expect(port.shows, 1);
    // E a navegação segue depois dele.
    expect(notifier.state.level.number, 2);
  });

  testWidgets('no onboarding (antes de vencer a fase 3) nada aparece', (
    tester,
  ) async {
    await pumpGame(tester);
    await winFirstLevel(tester);

    await tester.tap(find.byKey(const Key('next_level')));
    await tester.pumpAndSettle();

    expect(port.shows, 0);
    expect(notifier.state.level.number, 2);
  });

  testWidgets('sair da fase para o mapa mostra o intersticial', (tester) async {
    storage.campaignProgress = 10;
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: localizedApp(home: const LevelSelectScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(levelSelectPlayButtonKey));
    await tester.pumpAndSettle();
    expect(find.byType(GameScreen), findsOneWidget);
    expect(port.shows, 0, reason: 'entrar na fase não é momento de anúncio');

    await tester.tap(find.byKey(levelStartCloseKey));
    await tester.pumpAndSettle();

    expect(find.byType(GameScreen), findsNothing);
    expect(port.shows, 1);
  });

  testWidgets('sair do mapa depois de uma derrota não mostra nada', (
    tester,
  ) async {
    storage.campaignProgress = 10;
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: localizedApp(home: const LevelSelectScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(levelSelectPlayButtonKey));
    await tester.pumpAndSettle();

    notifier.forceLoss();
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(GameScreen))).pop();
    await tester.pumpAndSettle();

    expect(port.shows, 0);
  });
}
