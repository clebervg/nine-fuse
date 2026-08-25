import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/widgets/floating_text.dart';

void main() {
  Widget hostWith(WidgetBuilder builder) =>
      MaterialApp(home: Builder(builder: builder));

  testWidgets('nasce na posição informada com o texto e escala inicial 0.5', (
    tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      hostWith((context) {
        ctx = context;
        return const SizedBox.expand();
      }),
    );

    showFloatingText(ctx, '+100', position: const Offset(120, 240));
    await tester.pump();

    expect(find.text('+100'), findsOneWidget);

    final positioned = tester.widget<Positioned>(
      find
          .ancestor(of: find.text('+100'), matching: find.byType(Positioned))
          .first,
    );
    expect(positioned.left, 120);
    expect(positioned.top, 240);

    final transforms = tester
        .widgetList<Transform>(
          find.ancestor(
            of: find.text('+100'),
            matching: find.byType(Transform),
          ),
        )
        .toList();
    final scale = transforms
        .map((w) => w.transform.storage[0])
        .firstWhere((s) => (s - 1.0).abs() > 0.001);
    expect(scale, closeTo(0.5, 0.01));
  });

  testWidgets('isCritical aplica cor diferente do padrão', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      hostWith((context) {
        ctx = context;
        return const SizedBox.expand();
      }),
    );

    showFloatingText(
      ctx,
      '+250',
      position: Offset.zero,
      isCritical: true,
    );
    await tester.pump();

    final text = tester.widget<Text>(find.text('+250'));
    final shadowColor = text.style!.shadows!.first.color;
    expect(shadowColor, isNot(AppColors.digit3));
  });

  testWidgets('opacidade some no fim e o overlay se autodestrói', (
    tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      hostWith((context) {
        ctx = context;
        return const SizedBox.expand();
      }),
    );

    showFloatingText(ctx, '+10', position: Offset.zero);
    await tester.pump();

    expect(find.text('+10'), findsOneWidget);

    // Meio da animação: ainda visível.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('+10'), findsOneWidget);

    final opacityMid = tester
        .widget<Opacity>(
          find
              .ancestor(of: find.text('+10'), matching: find.byType(Opacity))
              .first,
        )
        .opacity;
    expect(opacityMid, closeTo(1.0, 0.001));

    // Fim da animação: some e o OverlayEntry é removido.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('+10'), findsNothing);
  });
}
