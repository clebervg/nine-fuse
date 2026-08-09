@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';
import 'package:nine_fuse/features/game/presentation/widgets/board_grid_widget.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';
import '../../../support/localized.dart';

/// Referência visual do tabuleiro.
///
/// Serve a dois propósitos: deixar o acabamento inspecionável sem precisar de
/// aparelho, e travar regressão — mexer em sombra, degradê ou raio de canto
/// sem querer passa a falhar aqui.
///
/// Regerar após mudança visual proposital:
///   flutter test --update-goldens test/features/game/presentation/board_golden_test.dart
/// Carrega a Nunito de verdade no ambiente de teste.
///
/// Sem isto o Flutter desenha cada glifo como um retângulo cheio, e o golden
/// vira uma grade de blocos — inútil para julgar legibilidade, que é
/// justamente o que se quer olhar num jogo de números.
Future<void> _loadNunito() async {
  final loader = FontLoader(AppFonts.display);
  for (final weight in const ['Bold', 'ExtraBold', 'Black']) {
    loader.addFont(rootBundle.load('assets/fonts/Nunito-$weight.ttf'));
  }
  await loader.load();
}

void main() {
  setUpAll(_loadNunito);

  testWidgets('tabuleiro com a paleta inteira', (tester) async {
    tester.view.physicalSize = const Size(440, 500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Um de cada dígito, para conferir contraste e legibilidade em toda a
    // paleta — inclusive o 9, que tem tratamento próprio.
    var board = Board.empty();
    for (int row = 0; row < Board.boardSize; row++) {
      for (int col = 0; col < Board.boardSize; col++) {
        final position = Position(row: row, col: col);
        board = board.updateTile(
          position,
          Tile(
            id: 'r${row}c$col',
            value: (row * Board.boardSize + col) % 10,
            position: position,
          ),
        );
      }
    }

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
              padding: const EdgeInsets.all(20),
              child: BoardGridWidget(
                board: board,
                selectedTile: board.getTileAt(Position(row: 2, col: 2)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(BoardGridWidget),
      matchesGoldenFile('goldens/board.png'),
    );
  });
}
