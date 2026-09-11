import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/assets/tile_sprite_manager.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';

/// Bundle de mentira: só "tem" os assets cujas chaves estão em [available].
/// Qualquer outra chave falha como um `rootBundle.load` real falharia para um
/// asset ausente — é essa falha que o manager precisa engolir.
class _FakeAssetBundle extends CachingAssetBundle {
  _FakeAssetBundle(this.available);

  final Map<String, ByteData> available;
  int loadCalls = 0;

  @override
  Future<ByteData> load(String key) async {
    loadCalls++;
    final data = available[key];
    if (data == null) {
      throw FlutterError('Unable to load asset: "$key".');
    }
    return data;
  }
}

/// PNG 1x1 transparente válido — o menor arquivo que o decodificador do
/// Flutter aceita, para os testes que chegam a montar um `Image` de verdade.
final Uint8List _kOnePixelPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // assinatura PNG
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, // IDAT
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, // IEND
  0x42, 0x60, 0x82,
]);

ByteData _asByteData(Uint8List bytes) => ByteData.view(bytes.buffer);

void main() {
  setUp(TileSpriteManager.clearCache);

  test('sem preload, nenhum dígito tem sprite', () {
    expect(TileSpriteManager.hasSprite(0), isFalse);
    expect(TileSpriteManager.spriteFor(0), isNull);
  });

  test('preload com bundle sem nenhum asset mantém o fallback para todos', () async {
    final bundle = _FakeAssetBundle(const {});

    await TileSpriteManager.preload(bundle: bundle);

    for (var value = 0; value <= 9; value++) {
      expect(TileSpriteManager.hasSprite(value), isFalse);
    }
  });

  test('preload registra sprite só para os dígitos cujo asset existe', () async {
    final bundle = _FakeAssetBundle({
      TileSpriteManager.assetKeyFor(3): _asByteData(_kOnePixelPng),
      TileSpriteManager.assetKeyFor(9): _asByteData(_kOnePixelPng),
    });

    await TileSpriteManager.preload(bundle: bundle);

    expect(TileSpriteManager.hasSprite(3), isTrue);
    expect(TileSpriteManager.spriteFor(3), isNotNull);
    expect(TileSpriteManager.hasSprite(9), isTrue);

    // O resto continua sem sprite — cai no renderizador vetorial.
    expect(TileSpriteManager.hasSprite(0), isFalse);
    expect(TileSpriteManager.hasSprite(4), isFalse);
  });

  test('sprite já em cache não é recarregado do bundle', () async {
    final bundle = _FakeAssetBundle({
      TileSpriteManager.assetKeyFor(5): _asByteData(_kOnePixelPng),
    });

    await TileSpriteManager.preload(bundle: bundle);
    final callsAfterFirst = bundle.loadCalls;
    await TileSpriteManager.preload(bundle: bundle);

    expect(bundle.loadCalls, callsAfterFirst);
  });

  test('clearCache devolve todos os dígitos ao fallback', () async {
    final bundle = _FakeAssetBundle({
      TileSpriteManager.assetKeyFor(7): _asByteData(_kOnePixelPng),
    });
    await TileSpriteManager.preload(bundle: bundle);
    expect(TileSpriteManager.hasSprite(7), isTrue);

    TileSpriteManager.clearCache();

    expect(TileSpriteManager.hasSprite(7), isFalse);
  });

  group('obstáculos', () {
    test('sem preload, nenhum estado de obstáculo tem sprite', () {
      expect(TileSpriteManager.hasObstacleSprite(ObstacleType.ice, 1), isFalse);
      expect(
        TileSpriteManager.spriteForObstacle(ObstacleType.stone, 3),
        isNull,
      );
    });

    test(
      'preloadObstacles com bundle vazio mantém o fallback para todos os estados',
      () async {
        final bundle = _FakeAssetBundle(const {});

        await TileSpriteManager.preloadObstacles(bundle: bundle);

        expect(TileSpriteManager.hasObstacleSprite(ObstacleType.ice, 1), isFalse);
        expect(TileSpriteManager.hasObstacleSprite(ObstacleType.glass, 2), isFalse);
        expect(TileSpriteManager.hasObstacleSprite(ObstacleType.glass, 1), isFalse);
        expect(TileSpriteManager.hasObstacleSprite(ObstacleType.stone, 3), isFalse);
        expect(TileSpriteManager.hasObstacleSprite(ObstacleType.stone, 2), isFalse);
        expect(TileSpriteManager.hasObstacleSprite(ObstacleType.stone, 1), isFalse);
      },
    );

    test(
      'preloadObstacles registra sprite só para os estados cujo asset existe',
      () async {
        final bundle = _FakeAssetBundle({
          TileSpriteManager.assetKeyForObstacle(ObstacleType.ice, 1):
              _asByteData(_kOnePixelPng),
          TileSpriteManager.assetKeyForObstacle(ObstacleType.stone, 2):
              _asByteData(_kOnePixelPng),
        });

        await TileSpriteManager.preloadObstacles(bundle: bundle);

        expect(TileSpriteManager.hasObstacleSprite(ObstacleType.ice, 1), isTrue);
        expect(
          TileSpriteManager.spriteForObstacle(ObstacleType.ice, 1),
          isNotNull,
        );
        expect(TileSpriteManager.hasObstacleSprite(ObstacleType.stone, 2), isTrue);

        // Vidro intacto e pedra cheia continuam sem sprite, cada estado com
        // sua própria chave.
        expect(TileSpriteManager.hasObstacleSprite(ObstacleType.glass, 2), isFalse);
        expect(TileSpriteManager.hasObstacleSprite(ObstacleType.stone, 3), isFalse);
      },
    );

    test('sprite de obstáculo já em cache não é recarregado do bundle', () async {
      final bundle = _FakeAssetBundle({
        TileSpriteManager.assetKeyForObstacle(ObstacleType.glass, 1):
            _asByteData(_kOnePixelPng),
      });

      await TileSpriteManager.preloadObstacles(bundle: bundle);
      final callsAfterFirst = bundle.loadCalls;
      await TileSpriteManager.preloadObstacles(bundle: bundle);

      expect(bundle.loadCalls, callsAfterFirst);
    });

    test('clearCache devolve todos os estados de obstáculo ao fallback', () async {
      final bundle = _FakeAssetBundle({
        TileSpriteManager.assetKeyForObstacle(ObstacleType.stone, 1):
            _asByteData(_kOnePixelPng),
      });
      await TileSpriteManager.preloadObstacles(bundle: bundle);
      expect(TileSpriteManager.hasObstacleSprite(ObstacleType.stone, 1), isTrue);

      TileSpriteManager.clearCache();

      expect(TileSpriteManager.hasObstacleSprite(ObstacleType.stone, 1), isFalse);
    });
  });
}
