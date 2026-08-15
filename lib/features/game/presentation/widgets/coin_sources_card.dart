import 'package:flutter/material.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Chave do cartão que lista de onde vêm as moedas.
const Key coinSourcesKey = Key('coin_sources');

/// As torneiras de moeda do jogo, listadas onde a moeda é gasta.
///
/// Nasceu dentro do convite do martelo e saiu para arquivo próprio quando a
/// loja de moedas do header passou a precisar da mesma lista: duas cópias
/// divergiriam na primeira torneira nova, e o jogador leria fontes diferentes
/// dependendo de qual caixa abriu.
///
/// Fica no rodapé de quem gasta, e não numa tela de ajuda: é ali que o jogador
/// descobre que o saldo não cobre o preço, e é ali que a pergunta "e como eu
/// consigo mais?" nasce. Respondê-la em outra tela é responder tarde.
class CoinSourcesCard extends StatelessWidget {
  const CoinSourcesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      key: coinSourcesKey,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.digit3.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.coinSourcesTitle.toUpperCase(),
            style: const TextStyle(
              color: AppColors.digit3,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          _CoinSource(icon: Icons.star_rounded, label: l10n.coinSourcesStars),
          _CoinSource(
            icon: Icons.ondemand_video_rounded,
            label: l10n.coinSourcesAds,
          ),
          _CoinSource(icon: Icons.flag_rounded, label: l10n.coinSourcesChests),
        ],
      ),
    );
  }
}

/// Uma linha da lista: ícone e frase, sem promessa de valor.
///
/// Sem número ao lado: `kCoinsPerStar` e `kChapterChestReward` vão ser
/// recalibrados, e um valor escrito na tela viraria promessa desatualizada no
/// primeiro ajuste de balanceamento.
class _CoinSource extends StatelessWidget {
  const _CoinSource({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Icon(icon, size: 14, color: AppColors.digit3),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12.5),
          ),
        ),
      ],
    ),
  );
}
