import 'dart:math';

import 'package:flutter/material.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';

/// Chave do aviso de fusão máxima.
const Key apexCelebrationKey = Key('apex_celebration');

/// Quanto tempo o aviso fica na tela.
///
/// Curto de propósito: é comemoração, não interrupção — o jogador acabou de
/// fazer a jogada mais difícil do jogo e não pode ser obrigado a esperar um
/// cartão para continuar.
const Duration kApexCelebrationDuration = Duration(milliseconds: 1800);

/// Comemoração da primeira fusão máxima da partida.
///
/// Aparece **uma vez por partida**: repetir a cada 9 transformaria a conquista
/// em ruído, e o clarão da explosão já marca as vezes seguintes.
///
/// Flutua sobre o tabuleiro e não intercepta toque — um `SnackBar` roubaria o
/// foco e empurraria o tabuleiro para cima justamente no quadro em que o
/// jogador está olhando para a explosão.
class ApexCelebration extends StatefulWidget {
  const ApexCelebration({super.key, this.onFinished});

  /// Chamado quando o aviso termina, para quem quiser limpar o estado.
  final VoidCallback? onFinished;

  @override
  State<ApexCelebration> createState() => _ApexCelebrationState();
}

class _ApexCelebrationState extends State<ApexCelebration>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  /// Direções sorteadas uma vez, com semente fixa. Sorteadas no `build`, os
  /// confetes saltariam de lugar a cada quadro em vez de voar em linha.
  late final List<_Confetti> _confetti;

  @override
  void initState() {
    super.initState();

    final random = Random(91);
    _confetti = [
      for (int i = 0; i < 28; i++)
        _Confetti(
          x: random.nextDouble(),
          delay: random.nextDouble() * 0.25,
          drift: (random.nextDouble() - 0.5) * 0.35,
          size: 3 + random.nextDouble() * 4,
          spin: (random.nextDouble() - 0.5) * 6,
          color: [
            AppColors.digit9,
            AppColors.digit9Deep,
            Colors.white,
            AppColors.digit6,
          ][i % 4],
        ),
    ];

    // Criado aqui, e não como `late final`: um campo preguiçoso pode acabar
    // sendo inicializado pelo próprio `dispose()`, construindo um controlador
    // no meio do desmonte da árvore.
    _c = AnimationController(vsync: this, duration: kApexCelebrationDuration)
      ..forward().whenComplete(() {
        if (mounted) widget.onFinished?.call();
      });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = _c.value;
          // Entra crescendo, fica legível no meio, some no fim. Aparecer e
          // sumir ao mesmo tempo deixaria a frase ilegível justamente na
          // conquista mais rara do jogo.
          final grow = Curves.easeOutBack.transform((t / 0.2).clamp(0.0, 1.0));
          final opacity = t < 0.75 ? 1.0 : 1 - (t - 0.75) / 0.25;

          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _ConfettiPainter(_confetti, t)),
              Align(
                alignment: const Alignment(0, -0.55),
                child: Opacity(
                  opacity: opacity.clamp(0, 1),
                  child: Transform.scale(scale: 0.7 + grow * 0.3, child: child),
                ),
              ),
            ],
          );
        },
        child: Container(
          key: apexCelebrationKey,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.digit9, width: 2),
            boxShadow: AppColors.apexGlow(scale: 0.8, spread: 1),
          ),
          child: Text(
            AppLocalizations.of(context).apexCelebration,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppFonts.display,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// Um confete: onde nasce, para onde deriva e de que cor.
class _Confetti {
  const _Confetti({
    required this.x,
    required this.delay,
    required this.drift,
    required this.size,
    required this.spin,
    required this.color,
  });

  /// Fração da largura em que nasce.
  final double x;

  /// Fração do tempo total antes de começar a cair.
  final double delay;

  /// Deslocamento horizontal ao longo da queda, em fração da largura.
  final double drift;

  final double size;

  /// Voltas dadas durante a queda.
  final double spin;

  final Color color;
}

/// Num `CustomPainter` e não num widget por confete: são dezenas, e cada widget
/// custaria layout a cada quadro para algo puramente decorativo.
class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter(this.confetti, this.t);

  final List<_Confetti> confetti;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    for (final piece in confetti) {
      final local = ((t - piece.delay) / (1 - piece.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;

      // Some no último terço: confete que desaparece de repente parece
      // travamento de quadro.
      final fade = local < 0.65 ? 1.0 : 1 - (local - 0.65) / 0.35;

      final dx = (piece.x + piece.drift * local) * size.width;
      // Acelera ao cair, como o olho espera de algo largado no ar.
      final dy = Curves.easeInQuad.transform(local) * size.height;

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(piece.spin * local);
      paint.color = piece.color.withValues(alpha: fade.clamp(0, 1));
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: piece.size,
          height: piece.size * 1.8,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => oldDelegate.t != t;
}
