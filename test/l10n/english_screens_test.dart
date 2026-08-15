import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/campaign_chapter.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/presentation/widgets/apex_celebration.dart';
import 'package:nine_fuse/features/game/presentation/widgets/campaign_header.dart';
import 'package:nine_fuse/features/game/presentation/widgets/endless_banner.dart';
import 'package:nine_fuse/features/game/presentation/widgets/endless_highlight.dart';
import 'package:nine_fuse/features/game/presentation/widgets/endless_outcome_card.dart';
import 'package:nine_fuse/features/game/presentation/widgets/level_banner.dart';
import 'package:nine_fuse/features/game/presentation/widgets/level_outcome_card.dart';
import 'package:nine_fuse/features/game/presentation/widgets/level_start_dialog.dart';
import 'package:nine_fuse/features/game/domain/endless_progression.dart';
import 'package:nine_fuse/features/game/providers/endless_state.dart';
import 'package:nine_fuse/features/game/providers/game_state.dart';

import '../support/localized.dart';

/// As telas sob o locale `en`.
///
/// O resto da suíte roda em português — é lá que as asserções de texto vivem.
/// Aqui a pergunta é outra: **o inglês chega à tela**. Um literal esquecido em
/// algum widget passaria despercebido em toda a suíte, porque em português ele
/// é indistinguível de uma frase traduzida.
///
/// Por isso quase toda asserção vem em par: o texto inglês aparece **e** o
/// português não. Só a primeira metade deixaria passar um widget que mostrasse
/// os dois.
void main() {
  const level = GameLevel(
    number: 4,
    objective: Objective(digit: 5, count: 2),
    moveLimit: 20,
    teaches: LevelTip.zeroStopped,
  );

  Future<void> pumpEn(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    // O `ProviderScope` entra porque estes cartões podem hospedar widgets que
    // leem providers (a pílula de saldo, por exemplo, quando montada na
    // AppBar da tela real). Sem overrides: em produção estas telas sempre
    // nascem sob um escopo, e o padrão da carteira é saldo zero.
    await tester.pumpWidget(
      ProviderScope(
        child: localizedApp(
          locale: kTestLocaleEn,
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('HUD da campanha', () {
    testWidgets('rótulos e objetivo saem em inglês', (tester) async {
      await pumpEn(
        tester,
        LevelBanner(
          state: GameState(board: Board.empty(), level: level, score: 120),
        ),
      );

      expect(find.text('GOAL'), findsOneWidget);
      expect(find.text('POINTS'), findsOneWidget);
      expect(find.text('MOVES'), findsOneWidget);
      expect(find.text('120 pts'), findsOneWidget);
      expect(find.text('0 of 2'), findsOneWidget);
      expect(find.text('Create 2 5 tiles'), findsOneWidget);

      expect(find.text('OBJETIVO'), findsNothing);
      expect(find.text('JOGADAS'), findsNothing);
    });
  });

  group('cartão de início de fase', () {
    testWidgets('objetivo, orçamento e dica saem em inglês', (tester) async {
      await pumpEn(tester, LevelStartDialog(level: level, onPlay: () {}));

      expect(find.text('Level 4'), findsOneWidget);
      expect(find.text('Create 2 5 tiles'), findsOneWidget);
      expect(find.text('20 Moves'), findsOneWidget);
      expect(find.text('PLAY'), findsOneWidget);
      expect(find.text(l10nFor(kTestLocaleEn).tipZeroStopped), findsOneWidget);

      expect(find.text('JOGAR'), findsNothing);
      expect(find.textContaining('Movimentos'), findsNothing);
    });

    testWidgets('o orçamento de um movimento usa o singular', (tester) async {
      const single = GameLevel(
        number: 1,
        objective: Objective(digit: 4),
        moveLimit: 1,
      );

      await pumpEn(tester, LevelStartDialog(level: single, onPlay: () {}));

      // O plural mora no ICU do ARB: "1 Move", não "1 Moves". Concatenar um
      // "s" em Dart daria a forma errada aqui e continuaria certa em português.
      expect(find.text('1 Move'), findsOneWidget);
    });
  });

  group('cartão de fim de fase', () {
    Widget card({
      required GameStatus status,
      LossReason? reason,
      int moves = 8,
      int? starsInChapter,
      int? starsGained,
    }) => LevelOutcomeCard(
      state: GameState(
        board: Board.empty(),
        level: level,
        status: status,
        lossReason: reason,
        moves: moves,
      ),
      onRetry: () {},
      onNext: () {},
      onBack: () {},
      starsInChapter: starsInChapter,
      starsGained: starsGained,
    );

    testWidgets('vitória', (tester) async {
      await pumpEn(tester, card(status: GameStatus.won));

      expect(find.text('LEVEL COMPLETED!'), findsOneWidget);
      expect(find.text('Goal reached in 8 moves.'), findsOneWidget);
      expect(find.text('NEXT LEVEL'), findsOneWidget);
      expect(find.text('FASE CONCLUÍDA!'), findsNothing);
    });

    // As duas derrotas continuam com títulos distintos depois de traduzidas —
    // é a regra que originou o relato de falso fim de jogo, e ela não pode se
    // perder num idioma só porque as duas frases foram parar no mesmo arquivo.
    testWidgets('derrota por saldo de movimentos', (tester) async {
      await pumpEn(
        tester,
        card(status: GameStatus.lost, reason: LossReason.moveLimitReached),
      );

      expect(find.text('OUT OF MOVES'), findsOneWidget);
      expect(find.textContaining('the board still had plays'), findsOneWidget);
      expect(find.text('BOARD STUCK'), findsNothing);
      expect(find.textContaining('No valid swaps left'), findsNothing);
    });

    testWidgets('derrota por tabuleiro travado', (tester) async {
      await pumpEn(
        tester,
        card(status: GameStatus.lost, reason: LossReason.boardStuck),
      );

      expect(find.text('BOARD STUCK'), findsOneWidget);
      expect(find.text('No valid swaps left!'), findsOneWidget);
      expect(find.text('OUT OF MOVES'), findsNothing);
      expect(find.textContaining('the board still had plays'), findsNothing);
    });

    // As asserções vêm em par: o texto inglês aparece **e** o português não.
    // Só a primeira metade deixaria passar um widget que mostrasse os dois.
    testWidgets('barra de capítulo em inglês', (tester) async {
      await pumpEn(
        tester,
        card(status: GameStatus.won, starsInChapter: 12, starsGained: 3),
      );

      expect(find.text('Chapter 1: Primary Fusions'), findsOneWidget);
      expect(find.text('Capítulo 1: Fusões Primárias'), findsNothing);
    });
  });

  group('Modo Recorde', () {
    testWidgets('o HUD usa termos inequívocos em inglês', (tester) async {
      await pumpEn(
        tester,
        EndlessBanner(
          state: EndlessState(board: Board.empty(), score: 90),
          highScore: 400,
          progression: const EndlessProgression(),
        ),
      );

      expect(find.text('Points'), findsOneWidget);
      expect(find.text('Best'), findsOneWidget);
      expect(find.text('Best Tile'), findsOneWidget);
      expect(find.text('Next band: create a'), findsOneWidget);

      expect(find.text('Pontos'), findsNothing);
      expect(find.text('Maior Bloco'), findsNothing);
    });

    testWidgets('o cartão de fim de jogo sai em inglês', (tester) async {
      await pumpEn(
        tester,
        EndlessOutcomeCard(
          state: EndlessState(board: Board.empty(), score: 90, moves: 30),
          highScore: 400,
          onRestart: () {},
          onBack: () {},
        ),
      );

      expect(find.text('Out of Moves!'), findsOneWidget);
      expect(find.text("You've run out of moves. Keep going?"), findsOneWidget);
      expect(find.text('New run'), findsOneWidget);
      expect(find.text('Back to menu'), findsOneWidget);
      expect(find.text('Sem Movimentos!'), findsNothing);
    });

    // "Endless" é termo de código e não pode vazar para a tela em nenhum dos
    // dois idiomas — em português o jogador lê "Modo Recorde"; em inglês,
    // "High Score Mode".
    testWidgets('a ilha do mapa nunca mostra "Endless"', (tester) async {
      await pumpEn(
        tester,
        EndlessHighlight(
          isUnlocked: true,
          unlockedAt: 5,
          highScore: 400,
          onTap: () {},
        ),
      );

      expect(find.textContaining('High Score Mode'), findsOneWidget);
      expect(find.text('Your best score: 400 pts'), findsOneWidget);
      expect(find.text('Beat Record'), findsOneWidget);
      expect(find.textContaining('Endless'), findsNothing);
    });

    testWidgets('travada, explica como liberar', (tester) async {
      await pumpEn(
        tester,
        const EndlessHighlight(
          isUnlocked: false,
          unlockedAt: 5,
          highScore: 0,
          onTap: _noop,
        ),
      );

      expect(find.text('Clear level 5 to unlock'), findsOneWidget);
    });
  });

  group('cabeçalho do mapa', () {
    testWidgets('o capítulo sai em inglês', (tester) async {
      await pumpEn(
        tester,
        CampaignHeader(
          chapter: kChapters.first,
          totalStars: 4,
          starTotal: kChapters.first.starTotal,
        ),
      );

      expect(find.text('Chapter 1: Primary Fusions'), findsOneWidget);
      expect(find.text('Capítulo 1: Fusões Primárias'), findsNothing);
    });
  });

  group('comemoração de fusão máxima', () {
    testWidgets('a pílula sai em inglês', (tester) async {
      await pumpEn(
        tester,
        const SizedBox(height: 300, child: ApexCelebration()),
      );

      expect(find.text('MAXIMUM FUSION! 🎉'), findsOneWidget);
      expect(find.textContaining('FUSÃO MÁXIMA'), findsNothing);
    });
  });
}

void _noop() {}
