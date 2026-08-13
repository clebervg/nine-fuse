import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/presentation/widgets/game_dialog.dart';
import 'package:nine_fuse/features/game/providers/wallet.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Chave do cartão de aquisição do martelo.
const Key hammerOfferKey = Key('hammer_offer');

/// Chave do botão que abre o anúncio.
const Key hammerOfferWatchKey = Key('hammer_offer_watch');

/// Chave do botão de recusa.
const Key hammerOfferDeclineKey = Key('hammer_offer_decline');

/// Chave do botão que troca moedas por martelo.
const Key hammerOfferBuyKey = Key('hammer_offer_buy');

/// Como o jogo pede um anúncio premiado, e o que ele responde.
///
/// `true` significa "o jogador assistiu até o fim, pague-o". É um provider, e
/// não uma chamada direta, porque **não há SDK de anúncio no projeto ainda**: a
/// integração real entra trocando este valor, sem tocar na tela nem na regra.
///
/// O padrão paga o jogador. Enquanto não há rede de anúncio, a alternativa era
/// um funil que nunca conclui — um botão que promete um martelo e não entrega é
/// pior do que a casa pagar por ele.
final hammerAdProvider = Provider<Future<bool> Function()>(
  (ref) =>
      () async => true,
);

/// Convite de aquisição, aberto quando o jogador mira sem ter martelo.
///
/// Chega com o alvo **já escolhido** (ver `GameState.pendingHammerTarget`): é o
/// que faz a proposta ser concreta — "quebre *aquela* célula" em vez de "compre
/// um item". Quem aplica o golpe depois é `GameNotifier.grantHammer`.
class HammerOfferDialog extends ConsumerStatefulWidget {
  const HammerOfferDialog({
    super.key,
    required this.onGranted,
    required this.onDecline,
  });

  /// O anúncio foi concluído: credite e bata no alvo guardado.
  final VoidCallback onGranted;

  /// O jogador desistiu, ou o anúncio não veio.
  final VoidCallback onDecline;

  @override
  ConsumerState<HammerOfferDialog> createState() => _HammerOfferDialogState();
}

class _HammerOfferDialogState extends ConsumerState<HammerOfferDialog> {
  /// O anúncio está no ar. Trava o botão: dois toques comprariam dois martelos
  /// para um alvo só, e o segundo bateria numa célula que já não existe.
  bool _waiting = false;

  /// O anúncio não veio. Dito na própria caixa, e não num `SnackBar`: o jogador
  /// está olhando para cá, e a resposta pertence à pergunta que ele fez.
  bool _failed = false;

  Future<void> _watch() async {
    if (_waiting) return;
    setState(() {
      _waiting = true;
      _failed = false;
    });

    final granted = await ref.read(hammerAdProvider)();
    if (!mounted) return;

    if (granted) {
      widget.onGranted();
      return;
    }

    // Recusa não fecha a caixa: o alvo continua escolhido, e tentar de novo é
    // um toque — obrigar a mirar outra vez puniria o jogador pela falha da rede.
    setState(() {
      _waiting = false;
      _failed = true;
    });
  }

  /// Troca moedas por um martelo.
  ///
  /// Debita e delega a entrega ao mesmo `onGranted` do anúncio: quem credita o
  /// item e bate no alvo guardado é `GameNotifier.grantHammer`. Creditar aqui
  /// também renderia dois martelos por uma compra.
  void _buy() {
    if (_waiting) return;
    // Mesma trava do anúncio, pela mesma razão: um item pago não pode ser
    // cobrado duas vezes por um deslize de dedo. Sem ligar `_waiting` aqui,
    // dois toques processados antes do rebuild que reavalia `canAfford`
    // debitam duas vezes — e o segundo martelo nem tem alvo, porque o
    // primeiro golpe já limpou o `pendingHammerTarget`.
    setState(() => _waiting = true);
    if (!ref.read(walletProvider.notifier).spendCoins(kHammerCoinPrice)) return;

    widget.onGranted();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wallet = ref.watch(walletProvider);
    final canAfford = wallet.canAfford(kHammerCoinPrice);

    return GameDialog(
      cardKey: hammerOfferKey,
      title: l10n.hammerOfferTitle,
      accent: AppColors.digit4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.gavel_rounded, color: AppColors.digit4, size: 44),
          const SizedBox(height: 12),
          Text(
            l10n.hammerOfferBody,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
          if (_failed) ...[
            const SizedBox(height: 10),
            Text(
              l10n.hammerOfferFailed,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.digit0, fontSize: 13),
            ),
          ],
          const SizedBox(height: 18),
          GameButton(
            key: hammerOfferWatchKey,
            label: l10n.hammerOfferWatch,
            color: AppColors.digit4,
            icon: Icons.play_circle_fill_rounded,
            onPressed: _watch,
          ),
          const SizedBox(height: 10),
          GameButton(
            key: hammerOfferBuyKey,
            label: l10n.hammerOfferBuy(kHammerCoinPrice),
            color: canAfford ? AppColors.digit3 : AppColors.darkSurface,
            foreground: canAfford ? Colors.black : Colors.white38,
            icon: Icons.shopping_bag_rounded,
            // Nulo desabilita o botão, e é o que o teste de saldo curto afirma:
            // um botão que aceita o toque e não faz nada é pior do que um
            // botão apagado, porque o jogador não sabe se falhou ou foi cobrado.
            onPressed: canAfford ? _buy : null,
          ),
          if (!canAfford) ...[
            const SizedBox(height: 6),
            Text(
              l10n.hammerOfferNoCoins,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          GameButton(
            key: hammerOfferDeclineKey,
            label: l10n.hammerOfferDecline,
            color: AppColors.darkSurface,
            foreground: Colors.white70,
            onPressed: widget.onDecline,
          ),
        ],
      ),
    );
  }
}
