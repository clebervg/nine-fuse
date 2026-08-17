import 'package:flutter/material.dart';
import 'package:nine_fuse/core/ads/ad_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/widgets/coins_header_badge.dart';
import 'package:nine_fuse/features/game/domain/campaign_chapter.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/star_rating.dart';
import 'package:nine_fuse/features/game/providers/campaign_records.dart';
import 'package:nine_fuse/features/game/providers/wallet.dart';
import 'package:nine_fuse/features/game/presentation/widgets/apex_celebration.dart';
import 'package:nine_fuse/features/game/presentation/widgets/board_grid_widget.dart';
import 'package:nine_fuse/features/game/presentation/widgets/combo_banner.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_button.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_offer_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/moves_offer_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_targeting_layer.dart';
import 'package:nine_fuse/features/game/presentation/widgets/juice_overlay.dart';
import 'package:nine_fuse/features/game/presentation/widgets/level_banner.dart';
import 'package:nine_fuse/features/game/presentation/widgets/level_outcome_card.dart';
import 'package:nine_fuse/features/game/presentation/widgets/level_start_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/strike_shake.dart';
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

  /// Quantas estrelas de capítulo a última vitória acrescentou.
  ///
  /// Vem do retorno de `CampaignRecords.record()`, e não de uma conta feita
  /// aqui: quando o cartão renderiza, o total do capítulo **já inclui** esta
  /// fase, e rejogar sem melhorar a nota rende zero mesmo tirando três
  /// estrelas. Só o notifier enxerga os dois lados.
  int _chapterStarsGained = 0;

  /// O convite de reforço de saldo está aberto agora?
  ///
  /// Mora na tela pelo mesmo motivo que [_ready]: é estado de apresentação. E
  /// precisa ser separado de `GameState.shouldOfferMoves` porque os dois se
  /// contradizem de propósito — mostrar o convite **gasta** a oferta da fase, o
  /// que torna `shouldOfferMoves` falso no mesmo quadro. Ligado direto ao
  /// getter, o cartão fecharia sozinho no frame seguinte ao de abrir.
  bool _movesOfferOpen = false;

  /// Onde o tabuleiro está na tela. A camada de mira do martelo precisa saber:
  /// é o que separa "bateu numa célula" de "tocou fora e desistiu".
  final GlobalKey _boardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // O tabuleiro depende da fase, então só pode ser criado depois do primeiro
    // frame, quando o ref já está disponível.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gameProvider.notifier).startLevel(widget.level);
      // Preload no início do nível: quando o convite abrir, o anúncio já está
      // em estoque e o jogador não espera a rede entre "quero" e "assisti".
      preloadRewardedAds(ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameProvider);
    final notifier = ref.read(gameProvider.notifier);

    // Observar o mapa é o que faz a barra reagir quando a leitura do disco
    // chega depois da abertura da tela. O total sai do próprio valor
    // observado (via a versão estática de `starsInChapter`), em vez de uma
    // segunda leitura do provider só para chamar o método de instância.
    final records = ref.watch(campaignRecordsProvider);
    final chapterStars = CampaignRecords.starsInChapterOf(
      records,
      chapterOf(state.level.number),
    );

    ref.listen(gameProvider, (previous, next) {
      // Vencer a fase libera a seguinte e registra como foi.
      if (next.status == GameStatus.won && previous?.status != GameStatus.won) {
        ref.read(campaignProgressProvider.notifier).complete(next.level.number);
        // A mesma nota que o cartão de desfecho mostra — vem da mesma função,
        // para o mapa nunca discordar da tela que acabou de premiar o jogador.
        //
        // Sem `setState`: esta atribuição ocorre durante a notificação do
        // `gameProvider`, que o `build` já observa com `ref.watch` — o
        // rebuild vem de qualquer forma, e chamar `setState` aqui arrisca
        // reentrada.
        _chapterStarsGained = ref
            .read(campaignRecordsProvider.notifier)
            .record(
              next.level.number,
              stars: starRating(
                movesLeft: next.movesLeft,
                movesAvailable: next.movesAvailable,
              ),
              score: next.score,
            );

        // A torneira da economia. Paga pelo ganho, e não pelas estrelas da
        // partida: `record()` já descontou as que o jogador tinha, então
        // rejogar a fase 1 em looping rende zero e nenhuma regra anti-farm
        // precisa existir.
        ref
            .read(walletProvider.notifier)
            .creditCoins(_chapterStarsGained * kCoinsPerStar);
      }

      // Toda partida que começa mostra o cartão de novo — inclusive ao tentar
      // de novo, quando o jogador pode ter esquecido o objetivo, e ao avançar,
      // quando o objetivo é outro. O sinal é o `runId`, e não uma transição de
      // status: recomeçar uma fase em andamento é `playing → playing`, e uma
      // regra baseada em status não veria nada acontecer.
      if (previous != null && next.runId != previous.runId) {
        setState(() {
          _ready = false;
          // A partida nova traz a oferta de volta (o notifier a devolve em
          // `startLevel`); um convite aberto da partida anterior ficaria por
          // cima do cartão de início da nova.
          _movesOfferOpen = false;
        });
      }

      // O convite abre no limiar, e quem o marca como gasto é a tela: a regra
      // sabe dizer que a fase está apertada, mas só aqui se sabe se o cartão
      // chegou a subir. `_ready` entra na conta porque o cartão de início ainda
      // está no ar antes dele, e dois cartões empilhados escondem os dois.
      if (!_movesOfferOpen && _ready && next.shouldOfferMoves) {
        _movesOfferOpen = true;
        ref.read(gameProvider.notifier).markMovesOfferShown();
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
        // Só as moedas: o estoque de martelos já tem número próprio na
        // `HammerBar`, e o espelho da carteira pode estar velho no meio de uma
        // partida — dois números do mesmo item na mesma tela.
        actions: const [CoinsHeaderBadge(), SizedBox(width: 4)],
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
                        // A faixa do booster fica **entre** o card de métricas e
                        // o tabuleiro, e fora dos dois: é ação, e a ação não
                        // pertence à moldura que informa. Some com a fase
                        // encerrada — um martelo oferecido sobre o cartão de
                        // derrota promete o que já não pode cumprir.
                        if (!state.isOver)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                            child: HammerBar(
                              buttonKey: hammerButtonKey,
                              targeting: state.isHammerTargeting,
                              count: state.hammerCount,
                              onPressed: notifier.toggleHammerTargeting,
                            ),
                          ),
                        // O disco do martelo projeta brilho (`blurRadius` 14)
                        // para fora da própria caixa, que só reserva 5pt abaixo
                        // dele. Com 12pt de folga esse brilho encostava na
                        // primeira linha do tabuleiro e lia como célula acesa.
                        //
                        // A folga **veio de cima**, não é altura nova: o card de
                        // métricas já separa visualmente a faixa, e crescer a
                        // coluna empurraria o tabuleiro para fora da dobra em
                        // telas curtas.
                        const SizedBox(height: 22),
                        // Margem menor que a do resto da tela, mas não zero:
                        // colado na borda o tabuleiro parece cortado. Os 8pt
                        // de cada lado são os mesmos assumidos no cálculo de
                        // tamanho de célula.
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          // Os efeitos ficam sobre o tabuleiro e compartilham
                          // a mesma geometria, para a pontuação nascer na
                          // célula certa.
                          //
                          // O tranco do martelo sacode o tabuleiro **com** os
                          // efeitos, e não a tela: quem quebrou foi uma peça, e
                          // um estilhaço que ficasse parado enquanto o tabuleiro
                          // anda denunciaria as duas camadas.
                          child: StrikeShake(
                            serial: state.shakeSerial,
                            child: Stack(
                              key: _boardKey,
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
                                    // A dica não sugere troca durante a mira: o
                                    // toque do jogador tem outro destino agora, e
                                    // um par aceso apontaria para a ação errada.
                                    hintEnabled:
                                        _ready &&
                                        !state.isOver &&
                                        !state.isHammerTargeting,
                                    // Durante a mira o toque não chega aqui: a
                                    // camada de mira o intercepta antes, para
                                    // poder distinguir "bateu na célula" de
                                    // "tocou fora e desistiu".
                                    onTileTap: notifier.selectTile,
                                    onTileSwipe: notifier.swapTiles,
                                  ),
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
                        // O placar subiu para o HUD: no rodapé ficava abaixo do
                        // tabuleiro, fora do campo de visão de quem joga.
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Acima do conteúdo, e é isso que a faz funcionar: a área vazia da
            // tela pertence à rolagem, que consome o toque sem repassá-lo — uma
            // camada por baixo nunca veria o toque de cancelamento.
            // **A mira sai de cena quando o convite de aquisição sobe.** O alvo
            // continua guardado no estado (é o que o Modo Fantasma promete), mas
            // o recorte do véu deixava a célula mirada sem desfoque e com o aro
            // neon aceso atrás do modal: dois focos de atenção competindo, e o
            // que o jogador tem a decidir naquele instante é o botão do
            // anúncio. Com a camada fora, sobra o véu homogêneo do próprio
            // modal.
            if (state.isHammerTargeting && state.pendingHammerTarget == null)
              HammerTargetingLayer(
                boardKey: _boardKey,
                onCell: notifier.useHammer,
                onCancel: notifier.cancelHammerTargeting,
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
            // O convite de aquisição vem antes do cartão de desfecho na ordem
            // de leitura, mas nunca convivem: mirar exige fase em andamento.
            if (state.pendingHammerTarget != null && !state.isOver)
              _OutcomeOverlay(
                child: HammerOfferDialog(
                  onGranted: notifier.grantHammer,
                  onDecline: notifier.cancelHammerTargeting,
                ),
              ),
            // Vem depois do funil do martelo e antes do desfecho: o jogador que
            // está mirando já escolheu o que fazer com a jogada, e a fase
            // encerrada não vende movimento nenhum (regra anti-churn).
            if (_movesOfferOpen &&
                !state.isOver &&
                state.pendingHammerTarget == null)
              _OutcomeOverlay(
                child: MovesOfferDialog(
                  movesLeft: state.movesLeft,
                  reward: state.rewardedMoves,
                  onGranted: () {
                    ref.read(gameProvider.notifier).grantBonusMoves();
                    setState(() => _movesOfferOpen = false);
                  },
                  onDecline: () => setState(() => _movesOfferOpen = false),
                ),
              ),
            if (state.isOver)
              _OutcomeOverlay(
                child: LevelOutcomeCard(
                  state: state,
                  onRetry: notifier.restartLevel,
                  onNext: notifier.nextLevel,
                  onBack: () => Navigator.of(context).maybePop(),
                  starsInChapter: chapterStars,
                  starsGained: _chapterStarsGained,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
