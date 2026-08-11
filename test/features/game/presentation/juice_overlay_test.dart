import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/juice_timings.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/presentation/widgets/board_geometry.dart';
import 'package:nine_fuse/features/game/presentation/widgets/combo_banner.dart';
import 'package:nine_fuse/features/game/presentation/widgets/juice_overlay.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';
import '../../../support/localized.dart';

/// Monta um passo de cascata à mão, sem passar pelo motor.
ResolutionStep stepWith({
  int cascade = 1,
  List<FusionEvent> fusions = const [],
  List<Position> explosions = const [],
  List<ObstacleHit> obstacleHits = const [],
}) => ResolutionStep(
  cascade: cascade,
  fusions: fusions,
  explosionCentres: explosions,
  clearedByExplosion: const {},
  boardAfterFusion: Board.empty(),
  boardAfterSettle: Board.empty(),
  score: fusions.fold(0, (t, f) => t + f.score),
  obstacleHits: obstacleHits,
);

FusionEvent fusionAt(
  Position at, {
  int value = 5,
  int score = 60,
  int length = 3,
  String? id,
}) => FusionEvent(
  consumed: [at],
  at: at,
  tileId: id ?? 'tile_${at.row}_${at.col}',
  value: value,
  matchLength: length,
  score: score,
);

