import 'package:flutter/material.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/core/theme/nf_tokens.dart';

/// As quatro vozes tipográficas do jogo.
enum NfTextVariant {
  /// Título branco com sombra sólida roxa empilhada.
  title,

  /// Título dourado com sombra sólida âmbar empilhada.
  titleGold,

  /// Número em Baloo 2 com contorno escuro.
  number,

  /// Rótulo pequeno, espaçado, em lilás suave.
  label,
}

/// Texto da direção "Observatório Real".
///
/// **As sombras empilhadas não podem viver dentro de `Transform` animado.** O
/// Impeller rasteriza a sombra de texto fora da transformação e o borrão fica
/// para trás (ver `kGameTextShadow`). Título que entra com escala deve usar
/// [shadows] `false`, e o contorno de [NfTextVariant.number] é traço — não
/// sombra — justamente para valer em qualquer lugar.
class NfText extends StatelessWidget {
  const NfText(
    this.text, {
    super.key,
    this.variant = NfTextVariant.title,
    this.size,
    this.color,
    this.strokeColor = NfColors.numberStroke,
    this.strokeWidth = 5,
    this.textAlign = TextAlign.center,
    this.shadows = true,
    this.maxLines = 1,
  });

  const NfText.title(
    this.text, {
    super.key,
    this.size = 34,
    this.color,
    this.textAlign = TextAlign.center,
    this.shadows = true,
    this.maxLines = 1,
  }) : variant = NfTextVariant.title,
       strokeColor = NfColors.numberStroke,
       strokeWidth = 5;

  const NfText.titleGold(
    this.text, {
    super.key,
    this.size = 34,
    this.textAlign = TextAlign.center,
    this.shadows = true,
    this.maxLines = 1,
  }) : variant = NfTextVariant.titleGold,
       color = null,
       strokeColor = NfColors.numberStroke,
       strokeWidth = 5;

  const NfText.number(
    this.text, {
    super.key,
    this.size = 22,
    this.color,
    this.strokeColor = NfColors.numberStroke,
    this.strokeWidth = 5,
    this.textAlign = TextAlign.center,
    this.maxLines = 1,
  }) : variant = NfTextVariant.number,
       shadows = false;

  const NfText.label(
    this.text, {
    super.key,
    this.size = 11,
    this.color,
    this.textAlign = TextAlign.center,
    this.maxLines = 1,
  }) : variant = NfTextVariant.label,
       strokeColor = NfColors.numberStroke,
       strokeWidth = 0,
       shadows = false;

  final String text;
  final NfTextVariant variant;
  final double? size;
  final Color? color;
  final Color strokeColor;
  final double strokeWidth;
  final TextAlign textAlign;
  final bool shadows;
  final int maxLines;

  /// Estilo-base de cada variante, exposto para quem precisa do `TextStyle`
  /// (ex.: `TextSpan`, `TextPainter` da roleta) sem montar o widget.
  static TextStyle styleFor(
    NfTextVariant variant, {
    double? size,
    Color? color,
    bool shadows = true,
  }) {
    switch (variant) {
      case NfTextVariant.title:
        return TextStyle(
          fontFamily: AppFonts.title,
          fontSize: size ?? 34,
          color: color ?? Colors.white,
          letterSpacing: 0.6,
          height: 1.05,
          shadows: shadows
              ? const [
                  Shadow(offset: Offset(0, 3), color: NfColors.gemTitleShadow),
                  Shadow(offset: Offset(0, 6), color: NfColors.gemDeep),
                  Shadow(
                    offset: Offset(0, 10),
                    blurRadius: 20,
                    color: Colors.black54,
                  ),
                ]
              : null,
        );
      case NfTextVariant.titleGold:
        return TextStyle(
          fontFamily: AppFonts.title,
          fontSize: size ?? 34,
          color: color ?? NfColors.gold,
          letterSpacing: 0.6,
          height: 1.05,
          shadows: shadows
              ? const [
                  Shadow(offset: Offset(0, 3), color: Color(0xFFC17A00)),
                  Shadow(offset: Offset(0, 6), color: Color(0xFF6B3E00)),
                ]
              : null,
        );
      case NfTextVariant.number:
        return TextStyle(
          fontFamily: AppFonts.number,
          fontWeight: FontWeight.w800,
          fontSize: size ?? 22,
          color: color ?? Colors.white,
          height: 1.1,
        );
      case NfTextVariant.label:
        return TextStyle(
          fontFamily: AppFonts.number,
          fontWeight: FontWeight.w800,
          fontSize: size ?? 11,
          letterSpacing: 1.6,
          color: color ?? NfColors.textSoft,
          height: 1.1,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = styleFor(variant, size: size, color: color, shadows: shadows);

    if (variant != NfTextVariant.number || strokeWidth <= 0) {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Contorno por dois textos sobrepostos: o de trás só com traço, o da
    // frente sólido. `Paint` com `stroke` desenha metade do traço por dentro
    // do glifo, e por isso o sólido vai por cima — senão o número afina.
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          text,
          textAlign: textAlign,
          maxLines: maxLines,
          style: style.copyWith(
            color: null,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeJoin = StrokeJoin.round
              ..color = strokeColor,
          ),
        ),
        Text(text, textAlign: textAlign, maxLines: maxLines, style: style),
      ],
    );
  }
}
