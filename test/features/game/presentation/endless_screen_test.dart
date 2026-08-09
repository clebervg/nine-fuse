import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/presentation/screens/endless_screen.dart';
import 'package:nine_fuse/features/game/presentation/widgets/board_grid_widget.dart';
import 'package:nine_fuse/features/game/presentation/widgets/endless_banner.dart';
import 'package:nine_fuse/features/game/presentation/widgets/tile_widget.dart';
import 'package:nine_fuse/features/game/providers/endless_notifier.dart';
import 'package:nine_fuse/features/game/providers/endless_state.dart';
import 'package:nine_fuse/features/game/domain/level_record.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import '../../../support/localized.dart';

/// Armazenamento que sempre falha, para verificar que o jogo não fica preso.
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
}

void main() {
  late EndlessNotifier notifier;
  late InMemoryGameStorage storage;

  setUp(() {
    storage = InMemoryGameStorage();
    notifier = EndlessNotifier(random: Random(7), storage: storage);
  });

  Future<void> pumpEndless(
    WidgetTester tester, {
    EndlessNotifier? custom,
  }) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [endlessProvider.overrideWith((ref) => custom ?? notifier)],
        child: localizedApp(home: const EndlessScreen()),
      ),
    );
    // O tabuleiro nasce depois de uma leitura assíncrona; `pumpAndSettle` não
    // serve porque o indicador de carregamento anima sem parar.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  (Position, Position)? findSwap({required bool creatingMatch}) {
    final engine = notifier.engine!;
    final board = notifier.state.board;

    for (final (a, b) in engine.candidateSwaps(board)) {
      if (engine.swapCreatesMatch(board, a, b) == creatingMatch) return (a, b);
    }
    return null;
  }

  testWidgets('desenha o tabuleiro e o painel de pontos', (tester) async {
    await pumpEndless(tester);

    expect(find.byType(TileWidget), findsNWidgets(64));
    expect(find.byKey(endlessScoreKey), findsOneWidget);
    expect(find.text('Pontos'), findsOneWidget);
    expect(find.text('Recorde'), findsOneWidget);
  });

  testWidgets('não mostra limite de movimentos', (tester) async {
    await pumpEndless(tester);

    // O Endless não tem limite; qualquer texto de movimentos restantes seria
    // uma mentira herdada da campanha.
    expect(find.text('movimentos'), findsNothing);
  });

  testWidgets('mostra a faixa de peças da vez e o que promove', (tester) async {
    await pumpEndless(tester);

    expect(find.byKey(endlessStepKey), findsOneWidget);

    // A frase e o dígito que promove ficam separados: o número é desenhado
    // como peça, para o jogador reconhecer no tabuleiro o que ele precisa
    // criar.
    expect(find.text('Próxima faixa: crie um'), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(endlessStepKey), matching: find.text('5')),
      findsOneWidget,
    );
    expect(find.byKey(endlessBandProgressKey), findsOneWidget);
  });

  testWidgets('uma jogada válida soma pontos na tela', (tester) async {
    await pumpEndless(tester);

    final pair = findSwap(creatingMatch: true)!;
    await tester.tap(find.byKey(tileKey(pair.$1)));
    await tester.pump();
    await tester.tap(find.byKey(tileKey(pair.$2)));
    await tester.pump();

    expect(notifier.state.score, greaterThan(0));
    expect(find.text('${notifier.state.score}'), findsWidgets);
  });

  testWidgets('o recorde salvo aparece no painel', (tester) async {
    final loaded = EndlessNotifier(
      random: Random(7),
      storage: InMemoryGameStorage(highScore: 4242),
    );
    await pumpEndless(tester, custom: loaded);

    expect(find.text('4242'), findsOneWidget);
  });

  testWidgets('falha de armazenamento não trava a tela no carregamento', (
    tester,
  ) async {
    final broken = EndlessNotifier(
      random: Random(7),
      storage: _BrokenStorage(),
    );

    await pumpEndless(tester, custom: broken);

    // O jogo tem de começar mesmo sem conseguir ler o recorde.
    expect(broken.state.status, EndlessStatus.playing);
    expect(broken.highScore, 0);
    expect(find.byType(TileWidget), findsNWidgets(64));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('o tabuleiro tem margem dos dois lados', (tester) async {
    // Largura real de um iPhone 16 Pro. Sem margem o tabuleiro encosta na
    // borda e parece cortado, mesmo cabendo tecnicamente.
    //
    // Monta a tela aqui em vez de usar `pumpEndless`, que fixa uma janela
    // larga própria e sobrescreveria este tamanho.
    const screen = 1206 / 3;
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [endlessProvider.overrideWith((ref) => notifier)],
        child: localizedApp(home: const EndlessScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final board = tester.getRect(find.byType(BoardGridWidget));

    expect(
      board.left,
      greaterThanOrEqualTo(8.0),
      reason: 'o tabuleiro está colado na borda esquerda',
    );
    expect(
      board.right,
      lessThanOrEqualTo(screen - 8),
      reason:
          'o tabuleiro está colado na borda direita: '
          '${board.right} de $screen',
    );
  });

  testWidgets('cabe em tela pequena sem estourar', (tester) async {
    tester.view.physicalSize = const Size(750, 1334);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [endlessProvider.overrideWith((ref) => notifier)],
        child: localizedApp(home: const EndlessScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(find.byType(TileWidget), findsNWidgets(64));
  });
}
