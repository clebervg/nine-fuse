import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';
import 'package:nine_fuse/features/game/presentation/widgets/tile_widget.dart';
import '../../../support/localized.dart';

/// Squash & stretch: compressão assimétrica ao ser selecionada e na fusão
/// instantânea dos dígitos 1-8.
void main() {
  const at = Position(row: 0, col: 0);

  Widget host(Tile tile, {bool selected = false}) => localizedApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 60,
          height: 60,
          child: TileWidget(tile: tile, side: 60, isSelected: selected),
        ),
      ),
    ),
  );

  /// A escala horizontal do `Transform` de squash, medida via a matriz —
  /// nenhum outro `Transform` na peça deforma os eixos de forma assimétrica
  /// (o `_pop`/`AnimatedScale` são uniformes), então basta achar o primeiro
  /// cujo x e y divergem.
  bool anyAsymmetricTransform(WidgetTester tester) => tester
      .widgetList<Transform>(find.byType(Transform))
      .any((t) {
        final m = t.transform.storage;
        return (m[0] - m[5]).abs() > 0.001;
      });

  testWidgets('a seleção comprime a peça por um instante', (tester) async {
    await tester.pumpWidget(host(const Tile(id: 't4', value: 4, position: at)));
    await tester.pumpAndSettle();
    expect(anyAsymmetricTransform(tester), isFalse);

    await tester.pumpWidget(
      host(const Tile(id: 't4', value: 4, position: at), selected: true),
    );
    await tester.pump(const Duration(milliseconds: 40));

    expect(anyAsymmetricTransform(tester), isTrue);

    await tester.pumpAndSettle();
    expect(anyAsymmetricTransform(tester), isFalse);
  });

  testWidgets('a fusão instantânea de um dígito 1-8 comprime a peça', (
    tester,
  ) async {
    await tester.pumpWidget(host(const Tile(id: 't3', value: 3, position: at)));
    await tester.pumpAndSettle();

    await tester.pumpWidget(host(const Tile(id: 't3', value: 4, position: at)));
    await tester.pump(const Duration(milliseconds: 40));

    expect(anyAsymmetricTransform(tester), isTrue);

    await tester.pumpAndSettle();
  });

  testWidgets('a fusão que produz o dígito 9 não dispara o squash', (
    tester,
  ) async {
    // O 9 recém-nascido ganha o tratamento próprio do ápice — o squash
    // competiria com ele no mesmo instante, sem acrescentar ênfase.
    await tester.pumpWidget(
      host(const Tile(id: 't8', value: kMaxDigit - 1, position: at)),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      host(const Tile(id: 't8', value: kMaxDigit, position: at)),
    );
    await tester.pump(const Duration(milliseconds: 40));

    expect(anyAsymmetricTransform(tester), isFalse);

    await tester.pumpAndSettle();
  });
}
