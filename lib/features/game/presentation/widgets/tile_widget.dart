import 'package:flutter/material.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/constants/tile_shape.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';
import 'package:nine_fuse/features/game/presentation/widgets/obstacle_overlay.dart';

/// Duração do pulo de uma peça que acabou de evoluir.
const Duration kTilePopDuration = Duration(milliseconds: 260);

/// Até quantas peças podem carregar o maior valor do tabuleiro e ainda assim
/// receber o brilho de destaque. Acima disso o valor é comum, e brilho comum
/// não destaca nada.
const int kPeakGlowMaxTiles = 3;

/// Chave do pulo da fusão.
///
/// O salto da seleção usa `AnimatedScale`, que por dentro também é um
/// `ScaleTransition` — sem chave, um teste que procura pelo tipo acharia os
/// dois e não saberia qual é qual.
const Key tilePopKey = Key('tile_pop');

/// Renderiza uma peça: número, cor do dígito e realce de seleção.
///
/// Não trata toque — quem faz isso é a camada de áreas tocáveis do tabuleiro,
/// endereçada por posição. Aqui só se desenha a peça.
class TileWidget extends StatefulWidget {
  const TileWidget({
    super.key,
    required this.tile,
    this.isSelected = false,
    this.animateEntrance = true,
    this.hintGlow = 0,
    this.fromBigMatch = false,
    this.isPeak = false,
    required this.side,
  });

  final Tile tile;

  /// Lado da célula em pixels lógicos.
  ///
  /// Vem de fora, e não de um `LayoutBuilder` interno: o tabuleiro já calculou
  /// esse número, e medir de novo em cada uma das 64 peças custaria 64
  /// callbacks de layout por quadro — em plena animação de cascata.
  final double side;
  final bool isSelected;

  /// A peça nasceu de uma combinação de 4+. Ganha pulo maior e um clarão, para
  /// que a recompensa por combinação grande seja visível — e não só contábil.
  final bool fromBigMatch;

  /// Esta peça carrega o maior valor presente no tabuleiro, e esse valor é
  /// raro o bastante para merecer destaque.
  ///
  /// Quem decide é o tabuleiro, não a peça: só ele enxerga as outras 63. Sem a
  /// condição de raridade, um tabuleiro recém-sorteado acenderia os dezesseis
  /// `3` de uma vez e o brilho deixaria de significar "olhe aqui".
  final bool isPeak;

  /// Intensidade do brilho de dica, de 0 a 1. Acende quando o jogador fica
  /// parado e esta peça faz parte de uma jogada possível.
  final double hintGlow;

  /// Desligado para a peça que está *saindo* do tabuleiro: ela já tem a sua
  /// própria animação de saída, e um pulo de entrada por cima brigaria com ela.
  final bool animateEntrance;

  @override
  State<TileWidget> createState() => _TileWidgetState();
}

