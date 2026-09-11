import 'dart:math';

import 'package:flutter/material.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/juice_timings.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/presentation/widgets/board_geometry.dart';

const Key floatingScoreKey = Key('floating_score');

/// Marcador do banner/véu do evento Supernova, para a suíte afirmar que ele
/// aparece e some sozinho. Fica no widget interno (não em `_SupernovaEvent`
/// em si) porque o segundo é reconstruído pelo `AnimatedBuilder` só enquanto
/// a animação está em curso — quando ela termina, o `Stack` com esta chave
/// deixa de ser construído e o finder passa a não achar nada, sem precisar de
/// nenhum sinal externo dizendo que o evento acabou.
const Key supernovaBannerKey = Key('supernova_banner');

/// Marcador da onda de choque + faíscas da Nova, visível só depois do
/// hitstop — mesmo raciocínio de [supernovaBannerKey]: o widget some sozinho
/// quando termina, sem precisar de sinal externo dizendo que acabou.
const Key novaBurstKey = Key('nova_burst');

/// Camada de recompensa visual sobre o tabuleiro.
///
/// Fica separada do tabuleiro de propósito: são efeitos efêmeros que nascem,
/// sobem e somem, sem relação com a grade. Misturá-los ao [BoardGridWidget]
/// obrigaria aquele widget a manter estado que não é dele.
///
/// Não intercepta toque: [IgnorePointer] envolve tudo, senão a pontuação
/// flutuante engoliria a próxima jogada do jogador.
class JuiceOverlay extends StatelessWidget {
  const JuiceOverlay({
    super.key,
    required this.step,
    required this.comboCount,
    this.hammerStrike,
    this.strikeSerial = 0,
    this.bombStrike,
    this.bombStrikeSerial = 0,
    this.showSupernova = false,
  });

  /// Passo da cascata sendo encenado. Nulo fora de uma jogada.
  final ResolutionStep? step;

  /// 1 no movimento do jogador, 2+ nas cascatas encadeadas.
  final int comboCount;

  /// Onde o último golpe de martelo caiu, e qual dígito morreu.
  ///
  /// Chega separado de [step] porque o estilhaço precisa sobreviver ao fim da
  /// encenação: o passo do golpe é descartado quando a jogada assenta, e o
  /// efeito ainda está no ar.
  final (Position, int)? hammerStrike;

  /// Número do golpe. Só serve de chave: dois golpes na mesma célula, com o
  /// mesmo dígito, não reacenderiam a animação sem ele.
  final int strikeSerial;

  /// Centro da última explosão da Bomba, e **cada célula realmente
  /// destruída** com o dígito que carregava.
  ///
  /// É um mapa, e não `(Position, int)` como o Martelo: a bomba atinge até 9
  /// células, e cada uma merece o próprio estilhaço na cor certa — um único
  /// efeito no centro esconderia a maior parte do que a explosão destruiu.
  final (Position, Map<Position, int>)? bombStrike;

  /// Número da explosão. Mesmo papel de [strikeSerial].
  final int bombStrikeSerial;

  /// Aceso por uma jogada em que o Super 9 nasceu ou foi ativado — a
  /// hierarquia de `JuiceDirector` já garantiu que nenhum outro efeito
  /// concorre com ele nesta jogada.
  final bool showSupernova;

