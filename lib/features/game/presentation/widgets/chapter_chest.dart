import 'package:flutter/material.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/feedback/haptics.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/core/theme/nf_tokens.dart';
import 'package:nine_fuse/core/widgets/nf_text.dart';
import 'package:nine_fuse/core/widgets/sprite_icon.dart';
import 'package:nine_fuse/features/game/domain/campaign_chapter.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/presentation/widgets/game_dialog.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Chave do nó de baú do fim de [chapter] na trilha.
Key chestNodeKey(int chapter) => Key('chapter_chest_$chapter');

/// Chave da caixa que anuncia o prêmio do baú.
const Key chestRewardPopupKey = Key('chapter_chest_reward');

/// Chave do botão "Coletar" da caixa do prêmio.
const Key chestCollectButtonKey = Key('chapter_chest_collect');

/// Chave da caixa da dica do baú trancado.
const Key chestLockedPopupKey = Key('chapter_chest_locked');

/// Estado visual de um baú de capítulo.
enum ChestState {
  /// Capítulo ainda não concluído.
  locked,

  /// Capítulo concluído e o baú ainda não pago: é o único que brilha.
  ready,

  /// Já pago.
  opened,
}

/// Se o capítulo tem baú: todo capítulo tem, o grande até o
/// `kChapterChestPayableCount` e o menor depois (`chapterChestReward`).
bool chapterHasChest(CampaignChapter chapter) =>
    chapterChestReward(chapter.number) > 0;

/// Estado do baú de [chapter].
///
/// "Concluído" lê o **progresso** (`progress` = última fase vencida), e não o
/// histórico de estrelas: a campanha só destrava em ordem, então
/// `progress >= lastLevel` já garante que todas as fases do capítulo foram
/// vencidas — e continua valendo depois que `CampaignRecords` poda o detalhe
/// das fases antigas (`prunedBelow`), que é justamente quando contar registros
/// diria "capítulo vazio".
ChestState chestStateFor(
  CampaignChapter chapter, {
  required int progress,
  required Set<int> claimedChests,
}) {
  if (progress < chapter.lastLevel) return ChestState.locked;
  return claimedChests.contains(chapter.number)
      ? ChestState.opened
      : ChestState.ready;
}

/// O nó de baú pendurado no fim de um capítulo da trilha.
///
/// Quadrado arredondado, e não disco: o círculo é a forma das fases, e o baú
/// não é uma fase — não abre partida, não tem número.
class ChapterChestNode extends StatelessWidget {
  const ChapterChestNode({
    super.key,
    required this.chapter,
    required this.state,
    required this.onTap,
  });

  final int chapter;
  final ChestState state;
  final VoidCallback onTap;

  static const double size = 50;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = switch (state) {
      ChestState.locked => l10n.semanticsChestLocked(chapter),
      ChestState.ready => l10n.semanticsChestReady(chapter),
      ChestState.opened => l10n.semanticsChestOpened(chapter),
    };

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        key: chestNodeKey(chapter),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Haptics.selection();
          onTap();
        },
        child: ExcludeSemantics(
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: size,
                height: size,
                decoration: _decoration(),
                child: Icon(
                  state == ChestState.opened
                      ? Icons.check_rounded
                      : Icons.redeem_rounded,
                  size: 28,
                  color: switch (state) {
                    ChestState.locked => const Color(0xFF7D86C2),
                    ChestState.ready => NfColors.goldText,
                    ChestState.opened => NfColors.goldPale,
                  },
                ),
              ),
              // O cadeado no canto, e não no lugar do ícone: o jogador precisa
              // ver que **é** um baú para saber o que está perseguindo.
              if (state == ChestState.locked)
                const Positioned(right: -6, bottom: -6, child: _LockBadge()),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _decoration() => switch (state) {
    ChestState.locked => BoxDecoration(
      borderRadius: BorderRadius.circular(NfRadii.sm),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1F2A66), Color(0xFF0E1640)],
      ),
      border: Border.all(color: const Color(0xFF3A4380), width: 2.5),
      boxShadow: const [
        BoxShadow(color: Color(0xFF05081C), offset: Offset(0, 5)),
      ],
    ),
    // Halo dourado **parado**: um brilho que pulsasse faria `pumpAndSettle`
    // nunca terminar, e o mapa já tem um elemento pulsante (a fase da vez).
    // O baú pronto chama a atenção pela cor, não pelo movimento.
    ChestState.ready => BoxDecoration(
      borderRadius: BorderRadius.circular(NfRadii.sm),
      gradient: const LinearGradient(
        begin: Alignment(-0.35, -1),
        end: Alignment(0.35, 1),
        colors: [NfColors.goldLight, NfColors.gold, NfColors.goldDeep],
      ),
      border: Border.all(color: const Color(0xFFFFF6C8), width: 2.5),
      boxShadow: [
        const BoxShadow(color: NfColors.goldShadow, offset: Offset(0, 5)),
        BoxShadow(
          color: NfColors.gold.withValues(alpha: 0.65),
          blurRadius: 22,
          spreadRadius: 3,
        ),
      ],
    ),
    ChestState.opened => BoxDecoration(
      borderRadius: BorderRadius.circular(NfRadii.sm),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF6B4A12), NfColors.bronze],
      ),
      border: Border.all(color: NfColors.goldShadow, width: 2.5),
      boxShadow: const [
        BoxShadow(color: Color(0xFF1E1000), offset: Offset(0, 5)),
      ],
    ),
  };
}

class _LockBadge extends StatelessWidget {
  const _LockBadge();

  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 22,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: NfColors.night1,
      border: Border.all(color: const Color(0xFF3A4380), width: 2),
    ),
    child: const Icon(Icons.lock_rounded, size: 12, color: Color(0xFF7D86C2)),
  );
}

/// A caixa que anuncia o prêmio do baú: moeda grande, "+200" e "Coletar".
///
/// Sobe **depois** do crédito, como o prêmio da roleta: é anúncio, não
/// confirmação. Fechar pelo véu não perde nada.
class ChestRewardPopup extends StatelessWidget {
  const ChestRewardPopup({super.key, required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Material(
      type: MaterialType.transparency,
      child: Container(
        key: chestRewardPopupKey,
        width: 264,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
        decoration: NfDecorations.panel(glow: true),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sem sombra empilhada: a caixa entra com escala (`showNfModal`).
            NfText.titleGold(l10n.chestReadyTitle, size: 28, shadows: false),
            const SizedBox(height: 16),
            const SpriteIcon(
              asset: 'assets/images/ic_coin.png',
              fallback: Icons.monetization_on,
              size: 88,
              color: NfColors.gold,
            ),
            const SizedBox(height: 6),
            NfText.number('+$coins', size: 36),
            const SizedBox(height: 18),
            GameButton(
              key: chestCollectButtonKey,
              label: l10n.chestCollect,
              color: AppColors.uiGold,
              fontSize: 20,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// A dica do baú trancado: o que falta para abri-lo.
class ChestLockedPopup extends StatelessWidget {
  const ChestLockedPopup({super.key, required this.chapter});

  final int chapter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Material(
      type: MaterialType.transparency,
      child: Container(
        key: chestLockedPopupKey,
        width: 264,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        decoration: NfDecorations.panel(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NfText.title(l10n.chestLockedTitle, size: 24, shadows: false),
            const SizedBox(height: 12),
            Text(
              l10n.chestLockedHint(chapter),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppFonts.number,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: NfColors.textSoft,
              ),
            ),
            const SizedBox(height: 16),
            GameButton(
              label: l10n.chestOk,
              color: AppColors.darkSurface,
              fontSize: 18,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
