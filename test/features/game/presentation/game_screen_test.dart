import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/star_rating.dart';
import 'package:nine_fuse/features/game/presentation/screens/game_screen.dart';
import 'package:nine_fuse/features/game/presentation/widgets/board_grid_widget.dart';
import 'package:nine_fuse/features/game/presentation/widgets/level_banner.dart';
import 'package:nine_fuse/features/game/presentation/widgets/level_start_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/level_outcome_card.dart';
import 'package:nine_fuse/features/game/presentation/widgets/tile_widget.dart';
import 'package:nine_fuse/features/game/presentation/widgets/chapter_star_progress.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_state.dart';
import 'package:nine_fuse/features/game/presentation/l10n_labels.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';
import '../../../support/localized.dart';

void main() {
  late GameNotifier notifier;

  /// Fase folgada, para exercitar a tela sem a fase acabar no meio do teste.
  const roomy = GameLevel(
    number: 42,
    objective: Objective(digit: 8, count: 9),
    moveLimit: 500,
  );

  setUp(() {
    notifier = GameNotifier(random: Random(42));
  });

  /// Fecha o cartão de início de fase, se estiver aberto.
  ///
  /// Toda fase abre com ele, e enquanto ele está na tela o tabuleiro não aceita
  /// toque. É idempotente de propósito: dá para chamar sem saber se a fase
  /// acabou de recomeçar (o que traz o cartão de volta) ou não.
  Future<void> startPlaying(WidgetTester tester) async {
    if (find.byKey(startLevelKey).evaluate().isEmpty) return;
    await tester.tap(find.byKey(startLevelKey));
    await tester.pumpAndSettle();
  }

  /// A tela é alta: sem uma janela grande o tabuleiro sai da área visível e os
  /// toques não chegam nas células.
  Future<void> pumpGame(WidgetTester tester, {GameLevel level = roomy}) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [gameProvider.overrideWith((ref) => notifier)],
        child: localizedApp(home: GameScreen(level: level)),
      ),
    );
    // Um frame extra: initState agenda a criação do tabuleiro.
    await tester.pumpAndSettle();
    await startPlaying(tester);
  }

  (Position, Position)? findSwap({required bool creatingMatch}) {
    final engine = notifier.engine!;
    final board = notifier.state.board;

    for (final (a, b) in engine.candidateSwaps(board)) {
      if (engine.swapCreatesMatch(board, a, b) == creatingMatch) return (a, b);
    }
    return null;
  }

  Future<void> playSwap(WidgetTester tester, (Position, Position) pair) async {
    // Jogar pressupõe a fase liberada. Os testes que montam a tela à mão, sem
    // `pumpGame`, cairiam num tabuleiro que não aceita toque.
    await startPlaying(tester);
    await tester.tap(find.byKey(tileKey(pair.$1)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(tileKey(pair.$2)));
    await tester.pumpAndSettle();
  }

  testWidgets('mostra a fase, o objetivo e os movimentos restantes', (
    tester,
  ) async {
    await pumpGame(tester);

    expect(find.text('Fase 42'), findsOneWidget);
    expect(find.text('Crie 9 peças 8'), findsOneWidget);
    expect(find.text('0 de 9'), findsOneWidget);
    expect(find.text('500'), findsOneWidget);
    expect(find.byType(TileWidget), findsNWidgets(64));
  });

  testWidgets('a dica da fase aparece quando existe', (tester) async {
    await pumpGame(tester, level: kCampaign.first);

    expect(
      find.text(l10nFor().levelTip(kCampaign.first.teaches)!),
      findsOneWidget,
    );
  });

  testWidgets('uma jogada válida consome movimento na tela', (tester) async {
    await pumpGame(tester);

    await playSwap(tester, findSwap(creatingMatch: true)!);

    expect(notifier.state.moves, 1);
    expect(
      find.text('499'),
      findsOneWidget,
      reason: 'o contador de movimentos deveria ter baixado',
    );
  });

  testWidgets('uma troca recusada não consome movimento', (tester) async {
    await pumpGame(tester);

    await playSwap(tester, findSwap(creatingMatch: false)!);

    expect(find.text('500'), findsOneWidget);
    expect(notifier.state.rejectedSwap, isNotNull);
  });

  testWidgets('o tabuleiro continua cheio depois da jogada', (tester) async {
    await pumpGame(tester);

    await playSwap(tester, findSwap(creatingMatch: true)!);

    expect(find.byType(TileWidget), findsNWidgets(64));
  });

  testWidgets('vencer mostra o cartão de fase concluída', (tester) async {
    // Objetivo mínimo: cai no primeiro movimento válido.
    const trivial = GameLevel(
      number: 43,
      objective: Objective(digit: 4),
      moveLimit: 30,
    );
    await pumpGame(tester, level: trivial);

    for (
      int i = 0;
      i < 20 && notifier.state.status == GameStatus.playing;
      i++
    ) {
      final pair = findSwap(creatingMatch: true);
      if (pair == null) break;
      await playSwap(tester, pair);
    }

    expect(notifier.state.status, GameStatus.won);
    expect(find.byKey(const Key('level_outcome')), findsOneWidget);
    expect(find.text('FASE CONCLUÍDA!'), findsOneWidget);
    expect(find.byKey(starsKey), findsOneWidget);
  });

  testWidgets('perder por saldo diz que foi o contador, não o tabuleiro', (
    tester,
  ) async {
    const tight = GameLevel(
      number: 44,
      objective: Objective(digit: 9, count: 9),
      moveLimit: 1,
    );
    await pumpGame(tester, level: tight);

    await playSwap(tester, findSwap(creatingMatch: true)!);

    expect(notifier.state.status, GameStatus.lost);
    expect(notifier.state.lossReason, LossReason.moveLimitReached);

    // O título e a frase precisam apontar o contador. Dizer só "os movimentos
    // acabaram" com o tabuleiro cheio de jogadas à vista parecia falso fim de
    // jogo.
    expect(find.text('MOVIMENTOS ESGOTADOS'), findsOneWidget);
    // Pelo texto traduzido e não por um trecho escrito à mão: esta fase tem
    // **um** movimento, e o detalhe cai no ramo singular do plural ICU ("o
    // único movimento da fase acabou"). Procurar "movimentos da fase acabaram"
    // acusaria falha numa frase que está certa.
    expect(
      find.text(l10nFor().outcomeMovesDetail(tight.moveLimit)),
      findsOneWidget,
    );
    expect(find.textContaining('ainda tinha jogadas'), findsOneWidget);
    expect(find.textContaining('Não restam trocas válidas'), findsNothing);
  });

  testWidgets('a mensagem de tabuleiro travado é diferente da de saldo', (
    tester,
  ) async {
    // Sem partida real: monta o estado das duas causas e compara os textos.
    const level = GameLevel(
      number: 43,
      objective: Objective(digit: 5),
      moveLimit: 20,
    );

    Widget card(LossReason reason) => MaterialApp(
      locale: kTestLocale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: LevelOutcomeCard(
          state: GameState(
            board: Board.empty(),
            level: level,
            status: GameStatus.lost,
            lossReason: reason,
            moves: reason == LossReason.moveLimitReached ? 20 : 7,
          ),
          onRetry: () {},
          onNext: () {},
          onBack: () {},
        ),
      ),
    );

    await tester.pumpWidget(card(LossReason.boardStuck));
    await tester.pumpAndSettle();
    expect(find.text('TABULEIRO TRAVADO'), findsOneWidget);
    expect(find.textContaining('Não restam trocas válidas'), findsOneWidget);

    await tester.pumpWidget(card(LossReason.moveLimitReached));
    await tester.pumpAndSettle();
    expect(find.text('MOVIMENTOS ESGOTADOS'), findsOneWidget);
    expect(find.textContaining('Não restam trocas válidas'), findsNothing);
  });

  testWidgets('tentar de novo reinicia a fase', (tester) async {
    const tight = GameLevel(
      number: 45,
      objective: Objective(digit: 9, count: 9),
      moveLimit: 1,
    );
    await pumpGame(tester, level: tight);

    await playSwap(tester, findSwap(creatingMatch: true)!);
    expect(notifier.state.status, GameStatus.lost);

    await tester.tap(find.byKey(const Key('retry_level')));
    await tester.pumpAndSettle();

    expect(notifier.state.status, GameStatus.playing);
    expect(notifier.state.moves, 0);
    expect(find.byKey(const Key('level_outcome')), findsNothing);
  });

  /// A área realmente visível, em pixels lógicos.
  Size viewport(WidgetTester tester) =>
      tester.view.physicalSize / tester.view.devicePixelRatio;

  /// `findsOneWidget` acha widget fora da dobra: um botão empurrado para baixo
  /// do tabuleiro "existe" e passa no teste, mas o jogador não o alcança sem
  /// rolar. Estas asserções olham a posição de verdade.
  void expectOnScreen(WidgetTester tester, Key key) {
    final rect = tester.getRect(find.byKey(key));
    final screen = viewport(tester);

    expect(rect.top, greaterThanOrEqualTo(0.0), reason: '$key acima da tela');
    expect(
      rect.bottom,
      lessThanOrEqualTo(screen.height),
      reason: '$key abaixo da dobra: ${rect.bottom} > ${screen.height}',
    );
    expect(rect.left, greaterThanOrEqualTo(0.0));
    expect(rect.right, lessThanOrEqualTo(screen.width));
  }

  testWidgets('ao vencer, o botão de avançar fica visível na tela', (
    tester,
  ) async {
    // Tela de celular pequeno: é onde o cartão empurrado para baixo do
    // tabuleiro deixava os botões fora da dobra.
    tester.view.physicalSize = const Size(750, 1334);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [gameProvider.overrideWith((ref) => notifier)],
        child: localizedApp(home: GameScreen(level: kCampaign.first)),
      ),
    );
    await tester.pumpAndSettle();

    for (
      int i = 0;
      i < 20 && notifier.state.status == GameStatus.playing;
      i++
    ) {
      final pair = findSwap(creatingMatch: true);
      if (pair == null) break;
      await playSwap(tester, pair);
    }
    expect(notifier.state.status, GameStatus.won);

    expectOnScreen(tester, const Key('next_level'));
    expectOnScreen(tester, const Key('back_to_levels'));
  });

  testWidgets('ao perder, o botão de tentar de novo fica visível na tela', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(750, 1334);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    const tight = GameLevel(
      number: 47,
      objective: Objective(digit: 9, count: 9),
      moveLimit: 1,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [gameProvider.overrideWith((ref) => notifier)],
        child: localizedApp(home: const GameScreen(level: tight)),
      ),
    );
    await tester.pumpAndSettle();

    await playSwap(tester, findSwap(creatingMatch: true)!);
    expect(notifier.state.status, GameStatus.lost);

    expectOnScreen(tester, const Key('retry_level'));
  });

  testWidgets('o contador para de alarmar quando a fase acaba', (tester) async {
    const tight = GameLevel(
      number: 48,
      objective: Objective(digit: 9, count: 9),
      moveLimit: 1,
    );
    await pumpGame(tester, level: tight);

    await playSwap(tester, findSwap(creatingMatch: true)!);
    expect(notifier.state.status, GameStatus.lost);

    // Vermelho significa perigo; com a fase encerrada não há perigo nenhum.
    final counter = tester.widget<Text>(find.byKey(movesLeftKey));
    expect(counter.data, '0');
    expect(
      counter.style?.color,
      isNot(AppColors.digit0),
      reason: 'o contador não deveria seguir vermelho após o fim da fase',
    );
  });

  testWidgets('o contador alarma na reta final, com a fase em andamento', (
    tester,
  ) async {
    // Contraprova do teste acima: o vermelho tem de aparecer quando importa.
    const short = GameLevel(
      number: 49,
      objective: Objective(digit: 9, count: 9),
      moveLimit: 3,
    );
    await pumpGame(tester, level: short);

    final counter = tester.widget<Text>(find.byKey(movesLeftKey));
    expect(counter.data, '3');
    expect(counter.style?.color, AppColors.digit0);
  });

  testWidgets('cabe numa tela pequena sem estourar o layout', (tester) async {
    // Um iPhone SE. A tela empilha banner, tabuleiro 8x8 e cartão de desfecho;
    // é onde um Column sem rolagem estouraria.
    tester.view.physicalSize = const Size(750, 1334);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [gameProvider.overrideWith((ref) => notifier)],
        child: localizedApp(home: const GameScreen(level: roomy)),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(TileWidget), findsNWidgets(64));
  });

  testWidgets('o cartão de desfecho também cabe na tela pequena', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(750, 1334);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    const tight = GameLevel(
      number: 46,
      objective: Objective(digit: 9, count: 9),
      moveLimit: 1,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [gameProvider.overrideWith((ref) => notifier)],
        child: localizedApp(home: const GameScreen(level: tight)),
      ),
    );
    await tester.pumpAndSettle();

    await playSwap(tester, findSwap(creatingMatch: true)!);

    expect(find.byKey(const Key('level_outcome')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vencer libera a fase seguinte na campanha', (tester) async {
    final container = ProviderContainer(
      overrides: [gameProvider.overrideWith((ref) => notifier)],
    );
    addTearDown(container.dispose);

    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(home: GameScreen(level: kCampaign.first)),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(campaignProgressProvider), 0);

    for (
      int i = 0;
      i < 20 && notifier.state.status == GameStatus.playing;
      i++
    ) {
      final pair = findSwap(creatingMatch: true);
      if (pair == null) break;
      await playSwap(tester, pair);
    }

    expect(notifier.state.status, GameStatus.won);
    expect(
      container.read(campaignProgressProvider),
      1,
      reason: 'concluir a fase 1 deveria destravar a fase 2',
    );
  });

  testWidgets('a vitória mostra a barra de estrelas do capítulo', (
    tester,
  ) async {
    // Fase 1 de verdade, do capítulo 1 da campanha (6 fases, 18 estrelas).
    // Objetivo mínimo e limite folgado: cai no primeiro movimento válido,
    // como no teste do cartão de fase concluída.
    const trivial = GameLevel(
      number: 1,
      objective: Objective(digit: 4),
      moveLimit: 30,
    );
    await pumpGame(tester, level: trivial);

    for (
      int i = 0;
      i < 20 && notifier.state.status == GameStatus.playing;
      i++
    ) {
      final pair = findSwap(creatingMatch: true);
      if (pair == null) break;
      await playSwap(tester, pair);
    }

    expect(notifier.state.status, GameStatus.won);
    expect(find.byKey(chapterStarProgressKey), findsOneWidget);

    // O denominador é o total do capítulo 1 (6 fases × 3 estrelas). O
    // numerador depende de quantos movimentos o jogador automático gastou —
    // por isso é calculado com a mesma fórmula da tela (`starRating`), em vez
    // de um valor fixo que oscilaria com a semente aleatória.
    final state = notifier.state;
    final stars = starRating(
      movesLeft: state.movesLeft,
      movesAvailable: state.movesAvailable,
    );
    expect(find.text('$stars/18'), findsOneWidget);
  });

  testWidgets(
    'uma fase fora de qualquer capítulo não quebra a barra de estrelas',
    (tester) async {
      // Fase 43 não existe na campanha nem em nenhum capítulo declarado:
      // `chapterOf` cai no capítulo 2 por fallback. A barra tem de desenhar
      // sem lançar, mesmo que o número não reflita a fase recém-vencida.
      const outOfChapter = GameLevel(
        number: 43,
        objective: Objective(digit: 4),
        moveLimit: 30,
      );
      await pumpGame(tester, level: outOfChapter);

      for (
        int i = 0;
        i < 20 && notifier.state.status == GameStatus.playing;
        i++
      ) {
        final pair = findSwap(creatingMatch: true);
        if (pair == null) break;
        await playSwap(tester, pair);
      }

      expect(notifier.state.status, GameStatus.won);
      expect(find.byKey(chapterStarProgressKey), findsOneWidget);
    },
  );
}
