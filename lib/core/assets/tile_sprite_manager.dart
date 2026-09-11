import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';

/// Cache dos sprites das peças (0-9), com fallback silencioso.
///
/// A produção artística ainda não entregou os PNGs — hoje a peça é desenhada
/// por [AppColors.tileGradient] + texto. Este manager é o ponto único que a
/// UI consulta para saber se já existe sprite para um dígito: se existir,
/// desenha a imagem; se não, [TileWidget] continua usando o renderizador
/// vetorial de sempre. Nenhum dos dois lados precisa saber por que o outro
/// existe.
///
/// Estático de propósito: é cache de asset, não estado de jogo — não faz
/// sentido por instância, e todo o tabuleiro (64 peças, no máximo 10 dígitos
/// distintos) lê do mesmo lugar.
abstract final class TileSpriteManager {
  static final Map<int, ImageProvider> _cache = {};

  /// Dígitos cuja carga já foi tentada nesta sessão, com ou sem sucesso.
  /// Sem isto, um dígito sem asset seria pedido ao bundle de novo a cada
  /// chamada de [preload] — e uma tela reaberta várias vezes bateria disco a
  /// cada visita só para redescobrir o mesmo "não existe".
  static final Set<int> _attempted = {};

  /// Caminho do asset esperado para o dígito, caso ele já tenha sido
  /// produzido. Convenção única: quem gera o asset e quem o carrega usam a
  /// mesma função, então não há como divergir em silêncio.
  static String assetKeyFor(int value) => 'assets/sprites/tiles/tile_$value.png';

  /// Tenta carregar o sprite de cada dígito (0-9). Um asset ausente não é
  /// erro — é o estado esperado durante a migração, e por isso a falha de
  /// carregamento de uma chave é engolida sem propagar para quem chamou.
  ///
  /// Idempotente: um dígito já em cache não é recarregado, então chamar de
  /// novo (por exemplo ao reabrir uma tela) é barato.
  static Future<void> preload({AssetBundle? bundle}) async {
    final assetBundle = bundle ?? rootBundle;
    for (var value = 0; value <= 9; value++) {
      if (_attempted.contains(value)) continue;
      _attempted.add(value);
      final key = assetKeyFor(value);
      final ByteData bytes;
      try {
        bytes = await assetBundle.load(key);
      } catch (_) {
        // Sem asset para este dígito: fica de fora do cache, e o fallback
        // vetorial assume — não há o que fazer aqui além de seguir adiante.
        continue;
      }
      // `MemoryImage` sobre os bytes já lidos, e não `AssetImage(key,
      // bundle:...)`: `AssetImage.obtainKey` resolve variantes de densidade
      // via `AssetManifest.bin`, que exigiria o bundle injetado saber
      // responder por um asset que este manager nunca pediu — acoplamento
      // que não compensa para um cache que já tem os bytes em mãos.
      _cache[value] = MemoryImage(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    }
  }

  /// Se há sprite carregado para o dígito.
  static bool hasSprite(int value) => _cache.containsKey(value);

  /// O provider do sprite, ou nulo se o dígito ainda não tem asset.
  static ImageProvider? spriteFor(int value) => _cache[value];

  /// Esvazia o cache. Usado pelos testes para isolar chamadas de [preload], e
  /// serve também para forçar uma nova tentativa de carga depois que os
  /// assets forem publicados numa atualização do app.
  static void clearCache() {
    _cache.clear();
    _attempted.clear();
    _obstacleCache.clear();
    _attemptedObstacles.clear();
  }

  // --- Obstáculos (Gelo, Vidro, Pedra) ---
  //
  // Trilha de cache separada da dos dígitos: chave por (tipo, hp) em vez de
  // por dígito, e "existir sprite de obstáculo" não tem relação nenhuma com
  // "existir sprite de dígito" — dois times de arte, dois estados de
  // migração, sem acoplar um ao outro.

  static final Map<String, ImageProvider> _obstacleCache = {};

  /// Chaves de obstáculo cuja carga já foi tentada, com ou sem sucesso.
  static final Set<String> _attemptedObstacles = {};

  /// Todas as combinações de (tipo, hp) que uma cobertura pode assumir em
  /// jogo — inclusive os estados intermediários (vidro trincado, pedra
  /// fissurada/quebradiça), e não só o hp cheio de cada tipo.
  static const List<(ObstacleType, int)> _obstacleStates = [
    (ObstacleType.ice, 1),
    (ObstacleType.glass, 2),
    (ObstacleType.glass, 1),
    (ObstacleType.stone, 3),
    (ObstacleType.stone, 2),
    (ObstacleType.stone, 1),
  ];

  /// Caminho do asset esperado para a cobertura em [type] com [hp] restante.
  /// Mesma convenção do dígito: quem gera o asset e quem o carrega leem desta
  /// única função.
  static String assetKeyForObstacle(ObstacleType type, int hp) =>
      'assets/sprites/obstacles/obstacle_${type.name}_$hp.png';

  /// Tenta carregar o sprite de cada estado de obstáculo. Mesmo contrato de
  /// [preload]: asset ausente não é erro, e a chamada é idempotente.
  static Future<void> preloadObstacles({AssetBundle? bundle}) async {
    final assetBundle = bundle ?? rootBundle;
    for (final (type, hp) in _obstacleStates) {
      final key = assetKeyForObstacle(type, hp);
      if (_attemptedObstacles.contains(key)) continue;
      _attemptedObstacles.add(key);
      final ByteData bytes;
      try {
        bytes = await assetBundle.load(key);
      } catch (_) {
        // Sem asset para este estado: fica de fora do cache, e o
        // ObstacleOverlay/CustomPainter atual assume o desenho.
        continue;
      }
      _obstacleCache[key] = MemoryImage(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    }
  }

  /// Se há sprite carregado para a cobertura em [type]/[hp].
  static bool hasObstacleSprite(ObstacleType type, int hp) =>
      _obstacleCache.containsKey(assetKeyForObstacle(type, hp));

  /// O provider do sprite da cobertura, ou nulo se este estado ainda não tem
  /// asset — caso em que quem chama deve cair no `ObstacleOverlay`.
  static ImageProvider? spriteForObstacle(ObstacleType type, int hp) =>
      _obstacleCache[assetKeyForObstacle(type, hp)];
}
