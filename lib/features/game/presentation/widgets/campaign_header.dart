import 'package:flutter/material.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/features/game/domain/campaign_chapter.dart';
import 'package:nine_fuse/features/game/presentation/l10n_labels.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Chave do contador de estrelas totais.
const Key totalStarsKey = Key('total_stars');

/// Chave do nome do capítulo.
const Key chapterLabelKey = Key('chapter_label');

/// Barra de status do mapa: o que o jogador acumulou e onde ele está.
///
/// Substitui a linha de texto "3 de 10 fases concluídas". A diferença não é
/// enfeite: fase concluída é binária e para de dar retorno assim que a fase
/// passa, enquanto estrelas continuam valendo — elas dão motivo para voltar a
/// uma fase já vencida, que é o que uma contagem de conclusão nunca faz.
class CampaignHeader extends StatelessWidget {
  const CampaignHeader({
    super.key,
    required this.chapter,
    required this.totalStars,
    required this.starTotal,
  });

  final CampaignChapter chapter;

  /// Estrelas conquistadas e o total em jogo.
  ///
  /// É a única moeda do cabeçalho, de propósito. O NineFuse não tem trava de
  /// vidas nem energia, e um medidor desses no topo prometeria uma mecânica que
  /// o jogo não tem — o valor ficaria parado, ou pior, sugeriria que em algum
  /// momento vai acabar.
  final int totalStars;
  final int starTotal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        children: [
          // Estrelas à esquerda, capítulo ao centro da barra.
          //
          // O capítulo é centralizado em relação ao **cartão**, não ao espaço
          // que sobra: um `Row` com o contador na frente empurraria o título
          // para a direita, e ele deixaria de parecer o cabeçalho da tela.
          // Daí o `Stack` com `Center` — e a reserva lateral que impede o
          // título de passar por baixo do contador numa tela estreita.
          Row(
            children: [
              // A legenda "CAMPANHA" não é enfeite. O contador é da campanha
              // inteira (30 estrelas nas 10 fases), mas fica lado a lado com o
              // nome de um **capítulo**, que cobre só um trecho dela — e o olho
              // lê os dois como se falassem da mesma coisa. Relato real: "de
              // onde vem 23/30 no Capítulo 2?", sendo que o capítulo 2 tem 4
              // fases e 12 estrelas. A palavra é justamente a que contrasta
              // com "Capítulo" ao lado.
              _Stat(
                key: totalStarsKey,
                icon: Icons.star_rounded,
                color: AppColors.digit3,
                label: '$totalStars/$starTotal',
                caption: l10n.starsCaption,
                semanticLabel: l10n.starsSemantics(totalStars, starTotal),
              ),
              const SizedBox(width: 12),
              // O título fica centralizado no espaço que sobra, e não no
              // cartão inteiro. Centralizar no cartão exigiria reservar à
              // direita a mesma largura do contador — espaço que ninguém
              // ocupa —, e o nome do capítulo passaria a ser cortado numa tela
              // de celular. Nome inteiro vale mais que simetria exata.
              Expanded(
                child: Text(
                  l10n.chapterTitle(chapter),
                  key: chapterLabelKey,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.display,
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // A barra mede **estrelas**, não fases: é a régua que continua
          // subindo depois de a campanha ser concluída.
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: starTotal == 0 ? 0 : (totalStars / starTotal).clamp(0, 1),
              minHeight: 5,
              backgroundColor: AppColors.darkBackground,
              valueColor: const AlwaysStoppedAnimation(AppColors.digit3),
            ),
          ),
        ],
      ),
    );
  }
}

/// Um número com o seu ícone e a legenda do que ele conta.
class _Stat extends StatelessWidget {
  const _Stat({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.caption,
    required this.semanticLabel,
  });

  final IconData icon;
  final Color color;
  final String label;

  /// O que o número mede. Fica **abaixo** dele, e não ao lado, porque a linha
  /// já divide espaço com o nome do capítulo: numa tela de 375pt qualquer
  /// palavra a mais na horizontal passa a comer o título.
  final String caption;

  /// A mesma informação em frase, para leitor de tela.
  ///
  /// "23/30" lido em voz alta não diz de que é a fração — e é justamente essa
  /// ambiguidade que a legenda resolve para quem enxerga.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    // Sem isto o leitor de tela anunciaria a frase **e** depois "23/30" e
    // "CAMPANHA" soltos, repetindo a mesma informação três vezes.
    excludeSemantics: true,
    child: Column(
      // `min` é obrigatório: dentro de um `Align`, um `Row` recebe restrição
      // frouxa e com `max` ele estica pela largura toda, centralizando o
      // conteúdo — o contador ia parar no meio do cabeçalho, por cima do
      // nome do capítulo.
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppFonts.display,
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        Text(
          caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: AppFonts.display,
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ],
    ),
  );
}
