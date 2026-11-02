import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/core/theme/nf_tokens.dart';
import 'package:nine_fuse/core/widgets/nf_text.dart';
import 'package:nine_fuse/features/game/presentation/widgets/game_dialog.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Chaves para os testes endereçarem o tutorial.
const Key tutorialBalloonKey = Key('tutorial_balloon');
const Key tutorialSkipKey = Key('tutorial_skip');
const Key tutorialGotItKey = Key('tutorial_got_it');
const Key tutorialHandKey = Key('tutorial_hand');
const Key tutorialVeilKey = Key('tutorial_veil');

/// Um gesto da mão: encostar, arrastar até a vizinha e soltar.
const Duration kTutorialHandStroke = Duration(milliseconds: 1100);

/// Quantas vezes a mão repete o gesto antes de parar.
///
/// **Finito de propósito**, como toda animação do jogo: em repetição o
/// `pumpAndSettle` nunca terminaria. Três vezes basta para o olho pegar o
/// movimento; depois disso a mão descansa sobre a primeira peça, e o balão
/// continua dizendo o que fazer.
const int kTutorialHandStrokes = 3;

/// Quanto um balão informativo fica no ar sem toque.
const Duration kTutorialAutoClose = Duration(seconds: 6);

/// Entrada do balão.
const Duration kTutorialEntry = Duration(milliseconds: 220);

/// Uma camada do tutorial: destaque nos alvos, balão e, na primeira jogada, a
/// mão.
///
/// **Não toma o toque do tabuleiro.** Véu, aros e mão ignoram o dedo; só o
/// balão o recebe. É o que deixa o jogador fazer **qualquer** troca válida
/// enquanto a mão mostra uma — prender o primeiro movimento a uma jogada só
/// ensinaria a obedecer, não a enxergar trios.
///
/// Os alvos chegam em coordenadas globais por [locate], perguntado a cada
/// quadro de layout: o tabuleiro e o dock mudam de lugar (a faixa de dica
/// entra e sai), e um aro medido uma vez só ficaria para trás.
class TutorialLayer extends StatefulWidget {
  const TutorialLayer({
    super.key,
    required this.message,
    required this.locate,
    required this.onSkip,
    this.onClose,
    this.veil = false,
    this.hand = false,
  });

  final String message;

  /// Retângulos a destacar, em coordenadas globais. Vazio = balão sem alvo.
  final List<Rect> Function() locate;

  /// Escurece tudo menos os alvos (a primeira jogada).
  final bool veil;

  /// A mão arrasta do primeiro alvo para o segundo.
  final bool hand;

  /// Balão informativo: fecha com "Entendi", com toque nele ou sozinho depois
  /// de [kTutorialAutoClose]. Nulo = só fecha quando a tela decidir (a
  /// primeira jogada fecha ao jogar).
  final VoidCallback? onClose;

  /// "Pular tutorial": marca tudo como visto.
  final VoidCallback onSkip;

  @override
  State<TutorialLayer> createState() => _TutorialLayerState();
}

