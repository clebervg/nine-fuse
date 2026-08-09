import 'dart:math';

import 'package:flutter/material.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';
import 'package:nine_fuse/core/juice_timings.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/presentation/widgets/board_geometry.dart';

const Key floatingScoreKey = Key('floating_score');

/// Chave do aviso de movimentos ganhos na explosão do dígito máximo.
const Key bonusMovesKey = Key('bonus_moves');

/// Camada de recompensa visual sobre o tabuleiro.
///
/// Fica separada do tabuleiro de propósito: são efeitos efêmeros que nascem,
/// sobem e somem, sem relação com a grade. Misturá-los ao [BoardGridWidget]
/// obrigaria aquele widget a manter estado que não é dele.
///
/// Não intercepta toque: [IgnorePointer] envolve tudo, senão a pontuação
/// flutuante engoliria a próxima jogada do jogador.
class JuiceOverlay extends StatelessWidget {
  const JuiceOverlay({super.key, required this.step, required this.comboCount});

  /// Passo da cascata sendo encenado. Nulo fora de uma jogada.
  final ResolutionStep? step;

  /// 1 no movimento do jogador, 2+ nas cascatas encadeadas.
  final int comboCount;

  @override
  Widget build(BuildContext context) {
    final current = step;
    if (current == null) return const SizedBox.shrink();

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // A mesma geometria do tabuleiro, para a pontuação nascer exatamente
          // na célula onde a fusão aconteceu.
          final geometry = BoardGeometry(availableWidth: constraints.maxWidth);
          final tileSize = geometry.tileSize;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (final fusion in current.fusions)
                Positioned(
                  left: geometry.centerOf(fusion.at).dx - 44,
                  // Acima da peça, não sobre ela: cobrindo o dígito o jogador
                  // perde de vista justamente o que acabou de conquistar.
                  top: geometry.centerOf(fusion.at).dy - tileSize * 0.85,
                  width: 88,
                  child: _FloatingScore(
                    // A chave amarrada ao id da peça faz o widget renascer a
                    // cada fusão, reiniciando a animação.
                    key: ValueKey('score_${fusion.tileId}'),
                    score: fusion.score,
                    color: AppColors.getColorByDigit(fusion.value),
                  ),
                ),

              for (final fusion in current.fusions)
                if (fusion.isBig)
                  Positioned(
                    left: geometry.centerOf(fusion.at).dx - tileSize,
                    top: geometry.centerOf(fusion.at).dy - tileSize,
                    width: tileSize * 2,
                    height: tileSize * 2,
                    child: _ImpactWave(
                      key: ValueKey('wave_${fusion.tileId}'),
                      color: AppColors.getColorByDigit(fusion.value),
                    ),
                  ),

              for (final centre in current.explosionCentres)
                Positioned(
                  left: geometry.centerOf(centre).dx - tileSize * 1.8,
                  top: geometry.centerOf(centre).dy - tileSize * 1.8,
                  width: tileSize * 3.6,
                  height: tileSize * 3.6,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _ExplosionFlash(
                        key: ValueKey('boom_${centre.row}_${centre.col}'),
                      ),
                      // As faíscas vêm por cima do clarão: sob ele elas seriam
                      // lavadas pelo branco justamente no quadro mais forte.
                      _ExplosionParticles(
                        key: ValueKey('sparks_${centre.row}_${centre.col}'),
                      ),
                    ],
                  ),
                ),

              // O prêmio em movimentos aparece no topo do tabuleiro, longe da
              // explosão: no centro ele competiria com o clarão e ninguém leria
              // o texto justamente no quadro em que ele importa.
              if (current.explosionCentres.isNotEmpty)
                Positioned(
                  top: -tileSize * 0.2,
                  left: 0,
                  right: 0,
                  child: _BonusMovesFlash(
                    key: ValueKey('bonus_${current.cascade}'),
                    moves:
                        current.explosionCentres.length * kExplosionBonusMoves,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// `+120` subindo e sumindo no ponto da fusão.
class _FloatingScore extends StatefulWidget {
  const _FloatingScore({super.key, required this.score, required this.color});

  final int score;
  final Color color;

  @override
  State<_FloatingScore> createState() => _FloatingScoreState();
}

class _FloatingScoreState extends State<_FloatingScore>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    // Criado aqui, e não como `late final`: um campo preguiçoso pode acabar
    // sendo inicializado pelo próprio `dispose()`, construindo um controlador
    // no meio do desmonte da árvore.
    _c = AnimationController(vsync: this, duration: JuiceTimings.floatingScore)
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        // Sobe 30px e some no último terço: aparecer e desaparecer ao mesmo
        // tempo deixaria o número ilegível.
        final opacity = t < 0.65 ? 1.0 : (1 - (t - 0.65) / 0.35);
        return Transform.translate(
          offset: Offset(0, -30 * Curves.easeOut.transform(t)),
          child: Opacity(opacity: opacity.clamp(0, 1), child: child),
        );
      },
      child: Text(
        key: floatingScoreKey,
        '+${widget.score}',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppFonts.display,
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          shadows: [
            Shadow(color: widget.color, blurRadius: 8),
            const Shadow(color: Colors.black87, blurRadius: 3),
          ],
        ),
      ),
    );
  }
}

