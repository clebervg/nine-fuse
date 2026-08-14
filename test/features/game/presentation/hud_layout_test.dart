import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/level_catalog.dart';
import 'package:nine_fuse/features/game/presentation/screens/game_screen.dart';
import 'package:nine_fuse/features/game/presentation/widgets/board_grid_widget.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_button.dart';
import 'package:nine_fuse/features/game/presentation/widgets/level_start_dialog.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import '../../../support/localized.dart';

/// Geometria do HUD da fase: o que não pode encostar em quê.
///
/// Mora fora de `game_screen_test` porque não mede comportamento nenhum — mede
/// retângulos. As duas coisas que ele guarda são regressões visuais que nenhum
/// teste de fluxo pega: o título da fase por baixo do entalhe, e o botão do
/// martelo por cima da primeira linha do tabuleiro.
void main() {
  /// Uma fase de capítulo gerado — a mesma que o pedido cita.
  final level = levelAt(21);

  Future<void> pumpGame(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    // Entalhe de verdade: sem `padding` o `SafeArea` não tem o que reservar e o
    // teste passaria sem exercitar nada.
    tester.view.padding = const FakeViewPadding(top: 88, bottom: 68);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameProvider.overrideWith(
            (ref) =>
                GameNotifier(random: Random(21), storage: InMemoryGameStorage()),
          ),
        ],
        child: localizedApp(home: GameScreen(level: level)),
      ),
    );
    await tester.pumpAndSettle();
    if (find.byKey(startLevelKey).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(startLevelKey));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('o título da fase fica abaixo do entalhe', (tester) async {
    await pumpGame(tester);

    final title = tester.getRect(find.text('Fase ${level.number}'));

    expect(title.top, greaterThanOrEqualTo(88));
  });

  testWidgets('o botão do martelo não invade o tabuleiro', (tester) async {
    await pumpGame(tester);

    final button = tester.getRect(find.byKey(hammerButtonKey));
    final board = tester.getRect(find.byType(BoardGridWidget));

    // O botão termina acima do tabuleiro, e com folga para o brilho do disco
    // (`blurRadius` 14) não encostar na primeira linha de células.
    expect(button.bottom, lessThan(board.top));
    expect(board.top - button.bottom, greaterThanOrEqualTo(14));
  });
}
