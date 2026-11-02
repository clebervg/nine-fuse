import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/core/theme/nf_tokens.dart';
import 'package:nine_fuse/core/widgets/nf_text.dart';
import 'package:nine_fuse/core/widgets/sprite_icon.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/presentation/widgets/coin_sources_card.dart';
import 'package:nine_fuse/features/game/presentation/l10n_labels.dart';
import 'package:nine_fuse/features/game/presentation/widgets/game_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/objective_disc.dart';
import 'package:nine_fuse/features/game/providers/game_state.dart';
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
  (ref) =>
      () async => true,
);

/// Convite de resgate, aberto quando a fase acabou de ser perdida por falta
/// de movimentos. Aceitar qualquer uma das duas opções revive a fase (volta a
/// `playing`) — é `GameNotifier.grantContinueMoves` quem faz isso.
///
/// É a tela "05 Derrota": o título, do que o jogador ficou perto e a placa do
/// resgate. Sem caixa em volta — a derrota ocupa a tela, e o resgate é a placa
/// dourada no meio dela. "DESISTIR" revela o cartão de desfecho por baixo.
///
/// Anti-churn: nada aqui é intersticial. As duas saídas pagas são escolha do
/// jogador (vídeo premiado ou moedas), e recusar é sempre um toque visível.
class ContinueOfferDialog extends ConsumerStatefulWidget {
  const ContinueOfferDialog({
    super.key,
    required this.onGranted,
    required this.onDecline,
    this.state,
    this.availableHeight,
  });

  final VoidCallback onGranted;
  final VoidCallback onDecline;

  /// Altura útil da camada, para "DESISTIR" caber na dobra sem rolagem.
  ///
  /// Recusar tem de ser sempre um toque visível — é a outra metade do
  /// anti-churn. Em tela baixa o título encolhe e o disco do objetivo sai (a
  /// frase "faltou pouco" segue dizendo do que se trata). Nula, vale a altura
  /// da tela.
  final double? availableHeight;

  /// A partida perdida, para dizer do que o jogador ficou perto. Opcional
  /// porque o convite também é montado isolado nos testes do funil; sem ela,
  /// o cabeçalho mostra só o título.
  final GameState? state;

  @override
  ConsumerState<ContinueOfferDialog> createState() =>
      _ContinueOfferDialogState();
}

class _ContinueOfferDialogState extends ConsumerState<ContinueOfferDialog>
    with SingleTickerProviderStateMixin {
  bool _waiting = false;
  bool _failed = false;

  /// Entrada da placa: `easeOutBack` de 320ms, a régua dos modais.
  late AnimationController _entry;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(vsync: this, duration: NfDurations.modal)
      ..forward();
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

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
    final state = widget.state;
    final missing = state == null
        ? 0
        : state.objectiveTarget - state.objectiveProgress;

    // Partes fixas (frase, placa, botões e espaços) ~470; o que escala é o
    // título (48) e o disco (144).
    final height =
        widget.availableHeight ?? MediaQuery.sizeOf(context).height - 48;
    final fit = ((height - 470) / 192).clamp(0.0, 1.0);
    final showDisc = fit >= 0.6;

    return ConstrainedBox(
      key: continueOfferKey,
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 28 * fit),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: NfText.title(
              l10n.continueOfferTitle,
              size: 48 * math.max(fit, 0.75),
            ),
          ),
          if (state != null && missing > 0) ...[
            const SizedBox(height: 12),
            Text(
              l10n.objectiveMissing(state.level.objective, missing),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppFonts.display,
                color: NfColors.textSoft,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (showDisc) ...[
              const SizedBox(height: 22),
              ObjectiveDisc(
                objective: state.level.objective,
                progress: state.objectiveProgress,
                target: state.objectiveTarget,
              ),
            ],
          ],
          SizedBox(height: 14 + 14 * fit),
          // Só a placa entra com escala. O título de cima é estático e pode ter
          // a sombra empilhada; o "+5 JOGADAS" daqui de dentro só ganha a dele
          // quando a entrada termina — sombra de texto dentro de `Transform`
          // animado é o bug do Impeller registrado em `NfText`.
          AnimatedBuilder(
            animation: _entry,
            builder: (context, child) => Transform.scale(
              scale: 0.85 + 0.15 * Curves.easeOutBack.transform(_entry.value),
              child: child,
            ),
            child: _plate(l10n, canAfford, wallet.coins),
          ),
          if (!canAfford) ...[
            // Onde o jogador descobre que o saldo não cobre o preço é onde a
            // pergunta "como consigo mais?" nasce (ver `CoinSourcesCard`).
            const SizedBox(height: 16),
            const CoinSourcesCard(),
          ],
          const SizedBox(height: 18),
          GameButton(
            key: continueOfferDeclineKey,
            label: l10n.continueOfferDecline,
            color: AppColors.darkSurface,
            fontSize: 20,
            onPressed: widget.onDecline,
          ),
        ],
      ),
    );
  }

  /// A placa do resgate: o que se ganha, e as duas formas de pagar.
  Widget _plate(AppLocalizations l10n, bool canAfford, int coins) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF22327A), Color(0xFF0E1640)],
      ),
      border: Border.all(color: NfColors.goldDeep, width: 2),
      boxShadow: [
        // Blur zero: a espessura da placa.
        const BoxShadow(color: Color(0xFF05081C), offset: Offset(0, 6)),
        BoxShadow(
          color: NfColors.goldDeep.withValues(alpha: 0.2),
          blurRadius: 40,
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NfText.label(l10n.continueOfferResume, color: NfColors.textMuted),
        const SizedBox(height: 14),
        ListenableBuilder(
          listenable: _entry,
          builder: (context, _) => FittedBox(
            fit: BoxFit.scaleDown,
            child: NfText.titleGold(
              l10n.continueOfferBonus(kContinueBonusMoves),
              size: 44,
              shadows: _entry.isCompleted,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Moeda primeiro, como no design: é a saída que não depende de rede. O
        // preço vem do código (`kContinueCoinPrice`), nunca do mock.
        GameButton(
          key: continueOfferBuyKey,
          label: '$kContinueCoinPrice',
          color: canAfford ? AppColors.uiGold : AppColors.darkSurface,
          fontSize: 28,
          leading: Opacity(
            // Apagada junto com o botão: uma moeda acesa num botão morto
            // prometeria uma compra que não vem.
            opacity: canAfford ? 1 : 0.4,
            child: const SpriteIcon(
              asset: 'assets/images/ic_coin.png',
              fallback: Icons.monetization_on_rounded,
              size: 34,
              color: NfColors.gold,
            ),
          ),
          onPressed: canAfford ? _buy : null,
        ),
        const SizedBox(height: 6),
        // O saldo fica logo abaixo do preço: sem ele, "moedas insuficientes"
        // diz que falta, mas não quanto.
        Text(
          canAfford
              ? l10n.continueOfferBalance(coins)
              : '${l10n.continueOfferNoCoins} · ${l10n.continueOfferBalance(coins)}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.display,
            color: canAfford ? Colors.white54 : Colors.white38,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        GameButton(
          key: continueOfferWatchKey,
          label: l10n.continueOfferWatch(kContinueBonusMoves),
          color: NfColors.gem,
          icon: Icons.play_circle_fill_rounded,
          onPressed: _watch,
        ),
        if (_failed) ...[
          const SizedBox(height: 10),
          Text(
            l10n.continueOfferFailed,
            textAlign: TextAlign.center,
            style: const TextStyle(color: NfColors.alert, fontSize: 13),
          ),
        ],
      ],
    ),
  );
}