  @override
  Widget build(BuildContext context) {
    final current = step;
    final strike = hammerStrike;
    final blast = bombStrike;
    if (current == null && strike == null && blast == null && !showSupernova) {
      return const SizedBox.shrink();
    }

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
              if (current != null) ...[
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

                // A Nova: 3+ peças de valor 9 já existentes no tabuleiro se
                // alinharam. O raio da celebração escala com o tier — tier 3
                // (5+ peças) é o núcleo mais largo que o motor já trata como
                // "o tabuleiro inteiro".
                for (final nova in current.novaEvents)
                  Positioned(
                    left:
                        geometry.centerOf(nova.at).dx -
                        tileSize * _novaSpan(nova.tier),
                    top:
                        geometry.centerOf(nova.at).dy -
                        tileSize * _novaSpan(nova.tier),
                    width: tileSize * _novaSpan(nova.tier) * 2,
                    height: tileSize * _novaSpan(nova.tier) * 2,
                    child: _NovaBurst(
                      key: ValueKey(
                        'nova_${nova.at.row}_${nova.at.col}_${nova.tier}',
                      ),
                      tier: nova.tier,
                    ),
                  ),

                // A quebra da cobertura acontece na célula do obstáculo, não na
                // da fusão: é ali que o jogador precisa olhar para entender que
                // o golpe alcançou o que ele estava mirando.
                for (final hit in current.obstacleHits)
                  Positioned(
                    left: geometry.centerOf(hit.position).dx - tileSize * 0.75,
                    top: geometry.centerOf(hit.position).dy - tileSize * 0.75,
                    width: tileSize * 1.5,
                    height: tileSize * 1.5,
                    child: ObstacleShatter(
                      key: ValueKey(
                        'shatter_${current.cascade}_'
                        '${hit.position.row}_${hit.position.col}',
                      ),
                      type: hit.type,
                      destroyed: hit.cleared,
                    ),
                  ),
              ],

              // O estilhaço do martelo vive fora do bloco do passo: quando a
              // jogada assenta, o passo é descartado e o efeito ainda está no
              // ar.
              if (strike != null)
                Positioned(
                  left: geometry.centerOf(strike.$1).dx - tileSize * 0.9,
                  top: geometry.centerOf(strike.$1).dy - tileSize * 0.9,
                  width: tileSize * 1.8,
                  height: tileSize * 1.8,
                  child: ShatterEffect(
                    key: ValueKey('hammer_$strikeSerial'),
                    color: AppColors.getColorByDigit(strike.$2),
                  ),
                ),

              // A explosão da Bomba, pelo mesmo motivo do estilhaço do
              // Martelo: vive fora do bloco do passo porque sobrevive ao
              // assentamento da jogada.
              if (blast != null) ...[
                Positioned(
                  left: geometry.centerOf(blast.$1).dx - tileSize * 1.5,
                  top: geometry.centerOf(blast.$1).dy - tileSize * 1.5,
                  width: tileSize * 3,
                  height: tileSize * 3,
                  child: _ImpactWave(
                    key: ValueKey('bomb_wave_$bombStrikeSerial'),
                    color: AppColors.digit0,
                  ),
                ),
                // Um estilhaço por célula de fato destruída — o centro sozinho
                // esconderia as até oito vizinhas que a explosão também levou.
                for (final entry in blast.$2.entries)
                  Positioned(
                    left: geometry.centerOf(entry.key).dx - tileSize * 0.75,
                    top: geometry.centerOf(entry.key).dy - tileSize * 0.75,
                    width: tileSize * 1.5,
                    height: tileSize * 1.5,
                    child: ShatterEffect(
                      key: ValueKey(
                        'bomb_${bombStrikeSerial}_'
                        '${entry.key.row}_${entry.key.col}',
                      ),
                      color: AppColors.getColorByDigit(entry.value),
                    ),
                  ),
              ],

              // Por cima de tudo: o Supernova é o clímax da jogada, e nada
              // mais deve competir com ele.
              if (showSupernova) const Positioned.fill(child: _SupernovaEvent()),
            ],
          );
        },
      ),
    );
  }
}

/// Raio da celebração da Nova, em múltiplos do lado da célula, por tier (1, 2
/// ou 3+). Cresce junto com a zona que o motor realmente afeta: núcleo 3x3
/// (tier 1) contra um anel maior (tier 2) contra o tabuleiro inteiro (tier 3).
double _novaSpan(int tier) => switch (tier) {
  1 => 1.5,
  2 => 2.5,
  _ => 3.5,
};

