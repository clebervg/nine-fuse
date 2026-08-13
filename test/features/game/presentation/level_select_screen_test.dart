import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/presentation/screens/endless_screen.dart';
import 'package:nine_fuse/features/game/presentation/screens/game_screen.dart';
import 'package:nine_fuse/features/game/presentation/screens/level_select_screen.dart';
import 'package:nine_fuse/features/game/presentation/widgets/endless_highlight.dart';
import 'package:nine_fuse/features/game/presentation/widgets/level_start_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/saga_map.dart';
import 'package:nine_fuse/features/game/domain/level_record.dart';
import 'package:nine_fuse/features/game/providers/campaign_records.dart';
import 'package:nine_fuse/features/game/providers/endless_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import '../../../support/localized.dart';

/// Armazenamento que sempre falha, para verificar que o menu não trava.
class _BrokenStorage implements GameStorage {
  @override
  Future<int> readCampaignProgress() async =>
      throw StateError('disco indisponível');

  @override
  Future<void> writeCampaignProgress(int levelNumber) async =>
      throw StateError('disco indisponível');

  @override
  Future<int> readHighScore() async => throw StateError('disco indisponível');

  @override
  Future<void> writeHighScore(int score) async =>
      throw StateError('disco indisponível');

  @override
  Future<Map<int, LevelRecord>> readLevelRecords() async =>
      throw StateError('disco indisponível');

  @override
  Future<void> writeLevelRecords(Map<int, LevelRecord> records) async =>
      throw StateError('disco indisponível');
  @override
  Future<int> readHammerCount() async => throw StateError('sem disco');
  @override
  Future<void> writeHammerCount(int count) async =>
      throw StateError('sem disco');
  @override
  Future<int> readCoins() async => throw StateError('sem disco');
  @override
  Future<void> writeCoins(int coins) async => throw StateError('sem disco');
  @override
  Future<Set<int>> readClaimedChests() async => throw StateError('sem disco');
  @override
  Future<void> writeClaimedChests(Set<int> chapters) async =>
      throw StateError('sem disco');
}

