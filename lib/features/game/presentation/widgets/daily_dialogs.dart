import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/feedback/haptics.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/core/theme/nf_tokens.dart';
import 'package:nine_fuse/core/widgets/nf_modal.dart';
import 'package:nine_fuse/core/widgets/nf_text.dart';
import 'package:nine_fuse/core/audio/audio_service.dart';
import 'package:nine_fuse/core/audio/sound_event.dart';
import 'package:nine_fuse/features/game/domain/daily_missions.dart';
import 'package:nine_fuse/features/game/domain/daily_reward.dart';
import 'package:nine_fuse/features/game/domain/daily_spin.dart';
import 'package:nine_fuse/features/game/presentation/widgets/game_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/prize_wheel.dart';
import 'package:nine_fuse/features/game/providers/daily_progress.dart';
import 'package:nine_fuse/features/game/providers/prize_credit.dart';
import 'package:nine_fuse/features/game/providers/wallet.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

const Key dailyRewardDialogKey = Key('daily_reward_dialog');
const Key dailyRewardCollectKey = Key('daily_reward_collect');
const Key dailyRewardCloseKey = Key('daily_reward_close');
Key dailyRewardDayKey(int cycleDay) => Key('daily_reward_day_$cycleDay');

const Key missionsDialogKey = Key('missions_dialog');
const Key missionsCloseKey = Key('missions_close');
const Key missionsBonusKey = Key('missions_bonus');
Key missionClaimKey(int index) => Key('mission_claim_$index');

/// Largura dos dois painéis — a mesma régua de 362pt da roleta, que encolhe
/// inteira em tela pequena em vez de cortar o botão.
const double _panelWidth = 362;

/// Moldura comum: painel noturno de aro dourado com o X no canto.
class _DailyPanel extends StatelessWidget {
  const _DailyPanel({
    required this.panelKey,
    required this.closeKey,
    required this.child,
  });

  final Key panelKey;
  final Key closeKey;
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    key: panelKey,
    type: MaterialType.transparency,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            width: _panelWidth,
            decoration: NfDecorations.panel(radius: 34, glow: true),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 30, 18, 24),
                  child: child,
                ),
                Positioned(
                  right: 11,
                  top: 13,
                  child: _CloseButton(
                    key: closeKey,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: MaterialLocalizations.of(context).closeButtonTooltip,
    child: GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3A4380), NfColors.night3],
          ),
          border: Border.all(color: const Color(0xFFC98A18), width: 2),
        ),
        child: const Icon(
          Icons.close_rounded,
          size: 22,
          color: NfColors.goldPale,
        ),
      ),
    ),
  );
}

const TextStyle _soft = TextStyle(
  fontFamily: AppFonts.number,
  fontWeight: FontWeight.w600,
  fontSize: 15,
  color: NfColors.textSoft,
);

/// Ícone e quantidade de um prêmio, como a roleta mostra.
Widget _prizeChip(SpinPrize prize, {double icon = 34, double text = 16}) =>
    Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PrizeWheel.iconFor(prize.type, size: icon),
        const SizedBox(height: 2),
        NfText.number(
          prize.type == SpinPrizeType.coins
              ? '${prize.amount}'
              : '×${prize.amount}',
          size: text,
          strokeWidth: 4,
        ),
      ],
    );

// ---------------------------------------------------------------------------
// Recompensa diária
// ---------------------------------------------------------------------------

/// O calendário de 7 dias: o que já foi coletado, o de hoje e os próximos.
///
/// Mostrar os próximos é o ponto: o jogador vê o baú do dia 7 e sabe o que
/// perde se faltar amanhã. Coletar não fecha a caixa — ver o dia virar
/// "coletado" é a confirmação de que funcionou.
class DailyRewardDialog extends ConsumerStatefulWidget {
  const DailyRewardDialog({super.key});

  @override
  ConsumerState<DailyRewardDialog> createState() => _DailyRewardDialogState();
}

