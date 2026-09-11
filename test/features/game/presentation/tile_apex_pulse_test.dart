import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/assets/tile_sprite_manager.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';
import 'package:nine_fuse/features/game/presentation/widgets/tile_widget.dart';
import '../../../support/localized.dart';

/// A respiração contínua do Bloco 9 em repouso.
///
/// `debugDisableApexPulse` fica ligado para a suíte inteira (ver
/// `test/flutter_test_config.dart`) pelo mesmo motivo do pulso do pin do
/// mapa: uma animação em repetição derruba `pumpAndSettle`. Este arquivo
/// desliga o flag caso a caso, e sempre o restaura no `tearDown` — nunca com
/// `pumpAndSettle` de uma peça pulsando.
void main() {
  setUp(TileSpriteManager.clearCache);
  tearDown(() {
    debugDisableApexPulse = true;
    TileSpriteManager.clearCache();
  });

  const at = Position(row: 0, col: 0);

  Widget host(Tile tile) => localizedApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(width: 60, height: 60, child: TileWidget(tile: tile, side: 60)),
      ),
    ),
  );

  testWidgets('sem o debug flag, o Bloco 9 escala continuamente', (
    tester,
  ) async {
    debugDisableApexPulse = false;

    await tester.pumpWidget(
      host(const Tile(id: 't9', value: kMaxDigit, position: at)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final early = tester
        .widgetList<Transform>(find.byType(Transform))
        .map((w) => w.transform.getMaxScaleOnAxis())
        .reduce((a, b) => a > b ? a : b);

    await tester.pump(const Duration(milliseconds: 500));

    final later = tester
        .widgetList<Transform>(find.byType(Transform))
        .map((w) => w.transform.getMaxScaleOnAxis())
        .reduce((a, b) => a > b ? a : b);

    // Não afirma a fase exata do ciclo — só que a escala **mudou** ao longo
    // do tempo, o que só acontece com o controlador de fato rodando.
    expect(early, isNot(closeTo(later, 0.0001)));
  });

  testWidgets('com o debug flag (padrão da suíte), a peça não pulsa', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const Tile(id: 't9', value: kMaxDigit, position: at)),
    );
    // Sem o pulso, isto não trava: a suíte inteira já depende disso.
    await tester.pumpAndSettle();

    expect(find.text('9'), findsWidgets);
  });

  testWidgets('dígito comum não pulsa', (tester) async {
    debugDisableApexPulse = false;

    await tester.pumpWidget(host(const Tile(id: 't4', value: 4, position: at)));
    // Sem pulso nenhum ativo, isto termina sozinho mesmo com o flag desligado.
    await tester.pumpAndSettle();

    expect(find.text('4'), findsWidgets);
  });

  testWidgets('com sprite carregado para o 9, o pulso não roda', (
    tester,
  ) async {
    debugDisableApexPulse = false;

    final bytes = ByteData.view(_kOnePixelPng.buffer);
    await TileSpriteManager.preload(
      bundle: _FakeAssetBundle({TileSpriteManager.assetKeyFor(kMaxDigit): bytes}),
    );

    await tester.pumpWidget(
      host(const Tile(id: 't9', value: kMaxDigit, position: at)),
    );
    // A arte já supre o destaque — sem controlador de pulso, isto termina
    // sozinho mesmo com o flag desligado.
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
  });
}

class _FakeAssetBundle extends CachingAssetBundle {
  _FakeAssetBundle(this.available);

  final Map<String, ByteData> available;

  @override
  Future<ByteData> load(String key) async {
    final data = available[key];
    if (data == null) throw FlutterError('Unable to load asset: "$key".');
    return data;
  }
}

final Uint8List _kOnePixelPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);
