import 'package:flutter/material.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';

/// Raio das caixas de mensagem do jogo.
const double kGameDialogRadius = 24;

/// Chave do selo do título.
///
/// Existe para o teste medir o selo em si: o texto dentro dele fica depois do
/// recheio e da borda, então a posição do `Text` não diz onde o selo começa.
const Key gameDialogTitleKey = Key('game_dialog_title');

/// Quanto o selo do título sobra para fora da caixa, acima da borda.
///
/// É o que faz a caixa parecer um objeto com um selo pregado em cima, em vez de
/// um `AlertDialog` com a primeira linha em negrito.
const double kGameDialogBannerOverhang = 20;

/// Sombra dos textos de destaque do jogo.
///
/// Não use isto em texto que viva dentro de `Transform`, `ScaleTransition` ou
/// `AnimatedPositioned`: o Impeller rasteriza a sombra de texto **fora** dessas
/// transformações, e as sombras se acumulam num canto da tela como dígitos
/// borrados. Foi exatamente o que aconteceu com o número das peças, e por isso
/// `TileWidget` não usa `shadows:`. Aqui vale porque estes textos são estáticos.
const List<Shadow> kGameTextShadow = [
  Shadow(color: Color(0xCC000000), blurRadius: 6, offset: Offset(0, 2)),
];

/// Caixa de mensagem do jogo: fundo com profundidade, borda reluzente e o
/// título num selo curvo pregado no alto.
///
/// Substitui o cartão plano que parecia diálogo de sistema. A diferença que o
/// jogador percebe não é o raio da borda — é o título **sair** da caixa: um
/// retângulo com texto dentro lê como aviso, um selo sobreposto lê como prêmio.
///
/// Como o resto das telas, não é `showDialog`: é uma camada do `Stack` da tela,
/// ligada e desligada por estado. Uma rota por cima tiraria o tabuleiro da
/// árvore de foco e obrigaria a coordenar duas navegações a cada reinício.
class GameDialog extends StatelessWidget {
  const GameDialog({
    super.key,
    required this.title,
    required this.accent,
    required this.child,
    this.cardKey,
    this.maxWidth = 360,
    this.titleFontSize = 22,
  });

  /// Texto do selo. Vai para o alto da caixa, não para dentro dela.
  final String title;

  /// Cor que assina a caixa: borda, brilho e selo.
  final Color accent;

  final Widget child;

  /// Chave do container do cartão. Fica separada da chave do widget porque os
  /// testes procuram o cartão em si (`level_outcome`, `level_start`).
  final Key? cardKey;

  final double maxWidth;
  final double titleFontSize;

  @override
  Widget build(BuildContext context) {
    return Stack(
      // O selo passa da borda de cima; sem isto ele seria recortado justamente
      // na parte que o faz parecer pregado no cartão.
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // O recuo é um `Padding` por fora, e não `margin` no próprio cartão:
        // a margem de um `Container` entra na caixa que a chave endereça, e o
        // cartão passaria a medir como se começasse onde está o selo.
        Padding(
          padding: const EdgeInsets.only(top: kGameDialogBannerOverhang),
          child: Container(
            key: cardKey,
            // Largura de leitura: esticada numa tela larga a caixa vira cartaz e
            // o botão principal foge do polegar.
            constraints: BoxConstraints(maxWidth: maxWidth),
            padding: EdgeInsets.fromLTRB(
              20,
              // Espaço para a metade do selo que invade a caixa.
              kGameDialogBannerOverhang + 18,
              20,
              20,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kGameDialogRadius),
              // Radial e não chapado: o centro mais claro dá a impressão de luz
              // batendo na caixa, que é o que separa um objeto de um retângulo.
              gradient: RadialGradient(
                center: const Alignment(0, -0.55),
                radius: 1.25,
                colors: [
                  Color.lerp(AppColors.darkSurface, accent, 0.14)!,
                  AppColors.darkSurface,
                  const Color(0xFF141418),
                ],
                stops: const [0, 0.55, 1],
              ),
              border: Border.all(
                color: accent.withValues(alpha: 0.85),
                width: 2,
              ),
              boxShadow: [
                // Halo da cor da caixa: é o "reluzente" do brief, e some contra
                // o fundo escuro sem ele.
                BoxShadow(
                  color: accent.withValues(alpha: 0.28),
                  blurRadius: 34,
                  spreadRadius: 2,
                ),
                const BoxShadow(
                  color: Color(0xB3000000),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: child,
          ),
        ),
        _TitleBanner(
          title: title,
          accent: accent,
          fontSize: titleFontSize,
          maxWidth: maxWidth,
        ),
      ],
    );
  }
}

/// O selo curvo do título, projetado para fora do cartão.
class _TitleBanner extends StatelessWidget {
  const _TitleBanner({
    required this.title,
    required this.accent,
    required this.fontSize,
    required this.maxWidth,
  });