class _DailyRewardDialogState extends ConsumerState<DailyRewardDialog> {
  bool _claiming = false;
  List<PrizePayout>? _payouts;

  Future<void> _claim() async {
    if (_claiming) return;
    setState(() => _claiming = true);
    final payouts = await ref.read(dailyRewardProvider.notifier).claim();
    // O crédito foi para o disco; o saldo do topo só reflete depois de reler.
    await ref.read(walletProvider.notifier).refresh();
    if (!mounted) return;
    if (payouts != null) {
      Haptics.medium();
      GameAudio.play(SoundEvent.spinPrize);
    }
    setState(() {
      _claiming = false;
      _payouts = payouts;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ref.watch(dailyRewardProvider);
    final status = ref.read(dailyRewardProvider.notifier).status;
    // Dias do ciclo já pagos nesta volta: o de hoje entra na conta assim que
    // é coletado.
    final collected = status.available ? status.cycleDay : status.cycleDay + 1;
    final overflow = _payouts?.fold(0, (sum, p) => sum + p.overflowCoins) ?? 0;

    Widget day(int index) => _DayCard(
      key: dailyRewardDayKey(index),
      label: l10n.dailyRewardDay(index + 1),
      prizes: kDailyRewardCycle[index],
      collected: index < collected,
      today: index == status.cycleDay,
      wide: index == kDailyRewardCycle.length - 1,
    );

    return _DailyPanel(
      panelKey: dailyRewardDialogKey,
      closeKey: dailyRewardCloseKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Folga dos dois lados do tamanho do X: sem ela o título corria
          // por baixo do botão de fechar (visto no aparelho).
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 34),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: NfText.titleGold(l10n.dailyRewardTitle.toUpperCase(), size: 28),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.dailyRewardSubtitle,
            textAlign: TextAlign.center,
            style: _soft,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              for (int i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(child: day(i)),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: day(4)),
              const SizedBox(width: 6),
              Expanded(child: day(5)),
              const SizedBox(width: 6),
              Expanded(flex: 2, child: day(6)),
            ],
          ),
          const SizedBox(height: 14),
          NfText.number(
            l10n.dailyRewardStreak(status.streakAfterClaim),
            size: 18,
            color: NfColors.gold,
            strokeWidth: 4,
          ),
          const SizedBox(height: 16),
          if (status.available)
            GameButton(
              key: dailyRewardCollectKey,
              label: l10n.dailyRewardCollect,
              color: AppColors.uiGold,
              fontSize: 24,
              onPressed: _claiming ? null : _claim,
            )
          else ...[
            if (overflow > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  l10n.dailySpinStockFull(overflow),
                  textAlign: TextAlign.center,
                  style: _soft,
                ),
              ),
            Text(
              l10n.dailyRewardComeBack,
              textAlign: TextAlign.center,
              style: _soft.copyWith(color: NfColors.goldPale),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            l10n.dailyRewardMissedHint,
            textAlign: TextAlign.center,
            style: _soft.copyWith(fontSize: 12, color: NfColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    super.key,
    required this.label,
    required this.prizes,
    required this.collected,
    required this.today,
    required this.wide,
  });

  final String label;
  final List<SpinPrize> prizes;
  final bool collected;
  final bool today;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    // Hoje (ainda não coletado) é o único cartão em ouro: é o que se toca.
    final highlight = today && !collected;
    return Container(
      height: 98,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(NfRadii.sm),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: highlight
              ? const [Color(0xFF6B4A0A), Color(0xFF3D2200)]
              : collected
              ? const [Color(0xFF14204F), Color(0xFF0A1236)]
              : const [Color(0xFF1B2A6B), Color(0xFF0C1440)],
        ),
        border: Border.all(
          color: highlight
              ? NfColors.gold
              : Colors.white.withValues(alpha: collected ? 0.06 : 0.14),
          width: highlight ? 2.5 : 1.5,
        ),
        boxShadow: highlight
            ? [
                BoxShadow(
                  color: NfColors.gold.withValues(alpha: 0.45),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              NfText.label(
                label,
                size: 11,
                color: highlight ? NfColors.gold : NfColors.textMuted,
              ),
              // Prêmio já coletado fica apagado por cor, não por `Opacity`.
              ColorFiltered(
                colorFilter: collected
                    ? const ColorFilter.mode(
                        Color(0x99060A24),
                        BlendMode.srcATop,
                      )
                    : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                child: FittedBox(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final prize in prizes) ...[
                        if (prize != prizes.first) const SizedBox(width: 8),
                        _prizeChip(prize, icon: wide ? 38 : 32),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (collected)
            const Icon(
              Icons.check_circle_rounded,
              color: NfColors.plusGreen,
              size: 30,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Missões
// ---------------------------------------------------------------------------

/// As três missões do dia, cada uma com a sua barra, e o bônus pelas três.
class MissionsDialog extends ConsumerStatefulWidget {
  const MissionsDialog({super.key});

  @override
  ConsumerState<MissionsDialog> createState() => _MissionsDialogState();
}

class _MissionsDialogState extends ConsumerState<MissionsDialog> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // O app pode ter passado a meia-noite aberto: a lista de ontem não pode
    // continuar no ar.
    ref.read(missionsProvider.notifier).ensureToday();
  }

  Future<void> _run(Future<Object?> Function() claim) async {
    if (_busy) return;
    setState(() => _busy = true);
    final paid = await claim();
    await ref.read(walletProvider.notifier).refresh();
    if (!mounted) return;
    if (paid != null) {
      Haptics.medium();
      GameAudio.play(SoundEvent.coins);
    }
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final missions = ref.watch(missionsProvider);
    final notifier = ref.read(missionsProvider.notifier);
    final bonus = missions.day.isEmpty ? null : missionsBonusFor(missions.day);

    return _DailyPanel(
      panelKey: missionsDialogKey,
      closeKey: missionsCloseKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Folga dos dois lados do tamanho do X: sem ela o título corria
          // por baixo do botão de fechar (visto no aparelho).
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 34),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: NfText.titleGold(l10n.missionsTitle.toUpperCase(), size: 28),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.missionsSubtitle,
            textAlign: TextAlign.center,
            style: _soft,
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < missions.missions.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _MissionRow(
              index: i,
              mission: missions.missions[i],
              progress: missions.progress[i],
              claimed: missions.claimed[i],
              onClaim: _busy ? null : () => _run(() => notifier.claim(i)),
            ),
          ],
          if (bonus != null) ...[
            const SizedBox(height: 14),
            _BonusRow(
              prize: bonus,
              done: missions.claimed.where((c) => c).length,
              total: missions.missions.length,
              claimed: missions.bonusClaimed,
              onClaim: missions.canClaimBonus && !_busy
                  ? () => _run(notifier.claimBonus)
                  : null,
            ),
          ],
          if (missions.allClaimed && missions.bonusClaimed) ...[
            const SizedBox(height: 12),
            Text(
              l10n.missionsAllDone,
              textAlign: TextAlign.center,
              style: _soft.copyWith(color: NfColors.goldPale),
            ),
          ],
        ],
      ),
    );
  }
}

/// O texto de cada missão, no plural certo de cada idioma.
String missionLabel(AppLocalizations l10n, Mission mission) =>
    switch (mission.kind) {
      MissionKind.winLevels => l10n.missionWinLevels(mission.target),
      MissionKind.fusions => l10n.missionFusions(mission.target),
      MissionKind.createNines => l10n.missionCreateNines(mission.target),
      MissionKind.breakObstacles => l10n.missionBreakObstacles(mission.target),
      MissionKind.useBoosters => l10n.missionUseBoosters(mission.target),
      MissionKind.earnStars => l10n.missionEarnStars(mission.target),
      MissionKind.triggerNova => l10n.missionTriggerNova(mission.target),
    };

IconData _missionIcon(MissionKind kind) => switch (kind) {
  MissionKind.winLevels => Icons.flag_rounded,
  MissionKind.fusions => Icons.merge_type_rounded,
  MissionKind.createNines => Icons.looks_one_rounded,
  MissionKind.breakObstacles => Icons.grid_view_rounded,
  MissionKind.useBoosters => Icons.handyman_rounded,
  MissionKind.earnStars => Icons.star_rounded,
  MissionKind.triggerNova => Icons.flare_rounded,
};

class _MissionRow extends StatelessWidget {
  const _MissionRow({
    required this.index,
    required this.mission,
    required this.progress,
    required this.claimed,
    required this.onClaim,
  });

