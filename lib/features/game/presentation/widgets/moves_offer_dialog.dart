import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/features/game/presentation/widgets/game_dialog.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Chave do cartão de reforço de saldo.
const Key movesOfferKey = Key('moves_offer');

/// Chave do botão que abre o anúncio.
const Key movesOfferWatchKey = Key('moves_offer_watch');

/// Chave do botão de recusa.
const Key movesOfferDeclineKey = Key('moves_offer_decline');

/// Como o jogo pede o anúncio premiado do reforço de saldo, e o que ele
/// responde.
///
/// Provider próprio, e não o mesmo do martelo, porque são dois **inventários**
/// de anúncio distintos: a regra de monetização impõe um teto diário ao martelo
/// e não ao reforço de saldo, e um provider só não teria como aplicar tetos
/// diferentes. A implementação real dos dois pode ser o mesmo serviço.
///
/// O padrão paga o jogador, pelo mesmo motivo registrado no funil do martelo:
/// enquanto não há rede de anúncio configurada, um convite que nunca conclui é
/// pior do que a casa pagar.
final movesAdProvider = Provider<Future<bool> Function()>(
  (ref) =>
      () async => true,
);

/// Convite de reforço de saldo, aberto quando a fase entra no limiar de
/// movimentos.
///
/// Sobe com o jogador **ainda jogando**, e não na tela de derrota: a regra
/// anti-churn proíbe monetizar o fracasso, e a proposta aqui é sobre continuar,
/// não sobre reviver. Quem credita o prêmio depois é `GameNotifier`.
class MovesOfferDialog extends ConsumerStatefulWidget {
  const MovesOfferDialog({
    super.key,
    required this.movesLeft,
    required this.reward,
    required this.onGranted,
    required this.onDecline,
  });

  /// Quantos movimentos ainda restam. É o número que dá urgência ao convite —
  /// "restam 2" é a informação, "quase lá" é só o tom.
  final int movesLeft;

  /// Quantos movimentos o anúncio paga. Vem de `GameState.rewardedMoves`, e
  /// não de uma constante: o cartão não pode prometer um número diferente do
  /// que o crédito soma.
  final int reward;

  /// O anúncio foi concluído: credite os movimentos.
  final VoidCallback onGranted;

  /// O jogador desistiu, ou o anúncio não veio.
  final VoidCallback onDecline;

  @override
  ConsumerState<MovesOfferDialog> createState() => _MovesOfferDialogState();
}

class _MovesOfferDialogState extends ConsumerState<MovesOfferDialog> {
  /// O anúncio está no ar. Trava o botão: dois toques creditariam dez
  /// movimentos por um anúncio só.
  bool _waiting = false;

  /// O anúncio não veio. Dito na própria caixa, como no funil do martelo: o
  /// jogador está olhando para cá, e a resposta pertence à pergunta que fez.
  bool _failed = false;

  Future<void> _watch() async {
    if (_waiting) return;
    setState(() {
      _waiting = true;
      _failed = false;
    });

    final granted = await ref.read(movesAdProvider)();
    if (!mounted) return;

    if (granted) {
      widget.onGranted();
      return;
    }

    // Recusa não fecha a caixa: perder a única oferta da fase por culpa da rede
    // puniria o jogador por algo que não é dele.
    setState(() {
      _waiting = false;
      _failed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return GameDialog(
      cardKey: movesOfferKey,
      title: l10n.movesOfferTitle,
      accent: AppColors.digit2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.swap_horiz_rounded,
            color: AppColors.digit2,
            size: 44,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.movesOfferBody(widget.movesLeft, widget.reward),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
          if (_failed) ...[
            const SizedBox(height: 10),
            Text(
              l10n.movesOfferFailed,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.digit0, fontSize: 13),
            ),
          ],
          const SizedBox(height: 18),
          GameButton(
            key: movesOfferWatchKey,
            label: l10n.movesOfferWatch(widget.reward),
            color: AppColors.digit2,
            icon: Icons.play_circle_fill_rounded,
            onPressed: _watch,
          ),
          const SizedBox(height: 10),
          GameButton(
            key: movesOfferDeclineKey,
            label: l10n.movesOfferDecline,
            color: AppColors.darkSurface,
            foreground: Colors.white70,
            onPressed: widget.onDecline,
          ),
        ],
      ),
    );
  }
}
