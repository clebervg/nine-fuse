import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/presentation/widgets/coin_sources_card.dart';
import 'package:nine_fuse/features/game/presentation/widgets/game_dialog.dart';
import 'package:nine_fuse/features/game/providers/wallet.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Chave do cartão de resgate de derrota.
const Key continueOfferKey = Key('continue_offer');
const Key continueOfferWatchKey = Key('continue_offer_watch');
const Key continueOfferBuyKey = Key('continue_offer_buy');
const Key continueOfferDeclineKey = Key('continue_offer_decline');

/// Como o jogo pede o anúncio premiado que paga o resgate de derrota.
///
/// Unidade própria (não `movesAdProvider`/`hammerAdProvider`): é por unidade
/// que a rede reporta receita, e este funil é distinto dos outros dois —
/// paga na **derrota**, não pre-churn. Mesmo padrão: paga o jogador enquanto
/// não há SDK ligado.
final continueAdProvider = Provider<Future<bool> Function()>(
  (ref) => () async => true,
);

/// Convite de resgate, aberto quando a fase acabou de ser perdida por falta
/// de movimentos. Aceitar qualquer uma das duas opções revive a fase (volta a
/// `playing`) — é `GameNotifier.grantContinueMoves` quem faz isso.
class ContinueOfferDialog extends ConsumerStatefulWidget {
  const ContinueOfferDialog({
    super.key,
    required this.onGranted,
    required this.onDecline,
  });

  final VoidCallback onGranted;
  final VoidCallback onDecline;

  @override
  ConsumerState<ContinueOfferDialog> createState() => _ContinueOfferDialogState();
}

class _ContinueOfferDialogState extends ConsumerState<ContinueOfferDialog> {
  bool _waiting = false;
  bool _failed = false;

  Future<void> _watch() async {
    if (_waiting) return;
    setState(() {
      _waiting = true;
      _failed = false;
    });

    final granted = await ref.read(continueAdProvider)();
    if (!mounted) return;

    if (granted) {
      widget.onGranted();
      return;
    }

    setState(() {
      _waiting = false;
      _failed = true;
    });
  }

  void _buy() {
    if (_waiting) return;
    setState(() => _waiting = true);
    if (!ref.read(walletProvider.notifier).spendCoins(kContinueCoinPrice)) {
      setState(() => _waiting = false);
      return;
    }
    widget.onGranted();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wallet = ref.watch(walletProvider);
    final canAfford = wallet.canAfford(kContinueCoinPrice);

    return GameDialog(
      cardKey: continueOfferKey,
      title: l10n.continueOfferTitle,
      accent: AppColors.digit1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.replay_circle_filled_rounded, color: AppColors.digit1, size: 44),
          const SizedBox(height: 12),
          Text(
            l10n.continueOfferBody(kContinueBonusMoves),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
          if (_failed) ...[
            const SizedBox(height: 10),
            Text(
              l10n.continueOfferFailed,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.digit0, fontSize: 13),
            ),
          ],
          const SizedBox(height: 18),
          GameButton(
            key: continueOfferWatchKey,
            label: l10n.continueOfferWatch(kContinueBonusMoves),
            color: AppColors.digit1,
            icon: Icons.play_circle_fill_rounded,
            onPressed: _watch,
          ),
          const SizedBox(height: 10),
          GameButton(
            key: continueOfferBuyKey,
            label: l10n.continueOfferBuy(kContinueCoinPrice),
            color: canAfford ? AppColors.uiGold : AppColors.darkSurface,
            foreground: canAfford ? Colors.black : Colors.white38,
            icon: Icons.shopping_bag_rounded,
            onPressed: canAfford ? _buy : null,
          ),
          const SizedBox(height: 6),
          Text(
            canAfford
                ? l10n.continueOfferBalance(wallet.coins)
                : '${l10n.continueOfferNoCoins} · ${l10n.continueOfferBalance(wallet.coins)}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: canAfford ? Colors.white54 : Colors.white38,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          const CoinSourcesCard(),
          const SizedBox(height: 10),
          GameButton(
            key: continueOfferDeclineKey,
            label: l10n.continueOfferDecline,
            color: AppColors.darkSurface,
            foreground: Colors.white70,
            onPressed: widget.onDecline,
          ),
        ],
      ),
    );
  }
}
