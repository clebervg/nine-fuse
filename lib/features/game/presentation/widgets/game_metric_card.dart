import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';

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

  @override
  Widget build(BuildContext context) {
    final ring = urgent ? AppColors.digit0 : accent;

    final pill = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        // Escuro translúcido com um fio da cor no topo: é o "brilho interno"
        // que separa a pílula do fundo sem clarear a caixa inteira.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(const Color(0xFF23232B), ring, 0.16)!,
            const Color(0xFF141419),
          ],
        ),
        border: Border.all(
          color: ring.withValues(alpha: urgent ? 0.95 : 0.45),
          width: urgent ? 2 : 1.4,
        ),
        boxShadow: [
          if (urgent)
            // Neon vermelho só na urgência: aceso o tempo todo, deixaria de
            // significar alguma coisa.
            BoxShadow(
              color: AppColors.digit0.withValues(alpha: 0.5),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          const BoxShadow(
            color: Color(0x80000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
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
                Icon(icon, size: compact ? 13 : 14, color: ring),
                const SizedBox(width: 5),
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          // Encolhe em vez de cortar: um placar com reticências não é placar.
          FittedBox(
            fit: BoxFit.scaleDown,
            child:
                valueWidget ??
                Text(
                  value!,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    color: urgent ? AppColors.digit0 : Colors.white,
                    fontSize: compact ? 20 : 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
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