class _TileWidgetState extends State<TileWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: kTilePopDuration,
  );

  /// Cresce e volta: dá peso à fusão sem deslocar a peça. Combinação grande
  /// cresce mais.
  Animation<double> get _pop {
    final peak = widget.fromBigMatch ? 1.45 : 1.22;
    return TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: peak), weight: 1),
      TweenSequenceItem(
        tween: Tween(
          begin: peak,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 2,
      ),
    ]).animate(_controller);
  }

  /// Clarão branco que some junto com o pulo. Só em combinação grande.
  late final Animation<double> _flash = Tween<double>(
    begin: 1,
    end: 0,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    if (widget.animateEntrance) {
      // Peça nova entra com o mesmo pulo: sinaliza que veio do topo.
      _controller.forward();
    } else {
      _controller.value = _controller.upperBound;
    }
  }

  @override
  void didUpdateWidget(TileWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Mesma peça com valor novo significa fusão: vale um pulo.
    if (widget.tile.value != oldWidget.tile.value) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.tile.value;
    final color = AppColors.getColorByDigit(value);
    // Branco em todos os dígitos. A legibilidade vem do contorno escuro, não
    // da cor do preenchimento — ver _OutlinedDigit.
    const textColor = Colors.white;
    // O topo da escala é o clímax do jogo e merece destaque próprio.
    final isTop = value >= kMaxDigit;
    final glow = widget.hintGlow.clamp(0.0, 1.0);

    // A silhueta muda com o dígito, então o raio acompanha o tamanho da célula.
    final radius = BorderRadius.circular(
      TileShape.radiusFor(value, widget.side),
    );

    // A peça selecionada salta sobre as vizinhas; a dica só insinua. Antes
    // esse destaque vinha de um halo que vazava para fora da célula.
    final lift = widget.isSelected ? 1.08 : 1 + 0.03 * glow;

    return ScaleTransition(
      key: tilePopKey,
      scale: _pop,
      child: AnimatedScale(
        scale: lift,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: _body(value, color, textColor, isTop, glow, radius, widget.side),
      ),
    );
  }

  Widget _body(
    int value,
    Color color,
    Color textColor,
    bool isTop,
    double glow,
    BorderRadius radius,
    double side,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        // Degradê no lugar de cor chapada: dá volume à peça, que é o que
        // separa um protótipo de um jogo acabado. São 64 objetos ocupando a
        // tela inteira, então é aqui que o ganho aparece.
        gradient: AppColors.tileGradient(value),
        borderRadius: radius,
        border: Border.all(
          // A dica usa a mesma borda branca da seleção, mais fina: comunica
          // "é aqui" sem se passar por peça já escolhida.
          color: widget.isSelected
              ? Colors.white
              : Colors.white.withValues(alpha: 0.9 * glow),
          width: widget.isSelected ? 3 : 2.5 * glow,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
        boxShadow: [
          // Sombra projetada: destaca a peça do fundo escuro do tabuleiro.
          // Difusa e curta — sombra dura devolveria o ar de protótipo que o
          // degradê acabou de tirar.
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
          // Halo da própria cor. O dígito máximo tem brilho próprio — neon
          // dourado, definido uma vez em [AppColors.apexGlow] para valer
          // igual no tabuleiro e no HUD. `spreadRadius` positivo desenha para
          // fora da célula e invade as vizinhas: só o clímax do jogo paga esse
          // preço.
          if (isTop)
            ...AppColors.apexGlow(spread: 2)
          else
            // A peça mais alta em jogo brilha o suficiente para o olho achá-la
            // no meio das 64; o resto só recebe um assentamento. Aqui o
            // destaque fica todo no desfoque, sem espalhamento.
            BoxShadow(
              color: color.withValues(alpha: widget.isPeak ? 0.50 : 0.22),
              blurRadius: widget.isPeak ? 13 : 7,
              offset: const Offset(0, 3),
            ),
          // Nada de halo externo para seleção nem para dica: `BoxShadow`
          // desenha **fora** da caixa e a mancha invadia as células vizinhas,
          // parecendo defeito de renderização em vez de destaque. O realce
          // agora é contido na própria peça — borda interna e um leve salto
          // de escala.
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Base mais escura, como a lateral de uma tecla. Substituiu o
          // reflexo esférico de plástico, que datava o visual e achatava a
          // peça em vez de lhe dar volume.
          Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: 0.16,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    bottomLeft: radius.bottomLeft,
                    bottomRight: radius.bottomRight,
                  ),
                  color: AppColors.darken(color, 0.13),
                ),
              ),
            ),
          ),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: _OutlinedDigit(value: value, side: side, apex: isTop),
              ),
            ),
          ),
          if (widget.fromBigMatch)
            // Por cima do número: o clarão cobre a peça inteira e revela a
            // cor conforme desaparece.
            IgnorePointer(
              child: FadeTransition(
                opacity: _flash,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    // Acompanha a silhueta da peça, senão o clarão vaza
                    // pelos cantos de um dígito arredondado.
                    borderRadius: radius,
                  ),
                ),
              ),
            ),
          // Por cima de tudo, inclusive do clarão: a cobertura é o que está
          // fisicamente entre o jogador e a peça.
          if (widget.tile.isBlocked)
            ObstacleOverlay(
              type: widget.tile.obstacle,
              cracked: widget.tile.isDamaged,
              radius: radius,
              // Derivado da posição, não sorteado: coberturas vizinhas não
              // repetem a mesma estampa, e cada uma delas é idêntica em todo
              // quadro reconstruído.
              cellIndex:
                  widget.tile.position.row * 31 + widget.tile.position.col,
            ),
        ],
      ),
    );
  }
}

/// Cor do contorno do número.
///
/// Escura e fixa, igual em todas as peças. É ela que garante a leitura, e não
/// a cor do preenchimento: assim o número pode ser branco em **todos** os
/// dígitos sem que o amarelo (1,40:1 de branco sobre amarelo) ou o prateado
/// (1,15:1) fiquem ilegíveis.
///
/// É a mesma técnica de legenda de vídeo e rótulo de mapa — texto claro com
/// contorno escuro sobre fundo imprevisível. A alternativa seria escurecer a
/// paleta até o branco passar sozinho, mas isso custaria 32% da luz do amarelo
/// e 48% da do prateado, apagando as duas cores mais distintivas do jogo.
const Color kDigitOutline = Color(0xE6101014);

/// Número com contorno.
///
/// Duas camadas de texto empilhadas: uma pintada só de traço, outra de
/// preenchimento por cima. Dá o acabamento de jogo sem recorrer a `shadows`,
/// que o Impeller rasteriza fora das transformações da peça e espalha dígitos
/// fantasma pelo tabuleiro.
///
/// Continua sendo texto de verdade: leitor de tela lê, e o Flutter reaproveita
/// o atlas de glifos nas 64 células — o que um SVG por peça não faria.
class _OutlinedDigit extends StatelessWidget {
  const _OutlinedDigit({
    required this.value,
    required this.side,
    this.apex = false,
  });

  final int value;
  final double side;

  /// Dígito máximo: o dourado é a cor mais clara da paleta e o branco chega a
  /// ele com pouco contraste, então o traço precisa ser mais marcante.
  final bool apex;

  @override
  Widget build(BuildContext context) {
    const fontSize = 32.0;
    // Proporcional ao tamanho da peça, senão o contorno engrossa demais em
    // tela pequena e some em tablet.
    final stroke = side * (apex ? 0.095 : 0.07);

    TextStyle style(Paint? paint, Color? color) => TextStyle(
      fontWeight: FontWeight.w900,
      fontSize: fontSize,
      height: 1.15,
      color: color,
      foreground: paint,
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          '$value',
          style: style(
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = stroke
              ..strokeJoin = StrokeJoin.round
              ..color = kDigitOutline,
            null,
          ),
        ),
        Text('$value', style: style(null, Colors.white)),
      ],
    );
  }
}
