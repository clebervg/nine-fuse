import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/core/theme/nf_tokens.dart';
import 'package:nine_fuse/core/widgets/nf_text.dart';

/// Duração de uma batida da pílula em alerta.
///
/// O pulso é **finito** de propósito: uma animação em repetição faria
/// `pumpAndSettle` nunca terminar e derrubaria a suíte de widget inteira —
/// mesma regra do brilho da dica e do selo do maior bloco.
const Duration kMetricPulseDuration = Duration(milliseconds: 420);

/// Pílula de métrica do HUD: ícone, rótulo e valor dentro de uma caixa própria.
///
/// Substitui os textos soltos que faziam o cabeçalho parecer barra de app de
/// tarefas. Cada número ganha moldura, e a moldura é o que dá peso visual: o
/// olho lê três objetos com função, não uma linha de legenda.
class GameMetricCard extends StatelessWidget {
  const GameMetricCard({
    super.key,
    required this.label,
    required this.icon,
    required this.accent,
    this.value,
    this.valueWidget,
    this.urgent = false,
    this.pulseSeed,
    this.compact = false,
    this.hero = false,
    this.valueFontSize,
  }) : assert(
         value != null || valueWidget != null,
         'a pílula precisa de um valor para mostrar',
       );

  final String label;
  final IconData icon;

  /// Cor que assina a pílula: ícone, aro e brilho.
  final Color accent;

  /// Valor em texto. Ignorado quando [valueWidget] é dado.
  final String? value;

  /// Valor desenhado à mão, para quando ele não é texto (uma peça, por exemplo).
  final Widget? valueWidget;

  /// Liga o aro vermelho de alerta.
  final bool urgent;

  /// Dispara uma batida sempre que muda. Normalmente é o próprio valor: cada
  /// movimento gasto monta um `TweenAnimationBuilder` novo, que anima meia onda
  /// de seno e para.
  final Object? pulseSeed;

  /// Aperta o espaçamento, para quando três pílulas dividem uma tela de 375pt.
  final bool compact;

  /// Destaca levemente a pílula (borda neutra um pouco mais clara).
  ///
  /// O HUD da campanha não usa mais pílula para o saldo de movimentos — ele
  /// virou o medalhão central do `LevelBanner` —, mas o parâmetro fica para
  /// quem precisar de uma métrica principal sem recorrer a cor: a cor da borda
  /// é reservada ao alerta.
  final bool hero;

  /// Corpo do número, quando o padrão da pílula não serve.
  final double? valueFontSize;

  @override
  Widget build(BuildContext context) {
    // Borda neutra (branco a 12%) e cor só no ícone: com o tabuleiro em moldura
    // de ouro e peças coloridas, um aro tingido em cada métrica disputava a
    // atenção com o que importa. A única exceção é o alerta — aí a borda
    // **tem** de chamar o olho, e por isso só ela ganha cor e neon.
    final base = NfDecorations.card(radius: NfRadii.sm);
    final pill = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 7 : 9,
      ),
      decoration: base.copyWith(
        border: Border.all(
          color: urgent
              ? NfColors.alert
              : Colors.white.withValues(alpha: hero ? 0.18 : 0.12),
          width: 1.5,
        ),
        // Neon só na urgência: sombra acesa o tempo todo vira papel de
        // parede, e o alerta deixa de ter para onde subir.
        boxShadow: urgent
            ? [
                BoxShadow(
                  color: NfColors.alert.withValues(alpha: 0.55),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Encolhe em vez de cortar. "Maior Blo…" não diz de que "maior" se
          // trata — que é exatamente o problema que o rótulo longo veio
          // resolver —, então aqui reticência é pior que letra menor.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: compact ? 13 : 14,
                  color: urgent ? NfColors.alert : accent,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  maxLines: 1,
                  style: NfText.styleFor(
                    NfTextVariant.label,
                    size: 10.5,
                  ).copyWith(letterSpacing: 1.2, color: NfColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Encolhe em vez de cortar: um placar com reticências não é placar.
          FittedBox(
            fit: BoxFit.scaleDown,
            child:
                valueWidget ??
                Text(
                  value!,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: AppFonts.number,
                    color: urgent ? NfColors.alert : Colors.white,
                    fontSize: valueFontSize ?? (compact ? 21 : 23),
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
          ),
        ],
      ),
    );

    if (pulseSeed == null) return pill;

    // A chave é a semente: cada mudança monta um builder novo, que anima uma
    // vez e para. É o que dá batida por jogada sem uma animação em repetição.
    return TweenAnimationBuilder<double>(
      key: ValueKey(pulseSeed),
      tween: Tween(begin: 0, end: 1),
      duration: kMetricPulseDuration,
      curve: Curves.easeOut,
      builder: (context, t, child) => Transform.scale(
        // Meio ciclo de seno: sai de 1, incha e volta a 1 exatamente no fim,
        // sem degrau no fecho.
        scale: 1 + 0.10 * math.sin(math.pi * t),
        child: child,
      ),
      child: pill,
    );
  }
}
