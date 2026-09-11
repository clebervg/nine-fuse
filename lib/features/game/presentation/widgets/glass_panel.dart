import 'dart:ui';

import 'package:flutter/material.dart';

/// Chave do `BackdropFilter` de um [GlassPanel], para o teste travar que o
/// desfoque continua vivendo dentro do `ClipRRect` — sem o recorte, o blur
/// vaza para a tela inteira e passa a redesenhar tudo atrás do painel a cada
/// quadro.
const Key glassPanelBlurKey = Key('glass_panel_blur');

/// Painel translúcido em "vidro fosco": a moldura compartilhada por baixo do
/// cabeçalho da fase, do cabeçalho do Endless e do dock de boosters.
///
/// Substitui o degradê + borda clara + sombra grossa que cada um desses três
/// widgets desenhava por conta própria — a mesma decoração, copiada três
/// vezes, seria a primeira coisa a divergir no próximo ajuste de estilo.
///
/// O `BackdropFilter` fica sempre dentro de um `ClipRRect` do mesmo raio: sem
/// o recorte, o filtro se aplica à tela inteira por trás do painel, e não só à
/// área que ele ocupa — o custo de repaint sobe com o tamanho da tela em vez
/// do tamanho do painel.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderRadius = 20,
    this.tint,
    this.emphasis = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  /// Tingimento opcional por cima do vidro, para um painel querer uma
  /// assinatura de cor própria (o slot do martelo, por exemplo) sem deixar de
  /// ser vidro. `null` é o vidro neutro do cabeçalho e do dock.
  final Color? tint;

  /// Borda mais acesa, para o painel que precisa se destacar dos irmãos sem
  /// ganhar uma segunda moldura por fora (o card de Jogadas, por exemplo).
  final bool emphasis;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(borderRadius),
    child: BackdropFilter(
      key: glassPanelBlurKey,
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          // Preto por baixo (o fundo do jogo já é escuro; sem ele o painel
          // ficaria claro demais sobre o tabuleiro) com um véu branco por
          // cima — é o véu que lê como vidro, não como escurecimento.
          color: Color.alphaBlend(
            Colors.white.withValues(alpha: 0.06),
            const Color(0x59000000),
          ),
          gradient: tint == null
              ? null
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    tint!.withValues(alpha: 0.28),
                    tint!.withValues(alpha: 0.08),
                  ],
                ),
          border: Border.all(
            color: (tint ?? Colors.white).withValues(
              alpha: tint == null ? 0.20 : (emphasis ? 0.75 : 0.55),
            ),
            width: emphasis ? 1.8 : 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    ),
  );
}
