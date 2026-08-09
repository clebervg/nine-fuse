import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/presentation/widgets/level_banner.dart';
import 'package:nine_fuse/features/game/providers/game_state.dart';
import 'package:nine_fuse/features/game/presentation/l10n_labels.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';
import '../../../support/localized.dart';

void main() {
  // A fase carrega a **identidade** da dica; a frase vem da tradução.
  const teaching = LevelTip.alignThree;
  final teachingText = l10nFor().levelTip(teaching)!;

  const first = GameLevel(
    number: 1,
    objective: Objective(digit: 4),
    moveLimit: 20,
    teaches: teaching,
  );

  const later = GameLevel(
    number: 7,
    objective: Objective(digit: 6),
    moveLimit: 20,
    teaches: teaching,
  );

  Future<void> pumpBanner(WidgetTester tester, GameState state) =>
      tester.pumpWidget(
        MaterialApp(
          locale: kTestLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: LevelBanner(state: state)),
        ),
      );

  /// Quantas estrelas estão acesas no HUD.
  int litStars(WidgetTester tester) => tester
      .widgetList<Icon>(
        find.descendant(
          of: find.byKey(starBarKey),
          matching: find.byType(Icon),
        ),
      )
      .where((icon) => icon.icon == Icons.star_rounded)
      .length;

  group('dica escrita da fase', () {
    testWidgets('aparece na fase 1 antes do primeiro movimento', (
      tester,
    ) async {
      await pumpBanner(tester, GameState(board: Board.empty(), level: first));

      expect(find.text(teachingText), findsOneWidget);
    });

    testWidgets('some depois do primeiro movimento', (tester) async {
      await pumpBanner(
        tester,
        GameState(board: Board.empty(), level: first, moves: 1),
      );
      await tester.pumpAndSettle();

      expect(find.text(teachingText), findsNothing);
    });

    testWidgets('nunca ocupa o HUD fora da fase 1', (tester) async {
      // O cartão de início já mostra a dica em toda fase que tem uma. Repeti-la
      // no HUD custaria espaço permanente para dizer algo que o jogador acabou
      // de ler.
      await pumpBanner(tester, GameState(board: Board.empty(), level: later));

      expect(find.text(teachingText), findsNothing);
    });
  });

  group('barra de estrelas', () {
    testWidgets('começa em três e cai conforme o saldo encolhe', (
      tester,
    ) async {
      await pumpBanner(tester, GameState(board: Board.empty(), level: first));
      expect(litStars(tester), 3);

      // 20 movimentos de limite: 15 gastos deixam 25% de folga (duas
      // estrelas), 19 deixam 5% (uma).
      await pumpBanner(
        tester,
        GameState(board: Board.empty(), level: first, moves: 15),
      );
      expect(litStars(tester), 2);

      await pumpBanner(
        tester,
        GameState(board: Board.empty(), level: first, moves: 19),
      );
      expect(litStars(tester), 1);
    });
  });

  group('placar', () {
    testWidgets('mora no HUD, não no rodapé', (tester) async {
      await pumpBanner(
        tester,
        GameState(board: Board.empty(), level: first, score: 1240),
      );

      expect(find.byKey(hudScoreKey), findsOneWidget);
      expect(find.text('1240 pts'), findsOneWidget);
    });
  });

  group('urgência dos movimentos', () {
    testWidgets('o pulso da reta final termina sozinho', (tester) async {
      // O ponto do teste não é o tamanho do salto e sim que ele **acaba**: uma
      // animação em repetição faria `pumpAndSettle` rodar para sempre e
      // derrubaria toda a suíte de widget, não só este teste.
      await pumpBanner(
        tester,
        GameState(
          board: Board.empty(),
          level: first,
          moves: first.moveLimit - kUrgentMovesLeft,
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(movesLeftKey), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(movesLeftKey)).style?.color,
        isNot(Colors.white),
        reason: 'a reta final deveria colorir o contador',
      );
    });

    testWidgets('com a fase acabada o contador não alarma', (tester) async {
      await pumpBanner(
        tester,
        GameState(
          board: Board.empty(),
          level: first,
          moves: first.moveLimit - 1,
          status: GameStatus.won,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(movesLeftKey)).style?.color,
        Colors.white,
      );
    });
  });
}
