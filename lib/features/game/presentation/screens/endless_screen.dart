import 'package:flutter/material.dart';
import 'package:nine_fuse/core/ads/ad_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/widgets/coins_header_badge.dart';
import 'package:nine_fuse/features/game/presentation/widgets/apex_celebration.dart';
import 'package:nine_fuse/features/game/presentation/widgets/board_grid_widget.dart';
import 'package:nine_fuse/features/game/presentation/widgets/combo_banner.dart';
import 'package:nine_fuse/features/game/presentation/widgets/juice_overlay.dart';
import 'package:nine_fuse/features/game/presentation/widgets/endless_banner.dart';
import 'package:nine_fuse/features/game/presentation/widgets/endless_outcome_card.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_button.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_offer_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_targeting_layer.dart';
import 'package:nine_fuse/features/game/presentation/widgets/strike_shake.dart';
import 'package:nine_fuse/features/game/providers/endless_notifier.dart';
import 'package:nine_fuse/features/game/providers/endless_state.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Modo Endless: joga até travar, valendo placar.
class EndlessScreen extends ConsumerStatefulWidget {
  const EndlessScreen({super.key});

  @override
  ConsumerState<EndlessScreen> createState() => _EndlessScreenState();
}

class _EndlessScreenState extends ConsumerState<EndlessScreen> {
  /// Onde o tabuleiro está na tela. A camada de mira do martelo precisa saber:
  /// é o que separa "bateu numa célula" de "tocou fora e desistiu".
  final GlobalKey _boardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // `start` é assíncrono porque lê o recorde salvo em disco.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(endlessProvider.notifier).start();
      // Mesmo motivo da campanha: o martelo vale nos dois modos, e o convite
      // não pode ser a primeira vez que o jogo pede um anúncio à rede.
      preloadRewardedAds(ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(endlessProvider);
    final notifier = ref.read(endlessProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        // "Endless" fica restrito ao código; o jogador lê "Modo Recorde" em
        // português e "High Score Mode" em inglês.
        title: Text(AppLocalizations.of(context).endlessTitle),
        centerTitle: true,
        backgroundColor: AppColors.darkSurface,
        elevation: 0,
        // Só as moedas: o estoque de martelos já tem número próprio na
        // `HammerBar`, e o espelho da carteira pode estar velho no meio de uma
        // partida — dois números do mesmo item na mesma tela.
        actions: const [CoinsHeaderBadge(), SizedBox(width: 4)],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: EndlessBanner(
                            state: state,
                            highScore: notifier.highScore,
                            progression: notifier.progression,
                          ),
                        ),
                        // A faixa do booster fica entre o card de métricas e o
                        // tabuleiro, e fora dos dois. Some com a corrida travada
                        // — ali o placar já foi gravado, e um golpe reabriria
                        // uma partida encerrada.
                        if (!state.isOver)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                            child: HammerBar(
                              buttonKey: endlessHammerButtonKey,
                              targeting: state.isHammerTargeting,
                              count: state.hammerCount,
                              onPressed: notifier.toggleHammerTargeting,
                            ),
                          ),
                        // Mesma folga da campanha: o brilho do disco do martelo
                        // vaza para fora da caixa e encostava na primeira linha
                        // do tabuleiro.
                        const SizedBox(height: 22),
                        if (state.status == EndlessStatus.idle)
                          const SizedBox(
                            height: 200,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else
                          // Margem menor que a do resto da tela, mas não zero:
                          // colado na borda o tabuleiro parece cortado. Os 8pt
                          // de cada lado são os mesmos assumidos no cálculo de
                          // tamanho de célula.
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            // O tranco do martelo sacode o tabuleiro **com** os
                            // efeitos, e não a tela: quem quebrou foi uma peça,
                            // e um estilhaço parado sobre um tabuleiro que anda
                            // denunciaria as duas camadas.
                            child: StrikeShake(
                              serial: state.shakeSerial,
                              child: Stack(
                                key: _boardKey,
                                children: [
                                  BoardGridWidget(
                                    board: state.board,
                                    selectedTile: state.selectedTile,
                                    rejectedSwap: state.rejectedSwap,
                                    hint: state.hint,
                                    bigFusionTileIds: state.bigFusionTileIds,
                                    // A dica não sugere troca durante a mira: o
                                    // toque tem outro destino agora.
                                    hintEnabled:
                                        !state.isOver &&
                                        !state.isHammerTargeting,
                                    // Durante a mira o toque não chega aqui: a
                                    // camada de mira o intercepta antes.
                                    onTileTap: notifier.selectTile,
                                    onTileSwipe: notifier.swapTiles,
                                  ),
                                  Positioned.fill(
                                    child: JuiceOverlay(
                                      step: state.activeStep,
                                      comboCount: state.comboCount,
                                      hammerStrike: state.hammerStrike,
                                      strikeSerial: state.hammerStrikes,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Acima do conteúdo: a área vazia da tela pertence à rolagem, que
            // consome o toque sem repassá-lo, então uma camada por baixo nunca
            // veria o toque de cancelamento.
            // Sai de cena quando o convite de aquisição sobe: ver o item 3 das
            // diretrizes, comentado no `game_screen.dart`.
            if (state.isHammerTargeting && state.pendingHammerTarget == null)
              HammerTargetingLayer(
                boardKey: _boardKey,
                onCell: notifier.useHammer,
                onCancel: notifier.cancelHammerTargeting,
              ),
            if (state.pendingHammerTarget != null && !state.isOver)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.75),
                  child: SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: HammerOfferDialog(
                          onGranted: notifier.grantHammer,
                          onDecline: notifier.cancelHammerTargeting,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ComboBanner(step: state.activeStep, comboCount: state.comboCount),
            // Aparece uma vez por corrida. A chave é **fixa** de propósito: o
            // sinal `apexCelebrated` não desliga durante a partida, então quem
            // limita a comemoração a uma vez é o widget não ser remontado.
            // Amarrada a `state.moves`, a chave mudava a cada jogada e a
            // comemoração tocava de novo para sempre.
            //
            // A próxima sessão comemora de novo porque o sinal volta a ser
            // falso ao começar, desmontando este widget.
            if (state.apexCelebrated && !state.isOver)
              const Positioned.fill(
                child: ApexCelebration(key: ValueKey('apex_session')),
              ),
            if (state.isOver)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.75),
                  child: SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: EndlessOutcomeCard(
                          state: state,
                          highScore: notifier.highScore,
                          onRestart: notifier.start,
                          onBack: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
