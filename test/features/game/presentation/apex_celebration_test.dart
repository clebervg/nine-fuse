import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/presentation/screens/endless_screen.dart';
import 'package:nine_fuse/core/juice_timings.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';
import 'package:nine_fuse/features/game/presentation/widgets/apex_celebration.dart';
import 'package:nine_fuse/features/game/providers/endless_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';
import '../../../support/localized.dart';

/// Monta um tabuleiro 8x8 a partir de uma matriz de valores.
Board _boardFromValues(List<List<int>> values) {
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

/// A uma troca de fundir três peças de [value] — em **L**, não em fila: já
/// alinhadas, o tabuleiro nasceria com a combinação pronta e a troca seria
/// recusada por não criar nada.
Board _boardWithTrio(int value) {
  final grid = [
    for (int row = 0; row < Board.boardSize; row++)
      [for (int col = 0; col < Board.boardSize; col++) (row + col) % 3],
  ];
  grid[4][2] = value;
  grid[4][4] = value;
  grid[3][3] = value;
  return _boardFromValues(grid);
}

/// A troca que fecha a fila.
void _playTrio(void Function(Position, Position) swap) =>
    swap(const Position(row: 3, col: 3), const Position(row: 4, col: 3));

void main() {
  group('sinal de fusão máxima na campanha', () {
    GameNotifier notifierAt(Board board, {int objective = 9}) {
      final notifier = GameNotifier(random: Random(7));
      notifier.startLevel(
        GameLevel(
          number: 95,
          objective: Objective(digit: kMaxDigit, count: objective),
          moveLimit: 20,
        ),
      );
      notifier.debugSetBoard(board);
      return notifier;
    }

    test('uma partida nova não começa comemorando', () {
      expect(notifierAt(_boardWithTrio(3)).state.apexCelebrated, isFalse);
    });

    test('criar o dígito máximo acende o sinal', () {
      final notifier = notifierAt(_boardWithTrio(kMaxDigit - 1));
      _playTrio(notifier.swapTiles);

      expect(notifier.state.apexCelebrated, isTrue);
    });

    test('uma jogada comum não acende nada', () {
      final notifier = notifierAt(_boardWithTrio(5));
      _playTrio(notifier.swapTiles);

      expect(notifier.state.apexCelebrated, isFalse);
    });

    test('recomeçar a fase apaga o sinal', () {
      // Sem isto a comemoração seria uma vez por *aparelho*, não por partida:
      // o sinal nunca desliga durante a corrida, de propósito.
      final notifier = notifierAt(_boardWithTrio(kMaxDigit - 1));
      _playTrio(notifier.swapTiles);
      expect(notifier.state.apexCelebrated, isTrue);

      notifier.restartLevel();

      expect(notifier.state.apexCelebrated, isFalse);
    });
  });

  group('sinal e batida no Endless', () {
    test('a explosão dispara o retorno tátil também no Endless', () async {
      // Antes só a campanha vibrava: no Endless, onde o dígito máximo é ainda
      // mais raro, o clímax passava em silêncio.
      var beats = 0;
      EndlessNotifier.explosionFeedback = () => beats++;
      JuiceTimings.instantResolution = false;
      addTearDown(() {
        EndlessNotifier.explosionFeedback = HapticFeedback.heavyImpact;
        JuiceTimings.instantResolution = true;
      });

      final notifier = EndlessNotifier(
        random: Random(7),
        storage: InMemoryGameStorage(),
        // Espera de mentira: a encenação avança sem gastar tempo real.
        delay: (_) async {},
      );
      await notifier.start();
      notifier.debugSetBoard(_boardWithTrio(kMaxDigit - 1));

      _playTrio(notifier.swapTiles);
      // São vários `await` em sequência: um drenar de microtarefas não basta.
      for (int i = 0; i < 40; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(beats, greaterThanOrEqualTo(1));
      expect(notifier.state.apexCelebrated, isTrue);
    });
  });

  group('o aviso do Endless não se repete a cada jogada', () {
    testWidgets('a comemoração é a mesma depois de outras jogadas', (
      tester,
    ) async {
      // O sinal `apexCelebrated` nunca desliga durante a corrida, de propósito.
      // Se a chave do aviso variar com algo que muda a cada jogada (era
      // `state.moves`), o widget é reconstruído do zero a cada movimento e a
      // comemoração toca de novo para sempre — o relato do jogador.
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final notifier = EndlessNotifier(
        random: Random(7),
        storage: InMemoryGameStorage(),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [endlessProvider.overrideWith((ref) => notifier)],
          child: localizedApp(home: const EndlessScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      notifier.debugSetBoard(_boardWithTrio(kMaxDigit - 1));
      _playTrio(notifier.swapTiles);
      await tester.pump();

      expect(find.byType(ApexCelebration), findsOneWidget);
      final celebration = tester.state(find.byType(ApexCelebration));

      // Deixa a comemoração terminar e joga mais algumas vezes.
      await tester.pump(kApexCelebrationDuration);
      final engine = notifier.engine!;
      for (int i = 0; i < 3; i++) {
        final board = notifier.state.board;
        for (final (a, b) in engine.candidateSwaps(board)) {
          if (engine.swapCreatesMatch(board, a, b)) {
            notifier.swapTiles(a, b);
            break;
          }
        }
        await tester.pump();
      }

      expect(
        tester.state(find.byType(ApexCelebration)),
        same(celebration),
        reason: 'a comemoração foi remontada e tocou de novo',
      );

      await tester.pumpAndSettle();
    });
  });

  group('aviso de fusão máxima', () {
    testWidgets('anuncia a conquista e some sozinho', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: kTestLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ApexCelebration()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(apexCelebrationKey), findsOneWidget);
      expect(find.textContaining('FUSÃO MÁXIMA'), findsOneWidget);

      // Termina sozinho: em repetição, `pumpAndSettle` nunca voltaria.
      await tester.pumpAndSettle();
    });

    testWidgets('não intercepta o toque do jogador', (tester) async {
      // A próxima jogada acontece por baixo do aviso — um `SnackBar` roubaria
      // o foco e empurraria o tabuleiro justamente no quadro da explosão.
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: kTestLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(child: GestureDetector(onTap: () => taps++)),
                const Positioned.fill(child: ApexCelebration()),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(apexCelebrationKey), warnIfMissed: false);
      expect(taps, 1);

      await tester.pumpAndSettle();
    });
  });
}
