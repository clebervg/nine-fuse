import 'package:flutter/material.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/features/game/domain/campaign_chapter.dart';
import 'package:nine_fuse/features/game/presentation/l10n_labels.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Chave do bloco inteiro, para o cartão de vitória afirmar que ele está lá.
const Key chapterStarProgressKey = Key('chapter_star_progress');

/// Chave da parte preenchida da barra. É por ela que o teste lê a fração
/// desenhada em cada quadro.
const Key chapterStarFillKey = Key('chapter_star_fill');

/// Quanto o jogador já juntou do capítulo, e o que esta fase acrescentou.
///
/// Mora num arquivo próprio, e não em `level_outcome_card.dart`: aquele já
/// carrega estrelas, confetes e botões, e uma barra de progresso de capítulo só
/// faz sentido na **vitória** — nenhuma das duas derrotas tem o que somar.
class ChapterStarProgress extends StatelessWidget {
  const ChapterStarProgress({
    super.key,
    required this.chapter,
    required this.starsInChapter,
    required this.starsGained,
  });

  final CampaignChapter chapter;

  /// Total de estrelas do capítulo **já incluindo** o que esta fase rendeu.
  final int starsInChapter;

  /// Quantas entraram agora. Zero quando o jogador rejogou sem melhorar a
  /// nota — e aí a barra não anima, porque não houve ganho para mostrar.
  final int starsGained;

  /// Toca uma vez e para. Animação em repetição faz `pumpAndSettle` nunca
  /// terminar e derruba a suíte de widget — mesma regra do brilho da dica, do
  /// pulso do mapa e do selo do maior bloco.
  static const Duration fillDuration = Duration(milliseconds: 900);

  double get _fraction => _fractionOf(starsInChapter);

  double get _previousFraction => _fractionOf(starsInChapter - starsGained);

  double _fractionOf(int stars) {
    final total = chapter.starTotal;
    if (total <= 0) return 0;
    return (stars / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = l10n.chapterTitle(chapter);

    return Semantics(
      key: chapterStarProgressKey,
      // Sem isto o leitor anuncia a frase e **depois** "12/18" e o título
      // soltos, que é a mesma ambiguidade que a frase existe para resolver.
      excludeSemantics: true,
      label: l10n.chapterStarsSemantics(
        starsInChapter,
        chapter.starTotal,
        title,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.display,
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$starsInChapter/${chapter.starTotal}',
                    style: const TextStyle(
                      fontFamily: AppFonts.display,
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.star_rounded,
                    size: 15,
                    color: AppColors.digit3,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          _Track(from: _previousFraction, to: _fraction),
        ],
      ),
    );
  }
}

/// A trilha e a parte preenchida.
class _Track extends StatelessWidget {
  const _Track({required this.from, required this.to});

  final double from;
  final double to;

  static const double _height = 7;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(_height / 2),
    child: SizedBox(
      height: _height,
      width: double.infinity,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: AppColors.darkBackground),
        // `TweenAnimationBuilder` anima de `begin` até `end` na primeira
        // construção, que é exatamente o que se quer aqui: o cartão aparece
        // com o total antigo e ele sobe sozinho. Sem ganho, `begin == end` e
        // nada se move.
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: from, end: to),
          duration: ChapterStarProgress.fillDuration,
          curve: Curves.easeOutCubic,
          // A chave fica no `FractionallySizedBox` porque é ele que carrega a
          // fração desenhada — é o que o teste mede a cada quadro.
          builder: (context, value, _) => FractionallySizedBox(
            key: chapterStarFillKey,
            alignment: Alignment.centerLeft,
            widthFactor: value,
            // Sem `heightFactor: 1` um `DecoratedBox` sem filho colapsa para
            // altura zero e a barra some — foi o que aconteceu com a barra do
            // objetivo no HUD, e nenhum teste acusou.
            heightFactor: 1,
            child: const DecoratedBox(
              decoration: BoxDecoration(color: AppColors.digit3),
            ),
          ),
        ),
      ),
    ),
  );
}
