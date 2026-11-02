import 'package:flutter/material.dart';
import 'package:nine_fuse/core/ads/ad_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/core/widgets/nf_background.dart';
import 'package:nine_fuse/features/game/presentation/widgets/apex_celebration.dart';
import 'package:nine_fuse/features/game/presentation/widgets/board_frame.dart';
import 'package:nine_fuse/features/game/presentation/widgets/board_grid_widget.dart';
import 'package:nine_fuse/features/game/presentation/widgets/bomb_offer_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/brush_offer_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/combo_banner.dart';
import 'package:nine_fuse/features/game/presentation/widgets/juice_overlay.dart';
import 'package:nine_fuse/features/game/presentation/widgets/endless_banner.dart';
import 'package:nine_fuse/features/game/presentation/widgets/endless_outcome_card.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_button.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_offer_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_targeting_layer.dart';
import 'package:nine_fuse/features/game/presentation/widgets/playfield_layout.dart';
import 'package:nine_fuse/features/game/presentation/widgets/strike_shake.dart';
import 'package:nine_fuse/features/game/providers/endless_notifier.dart';
import 'package:nine_fuse/features/game/providers/endless_state.dart';
import 'package:nine_fuse/features/game/providers/wallet.dart';
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

    // A Nova é a única fonte de moeda dentro de uma corrida — mesma régua da
    // campanha (`GameScreen`): o notifier só acumula o total em
    // `novaCoinsGranted`, e é a tela quem credita o delta na carteira.
    ref.listen(endlessProvider, (previous, next) {
      if (previous != null &&
          next.novaCoinsGranted > previous.novaCoinsGranted) {
        ref
            .read(walletProvider.notifier)
            .creditCoins(next.novaCoinsGranted - previous.novaCoinsGranted);
      }
    });

    return NfBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // "Endless" fica restrito ao código; o jogador lê "Modo Recorde" em
        // português e "High Score Mode" em inglês.
        appBar: playfieldAppBar(
          title: AppLocalizations.of(context).endlessTitle.toUpperCase(),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              // Mesma tela de jogo da campanha (`PlayfieldLayout`): HUD em
              // cima, tabuleiro em moldura de ouro e dock embaixo.
              PlayfieldLayout(
                hud: EndlessBanner(
                  state: state,
                  highScore: notifier.highScore,
                  progression: notifier.progression,
                ),
                // O dock some com a corrida travada — ali o placar já foi
                // gravado, e um golpe reabriria uma partida encerrada.
                dock: state.isOver
                    ? null
                    : HammerBar(
                        buttonKey: endlessHammerButtonKey,
                        targeting: state.isHammerTargeting,
                        count: state.hammerCount,
                        onPressed: notifier.toggleHammerTargeting,
                        bombButtonKey: endlessBombButtonKey,
                        bombTargeting: state.isBombTargeting,
                        bombCount: state.bombCount,
                        onBombPressed: notifier.toggleBombTargeting,
                        brushButtonKey: endlessBrushButtonKey,
                        brushTargeting: state.isBrushTargeting,
                        brushCount: state.brushCount,
                        onBrushPressed: notifier.toggleBrushTargeting,
                      ),
                board: state.status == EndlessStatus.idle
                    ? const SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    // O tranco do martelo sacode o tabuleiro **com** os
                    // efeitos e a moldura, e não a tela: quem quebrou foi uma
                    // peça, e um estilhaço parado sobre um tabuleiro que anda
                    // denunciaria as duas camadas.
                    : StrikeShake(
                        serial: state.novaStrikes,
                        amplitude: kStrikeShakeAmplitude * 2.0,
                        child: StrikeShake(
                          serial: state.bombStrikes,
                          amplitude: kStrikeShakeAmplitude * 1.8,
                          child: StrikeShake(
                            serial: state.shakeSerial,
                            // A moldura fica fora do `Stack` com a chave do
                            // tabuleiro: a camada de mira mede o tabuleiro
                            // por essa chave, e o aro de ouro não é célula.
                            child: BoardFrame(
                              child: Stack(
                                key: _boardKey,
                                children: [
                                  BoardGridWidget(
                                    board: state.board,
                                    selectedTile: state.selectedTile,
                                    rejectedSwap: state.rejectedSwap,
                                    hint: state.hint,
                                    bigFusionTileIds: state.bigFusionTileIds,
                                    // A dica não sugere troca durante a mira:
                                    // o toque tem outro destino agora.
                                    hintEnabled:
                                        !state.isOver &&
                                        !state.isHammerTargeting &&
                                        !state.isBombTargeting &&
                                        !state.isBrushTargeting,
                                    // Durante a mira o toque não chega aqui:
                                    // a camada de mira o intercepta antes.
                                    onTileTap: notifier.selectTile,
                                    onTileSwipe: notifier.swapTiles,
                                  ),
                                  Positioned.fill(
                                    child: JuiceOverlay(
                                      step: state.activeStep,
                                      comboCount: state.comboCount,
                                      hammerStrike: state.hammerStrike,
                                      strikeSerial: state.hammerStrikes,
                                      bombStrike: state.bombStrike,
                                      bombStrikeSerial: state.bombStrikes,
                                    ),
                                  ),
                                ],
                              ),
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
              if (state.isBombTargeting && state.pendingBombTarget == null)
                HammerTargetingLayer(
                  boardKey: _boardKey,
                  areaRadius: 1,
                  onCell: notifier.useBomb,
                  onCancel: notifier.cancelBombTargeting,
                ),
              if (state.isBrushTargeting && state.pendingBrushTarget == null)
                HammerTargetingLayer(
                  boardKey: _boardKey,
                  onCell: notifier.usePaint,
                  onCancel: notifier.cancelBrushTargeting,
                ),
              // Por cima do véu, como na campanha: é a frase que o jogador
              // precisa ler enquanto mira.
              if ((state.isHammerTargeting &&
                      state.pendingHammerTarget == null) ||
                  (state.isBombTargeting && state.pendingBombTarget == null) ||
                  (state.isBrushTargeting && state.pendingBrushTarget == null))
                const BoosterAimHint(),
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
              if (state.pendingBombTarget != null && !state.isOver)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.75),
                    child: SafeArea(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: BombOfferDialog(
                            onGranted: notifier.grantBomb,
                            onDecline: notifier.cancelBombTargeting,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (state.pendingBrushTarget != null && !state.isOver)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.75),
                    child: SafeArea(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: BrushOfferDialog(
                            onGranted: notifier.grantBrush,
                            onDecline: notifier.cancelBrushTargeting,
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
      ),
    );
  }
}
