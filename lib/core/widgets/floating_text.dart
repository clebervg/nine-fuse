import 'package:flutter/material.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';

/// Cor padrão do texto flutuante quando nenhuma é informada.
const Color _kDefaultColor = AppColors.digit3;

/// Cor de destaque para eventos críticos/combo.
const Color _kCriticalColor = Color(0xFFFF6D00);

const Duration _kNormalDuration = Duration(milliseconds: 700);
const Duration _kCriticalDuration = Duration(milliseconds: 800);

/// Dispara um texto numérico que sobe e desaparece na posição informada.
///
/// Independente do [JuiceOverlay] do tabuleiro: não depende de
/// `MatchEngine`/`ResolutionStep`, e insere-se no [Overlay] global, então
/// funciona a partir de qualquer [BuildContext] com um `Overlay` ancestral
/// (todo `MaterialApp`/`Scaffold` já provê um).
///
/// [position] é em coordenadas globais de tela. Autodestrói o próprio
/// [OverlayEntry] ao fim da animação — quem chama não gerencia ciclo de vida.
void showFloatingText(
  BuildContext context,
  String text, {
  required Offset position,
  Color? color,
  double fontSize = 18,
  bool isCritical = false,
}) {
  final overlay = Overlay.of(context);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _FloatingText(
      text: text,
      position: position,
      color: color ?? (isCritical ? _kCriticalColor : _kDefaultColor),
      fontSize: fontSize,
      isCritical: isCritical,
      onFinished: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _FloatingText extends StatefulWidget {
  const _FloatingText({
    required this.text,
    required this.position,
    required this.color,
    required this.fontSize,
    required this.isCritical,
    required this.onFinished,
  });

  final String text;
  final Offset position;
  final Color color;
  final double fontSize;
  final bool isCritical;
  final VoidCallback onFinished;

  @override
  State<_FloatingText> createState() => _FloatingTextState();
}

class _FloatingTextState extends State<_FloatingText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final double _riseDistance;
  late final double _popScale;

  @override
  void initState() {
    super.initState();
    _popScale = widget.isCritical ? 1.5 : 1.2;
    _riseDistance = 40 + (widget.isCritical ? 20 : 10);

    _c =
        AnimationController(
            vsync: this,
            duration: widget.isCritical ? _kCriticalDuration : _kNormalDuration,
          )
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) widget.onFinished();
          })
          ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _scaleAt(double t) {
    // Pop rápido de 0.5 a _popScale nos primeiros 14% da duração, depois
    // relaxa para 1.0 até 25%, e mantém 1.0 pelo resto do voo.
    const popEnd = 0.14;
    const settleEnd = 0.25;
    if (t < popEnd) {
      return 0.5 + (Curves.easeOutBack.transform(t / popEnd)) * (_popScale - 0.5);
    }
    if (t < settleEnd) {
      final settleT = (t - popEnd) / (settleEnd - popEnd);
      return _popScale + Curves.easeOut.transform(settleT) * (1.0 - _popScale);
    }
    return 1.0;
  }

  double _opacityAt(double t) {
    // Some nos últimos 0.3s da duração total, cheio até lá.
    final totalSeconds = _c.duration!.inMilliseconds / 1000;
    final fadeStart = 1 - (0.3 / totalSeconds);
    if (t < fadeStart) return 1.0;
    return (1 - (t - fadeStart) / (1 - fadeStart)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.position.dx,
      top: widget.position.dy,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            final t = _c.value;
            return Transform.translate(
              offset: Offset(0, -_riseDistance * Curves.easeOut.transform(t)),
              child: Opacity(
                opacity: _opacityAt(t),
                child: Transform.scale(scale: _scaleAt(t), child: child),
              ),
            );
          },
          child: Text(
            widget.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              shadows: [
                Shadow(color: widget.color, blurRadius: 8),
                const Shadow(color: Colors.black87, blurRadius: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
