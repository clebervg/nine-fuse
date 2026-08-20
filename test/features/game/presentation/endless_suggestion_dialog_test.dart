import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/presentation/widgets/endless_suggestion_dialog.dart';
import '../../../support/localized.dart';

void main() {
  testWidgets('mostra o cartão e os dois botões', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(
          body: EndlessSuggestionDialog(
            onGoToEndless: () {},
            onDecline: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(endlessSuggestionKey), findsOneWidget);
    expect(find.byKey(endlessSuggestionGoKey), findsOneWidget);
    expect(find.byKey(endlessSuggestionDeclineKey), findsOneWidget);
  });

  testWidgets('tocar em "ir para o Modo Recorde" chama o callback', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(
          body: EndlessSuggestionDialog(
            onGoToEndless: () => tapped = true,
            onDecline: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(endlessSuggestionGoKey));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('tocar em "continuar tentando" chama o callback', (
    tester,
  ) async {
    var declined = false;
    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(
          body: EndlessSuggestionDialog(
            onGoToEndless: () {},
            onDecline: () => declined = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(endlessSuggestionDeclineKey));
    await tester.pump();

    expect(declined, isTrue);
  });
}
