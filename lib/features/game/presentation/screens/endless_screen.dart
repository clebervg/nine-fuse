import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/features/game/presentation/widgets/apex_celebration.dart';
import 'package:nine_fuse/features/game/presentation/widgets/board_grid_widget.dart';
import 'package:nine_fuse/features/game/presentation/widgets/combo_banner.dart';
import 'package:nine_fuse/features/game/presentation/widgets/juice_overlay.dart';
import 'package:nine_fuse/features/game/presentation/widgets/endless_banner.dart';
import 'package:nine_fuse/features/game/presentation/widgets/endless_outcome_card.dart';
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
  @override
  void initState() {
    super.initState();
    // `start` é assíncrono porque lê o recorde salvo em disco.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(endlessProvider.notifier).start();
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
                        const SizedBox(height: 20),
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
                            child: Stack(
                              children: [
                                BoardGridWidget(
                                  board: state.board,
                                  selectedTile: state.selectedTile,
                                  rejectedSwap: state.rejectedSwap,
                                  hint: state.hint,
                                  bigFusionTileIds: state.bigFusionTileIds,
                                  hintEnabled: !state.isOver,
                                  onTileTap: notifier.selectTile,
                                  onTileSwipe: notifier.swapTiles,
                                ),
                                Positioned.fill(
                                  child: JuiceOverlay(
                                    step: state.activeStep,
                                    comboCount: state.comboCount,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
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
