import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:nine_fuse/core/theme/nf_tokens.dart';

/// Abre [child] como modal sobre o céu desfocado.
///
/// Para caixas abertas **fora** de uma partida (roleta, loja). Dentro da fase
/// as caixas continuam sendo camadas do `Stack` da tela — uma rota por cima
/// tiraria o tabuleiro da árvore de foco (ver `GameDialog`).
///
/// Entrada em 320ms com `easeOutBack` (escala 0,85 → 1); saída em 180ms sem
/// elástico. [elastic] troca a entrada por `elasticOut` — só para vitória, em
/// que o exagero é o ponto.
Future<T?> showNfModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool elastic = false,
}) => showGeneralDialog<T>(
  context: context,
  barrierDismissible: barrierDismissible,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  // O véu é desenhado no `transitionBuilder` (blur + escurecido); a barreira
  // do Navigator só captura o toque.
  barrierColor: Colors.transparent,
  transitionDuration: NfDurations.modal,
  pageBuilder: (context, _, _) =>
      SafeArea(child: Center(child: Builder(builder: builder))),
  transitionBuilder: (context, animation, _, child) {
    final reversing = animation.status == AnimationStatus.reverse;
    final curve = reversing
        ? Curves.easeIn
        : (elastic ? Curves.elasticOut : Curves.easeOutBack);
    final curved = CurvedAnimation(parent: animation, curve: curve);
    return Stack(
      children: [
        // O véu fica fora da escala: encolher o blur junto com a caixa
        // deixaria a borda dele à mostra no começo da entrada.
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                final t = animation.value.clamp(0.0, 1.0);
                return BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8 * t, sigmaY: 8 * t),
                  child: ColoredBox(
                    color: NfColors.night0.withValues(alpha: 0.45 * t),
                  ),
                );
              },
            ),
          ),
        ),
        FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1).animate(curved),
            child: child,
          ),
        ),
      ],
    );
  },
);
