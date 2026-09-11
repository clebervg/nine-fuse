import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/presentation/widgets/glass_panel.dart';

void main() {
  Future<void> pumpPanel(WidgetTester tester, {Color? tint}) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: GlassPanel(tint: tint, child: const Text('conteúdo')),
        ),
      ),
    ),
  );

  testWidgets('o desfoque fica contido dentro do ClipRRect do painel', (
    tester,
  ) async {
    await pumpPanel(tester);

    // Sem o recorte, o `BackdropFilter` desfoca a árvore inteira por trás
    // dele em vez de só a área do painel — o custo de repaint passaria a
    // escalar com o tamanho da tela, não do painel.
    final blur = find.byKey(glassPanelBlurKey);
    expect(blur, findsOneWidget);
    expect(
      find.ancestor(of: blur, matching: find.byType(ClipRRect)),
      findsOneWidget,
    );

    final filter = tester.widget<BackdropFilter>(blur).filter as ImageFilter;
    expect(filter, isNotNull);
  });

  testWidgets('mostra o conteúdo por cima do vidro', (tester) async {
    await pumpPanel(tester);

    expect(find.text('conteúdo'), findsOneWidget);
  });

  testWidgets('sem tingimento, a borda é neutra (branca translúcida)', (
    tester,
  ) async {
    await pumpPanel(tester);

    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(BackdropFilter),
        matching: find.byType(Container),
      ),
    );
    final border = (container.decoration! as BoxDecoration).border! as Border;

    expect(border.top.color.r, border.top.color.g);
    expect(border.top.color.g, border.top.color.b);
  });

  testWidgets('com tingimento, a borda assume a cor dada', (tester) async {
    await pumpPanel(tester, tint: const Color(0xFFFF0000));

    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(BackdropFilter),
        matching: find.byType(Container),
      ),
    );
    final border = (container.decoration! as BoxDecoration).border! as Border;

    expect(border.top.color.g, 0);
    expect(border.top.color.b, 0);
    expect(border.top.color.r, greaterThan(0));
  });
}
