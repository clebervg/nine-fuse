import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/presentation/widgets/level_outcome_card.dart';
import 'package:nine_fuse/features/game/presentation/widgets/chapter_star_progress.dart';
import 'package:nine_fuse/features/game/providers/game_state.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';
import '../../../support/localized.dart';

void main() {
  const level = GameLevel(
    number: 4,
    objective: Objective(digit: 5, count: 2),
    moveLimit: 20,
  );

  Future<void> pumpCard(
    WidgetTester tester, {
    required GameStatus status,
    LossReason? lossReason,
    int moves = 10,
    int bonusMoves = 0,
    GameLevel target = level,
    int? starsInChapter,
    int? starsGained,
  }) async {
    // Tela de celular pequeno: é onde o cartão precisa caber.
    tester.view.physicalSize = const Size(750, 1334);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        locale: kTestLocale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SingleChildScrollView(
              child: LevelOutcomeCard(
                state: GameState(
                  board: Board.empty(),
                  level: target,
                  status: status,
                  lossReason: lossReason,
                  moves: moves,
                  bonusMoves: bonusMoves,
                ),
                onRetry: () {},
                onNext: () {},
                onBack: () {},
                starsInChapter: starsInChapter,
                starsGained: starsGained,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Conta as estrelas acesas pelo ícone: a fileira sempre desenha três, e a
  /// diferença entre conquistada e vazia é justamente o ícone.
  int earnedStars(WidgetTester tester) => tester
      .widgetList<Icon>(
        find.descendant(of: find.byKey(starsKey), matching: find.byType(Icon)),
      )
      .where((icon) => icon.icon == Icons.star_rounded)
      .length;

  group('vitória', () {
    testWidgets('anuncia a fase concluída e oferece a próxima', (tester) async {
      await pumpCard(tester, status: GameStatus.won, moves: 8);

      expect(find.text('FASE CONCLUÍDA!'), findsOneWidget);
      expect(find.byKey(const Key('next_level')), findsOneWidget);
      expect(find.text('PRÓXIMA FASE'), findsOneWidget);
    });

    testWidgets('o selo mostra as moedas das estrelas novas', (tester) async {
      await pumpCard(
        tester,
        status: GameStatus.won,
        moves: 10,
        starsInChapter: 9,
        starsGained: 3,
      );

      expect(find.byKey(coinRewardKey), findsOneWidget);
      expect(find.text('+${3 * kCoinsPerStar} 🪙'), findsOneWidget);
    });

    testWidgets('sem estrela nova não há selo de moedas', (tester) async {
      // Rejogar uma fase já dominada não paga: um selo "+0 🪙" anunciaria que
      // o jogo esqueceu de pagar.
      await pumpCard(
        tester,
        status: GameStatus.won,
        moves: 10,
        starsInChapter: 9,
        starsGained: 0,
      );

      expect(find.byKey(coinRewardKey), findsNothing);
    });

    testWidgets('sobrando 30% ou mais do saldo, três estrelas', (tester) async {
      // 20 movimentos, gastou 10: sobraram 50%.
      await pumpCard(tester, status: GameStatus.won, moves: 10);

      expect(find.byKey(starsKey), findsOneWidget);
      expect(earnedStars(tester), 3);
    });

    testWidgets('sobrando entre 10% e 30%, duas estrelas', (tester) async {
      // Sobraram 4 de 20, ou 20%.
      await pumpCard(tester, status: GameStatus.won, moves: 16);

      expect(earnedStars(tester), 2);
    });

    testWidgets('vencendo no limite, uma estrela', (tester) async {
      await pumpCard(tester, status: GameStatus.won, moves: 20);

      expect(earnedStars(tester), 1);
    });

    // A fileira desenha sempre três: as vazias mostram o que ficou na mesa.
    testWidgets('a fileira mostra sempre três lugares', (tester) async {
      await pumpCard(tester, status: GameStatus.won, moves: 20);

      final icons = find.descendant(
        of: find.byKey(starsKey),
        matching: find.byType(Icon),
      );
      expect(icons, findsNWidgets(kMaxStars));
    });

    // O bônus de movimentos engorda o saldo restante; se não engordasse também
    // o total, uma explosão viraria estrela de graça.
    testWidgets('o bônus de movimentos entra nos dois lados da conta', (
      tester,
    ) async {
      // 20 + 3 de bônus, gastou 20: sobraram 3 de 23, ou 13%.
      await pumpCard(tester, status: GameStatus.won, moves: 20, bonusMoves: 3);

      expect(earnedStars(tester), 2);
    });

    // A campanha não tem última fase: vencer qualquer uma, inclusive a mais
    // avançada do conteúdo artesanal, sempre oferece a próxima.
    testWidgets('vencer a última fase artesanal ainda oferece a próxima', (
      tester,
    ) async {
      await pumpCard(tester, status: GameStatus.won, target: kCampaign.last);

      expect(find.byKey(const Key('next_level')), findsOneWidget);
    });
  });

  group('derrota', () {
    testWidgets('saldo esgotado tem título e frase próprios', (tester) async {
      await pumpCard(
        tester,
        status: GameStatus.lost,
        lossReason: LossReason.moveLimitReached,
        moves: 20,
      );

      expect(find.text('MOVIMENTOS ESGOTADOS'), findsOneWidget);
      expect(
        find.text('Faltou pouco para alcançar o objetivo!'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('retry_level')), findsOneWidget);
      expect(find.text('TENTAR NOVAMENTE'), findsOneWidget);
    });

    testWidgets('tabuleiro travado tem título e frase próprios', (
      tester,
    ) async {
      await pumpCard(
        tester,
        status: GameStatus.lost,
        lossReason: LossReason.boardStuck,
        moves: 7,
      );

      expect(find.text('TABULEIRO TRAVADO'), findsOneWidget);
      expect(find.text('Não restam trocas válidas!'), findsOneWidget);
    });

    // As duas causas são independentes: perder no limite com o tabuleiro cheio
    // de jogadas não pode anunciar tabuleiro travado.
    testWidgets('as duas derrotas não se confundem', (tester) async {
      await pumpCard(
        tester,
        status: GameStatus.lost,
        lossReason: LossReason.moveLimitReached,
        moves: 20,
      );
      expect(find.text('TABULEIRO TRAVADO'), findsNothing);

      await pumpCard(
        tester,
        status: GameStatus.lost,
        lossReason: LossReason.boardStuck,
        moves: 3,
      );
      expect(find.text('MOVIMENTOS ESGOTADOS'), findsNothing);
    });

    testWidgets('perder não mostra estrelas', (tester) async {
      await pumpCard(
        tester,
        status: GameStatus.lost,
        lossReason: LossReason.boardStuck,
      );

      expect(find.byKey(starsKey), findsNothing);
    });
  });

  group('responsividade', () {
    testWidgets('a vitória cabe num iPhone SE', (tester) async {
      await pumpCard(tester, status: GameStatus.won, moves: 2);

      expect(tester.takeException(), isNull);

      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      final rect = tester.getRect(find.byKey(const Key('level_outcome')));
      expect(rect.left, greaterThanOrEqualTo(0.0));
      expect(rect.right, lessThanOrEqualTo(screen.width));
    });

    testWidgets('a derrota cabe num iPhone SE', (tester) async {
      await pumpCard(
        tester,
        status: GameStatus.lost,
        lossReason: LossReason.moveLimitReached,
        moves: 20,
      );

      expect(tester.takeException(), isNull);
    });

    // Os confetes são decoração: não podem ficar entre o dedo do jogador e o
    // botão de avançar.
    testWidgets('a festa da vitória não intercepta o toque', (tester) async {
      var advanced = 0;

      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          locale: kTestLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: LevelOutcomeCard(
                state: GameState(
                  board: Board.empty(),
                  level: level,
                  status: GameStatus.won,
                  moves: 5,
                ),
                onRetry: () {},
                onNext: () => advanced++,
                onBack: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('next_level')));
      await tester.pumpAndSettle();

      expect(advanced, 1);
    });
  });

  group('barra de estrelas do capítulo', () {
    testWidgets('aparece na vitória quando os números chegam', (tester) async {
      await pumpCard(
        tester,
        status: GameStatus.won,
        starsInChapter: 12,
        starsGained: 3,
      );

      expect(find.byKey(chapterStarProgressKey), findsOneWidget);
      // A fase 4 é do capítulo 1, que tem 6 fases e portanto 18 estrelas.
      expect(find.text('12/18'), findsOneWidget);
    });

    // Os números são opcionais porque seis arquivos de teste constroem este
    // cartão direto; sem eles, o cartão continua sendo o de antes.
    testWidgets('sem os números, não desenha nada', (tester) async {
      await pumpCard(tester, status: GameStatus.won);

      expect(find.byKey(chapterStarProgressKey), findsNothing);
    });

    // Derrota não tem estrela para somar, e a barra ali leria como consolo.
    testWidgets('não aparece na derrota', (tester) async {
      await pumpCard(
        tester,
        status: GameStatus.lost,
        lossReason: LossReason.moveLimitReached,
        starsInChapter: 12,
        starsGained: 0,
      );

      expect(find.byKey(chapterStarProgressKey), findsNothing);
    });
  });
}