  final int index;
  final Mission mission;
  final int progress;
  final bool claimed;
  final VoidCallback? onClaim;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final complete = progress >= mission.target;
    final fraction = (progress / mission.target).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: NfDecorations.card(),
      child: Row(
        children: [
          Icon(
            mission.kind == MissionKind.createNines
                ? Icons.filter_9_plus_rounded
                : _missionIcon(mission.kind),
            color: complete ? NfColors.gold : NfColors.textMuted,
            size: 28,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  missionLabel(l10n, mission),
                  style: const TextStyle(
                    fontFamily: AppFonts.number,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    height: 1.1,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 10,
                    child: LinearProgressIndicator(
                      value: fraction,
                      backgroundColor: const Color(0xFF0A1030),
                      valueColor: AlwaysStoppedAnimation(
                        complete ? NfColors.plusGreen : NfColors.goldDeep,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$progress/${mission.target}',
                  style: const TextStyle(
                    fontFamily: AppFonts.number,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: NfColors.textMuted,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 92,
            child: claimed
                ? const Icon(
                    Icons.check_circle_rounded,
                    color: NfColors.plusGreen,
                    size: 32,
                  )
                : complete
                ? GameButton(
                    key: missionClaimKey(index),
                    label: '+${mission.reward}',
                    color: AppColors.uiGold,
                    fontSize: 16,
                    onPressed: onClaim,
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _prizeChip(
                        SpinPrize(SpinPrizeType.coins, mission.reward),
                        icon: 26,
                        text: 15,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _BonusRow extends StatelessWidget {
  const _BonusRow({
    required this.prize,
    required this.done,
    required this.total,
    required this.claimed,
    required this.onClaim,
  });

  final SpinPrize prize;
  final int done;
  final int total;
  final bool claimed;
  final VoidCallback? onClaim;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(NfRadii.sm),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A1670), Color(0xFF1C0A40)],
        ),
        border: Border.all(
          color: NfColors.gem.withValues(alpha: 0.8),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          PrizeWheel.iconFor(prize.type, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.missionsBonus(prize.amount),
                  style: const TextStyle(
                    fontFamily: AppFonts.number,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    height: 1.1,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$done/$total',
                  style: const TextStyle(
                    fontFamily: AppFonts.number,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: NfColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 92,
            child: claimed
                ? const Icon(
                    Icons.check_circle_rounded,
                    color: NfColors.plusGreen,
                    size: 32,
                  )
                : GameButton(
                    key: missionsBonusKey,
                    label: l10n.missionsCollect,
                    // Gema: é o prêmio "mágico" do dia, e o botão desativado
                    // lê como secundário até as três estarem coletadas.
                    color: onClaim == null
                        ? AppColors.darkSurface
                        : NfColors.gem,
                    fontSize: 14,
                    onPressed: onClaim,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Abre a recompensa diária.
Future<void> showDailyRewardDialog(BuildContext context) =>
    showNfModal<void>(context, builder: (_) => const DailyRewardDialog());

/// Abre as missões.
Future<void> showMissionsDialog(BuildContext context) =>
    showNfModal<void>(context, builder: (_) => const MissionsDialog());

/// Para os chamadores que só querem disparar e seguir.
void openDailyRewardDialog(BuildContext context) =>
    unawaited(showDailyRewardDialog(context));
