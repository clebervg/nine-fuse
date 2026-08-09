import 'package:flutter/material.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/features/game/presentation/widgets/game_dialog.dart';
import 'package:nine_fuse/features/game/providers/endless_state.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Fim de uma corrida Endless. Travar não é derrota: é o placar fechando.
class EndlessOutcomeCard extends StatelessWidget {
  const EndlessOutcomeCard({
    super.key,
    required this.state,
    required this.highScore,
    required this.onRestart,
    required this.onBack,
  });

  final EndlessState state;
  final int highScore;
  final VoidCallback onRestart;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = state.isRecord ? AppColors.digit3 : AppColors.digit1;

    return GameDialog(
      cardKey: const Key('endless_outcome'),
      title: state.isRecord ? l10n.endlessRecordTitle : l10n.endlessOverTitle,
      titleFontSize: 20,
      accent: accent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            state.isRecord ? Icons.emoji_events : Icons.flag_outlined,
            color: accent,
            size: 40,
          ),
          const SizedBox(height: 10),
          Text(
            l10n.endlessOverMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),
          _Line(label: l10n.endlessPoints, value: '${state.score}'),
          _Line(label: l10n.endlessRecord, value: '$highScore'),
          _Line(label: l10n.endlessMoves, value: '${state.moves}'),
          _Line(
            label: l10n.endlessHighestDigit,
            value: '${state.highestDigit}',
          ),
          if (state.explosions > 0)
            _Line(label: l10n.endlessExplosions, value: '${state.explosions}'),
          const SizedBox(height: 18),
          GameButton(
            key: const Key('endless_restart'),
            label: l10n.endlessRestart,
            icon: Icons.refresh,
            color: accent,
            onPressed: onRestart,
          ),
          const SizedBox(height: 8),
          GameTextButton(
            key: const Key('endless_back'),
            label: l10n.endlessBackToMenu,
            onPressed: onBack,
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
