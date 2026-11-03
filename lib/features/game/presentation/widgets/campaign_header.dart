import 'package:flutter/material.dart';
import 'package:nine_fuse/core/theme/nf_tokens.dart';
import 'package:nine_fuse/core/widgets/nf_text.dart';
import 'package:nine_fuse/features/game/domain/campaign_chapter.dart';
import 'package:nine_fuse/features/game/presentation/l10n_labels.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Chave do rótulo "CAPÍTULO N · x/y" (as estrelas do capítulo).
const Key totalStarsKey = Key('total_stars');

/// Chave do nome do capítulo.
const Key chapterLabelKey = Key('chapter_label');

/// Chave da fileira de pontos — uma por fase do capítulo.
const Key chapterDotsKey = Key('chapter_dots');

/// Placa do capítulo no topo do mapa: onde o jogador está e quanto já juntou.
///
/// Mede **estrelas**, não fases concluídas. Fase concluída é binária e para de
/// dar retorno assim que a fase passa, enquanto estrelas continuam valendo —
/// elas dão motivo para voltar a uma fase já vencida, que é o que uma contagem
/// de conclusão nunca faz.
///
/// O design mostra setas ‹ › para trocar de "mundo". Elas ficaram de fora: o
/// mapa não navega entre capítulos (a trilha é uma só, rolada), e uma seta que
/// não leva a lugar nenhum é promessa quebrada no primeiro toque.
class CampaignHeader extends StatelessWidget {
  const CampaignHeader({
    super.key,
    required this.chapter,
    required this.totalStars,
    required this.starTotal,
    required this.currentLevel,
  });

  final CampaignChapter chapter;

  /// Estrelas conquistadas no capítulo e o total em jogo nele.
  ///
  /// O denominador é o **capítulo**, não a campanha: numa campanha infinita
  /// não há total de campanha, e uma fração com denominador infinito decairia
  /// para zero para sempre. Medir o trecho atual devolve ao número um
  /// significado — quanto falta para fechar este pedaço.
  final int totalStars;
  final int starTotal;

  /// A fase da vez, que pinta o ponto alongado da fileira.
  final int currentLevel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(NfRadii.lg),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [NfColors.night3, Color(0xFF0E1640)],
        ),
        border: Border.all(color: NfColors.goldDeep, width: 2),
        boxShadow: [
          // Blur zero: é a espessura da placa, não uma sombra.
          const BoxShadow(color: Color(0xFF05081C), offset: Offset(0, 6)),
          BoxShadow(
            color: NfColors.goldDeep.withValues(alpha: 0.2),
            blurRadius: 30,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: l10n.starsSemantics(totalStars, starTotal),
            // "CAPÍTULO 1 · 5/18" lido em voz alta não diz de que é a fração;
            // a frase diz, e o texto solto não precisa ser lido de novo.
            excludeSemantics: true,
            child: Text(
              l10n.mapChapterStars(chapter.number, totalStars, starTotal),
              key: totalStarsKey,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: NfText.styleFor(
                NfTextVariant.label,
                size: 12,
                color: NfColors.gold,
              ),
            ),
          ),
          const SizedBox(height: 7),
          // Encolhe em vez de cortar: um nome de capítulo pela metade não
          // marca trecho nenhum.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: NfText.title(
              l10n.chapterName(chapter).toUpperCase(),
              key: chapterLabelKey,
              size: 25,
            ),
          ),
          const SizedBox(height: 9),
          _ChapterDots(chapter: chapter, currentLevel: currentLevel),
        ],
      ),
    );
  }
}

/// Um ponto por fase do capítulo: vencidas em ouro, a da vez alongada, as que
/// faltam apagadas.
///
/// No design os pontos indicam "qual mundo"; aqui indicam onde o jogador está
/// **dentro** do capítulo, que é a pergunta que a placa responde.
class _ChapterDots extends StatelessWidget {
  const _ChapterDots({required this.chapter, required this.currentLevel});

  final CampaignChapter chapter;
  final int currentLevel;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Row(
      key: chapterDotsKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int n = chapter.firstLevel; n <= chapter.lastLevel; n++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.5),
            child: Container(
              width: n == currentLevel ? 22 : 7,
              height: 7,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: n < currentLevel
                    ? NfColors.gold.withValues(alpha: 0.55)
                    : n == currentLevel
                    ? NfColors.gold
                    : const Color(0xFF3A4380),
              ),
            ),
          ),
      ],
    ),
  );
}