/// Anel que se expande e some — recompensa de combinação grande.
class _ImpactWave extends StatefulWidget {
  const _ImpactWave({super.key, required this.color});

  final Color color;

  @override
  State<_ImpactWave> createState() => _ImpactWaveState();
}

class _ImpactWaveState extends State<_ImpactWave>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    // Criado aqui, e não como `late final`: um campo preguiçoso pode acabar
    // sendo inicializado pelo próprio `dispose()`, construindo um controlador
    // no meio do desmonte da árvore.
    _c = AnimationController(vsync: this, duration: JuiceTimings.impactWave)
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) {
      final t = Curves.easeOut.transform(_c.value);
      final fade = 1 - t;

      // Dois anéis defasados. Um só, fino, some no meio de um tabuleiro
      // cheio de cor — a recompensa precisa competir com o fundo.
      Widget ring(double from, double span, double strength) => Transform.scale(
        scale: from + t * span,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Color.lerp(
                Colors.white,
                widget.color,
                0.35,
              )!.withValues(alpha: fade * 0.95 * strength),
              width: 7 * fade + 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: fade * 0.55),
                blurRadius: 16 * fade,
                spreadRadius: 2 * fade,
              ),
            ],
          ),
        ),
      );

      // `StackFit.expand` é obrigatório: um Stack passa restrições frouxas
      // aos filhos não posicionados, e um DecoratedBox sem filho colapsa
      // para zero — o anel virava um ponto invisível.
      return Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [ring(0.25, 1.3, 1), ring(0.15, 0.8, 0.55)],
      );
    },
  );
}

/// Faíscas brancas e prateadas jogadas para fora da célula do dígito máximo.
///
/// Num `CustomPainter` e não num widget por partícula: são dezenas, e cada
/// widget custaria layout a cada quadro para algo puramente decorativo.
class _ExplosionParticles extends StatefulWidget {
  const _ExplosionParticles({super.key});

  @override
  State<_ExplosionParticles> createState() => _ExplosionParticlesState();
}

class _ExplosionParticlesState extends State<_ExplosionParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  /// Direções sorteadas uma vez. Sorteadas no `build`, as faíscas saltariam de
  /// lugar a cada quadro em vez de voar em linha.
  late final List<_Spark> _sparks;

  @override
  void initState() {
    super.initState();

    // Semente fixa: o efeito não precisa ser diferente a cada explosão, e assim
    // um golden desta cena não treme entre rodadas.
    final random = Random(19);
    const count = 22;
    _sparks = [
      for (int i = 0; i < count; i++)
        _Spark(
          // Distribuídas em volta do círculo, com um empurrão aleatório para
          // não formarem um leque perfeito.
          angle: (i / count) * 2 * pi + (random.nextDouble() - 0.5) * 0.5,
          distance: 0.55 + random.nextDouble() * 0.45,
          size: 1.8 + random.nextDouble() * 2.6,
          silver: random.nextBool(),
        ),
    ];

    // Criado aqui, e não como `late final`: um campo preguiçoso pode acabar
    // sendo inicializado pelo próprio `dispose()`, construindo um controlador
    // no meio do desmonte da árvore.
    _c = AnimationController(
      vsync: this,
      duration: JuiceTimings.explosionParticles,
    )..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) => CustomPaint(
      painter: _ParticlePainter(sparks: _sparks, t: _c.value),
      size: Size.infinite,
    ),
  );
}

