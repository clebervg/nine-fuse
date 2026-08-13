@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/juice_timings.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';
import 'package:nine_fuse/features/game/presentation/widgets/board_grid_widget.dart';
import 'package:nine_fuse/features/game/presentation/widgets/combo_banner.dart';
import 'package:nine_fuse/features/game/presentation/widgets/juice_overlay.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';
import '../../../support/localized.dart';

/// Referência visual dos efeitos de recompensa, congelados no meio da
/// animação.
///
/// Sem isto não há como inspecionar o resultado: os efeitos duram menos de um
/// segundo e só aparecem depois de uma jogada, que uma captura de simulador não
/// consegue disparar.
///
/// Regerar após mudança proposital:
///   flutter test --update-goldens test/features/game/presentation/juice_golden_test.dart
Future<void> _loadNunito() async {
  final loader = FontLoader(AppFonts.display);
  for (final weight in const ['Bold', 'ExtraBold', 'Black']) {
    loader.addFont(rootBundle.load('assets/fonts/Nunito-$weight.ttf'));
  }
  await loader.load();
}

void main() {
  setUpAll(_loadNunito);

  Board boardOf(List<List<int>> values) {
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

  testWidgets('efeitos de fusão sobre o tabuleiro', (tester) async {
    tester.view.physicalSize = const Size(460, 560);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final grid = [
      for (int row = 0; row < Board.boardSize; row++)
        [for (int col = 0; col < Board.boardSize; col++) (row + col) % 4],
    ];

    final step = ResolutionStep(
      cascade: 2,
      fusions: [
        // Uma comum e uma grande, para comparar os dois tratamentos lado a
        // lado.
        FusionEvent(
          consumed: const [Position(row: 2, col: 1)],
          at: const Position(row: 2, col: 1),
          tileId: 'a',
          value: 5,
          matchLength: 3,
          score: 60,
        ),
        FusionEvent(
          consumed: const [Position(row: 4, col: 5)],
          at: const Position(row: 4, col: 5),
          tileId: 'b',
          value: 7,
          matchLength: 5,
          score: 210,
        ),
      ],
      explosionCentres: const [Position(row: 6, col: 2)],
      clearedDigits: const {},
      boardAfterFusion: Board.empty(),
      boardAfterSettle: Board.empty(),
      score: 270,
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: kTestLocale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          textTheme: ThemeData.dark().textTheme.apply(
            fontFamily: AppFonts.display,
          ),
        ),
        home: Scaffold(
          backgroundColor: AppColors.darkBackground,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Stack(
                children: [
                  BoardGridWidget(board: boardOf(grid)),
                  Positioned.fill(
                    child: JuiceOverlay(step: step, comboCount: 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Congela perto do pico. Na metade os efeitos já estão quase apagados, e
    // o golden não mostraria o que o jogador de fato vê.
    await tester.pump(JuiceTimings.impactWave ~/ 4);

    await expectLater(
      find.byType(Stack).first,
      matchesGoldenFile('goldens/juice_fusion.png'),
    );

    await tester.pumpAndSettle();
  });

  testWidgets('aviso de combo', (tester) async {
    tester.view.physicalSize = const Size(460, 240);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Widget host(ResolutionStep? step, int combo) => MaterialApp(
      locale: kTestLocale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        backgroundColor: AppColors.darkBackground,
        body: ComboBanner(step: step, comboCount: combo),
      ),
    );

    final step = ResolutionStep(
      cascade: 3,
      fusions: const [],
      explosionCentres: const [],
      clearedDigits: const {},
      boardAfterFusion: Board.empty(),
      boardAfterSettle: Board.empty(),
      score: 0,
    );

    // O aviso reage à mudança de passo, daí as duas passadas.
    await tester.pumpWidget(host(null, 0));
    await tester.pumpWidget(host(step, 3));
    await tester.pump(JuiceTimings.banner ~/ 3);

    await expectLater(
      find.byType(ComboBanner),
      matchesGoldenFile('goldens/combo_banner.png'),
    );

    await tester.pumpAndSettle();
  });
}
