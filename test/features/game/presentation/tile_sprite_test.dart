import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/assets/tile_sprite_manager.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';
import 'package:nine_fuse/features/game/presentation/widgets/obstacle_overlay.dart';
import 'package:nine_fuse/features/game/presentation/widgets/strike_shake.dart';
import 'package:nine_fuse/features/game/presentation/widgets/tile_widget.dart';
import '../../../support/localized.dart';

/// Mesmo bundle de mentira do teste do manager: só "tem" as chaves passadas.
class _FakeAssetBundle extends CachingAssetBundle {
  _FakeAssetBundle(this.available);

  final Map<String, ByteData> available;

  @override
  Future<ByteData> load(String key) async {
    final data = available[key];
    if (data == null) {
      throw FlutterError('Unable to load asset: "$key".');
    }
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

void main() {
  const origin = Position(row: 0, col: 0);
  const tile = Tile(id: 't0', value: 4, position: origin);

  setUp(TileSpriteManager.clearCache);
  tearDown(TileSpriteManager.clearCache);

  Future<void> pumpTile(WidgetTester tester) async {
    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 48,
              height: 48,
              child: TileWidget(tile: tile, side: 48),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sem sprite carregado, continua desenhando o número (fallback)', (
    tester,
  ) async {
    await pumpTile(tester);

    expect(find.text('4'), findsWidgets);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('com sprite carregado para o dígito, desenha a imagem em vez do texto', (
    tester,
  ) async {
    final bundle = _FakeAssetBundle({
      TileSpriteManager.assetKeyFor(4): ByteData.view(_kOnePixelPng.buffer),
    });
    await TileSpriteManager.preload(bundle: bundle);

    await pumpTile(tester);

    expect(find.byType(Image), findsOneWidget);
    // O texto do dígito não é mais desenhado: a arte já carrega o número.
    expect(find.text('4'), findsNothing);

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.width, 48);
    expect(image.height, 48);
  });

  testWidgets('a peça com sprite continua animando o pulo de fusão', (
    tester,
  ) async {
    final bundle = _FakeAssetBundle({
      TileSpriteManager.assetKeyFor(4): ByteData.view(_kOnePixelPng.buffer),
      TileSpriteManager.assetKeyFor(5): ByteData.view(_kOnePixelPng.buffer),
    });
    await TileSpriteManager.preload(bundle: bundle);

    await pumpTile(tester);
    expect(find.byType(ScaleTransition), findsWidgets);

    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 48,
              height: 48,
              child: TileWidget(
                tile: tile.copyWith(value: 5),
                side: 48,
                animateEntrance: false,
              ),
            ),
          ),
        ),
      ),
    );

    // A troca de valor dispara o mesmo pulo de sempre — sprite não muda essa
    // garantia, só o que é desenhado dentro da célula.
    expect(find.byType(ScaleTransition), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
  });

  group('sprite de obstáculo', () {
    final stoneTile = tile.withObstacle(ObstacleType.stone);

    Future<void> pumpObstacleTile(WidgetTester tester, Tile obstacleTile) {
      return tester.pumpWidget(
        localizedApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 48,
                height: 48,
                child: TileWidget(tile: obstacleTile, side: 48),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'sem sprite de obstáculo carregado, continua com o ObstacleOverlay (fallback)',
      (tester) async {
        await pumpObstacleTile(tester, stoneTile);
        await tester.pumpAndSettle();

        expect(find.byType(ObstacleOverlay), findsOneWidget);
      },
    );

    testWidgets(
      'com sprite carregado para tipo/hp, desenha a imagem em vez do ObstacleOverlay',
      (tester) async {
        final bundle = _FakeAssetBundle({
          TileSpriteManager.assetKeyForObstacle(ObstacleType.stone, 3):
              ByteData.view(_kOnePixelPng.buffer),
        });
        await TileSpriteManager.preloadObstacles(bundle: bundle);

        await pumpObstacleTile(tester, stoneTile);
        await tester.pumpAndSettle();

        expect(find.byType(ObstacleOverlay), findsNothing);
        // Uma Image é o dígito de fallback (sem sprite de dígito, ainda é
        // texto); a segunda é a cobertura — aqui só há a da cobertura.
        expect(find.byType(Image), findsOneWidget);
      },
    );

    testWidgets(
      'dano parcial na cobertura (hp cai, mas não zera) sacode a peça via StrikeShake',
      (tester) async {
        await pumpObstacleTile(tester, stoneTile);
        await tester.pumpAndSettle();

        final shakeBefore = tester.widget<StrikeShake>(
          find.byType(StrikeShake),
        );
        expect(shakeBefore.serial, 0);

        await pumpObstacleTile(tester, stoneTile.copyWith(obstacleHp: 2));
        await tester.pump();

        final shakeAfter = tester.widget<StrikeShake>(find.byType(StrikeShake));
        expect(shakeAfter.serial, 1);

        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'a quebra final da cobertura (hp chega a zero) não incrementa o serial do dano parcial',
      (tester) async {
        await pumpObstacleTile(tester, stoneTile.copyWith(obstacleHp: 1));
        await tester.pumpAndSettle();

        final shakeBefore = tester.widget<StrikeShake>(
          find.byType(StrikeShake),
        );
        expect(shakeBefore.serial, 0);

        // A cobertura some por completo: outro tile, sem obstáculo.
        await pumpObstacleTile(tester, tile);
        await tester.pump();

        final shakeAfter = tester.widget<StrikeShake>(find.byType(StrikeShake));
        expect(shakeAfter.serial, 0);

        await tester.pumpAndSettle();
      },
    );
  });
}