/// Celebração da Nova: hitstop curto, depois onda de choque radial e um
/// estouro de faíscas douradas, ambos ancorados na célula exata do evento —
/// nunca no centro da tela, ao contrário do banner de dígito máximo.
///
/// Uma animação só, dividida em dois trechos, mesmo desenho do
/// `_SupernovaEvent`: o hitstop é a fração inicial em que nada muda (o jogo
/// "segura a respiração"), e o resto do tempo é o payoff.
class _NovaBurst extends StatefulWidget {
  const _NovaBurst({super.key, required this.tier});

  /// 1 (3 peças), 2 (4 peças) ou 3 (5+ peças).
  final int tier;

  @override
  State<_NovaBurst> createState() => _NovaBurstState();
}

class _NovaBurstState extends State<_NovaBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Spark> _sparks;
  late final double _hitstopFraction;

  @override
  void initState() {
    super.initState();

    // Semente fixa e derivada do tier: dois eventos do mesmo tier têm o mesmo
    // padrão de faíscas, e o golden não treme a cada quadro reconstruído.
    final random = Random(97 + widget.tier);
    // Mais faíscas em tiers maiores — o mesmo raciocínio de `ShatterEffect`
    // pesar mais que `ObstacleShatter`.
    final count = 10 + widget.tier * 8;
    _sparks = [
      for (int i = 0; i < count; i++)
        _Spark(
          angle: (i / count) * 2 * pi + (random.nextDouble() - 0.5) * 0.5,
          distance: 0.55 + random.nextDouble() * 0.4,
          size: 1.6 + random.nextDouble() * 2.4,
          silver: random.nextBool(),
        ),
    ];

    final total = JuiceTimings.novaHitstop + JuiceTimings.novaPayoff;
    _hitstopFraction =
        JuiceTimings.novaHitstop.inMilliseconds / total.inMilliseconds;
    _c = AnimationController(vsync: this, duration: total)..forward();
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
      // Ainda no hitstop: nada é desenhado. É a pausa dramática antes do
      // impacto — o jogo "segurou a respiração" de verdade em
      // `GameNotifier._playResolution` (que aguarda a mesma duração antes de
      // continuar a encenação); aqui é só o espelho visual dessa pausa.
      //
      // Terminada, a celebração também não desenha mais nada — mesmo
      // raciocínio do `_SupernovaEvent`: o widget encerra sozinho o evento
      // que ele começou, sem depender de sinal externo.
      if (_c.value < _hitstopFraction || _c.isCompleted) {
        return const SizedBox.shrink();
      }

      final payoffT = ((_c.value - _hitstopFraction) / (1 - _hitstopFraction))
          .clamp(0.0, 1.0);
      final waveT = Curves.easeOut.transform(
        (payoffT / 0.6).clamp(0.0, 1.0),
      );
      final waveFade = 1 - waveT;

      // Entra rápido, fica legível na maior parte do payoff e some nos
      // últimos 25% — mesma forma de sino do banner do Supernova
      // (`_SupernovaEvent`), texto diferente porque o gatilho é outro: a
      // Nova nasce de noves que já estavam no tabuleiro, o Supernova é a
      // ativação/criação do Super 9.
      final bannerOpacity = switch (payoffT) {
        < 0.15 => payoffT / 0.15,
        > 0.75 => (1 - payoffT) / 0.25,
        _ => 1.0,
      }.clamp(0.0, 1.0);

      return Stack(
        key: novaBurstKey,
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          // Onda de choque: mesmo formato de anel do `_ImpactWave`, mas com
          // um segundo anel externo — a Nova é o clímax maior, e merece ler
          // mais largo que uma combinação grande comum.
          Transform.scale(
            scale: 0.2 + waveT * (1.1 + widget.tier * 0.2),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.digit9.withValues(
                    alpha: waveFade * 0.95,
                  ),
                  width: 8 * waveFade + 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.digit9Deep.withValues(
                      alpha: waveFade * 0.6,
                    ),
                    blurRadius: 20 * waveFade,
                    spreadRadius: 3 * waveFade,
                  ),
                ],
              ),
            ),
          ),
          CustomPaint(
            painter: _ParticlePainter(
              sparks: _sparks,
              t: payoffT,
              tint: AppColors.digit9,
            ),
            size: Size.infinite,
          ),
          // O banner de texto, por cima da onda e das faíscas: é a leitura
          // que fecha a celebração, não um efeito a mais competindo com ela.
          Text(
            'SUPERNOVA 9!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: Colors.white.withValues(alpha: bannerOpacity),
              shadows: [
                Shadow(
                  color: AppColors.digit9.withValues(alpha: bannerOpacity),
                  blurRadius: 10,
                ),
                Shadow(
                  color: Colors.black.withValues(alpha: 0.8 * bannerOpacity),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
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

/// Estilhaços de uma cobertura que levou impacto.
///
/// Público porque é o marcador que a suíte usa para afirmar que o obstáculo
/// certo reagiu no lugar certo — os efeitos duram menos de meio segundo e não
/// deixariam outro rastro verificável.
///
/// Um golpe que **destrói** espalha mais e mais longe que um que apenas trinca:
/// é o que diferencia "faltou um" de "acabou", sem texto nenhum.
class ObstacleShatter extends StatefulWidget {
  const ObstacleShatter({
    super.key,
    required this.type,
    required this.destroyed,
  });

  final ObstacleType type;

  /// A cobertura caiu neste impacto.
  final bool destroyed;

  @override
  State<ObstacleShatter> createState() => _ObstacleShatterState();
}

class _ObstacleShatterState extends State<ObstacleShatter>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late final List<_Spark> _shards;

  /// Cor dos cacos, por material. A poeira da pedra é opaca e curta; o gelo e
  /// o vidro estilhaçam claros.
  Color get _color => switch (widget.type) {
    ObstacleType.stone => const Color(0xFF9AA0A6),
    ObstacleType.glass => const Color(0xFFE8F1F8),
    _ => const Color(0xFFBFEBFF),
  };

  @override
  void initState() {
    super.initState();

    // Semente fixa, como nas faíscas da explosão: o efeito não precisa ser
    // diferente a cada quebra, e assim um golden desta cena não treme.
    final random = Random(31);
    final count = widget.destroyed ? 14 : 6;
    _shards = [
      for (int i = 0; i < count; i++)
        _Spark(
          angle: (i / count) * 2 * pi + (random.nextDouble() - 0.5) * 0.6,
          distance:
              (widget.destroyed ? 0.5 : 0.28) + random.nextDouble() * 0.35,
          size: 1.4 + random.nextDouble() * 2.0,
          silver: random.nextBool(),
        ),
    ];

    // Criado aqui, e não como `late final`: um campo preguiçoso pode acabar
    // sendo inicializado pelo próprio `dispose()`.
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
      painter: _ParticlePainter(sparks: _shards, t: _c.value, tint: _color),
      size: Size.infinite,
    ),
  );
}

/// Estilhaços de uma célula obliterada pelo Martelo de Fusão.
///
/// Tem widget próprio, em vez de reusar [ObstacleShatter], porque o material é
/// outro: aqui o que se quebra é a **peça**, e a cor tem de ser a do dígito que
/// morreu. Sem essa ligação o jogador não ata o efeito à célula que ele mesmo
/// escolheu — e o martelo é a única ação do jogo em que ele aponta o dedo e
/// nomeia a vítima.
///
/// Público pelo mesmo motivo que [ObstacleShatter]: é o marcador que a suíte usa
/// para afirmar que o golpe reagiu no lugar e na cor certos.
class ShatterEffect extends StatefulWidget {
  const ShatterEffect({super.key, required this.color});

  /// A cor do dígito destruído.
  final Color color;

  @override
  State<ShatterEffect> createState() => _ShatterEffectState();
}

class _ShatterEffectState extends State<ShatterEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late final List<_Spark> _shards;

  @override
  void initState() {
    super.initState();

    // Semente fixa, como no resto dos efeitos de partícula: sem ela o estilhaço
    // dança a cada quadro reconstruído e nenhum golden se sustenta.
    final random = Random(53);
    // Mais cacos que uma quebra de cobertura: o martelo tira a célula inteira,
    // e o efeito precisa pesar mais que o de um impacto de fusão.
    const count = 18;
    _shards = [
      for (int i = 0; i < count; i++)
        _Spark(
          angle: (i / count) * 2 * pi + (random.nextDouble() - 0.5) * 0.6,
          distance: 0.55 + random.nextDouble() * 0.4,
          size: 1.6 + random.nextDouble() * 2.2,
          silver: random.nextBool(),
        ),
    ];

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
      painter: _ParticlePainter(
        sparks: _shards,
        t: _c.value,
        tint: widget.color,
      ),
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
  const _ParticlePainter({required this.sparks, required this.t, this.tint});

  final List<_Spark> sparks;
  final double t;

  /// Cor do material. Nula na explosão do dígito máximo, que é branco/prata
  /// por definição.
  final Color? tint;

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

      // Sem material, a explosão do dígito máximo: branco e prata, que é a
      // leitura de metal que o clímax pede.
      final base = tint ?? Colors.white;
      final pale = tint == null
          ? const Color(0xFFB0BEC5)
          : Color.lerp(base, Colors.white, 0.45)!;

      paint.color = (spark.silver ? pale : base).withValues(alpha: fade);

      // Encolhe enquanto voa: uma faísca de tamanho fixo parece uma bolinha.
      canvas.drawCircle(offset, spark.size * (0.4 + fade * 0.6), paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.tint != tint;
}

/// Hitstop + focus-fade + banner do evento Supernova. Uma animação só,
/// finita, dividida em dois trechos de tempo: segura (hitstop) e mostra o
/// véu escuro com o texto, que sobe, fica e desvanece sozinho.
class _SupernovaEvent extends StatefulWidget {
  const _SupernovaEvent();

  @override
  State<_SupernovaEvent> createState() => _SupernovaEventState();
}

class _SupernovaEventState extends State<_SupernovaEvent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scrimOpacity;
  late final Animation<double> _bannerOpacity;

  @override
  void initState() {
    super.initState();
    final total = JuiceTimings.supernovaHitstop + JuiceTimings.supernovaPayoff;
    _controller = AnimationController(vsync: this, duration: total)
      ..forward();

    final hitstopFraction =
        JuiceTimings.supernovaHitstop.inMilliseconds / total.inMilliseconds;

    // Focus-fade: escurece o fundo a 30% de opacidade assim que o hitstop
    // termina, e mantém até o fim.
    _scrimOpacity = Tween<double>(begin: 0, end: 0.3).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(
          hitstopFraction,
          hitstopFraction + 0.15,
          curve: Curves.easeOut,
        ),
      ),
    );

    // O banner aparece com o escurecimento e some nos últimos 20% da
    // duração total — nunca fica em loop, some sozinho.
    _bannerOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(
      CurvedAnimation(parent: _controller, curve: Interval(hitstopFraction, 1.0)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Uma vez completa, a animação não constrói mais nada — nem o véu,
        // nem a chave que a suíte procura. É o que faz `supernovaBannerKey`
        // sumir da árvore sozinho, sem depender de `showSupernova` mudar de
        // fora: o próprio widget encerra o evento que ele começou.
        if (_controller.isCompleted) return const SizedBox.shrink();

        return Stack(
          key: supernovaBannerKey,
          children: [
            ColoredBox(color: Colors.black.withValues(alpha: _scrimOpacity.value)),
            Center(
              child: Text(
                'SUPERNOVA',
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  color: Colors.white.withValues(alpha: _bannerOpacity.value),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

