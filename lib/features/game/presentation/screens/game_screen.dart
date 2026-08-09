import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/star_rating.dart';
import 'package:nine_fuse/features/game/providers/campaign_records.dart';
import 'package:nine_fuse/features/game/presentation/screens/endless_screen.dart';
import 'package:nine_fuse/features/game/presentation/widgets/apex_celebration.dart';
import 'package:nine_fuse/features/game/presentation/widgets/board_grid_widget.dart';
import 'package:nine_fuse/features/game/presentation/widgets/combo_banner.dart';
import 'package:nine_fuse/features/game/presentation/widgets/juice_overlay.dart';
import 'package:nine_fuse/features/game/presentation/widgets/level_banner.dart';
import 'package:nine_fuse/features/game/presentation/widgets/level_outcome_card.dart';
import 'package:nine_fuse/features/game/presentation/widgets/level_start_dialog.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_state.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Tela de uma fase: objetivo, movimentos restantes, tabuleiro e desfecho.
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key, required this.level});

  final GameLevel level;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

/// Escurece o tabuleiro e centraliza o cartão de desfecho, garantindo que os
/// botões fiquem visíveis mesmo em tela pequena.
class _OutcomeOverlay extends StatelessWidget {
  const _OutcomeOverlay({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: ColoredBox(
      color: Colors.black.withValues(alpha: 0.75),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(child: child),
        ),
      ),
    ),
  );
}

class _GameScreenState extends ConsumerState<GameScreen> {
  /// O jogador já apertou "JOGAR" nesta fase?
  ///
  /// Mora na tela, e não no [GameState], porque é estado de apresentação: o
  /// motor não tem nada a decidir enquanto o cartão está aberto, e um status
  /// novo obrigaria toda regra que pergunta "está jogando?" a considerar mais
  /// um caso.
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // O tabuleiro depende da fase, então só pode ser criado depois do primeiro
    // frame, quando o ref já está disponível.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gameProvider.notifier).startLevel(widget.level);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameProvider);
    final notifier = ref.read(gameProvider.notifier);

    ref.listen(gameProvider, (previous, next) {
      // Vencer a fase libera a seguinte e registra como foi.
      if (next.status == GameStatus.won && previous?.status != GameStatus.won) {
        ref.read(campaignProgressProvider.notifier).complete(next.level.number);
        // A mesma nota que o cartão de desfecho mostra — vem da mesma função,
        // para o mapa nunca discordar da tela que acabou de premiar o jogador.
        ref
            .read(campaignRecordsProvider.notifier)
            .record(
              next.level.number,
              stars: starRating(
                movesLeft: next.movesLeft,
                movesAvailable: next.movesAvailable,
              ),
              score: next.score,
            );
      }

      // Toda partida que começa mostra o cartão de novo — inclusive ao tentar
      // de novo, quando o jogador pode ter esquecido o objetivo, e ao avançar,
      // quando o objetivo é outro. O sinal é o `runId`, e não uma transição de
      // status: recomeçar uma fase em andamento é `playing → playing`, e uma
      // regra baseada em status não veria nada acontecer.
      if (previous != null && next.runId != previous.runId) {
        setState(() => _ready = false);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).levelTitle(state.level.number),
        ),
        centerTitle: true,
        backgroundColor: AppColors.darkSurface,
        elevation: 0,
      ),
      body: SafeArea(
        // O desfecho é sobreposto, não empilhado abaixo do tabuleiro: numa
        // tela de celular os botões cairiam fora da dobra e a ação principal
        // depois de vencer ficaria inalcançável sem rolar.
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  // O tabuleiro recebe margem menor que o resto: num 8x8 cada
                  // ponto de margem sai do tamanho do dedo.
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: LevelBanner(state: state),
                        ),
                        const SizedBox(height: 20),
                        // Margem menor que a do resto da tela, mas não zero:
                        // colado na borda o tabuleiro parece cortado. Os 8pt
                        // de cada lado são os mesmos assumidos no cálculo de
                        // tamanho de célula.
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          // Os efeitos ficam sobre o tabuleiro e compartilham
                          // a mesma geometria, para a pontuação nascer na
                          // célula certa.
                          child: Stack(
                            children: [
                              // Enquanto o cartão de início está aberto o
                              // tabuleiro não aceita toque: um dedo que
                              // encostasse fora do cartão gastaria movimento
                              // antes de o jogador ter lido o objetivo.
                              IgnorePointer(
                                ignoring: !_ready,
                                child: BoardGridWidget(
                                  board: state.board,
                                  selectedTile: state.selectedTile,
                                  rejectedSwap: state.rejectedSwap,
                                  hint: state.hint,
                                  bigFusionTileIds: state.bigFusionTileIds,
                                  // A dica só começa a contar depois do
                                  // "JOGAR": senão o relógio de ociosidade
                                  // corre enquanto o jogador lê o cartão e a
                                  // dica acende junto com o tabuleiro.
                                  // Fase acabada também não sugere jogada.
                                  hintEnabled: _ready && !state.isOver,
                                  onTileTap: notifier.selectTile,
                                  onTileSwipe: notifier.swapTiles,
                                ),
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
                        // O placar subiu para o HUD: no rodapé ficava abaixo do
                        // tabuleiro, fora do campo de visão de quem joga.
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ComboBanner(step: state.activeStep, comboCount: state.comboCount),
            // A chave amarrada à partida faz a comemoração renascer a cada
            // fase iniciada: o `runId` é o único sinal de "uma partida
            // começou" — recomeçar a fase atual é `playing → playing`.
            if (state.apexCelebrated && !state.isOver)
              Positioned.fill(
                child: ApexCelebration(key: ValueKey('apex_${state.runId}')),
              ),
            // O cartão de início some assim que a fase acaba: perder no
            // primeiro movimento não pode deixar dois cartões na tela.
            if (!_ready && !state.isOver)
              _OutcomeOverlay(
                child: LevelStartDialog(
                  level: state.level,
                  onPlay: () => setState(() => _ready = true),
                ),
              ),
            if (state.isOver)
              _OutcomeOverlay(
                child: LevelOutcomeCard(
                  state: state,
                  onRetry: notifier.restartLevel,
                  onNext: notifier.nextLevel,
                  onBack: () => Navigator.of(context).maybePop(),
                  onEndless: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const EndlessScreen()),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