/// Uma faísca: para onde vai, quão longe e de que cor.
class _Spark {
  const _Spark({
    required this.angle,
    required this.distance,
    required this.size,
    required this.silver,
  });

  final double angle;

  /// Fração do raio disponível que a faísca percorre.
  final double distance;
  final double size;

  /// Prateada em vez de branca. A mistura das duas dá o brilho de metal do
  /// dígito máximo, que na paleta é justamente branco/prata.
  final bool silver;
}

class _ParticlePainter extends CustomPainter {
  const _ParticlePainter({required this.sparks, required this.t});

  final List<_Spark> sparks;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    // Desacelera ao se afastar, como estilhaço perdendo energia.
    final travel = Curves.easeOutCubic.transform(t);
    final fade = (1 - t).clamp(0.0, 1.0);

    final paint = Paint();

    for (final spark in sparks) {
      final reach = radius * spark.distance * travel;
      final offset =
          centre + Offset(cos(spark.angle) * reach, sin(spark.angle) * reach);

      paint.color = (spark.silver ? const Color(0xFFB0BEC5) : Colors.white)
          .withValues(alpha: fade);

      // Encolhe enquanto voa: uma faísca de tamanho fixo parece uma bolinha.
      canvas.drawCircle(offset, spark.size * (0.4 + fade * 0.6), paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) => oldDelegate.t != t;
}

/// "+3 Movimentos!" subindo no topo do tabuleiro.
class _BonusMovesFlash extends StatefulWidget {
  const _BonusMovesFlash({super.key, required this.moves});

  final int moves;

  @override
  State<_BonusMovesFlash> createState() => _BonusMovesFlashState();
}

class _BonusMovesFlashState extends State<_BonusMovesFlash>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    // Criado aqui, e não como `late final`: um campo preguiçoso pode acabar
    // sendo inicializado pelo próprio `dispose()`, construindo um controlador
    // no meio do desmonte da árvore.
    _c = AnimationController(vsync: this, duration: JuiceTimings.bonusMoves)
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) {
      final t = _c.value;
      // Entra crescendo, fica legível no meio, some no fim. Aparecer e
      // sumir ao mesmo tempo deixaria o texto ilegível justamente na
      // recompensa mais rara do jogo.
      final grow = Curves.easeOutBack.transform((t / 0.25).clamp(0.0, 1.0));
      final opacity = t < 0.7 ? 1.0 : 1 - (t - 0.7) / 0.3;

      return Opacity(
        opacity: opacity.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, -14 * Curves.easeOut.transform(t)),
          child: Transform.scale(scale: 0.6 + grow * 0.4, child: child),
        ),
      );
    },
    child: Center(
      child: Container(
        key: bonusMovesKey,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.digit9, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.digit9.withValues(alpha: 0.5),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Text(
          AppLocalizations.of(context).bonusMoves(widget.moves),
          style: const TextStyle(
            fontFamily: AppFonts.display,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    ),
  );
}

/// Clarão branco da explosão do dígito máximo.
class _ExplosionFlash extends StatefulWidget {
  const _ExplosionFlash({super.key});

  @override
  State<_ExplosionFlash> createState() => _ExplosionFlashState();
}

class _ExplosionFlashState extends State<_ExplosionFlash>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    // Criado aqui, e não como `late final`: um campo preguiçoso pode acabar
    // sendo inicializado pelo próprio `dispose()`, construindo um controlador
    // no meio do desmonte da árvore.
    _c = AnimationController(vsync: this, duration: JuiceTimings.explosionFlash)
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) {
      final t = Curves.easeOut.transform(_c.value);
      return Transform.scale(
        scale: 0.4 + t * 0.8,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.white.withValues(alpha: (1 - t) * 0.95),
                Colors.white.withValues(alpha: (1 - t) * 0.35),
                Colors.white.withValues(alpha: 0),
              ],
              stops: const [0, 0.55, 1],
            ),
          ),
        ),
      );
    },
  );
}