class _TutorialLayerState extends State<TutorialLayer>
    with TickerProviderStateMixin {
  final GlobalKey _selfKey = GlobalKey();

  /// Alvos em coordenadas desta camada. Vazio até o primeiro layout.
  List<Rect> _targets = const [];

  late final AnimationController _entry = AnimationController(
    duration: kTutorialEntry,
    vsync: this,
  )..forward();

  late final AnimationController _handController = AnimationController(
    duration: kTutorialHandStroke * kTutorialHandStrokes,
    vsync: this,
  );

  late final AnimationController _life = AnimationController(
    duration: kTutorialAutoClose,
    vsync: this,
  );

  bool _closed = false;

  @override
  void initState() {
    super.initState();
    if (widget.hand) _handController.forward();
    if (widget.onClose != null) {
      _life
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) _close();
        })
        ..forward();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void dispose() {
    _entry.dispose();
    _handController.dispose();
    _life.dispose();
    super.dispose();
  }

  void _close() {
    if (_closed) return;
    _closed = true;
    widget.onClose?.call();
  }

  void _measure() {
    if (!mounted) return;
    final self = _selfKey.currentContext?.findRenderObject();
    if (self is! RenderBox || !self.hasSize) return;

    final origin = self.localToGlobal(Offset.zero);
    final local = [for (final r in widget.locate()) r.shift(-origin)];
    if (!_sameRects(local, _targets)) setState(() => _targets = local);
  }

  static bool _sameRects(List<Rect> a, List<Rect> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Rect? get _union => _targets.isEmpty
      ? null
      : _targets
            .skip(1)
            .fold<Rect>(_targets.first, (u, r) => u.expandToInclude(r));

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          key: _selfKey,
          fit: StackFit.expand,
          children: [
            if (widget.veil) _veil(),
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _entry,
                builder: (context, _) => CustomPaint(
                  painter: _RingPainter(targets: _targets, t: _entry.value),
                ),
              ),
            ),
            if (widget.hand && _targets.length >= 2) _hand(),
            _balloon(context, constraints.biggest),
          ],
        ),
      ),
    );
  }

  Widget _veil() {
    final union = _union;
    final hole = union?.inflate(6);
    return IgnorePointer(
      key: tutorialVeilKey,
      // O `ClipRect` limita o `BackdropFilter` ao que está na camada — sem ele
      // o filtro lê o fundo da árvore inteira, e o tabuleiro animado engasga.
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _entry,
          builder: (context, _) {
            final t = _entry.value;
            final scrim = BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 2 * t, sigmaY: 2 * t),
              // Alfa na cor, e não `Opacity`: a suíte usa esse tipo como
              // marcador de outros efeitos.
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.55 * t),
                child: const SizedBox.expand(),
              ),
            );
            if (hole == null) return scrim;
            return ClipPath(clipper: _HoleClipper(hole), child: scrim);
          },
        ),
      ),
    );
  }

  Widget _hand() {
    final from = _targets[0].center;
    final to = _targets[1].center;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _handController,
        builder: (context, _) {
          final total = _handController.value * kTutorialHandStrokes;
          // Terminado o último gesto, a mão descansa sobre a peça de partida:
          // o convite continua apontado sem continuar se mexendo.
          final phase = _handController.isCompleted
              ? 0.0
              : total - total.floor();
          // Encosta (0-0,2), arrasta (0,2-0,7), segura na vizinha (0,7-1).
          final travel = Curves.easeInOut.transform(
            ((phase - 0.2) / 0.5).clamp(0.0, 1.0),
          );
          final at = Offset.lerp(from, to, travel)!;
          const size = 46.0;
          return Stack(
            children: [
              Positioned(
                // A ponta do dedo do ícone fica no alto, um pouco à esquerda
                // do centro: é ela que tem de tocar a peça.
                left: at.dx - size * 0.42,
                top: at.dy - size * 0.12,
                child: const Icon(
                  Icons.touch_app_rounded,
                  key: tutorialHandKey,
                  size: size,
                  color: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _balloon(BuildContext context, Size size) {
    final l10n = AppLocalizations.of(context);
    final union = _union;
    const gap = 14.0;

    // Acima ou abaixo do alvo, do lado que tem mais tela; sem alvo, no terço
    // de cima, onde não cobre o meio do tabuleiro.
    final double? top;
    final double? bottom;
    if (union == null) {
      top = size.height * 0.3;
      bottom = null;
    } else if (union.center.dy < size.height / 2) {
      top = math.min(union.bottom + gap, size.height - 160);
      bottom = null;
    } else {
      top = null;
      bottom = math.min(size.height - union.top + gap, size.height - 160);
    }

    final closable = widget.onClose != null;
    final card = GestureDetector(
      key: tutorialBalloonKey,
      behavior: HitTestBehavior.opaque,
      onTap: closable ? _close : null,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
        decoration: NfDecorations.panel(radius: NfRadii.md, borderWidth: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppFonts.display,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                height: 1.3,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            if (closable) ...[
              GameButton(
                key: tutorialGotItKey,
                label: l10n.tutorialGotIt,
                color: NfColors.gold,
                expand: false,
                fontSize: 14,
                onPressed: _close,
              ),
              const SizedBox(height: 4),
            ],
            // Discreto de propósito: quem já sabe jogar acha a saída, e quem
            // está aprendendo não é convidado a pular.
            GestureDetector(
              key: tutorialSkipKey,
              behavior: HitTestBehavior.opaque,
              onTap: widget.onSkip,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 12,
                ),
                child: NfText.label(
                  l10n.tutorialSkip,
                  color: NfColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Positioned(
      left: 16,
      right: 16,
      top: top,
      bottom: bottom,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: AnimatedBuilder(
            animation: _entry,
            builder: (context, child) => Transform.scale(
              scale: 0.9 + 0.1 * Curves.easeOutBack.transform(_entry.value),
              child: child,
            ),
            child: card,
          ),
        ),
      ),
    );
  }
}

/// O véu cobre tudo menos [hole].
class _HoleClipper extends CustomClipper<Path> {
  const _HoleClipper(this.hole);

  final Rect hole;

  @override
  Path getClip(Size size) => Path.combine(
    PathOperation.difference,
    Path()..addRect(Offset.zero & size),
    Path()..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(14))),
  );

  @override
  bool shouldReclip(_HoleClipper oldClipper) => oldClipper.hole != hole;
}

/// Aro de ouro em volta de cada alvo — ouro é o que é tocável.
class _RingPainter extends CustomPainter {
  const _RingPainter({required this.targets, required this.t});

  final List<Rect> targets;

  /// Entrada, de 0 a 1: o aro acende junto com o balão e para aceso.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final target in targets) {
      final rrect = RRect.fromRectAndRadius(
        target.inflate(4),
        const Radius.circular(14),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = NfColors.gold.withValues(alpha: t)
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = NfColors.goldLight.withValues(alpha: t),
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.t != t || !identical(oldDelegate.targets, targets);
}
