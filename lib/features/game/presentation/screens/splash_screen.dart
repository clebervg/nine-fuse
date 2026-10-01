import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nine_fuse/core/assets/tile_sprite_manager.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/features/game/presentation/screens/level_select_screen.dart';

/// Tempo mínimo de abertura: a barra leva isto para ir de 0 a 100% quando o
/// carregamento já terminou. Sem um mínimo, num aparelho rápido a arte
/// apareceria e sumiria num piscar.
const Duration kSplashDuration = Duration(milliseconds: 1600);

/// Uma etapa de carregamento que a barra acompanha.
typedef SplashLoader = Future<void> Function();

/// O que a abertura carrega por padrão: os sprites de peça e de cobertura.
/// Esperar por eles aqui evita o tabuleiro abrir com o desenho vetorial e
/// trocar para a arte um quadro depois.
const List<SplashLoader> kDefaultSplashLoaders = [
  TileSpriteManager.preload,
  TileSpriteManager.preloadObstacles,
];

/// Tela de carregamento, exibida uma única vez entre a splash nativa
/// (`flutter_native_splash`, mesma cor de fundo) e o menu de fases.
///
/// É a arte do pacote "candy pop" (`assets/splash/splash_1290x2796.png`) em
/// tela cheia, com a barra de progresso preenchendo o trilho que **já vem
/// desenhado na imagem**. Por isso a barra é posicionada em coordenadas da
/// arte e convertida pela mesma escala da imagem — duas contas diferentes
/// descolariam o preenchimento do trilho.
///
/// Uma imagem só, e não as três resoluções do pacote: as três têm a mesma
/// proporção, e o trilho só tem coordenadas publicadas para a de 1290.
///
/// O progresso é real, mas com piso de tempo: um único `AnimationController`
/// anda de 0 a 1 em [kSplashDuration] e é **segurado** num teto que só sobe
/// conforme as [loaders] terminam. Nada de `Future.delayed`, e a duração é
/// finita para não travar `pumpAndSettle` em teste.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.onSplashComplete,
    this.loaders = kDefaultSplashLoaders,
  });

  /// Chamado quando a barra chega ao fim. Por padrão navega para
  /// [LevelSelectScreen]; testes podem substituir para observar o fim sem
  /// depender de navegação.
  final VoidCallback? onSplashComplete;

  /// Etapas de carregamento. Falha numa delas conta como concluída: um sprite
  /// que não carregou cai no desenho vetorial, e não pode prender o jogador
  /// na abertura.
  final List<SplashLoader> loaders;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const String _artAsset = 'assets/splash/splash_1290x2796.png';
  static const String _fillAsset = 'assets/splash/loading_bar_fill.png';

  /// Tamanho da arte e retângulo interno do trilho nela
  /// (`splash.loading_bar` em `docs/brand/asset-manifest.json`).
  static const Size _art = Size(1290, 2796);
  static const Rect _track = Rect.fromLTWH(331, 2336, 628, 32);
  static const double _trackRadius = 16;

  /// Até onde o controller pode andar enquanto nenhuma etapa terminou. O teto
  /// sobe até ele em proporção às etapas concluídas, e só a última libera o
  /// trecho final — a barra nunca chega a 100% antes de o jogo estar pronto.
  static const double _holdAt = 0.7;

  late final AnimationController _controller;
  int _done = 0;

  double get _cap {
    final total = widget.loaders.length;
    if (_done >= total) return 1;
    return _holdAt * (0.5 + 0.5 * _done / total);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: kSplashDuration)
      ..addListener(_holdAtCap)
      ..addStatusListener(_onStatusChanged)
      ..forward();
    for (final load in widget.loaders) {
      unawaited(
        Future<void>.sync(load).catchError((Object _) {}).whenComplete(_onLoaded),
      );
    }
  }

  void _holdAtCap() {
    final cap = _cap;
    if (cap >= 1 || _controller.value < cap) return;
    // Um quadro longo (engasgo no aparelho) pode saltar o controller por cima
    // do teto até 1,0. Os listeners rodam antes do aviso de status, então
    // devolver o valor ao teto aqui impede o "completed" de sair antes de o
    // carregamento terminar. Atribuir `value` também para o controller.
    if (_controller.value > cap) {
      _controller.value = cap;
    } else {
      _controller.stop();
    }
  }

  void _onLoaded() {
    if (!mounted) return;
    _done++;
    if (!_controller.isAnimating && _controller.value < _cap) {
      _controller.forward();
    }
  }

  void _onStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final onComplete = widget.onSplashComplete;
    if (onComplete != null) {
      onComplete();
      return;
    }
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, _, _) => const LevelSelectScreen(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.splashBackground,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final layout = _ArtLayout.fit(constraints.biggest, _art, _track);
          final track = layout.map(_track);
          final dpr = MediaQuery.devicePixelRatioOf(context);
          return Stack(
            children: [
              Positioned.fromRect(
                rect: layout.map(Offset.zero & _art),
                child: Image.asset(
                  _artAsset,
                  fit: BoxFit.fill,
                  cacheWidth: math
                      .min(_art.width, _art.width * layout.scale * dpr)
                      .round(),
                  // A arte entra com um esmaecer curto: o primeiro quadro é só
                  // o fundo da splash nativa, e a imagem "estalar" por cima
                  // dele lê como travamento.
                  frameBuilder: (context, child, frame, _) => AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: child,
                  ),
                ),
              ),
              Positioned.fromRect(
                rect: track,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => _fill(
                    track.size,
                    Curves.easeOut.transform(_controller.value),
                    _trackRadius * layout.scale,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Preenchimento cortado pela largura, e não esticado: a arte da barra tem
  /// brilho e ponta arredondada, que esticados de 0 a 100% se deformariam.
  Widget _fill(Size track, double progress, double radius) {
    return Semantics(
      value: '${(progress * 100).round()}%',
      child: Align(
        alignment: Alignment.centerLeft,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: SizedBox(
            width: track.width * progress,
            height: track.height,
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: track.width,
              maxWidth: track.width,
              child: Image.asset(
                _fillAsset,
                width: track.width,
                height: track.height,
                fit: BoxFit.fill,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Escala e deslocamento que levam a arte para a tela.
class _ArtLayout {
  const _ArtLayout(this.scale, this.offset);

  /// Preenche a tela (aspect fill, centralizado), exceto quando isso cortaria
  /// o trilho: em telas mais largas que a arte (tablet), preencher corta o
  /// rodapé, e a barra sumiria junto. Aí a arte cabe inteira, com o fundo da
  /// splash nas laterais — ele é a mesma cor das bordas da imagem.
  factory _ArtLayout.fit(Size screen, Size art, Rect track) {
    var scale = math.max(screen.width / art.width, screen.height / art.height);
    // Folga abaixo do trilho para ele não encostar na borda da tela.
    final trackBottom = track.bottom + track.height * 1.5;
    final top = (screen.height - art.height * scale) / 2;
    if (top + trackBottom * scale > screen.height) {
      scale = math.min(screen.width / art.width, screen.height / art.height);
    }
    return _ArtLayout(
      scale,
      Offset(
        (screen.width - art.width * scale) / 2,
        (screen.height - art.height * scale) / 2,
      ),
    );
  }

  final double scale;
  final Offset offset;

  /// Um retângulo em pixels da arte, em coordenadas de tela.
  Rect map(Rect r) => Rect.fromLTWH(
    offset.dx + r.left * scale,
    offset.dy + r.top * scale,
    r.width * scale,
    r.height * scale,
  );
}
