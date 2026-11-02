import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/core/theme/nf_tokens.dart';

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
    this.onClose,
    this.closeKey,
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

  /// Fecha o cartão explicitamente. Nulo omite o 'X' — a maioria das caixas
  /// do jogo já fecha por um botão de ação própria (JOGAR, CONTINUAR), e um
  /// 'X' ali seria uma segunda saída para a mesma decisão.
  final VoidCallback? onClose;

  /// Chave do 'X', para o cartão que precisar endereçá-lo em teste.
  final Key? closeKey;

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
              // A placa do observatório: azul-noite com luz no alto, aro de ouro
              // e uma base bronze sólida que dá espessura. O [accent] fica no
              // halo e no selo — a moldura é a mesma em toda caixa do jogo.
              gradient: RadialGradient(
                center: const Alignment(0, -0.6),
                radius: 1.3,
                colors: [
                  Color.lerp(NfColors.night3, accent, 0.10)!,
                  NfColors.night3,
                  const Color(0xFF0B1236),
                ],
                stops: const [0, 0.5, 1],
              ),
              border: Border.all(color: NfColors.goldDeep, width: 2.5),
              boxShadow: [
                // Blur zero: espessura da placa, não sombra.
                const BoxShadow(color: NfColors.bronze, offset: Offset(0, 7)),
                BoxShadow(
                  color: accent.withValues(alpha: 0.28),
                  blurRadius: 40,
                  spreadRadius: 2,
                ),
                const BoxShadow(
                  color: Color(0x99000000),
                  blurRadius: 30,
                  offset: Offset(0, 18),
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
        if (onClose case final close?)
          Positioned(
            top: kGameDialogBannerOverhang + 8,
            right: 8,
            child: _CloseButton(key: closeKey, onPressed: close),
          ),
      ],
    );
  }
}

