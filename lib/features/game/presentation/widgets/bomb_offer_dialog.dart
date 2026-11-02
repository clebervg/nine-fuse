import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/core/theme/nf_tokens.dart';
import 'package:nine_fuse/core/widgets/sprite_icon.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/presentation/widgets/coin_sources_card.dart';
import 'package:nine_fuse/features/game/presentation/widgets/game_dialog.dart';
import 'package:nine_fuse/features/game/providers/wallet.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Chave do cartão de aquisição da bomba.
const Key bombOfferKey = Key('bomb_offer');

/// Chave do botão que abre o anúncio.
const Key bombOfferWatchKey = Key('bomb_offer_watch');

/// Chave do botão que troca moedas por bomba.
const Key bombOfferBuyKey = Key('bomb_offer_buy');

/// Chave do botão de recusa.
const Key bombOfferDeclineKey = Key('bomb_offer_decline');

/// Unidade própria de anúncio para a Bomba — mesma razão de todas as outras:
/// é por unidade que a rede reporta receita.
final bombAdProvider = Provider<Future<bool> Function()>(
  (ref) =>
      () async => true,
);

/// Convite de aquisição da Bomba, aberto quando o jogador mira sem estoque —
/// sibling de `HammerOfferDialog`/`ContinueOfferDialog`, e não uma
/// generalização: mesma decisão de projeto já aplicada aos mixins de
/// booster (mecânicas divergem, telas ficam separadas).
class BombOfferDialog extends ConsumerStatefulWidget {
  const BombOfferDialog({
    super.key,
    required this.onGranted,
    required this.onDecline,
  });

  final VoidCallback onGranted;
  final VoidCallback onDecline;

  @override
  ConsumerState<BombOfferDialog> createState() => _BombOfferDialogState();
}

class _BombOfferDialogState extends ConsumerState<BombOfferDialog> {
  bool _waiting = false;
  bool _failed = false;

  Future<void> _watch() async {
    if (_waiting) return;
    setState(() {
      _waiting = true;
      _failed = false;
    });

    final granted = await ref.read(bombAdProvider)();
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
    if (!ref.read(walletProvider.notifier).spendCoins(kBombCoinPrice)) {
      setState(() => _waiting = false);
      return;
    }
    widget.onGranted();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wallet = ref.watch(walletProvider);
    final canAfford = wallet.canAfford(kBombCoinPrice);

    return GameDialog(
      cardKey: bombOfferKey,
      title: l10n.bombOfferTitle,
      accent: AppColors.digit0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // A arte do booster, a mesma do dock: o convite fala do item que o
          // jogador acabou de tocar, e um ícone de fonte seria outro objeto.
          const SpriteIcon(
            asset: 'assets/images/ic_bomb.png',
            fallback: Icons.gps_fixed_rounded,
            size: 76,
            color: AppColors.digit0,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.bombOfferBody,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppFonts.display,
              color: NfColors.textSoft,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_failed) ...[
            const SizedBox(height: 10),
            Text(
              l10n.bombOfferFailed,
              textAlign: TextAlign.center,
              style: const TextStyle(color: NfColors.alert, fontSize: 13),
            ),
          ],
          const SizedBox(height: 18),
          GameButton(
            key: bombOfferWatchKey,
            label: l10n.bombOfferWatch,
            color: NfColors.gem,
            icon: Icons.play_circle_fill_rounded,
            onPressed: _watch,
          ),
          const SizedBox(height: 10),
          GameButton(
            key: bombOfferBuyKey,
            label: l10n.bombOfferBuy(kBombCoinPrice),
            color: canAfford ? AppColors.uiGold : AppColors.darkSurface,
            icon: Icons.shopping_bag_rounded,
            onPressed: canAfford ? _buy : null,
          ),
          const SizedBox(height: 6),
          Text(
            canAfford
                ? l10n.bombOfferBalance(wallet.coins)
                : '${l10n.bombOfferNoCoins} · ${l10n.bombOfferBalance(wallet.coins)}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.display,
              color: canAfford ? Colors.white54 : Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          const CoinSourcesCard(),
          const SizedBox(height: 10),
          GameButton(
            key: bombOfferDeclineKey,
            label: l10n.bombOfferDecline,
            color: AppColors.darkSurface,
            onPressed: widget.onDecline,
          ),
        ],
      ),
    );
  }
}
