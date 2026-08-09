import 'package:flutter/material.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';
import 'package:nine_fuse/core/juice_timings.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';

const Key comboBannerKey = Key('combo_banner');

/// O que o aviso central anuncia. Só um por vez: dois textos disputando o
/// centro da tela cancelam um ao outro.
enum _Announcement { superFuse, comboTwo, comboMany }

/// O que merece anúncio nesta cascata.
///
/// A cascata vale mais que o tamanho da combinação: encadear é mais difícil e
/// mais raro, então quando os dois acontecem o combo é o que se anuncia.
_Announcement? _announcementFor(ResolutionStep? step, int combo) {
  if (step == null) return null;
  if (combo >= 3) return _Announcement.comboMany;
  if (combo == 2) return _Announcement.comboTwo;
  if (step.hasBigFusion) return _Announcement.superFuse;
  return null;
}

/// Aviso central de combo ou super fusão.
///
/// Aparece, dá um solavanco e some. Vive fora do tabuleiro porque é feedback
/// da jogada inteira, não de uma célula.
class ComboBanner extends StatefulWidget {
  const ComboBanner({super.key, required this.step, required this.comboCount});

  final ResolutionStep? step;
  final int comboCount;

  @override
  State<ComboBanner> createState() => _ComboBannerState();
}

class _ComboBannerState extends State<ComboBanner>
    with SingleTickerProviderStateMixin {
  /// Criado no [initState], e não como `late final`.
  ///
  /// Quando não há aviso a mostrar, o campo nunca seria acessado durante a
  /// vida do widget — e o `dispose()` acabaria sendo quem o inicializa,
  /// construindo um `AnimationController` no meio do desmonte da árvore.
  late AnimationController _c;

  _Announcement? _showing;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: JuiceTimings.banner);
  }

  @override
  void didUpdateWidget(ComboBanner old) {
    super.didUpdateWidget(old);

    final next = _announcementFor(widget.step, widget.comboCount);
    // Reinicia só quando há anúncio novo: cascatas seguidas devem reacender o
    // aviso, e não deixá-lo congelado do primeiro passo.
    if (next != null && !identical(widget.step, old.step)) {
      setState(() => _showing = next);
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  ({String text, Color color, bool shake}) _style(
    _Announcement a,
    AppLocalizations l10n,
  ) => switch (a) {
    _Announcement.superFuse => (
      text: l10n.comboSuperFusion,
      color: AppColors.digit7,
      shake: false,
    ),
    _Announcement.comboTwo => (
      text: l10n.comboTwo,
      color: AppColors.digit3,
      shake: false,
    ),
    _Announcement.comboMany => (
      text: l10n.comboMany(widget.comboCount),
      color: AppColors.digit4,
      shake: true,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final showing = _showing;
    if (showing == null) return const SizedBox.shrink();

    final style = _style(showing, AppLocalizations.of(context));

    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            final t = _c.value;
            if (t == 0 || t == 1) return const SizedBox.shrink();

            // Entra crescendo, segura, e sobe sumindo.
            final scale = t < 0.2
                ? Curves.easeOutBack.transform(t / 0.2) * 0.4 + 0.7
                : 1.1;
            final opacity = t < 0.15
                ? t / 0.15
                : (t > 0.7 ? (1 - (t - 0.7) / 0.3) : 1.0);
            final lift = t > 0.7 ? -28 * ((t - 0.7) / 0.3) : 0.0;
            // O balanço só no combo alto, senão vira ruído em toda jogada.
            final tilt = style.shake
                ? 0.05 * (1 - t) * (t * 28 % 2 < 1 ? 1 : -1)
                : 0.0;

            return Opacity(
              opacity: opacity.clamp(0, 1),
              child: Transform.translate(
                offset: Offset(0, lift),
                child: Transform.rotate(
                  angle: tilt,
                  child: Transform.scale(scale: scale, child: child),
                ),
              ),
            );
          },
          child: Container(
            key: comboBannerKey,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: style.color, width: 2),
              boxShadow: [
                BoxShadow(
                  color: style.color.withValues(alpha: 0.55),
                  blurRadius: 22,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Text(
              style.text,
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: style.color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
