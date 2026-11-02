import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/level_catalog.dart';
import 'package:nine_fuse/features/game/presentation/screens/game_screen.dart';
import 'package:nine_fuse/features/game/presentation/widgets/board_grid_widget.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_button.dart';
import 'package:nine_fuse/features/game/presentation/widgets/level_banner.dart';
import 'package:nine_fuse/features/game/presentation/widgets/level_start_dialog.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import '../../../support/localized.dart';

/// Geometria do HUD da fase: o que não pode encostar em quê.
///
/// Mora fora de `game_screen_test` porque não mede comportamento nenhum — mede
/// retângulos. As duas coisas que ele guarda são regressões visuais que nenhum
/// teste de fluxo pega: o título da fase por baixo do entalhe, e o dock de
/// boosters invadindo o tabuleiro ou a área segura de baixo.
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
            (ref) => GameNotifier(
              random: Random(21),
              storage: InMemoryGameStorage(),
            ),
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

    final title = tester.getRect(find.text('FASE ${level.number}'));

    expect(title.top, greaterThanOrEqualTo(88));
  });

  testWidgets('o dock fica abaixo do tabuleiro, sem invadi-lo', (tester) async {
    await pumpGame(tester);

    final button = tester.getRect(find.byKey(hammerButtonKey));
    final board = tester.getRect(find.byType(BoardGridWidget));
    final hud = tester.getRect(find.byType(LevelBanner));

    // O dock mora embaixo, no alcance do polegar, e com folga para a base 3D
    // da moldura de ouro (10pt) e os rebites não encostarem nos discos.
    expect(button.top, greaterThan(board.bottom));
    expect(button.top - board.bottom, greaterThanOrEqualTo(14));
    // E continua fora do card de métricas, que fica acima do tabuleiro.
    expect(hud.bottom, lessThan(board.top));
  });

  testWidgets('o dock assenta acima da área segura de baixo', (tester) async {
    await pumpGame(tester);

    final dock = tester.getRect(find.byKey(boosterDockKey));
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;

    // 68pt de entalhe embaixo (ver `pumpGame`) mais a margem mínima de 16pt.
    expect(dock.bottom, lessThanOrEqualTo(screen.height - 68 - 16));
  });
}
