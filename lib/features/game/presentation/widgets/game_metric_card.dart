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

  /// Promove a pílula a cartão principal do HUD.
  ///
  /// Três caixas do mesmo tamanho, com a mesma borda e o mesmo peso, dizem que
  /// as três informações valem o mesmo — e não valem: os pontos são placar, o
  /// objetivo é consulta, e o **saldo de movimentos** é o relógio que decide a
  /// fase. O destaque é o que dá hierarquia sem precisar de um rótulo dizendo
  /// "olhe aqui": aro em degradê quente, base mais funda e número maior.
  final bool hero;

  /// Corpo do número, quando o padrão da pílula não serve.
  final double? valueFontSize;

  @override
  Widget build(BuildContext context) {
    final ring = urgent ? AppColors.digit0 : accent;

    // A borda é um degradê, e por isso é uma **caixa por fora** e não um
    // `Border.all`: `BoxBorder` só aceita cor chapada. O aro claro em cima
    // descendo para escuro embaixo é o que faz a peça parecer iluminada de
    // cima, como as do tabuleiro — um contorno de cor única lê como contorno
    // de formulário.
    final pill = Container(
      padding: EdgeInsets.all(urgent || hero ? 2 : 1.4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: hero && !urgent
              ? [
                  AppColors.lighten(AppColors.digit3, 0.35),
                  AppColors.digit4.withValues(alpha: 0.75),
                ]
              : [
                  ring.withValues(alpha: urgent ? 1 : 0.72),
                  ring.withValues(alpha: urgent ? 0.7 : 0.18),
                ],
        ),
        boxShadow: [
          if (urgent)
            // Neon vermelho só na urgência: aceso o tempo todo, deixaria de
            // significar alguma coisa.
            BoxShadow(
              color: AppColors.digit0.withValues(alpha: 0.5),
              blurRadius: 16,
              spreadRadius: 1,
            )
          else if (hero)
            BoxShadow(
              color: AppColors.digit3.withValues(alpha: 0.32),
              blurRadius: 14,
            ),
          // A base projetada é o que dá os três de "3D": a caixa passa a ter
          // um lado de baixo, em vez de estar colada no fundo. Mais funda no
          // cartão principal, porque quem está mais à frente projeta mais
          // longe.
          BoxShadow(
            color: const Color(0xB3000000),
            blurRadius: hero ? 14 : 10,
            offset: Offset(0, hero ? 6 : 4),
          ),
        ],
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: compact ? 8 : 10,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14.5),
          // Escuro translúcido com um fio da cor no topo: é o "brilho interno"
          // que separa a pílula do fundo sem clarear a caixa inteira. No cartão
          // principal o fundo puxa para o quente, para ele se distinguir dos
          // irmãos mesmo em foto sem cor de aro visível.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(
                const Color(0xFF23232B),
                hero && !urgent ? AppColors.digit4 : ring,
                hero ? 0.22 : 0.16,
              )!,
              hero && !urgent
                  ? const Color(0xFF1A1512)
                  : const Color(0xFF141419),
            ],
          ),
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
                      fontSize: valueFontSize ?? (compact ? 20 : 22),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
            ),
          ],
        ),
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