/// O 'X' que fecha o cartão explicitamente, no canto superior direito.
class _CloseButton extends StatelessWidget {
  const _CloseButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    shape: const CircleBorder(),
    child: Ink(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A4380), NfColors.night3],
        ),
        border: Border.all(color: const Color(0xFFC98A18), width: 2),
      ),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: const Padding(
          padding: EdgeInsets.all(7),
          child: Icon(Icons.close_rounded, color: NfColors.goldPale, size: 20),
        ),
      ),
    ),
  );
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
          fontFamily: AppFonts.title,
          color: Colors.white,
          fontSize: fontSize + 2,
          letterSpacing: 0.8,
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
    this.leading,
    this.foreground,
    this.expand = true,
    this.fontSize = 17,
    this.subtitle,
  });

  final String label;

  /// Linha menor abaixo do rótulo — ex.: o objetivo da fase sob "JOGAR FASE
  /// 8". Diz o que o toque vai custar sem o jogador ter de abrir a fase.
  final String? subtitle;
  final Color color;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Arte antes do rótulo, no lugar de [icon] — ex.: o sprite da moeda num
  /// botão de compra. Ícone de fonte não tem o acabamento 3D da arte, e ao
  /// lado de um preço é a moeda de verdade que o jogador precisa reconhecer.
  final Widget? leading;

  /// Cor do texto. Por padrão sai do contraste com [color].
  final Color? foreground;

  final bool expand;
  final double fontSize;

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _pressed = false;

  /// Sem callback o botão é decorativo: não afunda e não anuncia ação.
  bool get _enabled => widget.onPressed != null;

  /// Altura da aresta inferior em repouso e pressionado. É ela que dá o
  /// volume — e é ela que encolhe sob o dedo, o que o olho lê como afundar.
  static const double _depth = 8;
  static const double _pressedDepth = 3;

  @override
  Widget build(BuildContext context) {
    final palette = _GameButtonPalette.of(widget.color, enabled: _enabled);
    final fg = widget.foreground ?? palette.foreground;
    final edge = _pressed ? _pressedDepth : _depth;

    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.leading case final leading?) ...[
          leading,
          const SizedBox(width: 10),
        ] else if (widget.icon case final icon?) ...[
          Icon(icon, color: fg, size: widget.fontSize + 3),
          const SizedBox(width: 8),
        ],
        Flexible(
          // Rótulos longos (ex.: "Ganhar +25 🪙 (Assistir Vídeo)") encolhem
          // para caber, em vez de serem cortados com "...". `FittedBox` não
          // faz nada quando o texto já cabe, então botões curtos não mudam.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    // Lilita One: a voz dos títulos e botões grandes. Tem um
                    // peso só, então nada de `fontWeight` (o Flutter
                    // sintetizaria um negrito borrado).
                    fontFamily: AppFonts.title,
                    color: fg,
                    fontSize: widget.fontSize + 2,
                    letterSpacing: 0.9,
                    height: widget.subtitle == null ? null : 1.05,
                  ),
                ),
                if (widget.subtitle case final subtitle?)
                  Text(
                    subtitle,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.number,
                      fontWeight: FontWeight.w800,
                      // Mais apagado que o rótulo: é o detalhe, não a ação.
                      color: fg.withValues(alpha: 0.72),
                      fontSize: 12,
                      letterSpacing: 1.4,
                      height: 1.1,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      // Sem `label`: o `Text` de dentro já anuncia o rótulo, e repeti-lo aqui
      // faria o leitor de tela ler "CONTINUAR CONTINUAR".
      child: GestureDetector(
        onTapDown: (_) {
          if (!_enabled) return;
          setState(() => _pressed = true);
        },
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: _enabled
            ? () {
                // Batida leve: confirma o toque sem competir com o
                // `heavyImpact` das destruições no tabuleiro.
                HapticFeedback.lightImpact();
                widget.onPressed!();
              }
            : null,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1,
          duration: NfDurations.press,
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: NfDurations.press,
            curve: Curves.easeOut,
            // Desce o que a aresta perde: o topo do botão fica exatamente onde
            // a base estava, sem o conjunto mudar de tamanho.
            transform: Matrix4.translationValues(0, _depth - edge, 0),
            width: widget.expand ? double.infinity : null,
            // Área tocável ≥ 48dp mesmo com fonte pequena.
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(NfRadii.md),
              gradient: palette.fill,
              border: palette.border,
              boxShadow: [
                // Blur zero de propósito: é uma aresta sólida, não uma sombra.
                // É o que simula a espessura do botão.
                BoxShadow(color: palette.edge, offset: Offset(0, edge)),
                if (palette.glow case final glow?)
                  BoxShadow(
                    color: glow.withValues(alpha: _pressed ? 0.12 : 0.32),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Reflexo no topo: o "inset 0 3px 0 rgba(255,255,255,.75)" do
                // design. É o que separa um botão de vidro de uma pílula chapada.
                if (palette.highlight)
                  Positioned(
                    top: -9,
                    left: 6,
                    right: 6,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                content,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// As cores de um [GameButton], derivadas da cor que o chamador pediu.
///
/// Os chamadores continuam passando `color` — o que mudou foi a **leitura**
/// dela: o dourado da UI vira o botão de ouro do observatório, e o
/// `darkSurface` vira o botão secundário azul-noite com contorno discreto. Os
/// demais tons (botões de anúncio, em cor de peça) seguem a cor, com o mesmo
/// volume.
class _GameButtonPalette {
  const _GameButtonPalette({
    required this.fill,
    required this.edge,
    required this.foreground,
    this.border,
    this.glow,
    this.highlight = true,
  });

  factory _GameButtonPalette.of(Color base, {required bool enabled}) {
    if (base == AppColors.uiGold || base == NfColors.gold) {
      return const _GameButtonPalette(
        fill: NfDecorations.goldFill,
        edge: NfColors.goldShadow,
        foreground: NfColors.goldText,
        glow: Color(0xFFFFAA00),
      );
    }
    if (base == AppColors.darkSurface || !enabled) {
      return _GameButtonPalette(
        fill: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [NfColors.night3, NfColors.night2],
        ),
        edge: NfColors.night0,
        foreground: enabled ? NfColors.textSoft : Colors.white38,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: 1.5,
        ),
        highlight: false,
      );
    }
    return _GameButtonPalette(
      fill: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.lighten(base, 0.22),
          base,
          AppColors.darken(base, 0.08),
        ],
        stops: const [0, 0.45, 1],
      ),
      edge: AppColors.darken(base, 0.28),
      // Texto legível sobre a cor do botão, pela mesma regra da paleta: as
      // cores claras do jogo pedem texto escuro.
      foreground: base.computeLuminance() > 0.45
          ? const Color(0xFF15150F)
          : Colors.white,
      glow: base,
    );
  }

  final Gradient fill;
  final Color edge;
  final Color foreground;
  final BoxBorder? border;
  final Color? glow;
  final bool highlight;
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
