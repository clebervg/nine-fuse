import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/juice_timings.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';
import 'package:nine_fuse/features/game/presentation/widgets/juice_overlay.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_state.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import '../../../support/localized.dart';

/// Monta um tabuleiro 8x8 a partir de uma matriz de valores.
Board boardFromValues(List<List<int>> values) {
  var board = Board.empty();
  for (int row = 0; row < Board.boardSize; row++) {
    for (int col = 0; col < Board.boardSize; col++) {
      final position = Position(row: row, col: col);
      board = board.updateTile(
        position,
        Tile(id: 'r${row}c$col', value: values[row][col], position: position),
      );
    }
  }
  return board;
}

/// Base sem nenhuma combinação pronta.
List<List<int>> baseGrid() => [
  for (int row = 0; row < Board.boardSize; row++)
    [for (int col = 0; col < Board.boardSize; col++) (row + col) % 3],
];

void main() {
  group('recompensa do dígito máximo', () {
    late MatchEngine engine;

    setUp(() {
      engine = MatchEngine(random: Random(7));
    });

    /// Tabuleiro a uma troca de fundir três peças de [value].
    ///
    /// As três ficam em **L**, não em fila: já alinhadas, o tabuleiro nasceria
    /// com a combinação pronta e a troca seria recusada por não criar nada.
    /// Descer a peça de (3,3) para (4,3) fecha a fila em (4,2)-(4,4).
    Board boardWithTrio(int value) {
      final grid = baseGrid();
      grid[4][2] = value;
      grid[4][4] = value;
      grid[3][3] = value;
      return boardFromValues(grid);
    }

    /// A uma troca de criar o dígito máximo.
    Board boardCreatingMax() => boardWithTrio(kMaxDigit - 1);

    test('criar o dígito máximo produz uma explosão', () {
      final move = engine.tryMove(
        boardCreatingMax(),
        const Position(row: 3, col: 3),
        const Position(row: 4, col: 3),
      );

      final resolution = (move as MoveResolved).resolution;
      expect(resolution.producedDigits, contains(kMaxDigit));
      expect(resolution.explosions, greaterThanOrEqualTo(1));
    });

    test('cada explosão devolve movimentos ao jogador', () async {
      final notifier = GameNotifier(
        random: Random(7),
        storage: InMemoryGameStorage(),
      );
      notifier.startLevel(
        const GameLevel(
          number: 90,
          objective: Objective(digit: kMaxDigit, count: 5),
          moveLimit: 20,
        ),
      );

      // Um tabuleiro montado à mão substitui o sorteado: assim a jogada que
      // cria o 9 é conhecida, em vez de depender da sorte do gerador.
      notifier.debugSetBoard(boardCreatingMax());
      expect(notifier.state.bonusMoves, 0);
      final before = notifier.state.movesAvailable;

      // A troca que fecha o trio de 8 na horizontal.
      notifier.swapTiles(
        const Position(row: 3, col: 3),
        const Position(row: 4, col: 3),
      );

      expect(
        notifier.state.bonusMoves,
        greaterThanOrEqualTo(1),
        reason: 'a explosão deveria ter devolvido movimentos',
      );
      expect(notifier.state.bonusMoves % kExplosionBonusMoves, 0);
      expect(notifier.state.movesAvailable, greaterThan(before));
    });

    // O bônus só serve se chegar a tempo: um 9 criado na jogada que zeraria o
    // contador tem de salvar a fase, não chegar tarde demais.
    test('o bônus da última jogada evita a derrota por saldo', () {
      final notifier = GameNotifier(
        random: Random(7),
        storage: InMemoryGameStorage(),
      );
      notifier.startLevel(
        const GameLevel(
          number: 91,
          objective: Objective(digit: kMaxDigit, count: 9),
          moveLimit: 1,
        ),
      );
      notifier.debugSetBoard(boardCreatingMax());

      notifier.swapTiles(
        const Position(row: 3, col: 3),
        const Position(row: 4, col: 3),
      );

      expect(notifier.state.moves, 1);
      expect(
        notifier.state.status,
        GameStatus.playing,
        reason: 'o movimento-bônus deveria ter mantido a fase viva',
      );
      expect(notifier.state.movesLeft, greaterThan(0));
    });

    test('uma jogada sem explosão não muda o saldo', () {
      final notifier = GameNotifier(
        random: Random(7),
        storage: InMemoryGameStorage(),
      );
      notifier.startLevel(
        const GameLevel(
          number: 92,
          objective: Objective(digit: 5, count: 9),
          moveLimit: 20,
        ),
      );

      // Um valor fora da faixa da base (0-2), para o L não esbarrar em peças
      // iguais já presentes e formar combinação sem querer.
      notifier.debugSetBoard(boardWithTrio(5));

      notifier.swapTiles(
        const Position(row: 3, col: 3),
        const Position(row: 4, col: 3),
      );

      expect(notifier.state.bonusMoves, 0);
      expect(notifier.state.movesAvailable, 20);
    });

    // O retorno tátil é a única coisa aqui que fala com a plataforma. Fica
    // injetado para a suíte não depender de canal nativo — e para dar como
    // verificar que ele acontece.
    test('a explosão dispara o retorno tátil', () async {
      var beats = 0;
      GameNotifier.explosionFeedback = () => beats++;
      JuiceTimings.instantResolution = false;
      addTearDown(() {
        GameNotifier.explosionFeedback = HapticFeedback.heavyImpact;
        JuiceTimings.instantResolution = true;
      });

      final notifier = GameNotifier(
        random: Random(7),
        // Espera de mentira: a encenação avança sem gastar tempo real.
        delay: (_) async {},
        storage: InMemoryGameStorage(),
      );
      notifier.startLevel(
        const GameLevel(
          number: 93,
          objective: Objective(digit: kMaxDigit, count: 9),
          moveLimit: 20,
        ),
      );
      notifier.debugSetBoard(boardCreatingMax());

      notifier.swapTiles(
        const Position(row: 3, col: 3),
        const Position(row: 4, col: 3),
      );
      // Deixa a encenação correr até o fim: são vários `await` em sequência,
      // então um drenar de microtarefas só não basta.
      for (int i = 0; i < 40; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(beats, greaterThanOrEqualTo(1));
    });
  });

  group('aviso de movimentos-bônus', () {
    /// Um passo de cascata com uma explosão, montado à mão: o widget só precisa
    /// dos centros de explosão para decidir o que desenhar.
    ResolutionStep stepWithExplosions(int count) => ResolutionStep(
      cascade: 1,
      fusions: const [],
      explosionCentres: [
        for (int i = 0; i < count; i++) Position(row: 3, col: i),
      ],
      clearedDigits: const {},
      boardAfterFusion: Board.empty(),
      boardAfterSettle: Board.empty(),
      score: 0,
    );

    Future<void> pumpOverlay(WidgetTester tester, ResolutionStep? step) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: kTestLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 360,
              child: JuiceOverlay(step: step, comboCount: 1),
            ),
          ),
        ),
      );
      // Um quadro no meio da animação: no fim ela já está apagada.
      await tester.pump(const Duration(milliseconds: 120));
    }

    testWidgets('anuncia os movimentos ganhos', (tester) async {
      await pumpOverlay(tester, stepWithExplosions(1));

      expect(find.byKey(bonusMovesKey), findsOneWidget);
      expect(find.text('+$kExplosionBonusMoves Movimentos!'), findsOneWidget);

      // Sem isto o widget fica com animação pendente ao fim do teste.
      await tester.pumpAndSettle();
    });

    testWidgets('duas explosões no mesmo passo somam', (tester) async {
      await pumpOverlay(tester, stepWithExplosions(2));

      expect(
        find.text('+${2 * kExplosionBonusMoves} Movimentos!'),
        findsOneWidget,
      );

      await tester.pumpAndSettle();
    });

    testWidgets('jogada sem explosão não anuncia nada', (tester) async {
      await pumpOverlay(tester, stepWithExplosions(0));

      expect(find.byKey(bonusMovesKey), findsNothing);

      await tester.pumpAndSettle();
    });
  });
}