void main() {
  late ProviderContainer container;

  late InMemoryGameStorage storage;

  setUp(() {
    storage = InMemoryGameStorage();
    container = ProviderContainer(
      overrides: [
        // Sem isso os dois modos tentariam ler o armazenamento real do
        // dispositivo, que não existe em teste.
        endlessProvider.overrideWith(
          (ref) => EndlessNotifier(random: Random(1), storage: storage),
        ),
        campaignProgressProvider.overrideWith(
          (ref) => CampaignProgress(storage: storage),
        ),
        campaignRecordsProvider.overrideWith(
          (ref) => CampaignRecords(storage: storage),
        ),
        endlessHighScoreProvider.overrideWith(
          (ref) => EndlessHighScore(storage: storage),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> pumpSelect(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(home: const LevelSelectScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lista todas as fases da campanha', (tester) async {
    await pumpSelect(tester);

    for (final level in kCampaign) {
      expect(
        find.byKey(levelCardKey(level.number)),
        findsOneWidget,
        reason: 'fase ${level.number} não apareceu',
      );
    }
  });

  // O mapa mostra o **número** da fase no pin, não o objetivo: a trilha é
  // orientação, e o briefing completo vive no cartão de início de fase.
  testWidgets('cada pin mostra o número da sua fase', (tester) async {
    await pumpSelect(tester);

    // A fase da vez traz o número e o convite para jogar.
    expect(
      find.descendant(
        of: find.byKey(levelCardKey(1)),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(find.text('JOGAR'), findsOneWidget);

    // As bloqueadas trazem cadeado no lugar do número.
    expect(
      find.descendant(
        of: find.byKey(levelCardKey(2)),
        matching: find.byIcon(Icons.lock_outline),
      ),
      findsOneWidget,
    );
  });

  testWidgets('sem progresso, só a fase 1 está liberada', (tester) async {
    await pumpSelect(tester);

    final unlocked = container.read(campaignProgressProvider.notifier);

    expect(unlocked.isUnlocked(kCampaign[0]), isTrue);
    expect(unlocked.isUnlocked(kCampaign[1]), isFalse);
    expect(unlocked.isUnlocked(kCampaign.last), isFalse);
  });

  testWidgets('as fases bloqueadas aparecem com cadeado', (tester) async {
    await pumpSelect(tester);

    // Nove das dez fases começam bloqueadas, e o Endless também. Somam-se os
    // nós projetados no fim da trilha, que também trazem cadeado: eles não são
    // fase, mas contam no total de cadeados na tela.
    expect(
      find.byIcon(Icons.lock_outline),
      findsNWidgets(kCampaign.length + SagaGeometry.futureNodes),
    );
  });

  testWidgets('concluir uma fase libera a seguinte e marca a anterior', (
    tester,
  ) async {
    container.read(campaignProgressProvider.notifier).complete(1);
    await pumpSelect(tester);

    final unlocked = container.read(campaignProgressProvider.notifier);
    expect(unlocked.isUnlocked(kCampaign[1]), isTrue);
    expect(unlocked.isUnlocked(kCampaign[2]), isFalse);

    // A fase 1 sai do cadeado (vencida) e a 2 vira a da vez: sobram oito
    // travadas na trilha, mais o cadeado do Endless.
    expect(
      find.byIcon(Icons.lock_outline),
      findsNWidgets(kCampaign.length - 1 + SagaGeometry.futureNodes),
    );
  });

  group('cartão do Endless', () {
    testWidgets('aparece travado antes da fase $kEndlessUnlockLevel', (
      tester,
    ) async {
      await pumpSelect(tester);

      expect(find.byKey(endlessCardKey), findsOneWidget);
      expect(
        find.text('Conclua a fase $kEndlessUnlockLevel para liberar'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(endlessCardKey), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byType(EndlessScreen), findsNothing);
    });

    testWidgets('destrava ao concluir a fase $kEndlessUnlockLevel', (
      tester,
    ) async {
      container
          .read(campaignProgressProvider.notifier)
          .complete(kEndlessUnlockLevel);
      await pumpSelect(tester);

      // Destravado, o destaque troca a promessa pelo recorde do jogador.
      expect(find.byKey(endlessRecordKey), findsOneWidget);
      expect(find.textContaining('Sua melhor pontuação'), findsOneWidget);
      expect(
        find.text('Conclua a fase $kEndlessUnlockLevel para liberar'),
        findsNothing,
      );
    });

    testWidgets('tocar no cartão destravado abre o Endless', (tester) async {
      container
          .read(campaignProgressProvider.notifier)
          .complete(kEndlessUnlockLevel);
      await pumpSelect(tester);

      await tester.tap(find.byKey(endlessCardKey));
      // `pump` em vez de `pumpAndSettle`: o tabuleiro só aparece depois do
      // carregamento, e o indicador de progresso anima sem fim.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(EndlessScreen), findsOneWidget);
    });

    testWidgets('a chamada só existe destravada, e também abre o modo', (
      tester,
    ) async {
      await pumpSelect(tester);
      expect(
        find.byKey(endlessCallToActionKey),
        findsNothing,
        reason: 'travado não há o que superar',
      );

      container
          .read(campaignProgressProvider.notifier)
          .complete(kEndlessUnlockLevel);
      await tester.pump();

      expect(find.byKey(endlessCallToActionKey), findsOneWidget);

      await tester.tap(find.byKey(endlessCallToActionKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(EndlessScreen), findsOneWidget);
    });
  });

  testWidgets('tocar numa fase liberada abre o jogo', (tester) async {
    await pumpSelect(tester);

    await tester.tap(find.byKey(levelCardKey(1)));
    await tester.pumpAndSettle();

    expect(find.byType(GameScreen), findsOneWidget);
    // "Fase 1" aparece na barra de título e no cartão de início, que abre
    // junto com a fase.
    expect(find.text('Fase 1'), findsWidgets);
    expect(find.byKey(levelStartKey), findsOneWidget);
  });

  testWidgets('tocar numa fase bloqueada não abre nada', (tester) async {
    await pumpSelect(tester);

    await tester.tap(find.byKey(levelCardKey(5)), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(GameScreen), findsNothing);
    expect(find.byType(LevelSelectScreen), findsOneWidget);
  });

  group('CampaignProgress', () {
    test('complete só avança, nunca retrocede', () {
      final progress = CampaignProgress(storage: InMemoryGameStorage());

      progress.complete(3);
      expect(progress.state, 3);

      progress.complete(1);
      expect(
        progress.state,
        3,
        reason: 'refazer fase antiga não pode regredir',
      );

      progress.complete(4);
      expect(progress.state, 4);
    });

    test('isUnlocked libera exatamente a fase seguinte à última concluída', () {
      final progress = CampaignProgress(storage: InMemoryGameStorage())
        ..complete(2);

      expect(progress.isUnlocked(kCampaign[1]), isTrue); // fase 2, refazível
      expect(progress.isUnlocked(kCampaign[2]), isTrue); // fase 3, liberada
      expect(progress.isUnlocked(kCampaign[3]), isFalse); // fase 4, travada
    });

    test('reset volta ao começo', () {
      final progress = CampaignProgress(storage: InMemoryGameStorage())
        ..complete(5);
      progress.reset();

      expect(progress.state, 0);
      expect(progress.isUnlocked(kCampaign.first), isTrue);
    });
  });

  group('persistência do progresso', () {
    // O avanço na campanha vivia só em memória, e reabrir o app custava a
    // campanha inteira. Estes testes fixam o comportamento contrário.

    test('carrega o avanço salvo ao iniciar', () async {
      final saved = InMemoryGameStorage(campaignProgress: 7);
      final progress = CampaignProgress(storage: saved);

      // A leitura é assíncrona: o estado começa em zero e sobe quando chega.
      expect(progress.state, 0);
      await Future<void>.delayed(Duration.zero);

      expect(progress.state, 7);
      expect(progress.isUnlocked(kCampaign[7]), isTrue);
    });

    test('grava ao concluir uma fase', () async {
      final saved = InMemoryGameStorage();
      CampaignProgress(storage: saved).complete(4);
      await Future<void>.delayed(Duration.zero);

      expect(saved.campaignProgress, 4);
    });

    test('grava ao resetar', () async {
      final saved = InMemoryGameStorage(campaignProgress: 6);
      final progress = CampaignProgress(storage: saved);
      await Future<void>.delayed(Duration.zero);

      progress.reset();
      await Future<void>.delayed(Duration.zero);

      expect(saved.campaignProgress, 0);
    });

    test('a leitura tardia não apaga um avanço feito antes dela', () async {
      // Corrida real: o jogador conclui uma fase antes de o disco responder.
      final saved = InMemoryGameStorage(campaignProgress: 2);
      final progress = CampaignProgress(storage: saved);

      progress.complete(5);
      await Future<void>.delayed(Duration.zero);

      expect(progress.state, 5, reason: 'a leitura antiga sobrescreveu o novo');
    });

    test('falha de leitura não impede de jogar', () async {
      final progress = CampaignProgress(storage: _BrokenStorage());
      await Future<void>.delayed(Duration.zero);

      expect(progress.state, 0);
      expect(progress.isUnlocked(kCampaign.first), isTrue);
    });

    test('falha de gravação não derruba o jogo', () async {
      final progress = CampaignProgress(storage: _BrokenStorage());

      expect(() => progress.complete(3), returnsNormally);
      await Future<void>.delayed(Duration.zero);
      expect(progress.state, 3);
    });
  });
}
