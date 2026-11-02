import 'dart:math';

import 'package:flutter/material.dart';
import 'package:nine_fuse/core/theme/nf_tokens.dart';

/// O céu do observatório: gradiente radial azul-noite com estrelas paradas.
///
/// As estrelas são estáticas e de semente fixa, de propósito: um campo de
/// estrelas que pisca é uma animação em loop, e `pumpAndSettle` nunca
/// terminaria (ver "Toda animação nova é finita" no CLAUDE.md). Semente fixa
/// também mantém os goldens estáveis.
class NfBackground extends StatelessWidget {
  const NfBackground({super.key, this.child, this.dim = 0});

  final Widget? child;

  /// Escurece o céu (0..1). A tela de derrota usa um fundo mais escuro.
  final double dim;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(gradient: NfDecorations.sky),
    child: CustomPaint(
      painter: _StarsPainter(dim),
      child: child ?? const SizedBox.expand(),
    ),
  );
}

class _StarsPainter extends CustomPainter {
  const _StarsPainter(this.dim);

  final double dim;

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(9);
    final paint = Paint();
    // Densidade proporcional à área: tablet não fica com céu ralo.
    final count = (size.width * size.height / 3800).clamp(40, 260).round();
    for (var i = 0; i < count; i++) {
      final dx = random.nextDouble() * size.width;
      final dy = random.nextDouble() * size.height;
      final r = 0.4 + random.nextDouble() * 1.1;
      paint.color = Colors.white.withValues(
        alpha: 0.15 + random.nextDouble() * 0.55,
      );
      canvas.drawCircle(Offset(dx, dy), r, paint);
    }
    if (dim > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = NfColors.night0.withValues(alpha: dim.clamp(0, 1)),
      );
    }
  }

  @override
  bool shouldRepaint(_StarsPainter oldDelegate) => oldDelegate.dim != dim;
}