void main() {
  Widget host(Widget child) => MaterialApp(
    locale: kTestLocale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(child: SizedBox(width: 400, height: 400, child: child)),
    ),
  );

  group('pontuação flutuante', () {
    testWidgets('aparece com o valor da fusão', (tester) async {
      await tester.pumpWidget(
        host(
          JuiceOverlay(
            step: stepWith(fusions: [fusionAt(Position(row: 2, col: 3))]),
            comboCount: 1,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('+60'), findsOneWidget);
    });

    testWidgets('nasce sobre a célula onde a fusão aconteceu', (tester) async {
      const at = Position(row: 1, col: 6);

      await tester.pumpWidget(
        host(
          JuiceOverlay(step: stepWith(fusions: [fusionAt(at)]), comboCount: 1),
        ),
      );
      await tester.pump();

      final geometry = BoardGeometry(availableWidth: 400);
      final expected = geometry.centerOf(at);
      final actual = tester.getCenter(find.text('+60'));
      final overlayOrigin = tester.getTopLeft(find.byType(JuiceOverlay));

      // Tolerância de meia célula: o texto sobe enquanto anima.
      expect(
        (actual.dx - overlayOrigin.dx - expected.dx).abs(),
        lessThan(geometry.tileSize / 2),
        reason: 'a pontuação apareceu longe da célula da fusão',
      );
    });

    testWidgets('sobe e desaparece', (tester) async {
      await tester.pumpWidget(
        host(
          JuiceOverlay(
            step: stepWith(fusions: [fusionAt(Position(row: 4, col: 4))]),
            comboCount: 1,
          ),
        ),
      );
      await tester.pump();

      final start = tester.getCenter(find.text('+60'));
      await tester.pump(JuiceTimings.floatingScore ~/ 2);
      final later = tester.getCenter(find.text('+60'));

      expect(later.dy, lessThan(start.dy), reason: 'deveria estar subindo');

      final opacity = tester
          .widget<Opacity>(
            find.ancestor(of: find.text('+60'), matching: find.byType(Opacity)),
          )
          .opacity;
      await tester.pump(JuiceTimings.floatingScore);
      expect(opacity, lessThanOrEqualTo(1.0));
    });

    testWidgets('uma por fusão', (tester) async {
      await tester.pumpWidget(
        host(
          JuiceOverlay(
            step: stepWith(
              fusions: [
                fusionAt(Position(row: 0, col: 0), score: 30, id: 'a'),
                fusionAt(Position(row: 5, col: 5), score: 90, id: 'b'),
              ],
            ),
            comboCount: 1,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('+30'), findsOneWidget);
      expect(find.text('+90'), findsOneWidget);
    });

    testWidgets('nada aparece fora de uma jogada', (tester) async {
      await tester.pumpWidget(
        host(const JuiceOverlay(step: null, comboCount: 0)),
      );
      await tester.pump();

      expect(find.byKey(floatingScoreKey), findsNothing);
    });

    testWidgets('não intercepta toque', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        host(
          Stack(
            children: [
              GestureDetector(
                onTap: () => tapped = true,
                child: const ColoredBox(
                  color: Colors.transparent,
                  child: SizedBox.expand(),
                ),
              ),
              Positioned.fill(
                child: JuiceOverlay(
                  step: stepWith(fusions: [fusionAt(Position(row: 4, col: 4))]),
                  comboCount: 1,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      // A pontuação nasce sobre o tabuleiro; se capturasse o toque, engoliria
      // a jogada seguinte.
      await tester.tapAt(tester.getCenter(find.text('+60')));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });

  group('aviso central', () {
    Future<void> show(
      WidgetTester tester, {
      required int combo,
      bool big = false,
    }) async {
      // Precisa de duas passadas: o aviso reage à *mudança* de passo.
      await tester.pumpWidget(
        host(const ComboBanner(step: null, comboCount: 0)),
      );
      await tester.pumpWidget(
        host(
          ComboBanner(
            step: stepWith(
              cascade: combo,
              fusions: [
                fusionAt(Position(row: 3, col: 3), length: big ? 5 : 3),
              ],
            ),
            comboCount: combo,
          ),
        ),
      );
      await tester.pump(JuiceTimings.banner ~/ 3);
    }

    testWidgets('combinação grande anuncia super fusão', (tester) async {
      await show(tester, combo: 1, big: true);

      expect(find.text('SUPER FUSÃO!'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('cascata dupla anuncia combo x2', (tester) async {
      await show(tester, combo: 2);

      expect(find.text('COMBO x2!'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('cascata tripla anuncia incrível', (tester) async {
      await show(tester, combo: 3);

      expect(find.text('INCRÍVEL x3!'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('jogada comum não anuncia nada', (tester) async {
      await show(tester, combo: 1);

      expect(find.byKey(comboBannerKey), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('o combo tem prioridade sobre a super fusão', (tester) async {
      // Dois textos disputando o centro da tela cancelam um ao outro; a
      // cascata é o feito mais raro, então é ela que se anuncia.
      await show(tester, combo: 2, big: true);

      expect(find.text('COMBO x2!'), findsOneWidget);
      expect(find.text('SUPER FUSÃO!'), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('some sozinho', (tester) async {
      await show(tester, combo: 2);
      expect(find.text('COMBO x2!'), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.byKey(comboBannerKey), findsNothing);
    });

    testWidgets('não intercepta toque', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        host(
          Stack(
            children: [
              GestureDetector(
                onTap: () => tapped = true,
                child: const ColoredBox(
                  color: Colors.transparent,
                  child: SizedBox.expand(),
                ),
              ),
              const ComboBanner(step: null, comboCount: 0),
            ],
          ),
        ),
      );
      await tester.pumpWidget(
        host(
          Stack(
            children: [
              GestureDetector(
                onTap: () => tapped = true,
                child: const ColoredBox(
                  color: Colors.transparent,
                  child: SizedBox.expand(),
                ),
              ),
              ComboBanner(
                step: stepWith(
                  cascade: 2,
                  fusions: [fusionAt(Position(row: 3, col: 3))],
                ),
                comboCount: 2,
              ),
            ],
          ),
        ),
      );
      await tester.pump(JuiceTimings.banner ~/ 3);

      await tester.tapAt(tester.getCenter(find.text('COMBO x2!')));
      await tester.pump();

      expect(tapped, isTrue);
      await tester.pumpAndSettle();
    });
  });

  group('quebra de obstáculo', () {
    ObstacleHit hit(
      Position at, {
      ObstacleType type = ObstacleType.ice,
      int remaining = 0,
    }) => ObstacleHit(position: at, type: type, remainingHp: remaining);

    testWidgets('cada impacto rende um estilhaço', (tester) async {
      await tester.pumpWidget(
        host(
          JuiceOverlay(
            step: stepWith(
              obstacleHits: [
                hit(const Position(row: 1, col: 1)),
                hit(
                  const Position(row: 4, col: 2),
                  type: ObstacleType.stone,
                  remaining: 2,
                ),
              ],
            ),
            comboCount: 1,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 60));

      expect(find.byType(ObstacleShatter), findsNWidgets(2));
    });

    testWidgets('o estilhaço usa a cor do obstáculo atingido', (tester) async {
      await tester.pumpWidget(
        host(
          JuiceOverlay(
            step: stepWith(
              obstacleHits: [
                hit(
                  const Position(row: 3, col: 3),
                  type: ObstacleType.glass,
                  remaining: 1,
                ),
              ],
            ),
            comboCount: 1,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 60));

      final shatter = tester.widget<ObstacleShatter>(
        find.byType(ObstacleShatter),
      );
      expect(shatter.type, ObstacleType.glass);
      // Trincou, não quebrou: o efeito é mais contido.
      expect(shatter.destroyed, isFalse);
    });

    testWidgets('passo sem obstáculo não desenha estilhaço', (tester) async {
      await tester.pumpWidget(
        host(
          JuiceOverlay(
            step: stepWith(fusions: [fusionAt(const Position(row: 2, col: 2))]),
            comboCount: 1,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 60));

      expect(find.byType(ObstacleShatter), findsNothing);
    });
  });
}
