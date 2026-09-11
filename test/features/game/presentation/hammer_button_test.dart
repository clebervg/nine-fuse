import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_button.dart';
import '../../../support/localized.dart';

/// O dock de boosters: Martelo, Bomba e Pincel já funcionam.
void main() {
  Future<void> pumpDock(
    WidgetTester tester, {
    bool targeting = false,
    bool bombTargeting = false,
    int bombCount = 2,
    bool brushTargeting = false,
    int brushCount = 2,
  }) => tester.pumpWidget(
    localizedApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: HammerBar(
            targeting: targeting,
            count: 2,
            onPressed: () {},
            buttonKey: hammerButtonKey,
            bombTargeting: bombTargeting,
            bombCount: bombCount,
            onBombPressed: () {},
            bombButtonKey: bombButtonKey,
            brushTargeting: brushTargeting,
            brushCount: brushCount,
            onBrushPressed: () {},
            brushButtonKey: brushButtonKey,
          ),
        ),
      ),
    ),
  );

  testWidgets('o dock mostra os slots do Martelo, da Bomba e do Pincel', (
    tester,
  ) async {
    await pumpDock(tester);

    expect(find.byKey(hammerButtonKey), findsOneWidget);
    expect(find.byKey(bombButtonKey), findsOneWidget);
    expect(find.byKey(brushButtonKey), findsOneWidget);
  });

  testWidgets(
    'com os sprites de booster em disco, os três slots desenham a imagem',
    (tester) async {
      // `ic_hammer.png`, `ic_bomb.png` e `ic_brush.png` já foram produzidos e
      // estão em `assets/images/`: os três slots caem no sprite, não mais no
      // ícone Material de fallback.
      await pumpDock(tester);
      await tester.pumpAndSettle();

      for (final key in [hammerButtonKey, bombButtonKey, brushButtonKey]) {
        expect(
          find.descendant(of: find.byKey(key), matching: find.byType(Image)),
          findsOneWidget,
          reason: '$key devia estar desenhando o sprite',
        );
      }
    },
  );

  testWidgets('o Martelo continua funcional e some da mira quando desligado', (
    tester,
  ) async {
    var pressed = false;
    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(
          body: HammerBar(
            targeting: false,
            count: 2,
            onPressed: () => pressed = true,
            buttonKey: hammerButtonKey,
            bombTargeting: false,
            bombCount: 2,
            onBombPressed: () {},
            bombButtonKey: bombButtonKey,
            brushTargeting: false,
            brushCount: 2,
            onBrushPressed: () {},
            brushButtonKey: brushButtonKey,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(hammerButtonKey));
    expect(pressed, isTrue);
  });

  testWidgets('a Bomba dispara o callback ao ser tocada', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(
          body: HammerBar(
            targeting: false,
            count: 2,
            onPressed: () {},
            buttonKey: hammerButtonKey,
            bombTargeting: false,
            bombCount: 2,
            onBombPressed: () => pressed = true,
            bombButtonKey: bombButtonKey,
            brushTargeting: false,
            brushCount: 2,
            onBrushPressed: () {},
            brushButtonKey: brushButtonKey,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(bombButtonKey));
    expect(pressed, isTrue);
  });

  testWidgets('o Pincel dispara o callback ao ser tocado', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(
          body: HammerBar(
            targeting: false,
            count: 2,
            onPressed: () {},
            buttonKey: hammerButtonKey,
            bombTargeting: false,
            bombCount: 2,
            onBombPressed: () {},
            bombButtonKey: bombButtonKey,
            brushTargeting: false,
            brushCount: 2,
            onBrushPressed: () => pressed = true,
            brushButtonKey: brushButtonKey,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(brushButtonKey));
    expect(pressed, isTrue);
  });

  testWidgets('a Bomba em mira mostra o X e o badge some', (tester) async {
    await pumpDock(tester, bombTargeting: true);

    expect(
      find.descendant(
        of: find.byKey(bombButtonKey),
        matching: find.byIcon(Icons.close_rounded),
      ),
      findsOneWidget,
    );
    expect(find.byKey(bombBadgeKey), findsNothing);
  });

  testWidgets('o Pincel em mira mostra o X e o badge some', (tester) async {
    await pumpDock(tester, brushTargeting: true);

    expect(
      find.descendant(
        of: find.byKey(brushButtonKey),
        matching: find.byIcon(Icons.close_rounded),
      ),
      findsOneWidget,
    );
    expect(find.byKey(brushBadgeKey), findsNothing);
  });

  testWidgets('estoque zero da Bomba mostra 0, não +', (tester) async {
    await pumpDock(tester, bombCount: 0);

    expect(
      find.descendant(
        of: find.byKey(bombBadgeKey),
        matching: find.text('0'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byKey(bombBadgeKey), matching: find.text('+')),
      findsNothing,
    );
  });

  testWidgets('estoque zero do Pincel mostra 0, não +', (tester) async {
    await pumpDock(tester, brushCount: 0);

    expect(
      find.descendant(
        of: find.byKey(brushBadgeKey),
        matching: find.text('0'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byKey(brushBadgeKey), matching: find.text('+')),
      findsNothing,
    );
  });
}