  final String title;
  final Color accent;
  final double fontSize;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: gameDialogTitleKey,
      // Nunca mais largo que o cartão, com folga para as laterais: títulos
      // longos como "MOVIMENTOS ESGOTADOS" encostariam nas bordas.
      constraints: BoxConstraints(maxWidth: maxWidth - 24),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.lighten(accent, 0.16),
            AppColors.darken(accent, 0.10),
          ],
        ),
        // Aro claro por fora: destaca o selo do fundo escuro e da própria caixa.
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.45),
            blurRadius: 18,
            spreadRadius: 1,
          ),
          const BoxShadow(
            color: Color(0x99000000),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Text(
        title,
        textAlign: TextAlign.center,
        maxLines: 2,
        style: TextStyle(
          fontFamily: AppFonts.display,
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
          height: 1.1,
          shadows: kGameTextShadow,
        ),
      ),
    );
  }
}

/// Botão-pílula com profundidade: aresta inferior escura, brilho interno no
/// topo e compressão ao ser pressionado.
///
/// Não é `ElevatedButton` porque o que se quer aqui é justamente o que o
/// Material evita — a peça afundar sob o dedo. O gesto é `GestureDetector` com
/// `Semantics(button: true)`, então leitor de tela e `tester.tap` continuam
/// funcionando como num botão comum.
class GameButton extends StatefulWidget {
  const GameButton({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
    this.icon,
    this.foreground,
    this.expand = true,
    this.fontSize = 17,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;
  final IconData? icon;

  /// Cor do texto. Por padrão sai do contraste com [color].
  final Color? foreground;

  final bool expand;
  final double fontSize;

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _pressed = false;

  /// Altura da aresta inferior. É ela que dá o volume — e é ela que some
  /// quando o botão é pressionado, o que o olho lê como afundar.
  static const double _depth = 5;

  @override
  Widget build(BuildContext context) {
    final base = widget.color;
    // Texto legível sobre a cor do botão, pela mesma regra da paleta: as cores
    // claras do jogo (amarelo, dourado) pedem texto escuro.
    final fg =
        widget.foreground ??
        (base.computeLuminance() > 0.45
            ? const Color(0xFF15150F)
            : Colors.white);

    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon case final icon?) ...[
          Icon(icon, color: fg, size: widget.fontSize + 3),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.display,
              color: fg,
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      // Sem `label`: o `Text` de dentro já anuncia o rótulo, e repeti-lo aqui
      // faria o leitor de tela ler "CONTINUAR CONTINUAR".
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          // Desce a mesma altura da aresta que perde: o topo do botão fica
          // exatamente onde a base estava, sem o conjunto mudar de tamanho.
          transform: Matrix4.translationValues(0, _pressed ? _depth : 0, 0),
          width: widget.expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.lighten(base, 0.18),
                base,
                AppColors.darken(base, 0.06),
              ],
              stops: const [0, 0.5, 1],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.30),
              width: 1.5,
            ),
            boxShadow: [
              // Blur zero de propósito: é uma aresta sólida, não uma sombra.
              // É o que simula a espessura da pílula.
              BoxShadow(
                color: AppColors.darken(base, 0.24),
                offset: Offset(0, _pressed ? 0 : _depth),
              ),
              BoxShadow(
                color: base.withValues(alpha: _pressed ? 0.15 : 0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: content,
        ),
      ),
    );
  }
}

/// Ação secundária: texto sem caixa, para não competir com o botão principal.
class GameTextButton extends StatelessWidget {
  const GameTextButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white60,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    ),
  );
}
