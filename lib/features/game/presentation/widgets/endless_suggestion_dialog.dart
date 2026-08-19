import 'package:flutter/material.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/features/game/presentation/widgets/game_dialog.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Chave do cartão de sugestão do Modo Recorde.
const Key endlessSuggestionKey = Key('endless_suggestion');

/// Chave do botão que leva ao Modo Recorde.
const Key endlessSuggestionGoKey = Key('endless_suggestion_go');

/// Chave do botão que recusa e mantém o cartão de desfecho da fase.
const Key endlessSuggestionDeclineKey = Key('endless_suggestion_decline');

/// Convite para migrar ao Modo Recorde, aberto depois de três derrotas
/// seguidas na mesma fase da campanha.
///
/// Sobe **sobre** o `LevelOutcomeCard` (a fase já perdeu), e não em vez dele:
/// recusar mantém o cartão de desfecho visível, com o botão de tentar de
/// novo. Quem decide se ele aparece é `GameState.shouldOfferEndless`
/// combinado com `endlessIsUnlocked`, lidos em `game_screen.dart` — este
/// widget só apresenta a escolha.
class EndlessSuggestionDialog extends StatelessWidget {
  const EndlessSuggestionDialog({
    super.key,
    required this.onGoToEndless,
    required this.onDecline,
  });

  /// O jogador quer testar o Modo Recorde agora.
  final VoidCallback onGoToEndless;

  /// O jogador prefere continuar tentando a fase.
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return GameDialog(
      cardKey: endlessSuggestionKey,
      title: l10n.endlessSuggestionTitle,
      accent: AppColors.digit9,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            color: AppColors.digit9,
            size: 44,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.endlessSuggestionBody,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
          const SizedBox(height: 18),
          GameButton(
            key: endlessSuggestionGoKey,
            label: l10n.endlessSuggestionGo,
            color: AppColors.digit9,
            icon: Icons.emoji_events_rounded,
            onPressed: onGoToEndless,
          ),
          const SizedBox(height: 10),
          GameButton(
            key: endlessSuggestionDeclineKey,
            label: l10n.endlessSuggestionDecline,
            color: AppColors.darkSurface,
            foreground: Colors.white70,
            onPressed: onDecline,
          ),
        ],
      ),
    );
  }
}
