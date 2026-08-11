import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Quanto tempo o tabuleiro treme depois de um golpe de martelo.
///
/// Curto e **finito**: uma trepidação em repetição faria `pumpAndSettle` nunca
/// terminar, e um tranco longo num tabuleiro que o jogador ainda vai tocar
/// atrasaria o próximo movimento em vez de comemorar o anterior.
const Duration kStrikeShakeDuration = Duration(milliseconds: 100);

/// Deslocamento máximo do tranco, em pontos.
const double kStrikeShakeAmplitude = 6;

/// Sacode [child] a cada golpe novo.
///
/// O sinal é [serial], e não a posição do golpe: dois golpes na mesma célula com
/// o mesmo dígito são indistinguíveis por qualquer outro campo, e o segundo não
/// sacudiria nada. É o mesmo motivo pelo qual `hammerStrikes` existe.
///
/// O tranco é do **tabuleiro**, não da tela: sacudir a tela inteira levaria o HUD
/// e o botão junto, e o que quebrou foi uma peça.
class StrikeShake extends StatefulWidget {
  const StrikeShake({super.key, required this.serial, required this.child});

  /// Quantos golpes esta partida já levou.
  final int serial;

  final Widget child;

  @override
  State<StrikeShake> createState() => _StrikeShakeState();
}

class _StrikeShakeState extends State<StrikeShake>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: kStrikeShakeDuration,
    vsync: this,
  );

  @override
  void didUpdateWidget(StrikeShake oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Só golpe novo sacode. `forward(from: 0)` em vez de `forward()` para o
    // segundo golpe reacender o tranco em curso, em vez de ser ignorado.
    if (widget.serial > oldWidget.serial) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    // O filho fica fora do `builder`: sem isso o tabuleiro inteiro seria
    // reconstruído a cada quadro do tranco.
    child: widget.child,
    builder: (context, child) {
      final t = _controller.value;
      if (t == 0 || t == 1) return child!;

      // Duas idas e voltas que morrem no fim: a amplitude decai com `1 - t`,
      // senão o tabuleiro pararia no meio de um solavanco.
      final decay = 1 - t;
      final dx = math.sin(t * 4 * math.pi) * kStrikeShakeAmplitude * decay;
      final dy =
          math.sin(t * 6 * math.pi) * kStrikeShakeAmplitude * 0.4 * decay;

      return Transform.translate(offset: Offset(dx, dy), child: child);
    },
  );
}
