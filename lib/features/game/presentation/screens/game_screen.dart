import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/core/ads/ad_providers.dart';
import 'package:nine_fuse/core/audio/audio_service.dart';
import 'package:nine_fuse/core/audio/sound_event.dart';
import 'package:nine_fuse/core/theme/nf_tokens.dart';
import 'package:nine_fuse/core/widgets/nf_background.dart';
import 'package:nine_fuse/features/game/domain/campaign_chapter.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/star_rating.dart';
import 'package:nine_fuse/features/game/presentation/screens/endless_screen.dart';
import 'package:nine_fuse/features/game/presentation/widgets/apex_celebration.dart';
import 'package:nine_fuse/features/game/presentation/widgets/board_frame.dart';
import 'package:nine_fuse/features/game/presentation/widgets/board_grid_widget.dart';
import 'package:nine_fuse/features/game/presentation/widgets/bomb_offer_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/brush_offer_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/combo_banner.dart';
import 'package:nine_fuse/features/game/presentation/widgets/continue_offer_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/endless_suggestion_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_button.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_offer_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_targeting_layer.dart';
import 'package:nine_fuse/features/game/presentation/widgets/juice_overlay.dart';
import 'package:nine_fuse/features/game/presentation/widgets/level_banner.dart';
import 'package:nine_fuse/features/game/presentation/widgets/level_outcome_card.dart';
import 'package:nine_fuse/features/game/presentation/widgets/level_start_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/moves_offer_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/playfield_layout.dart';
import 'package:nine_fuse/features/game/presentation/widgets/strike_shake.dart';
import 'package:nine_fuse/features/game/providers/campaign_records.dart';
import 'package:nine_fuse/features/game/providers/endless_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_state.dart';
import 'package:nine_fuse/features/game/providers/wallet.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Tela de uma fase: objetivo, movimentos restantes, tabuleiro e desfecho.
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key, required this.level});

  final GameLevel level;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

/// Fundo de uma camada de [_OutcomeOverlay].
enum _Backdrop {
  /// Véu escuro sobre o tabuleiro: convites e cartões que pedem uma decisão
  /// no meio da partida, com o tabuleiro ainda de pé por trás.
  veil,

  /// O céu inteiro: a vitória ocupa a tela, e o tabuleiro por trás só
  /// competiria com os raios.
  sky,

  /// O céu mais escuro da derrota. Mais apagado que o da vitória, para as duas
  /// telas não se confundirem de relance.
  skyDim,
}

/// Escurece o tabuleiro e centraliza o cartão de desfecho, garantindo que os
/// botões fiquem visíveis mesmo em tela pequena.
class _OutcomeOverlay extends StatelessWidget {
  const _OutcomeOverlay({this.child, this.fit, this.backdrop = _Backdrop.veil})
    : assert((child == null) != (fit == null), 'child ou fit, um dos dois');

  final Widget? child;

  /// Monta o conteúdo sabendo a altura útil da camada.
  ///
  /// Para as telas cheias (vitória e derrota), que precisam caber sem rolagem
  /// com o botão principal à vista: dentro do `SingleChildScrollView` a altura
  /// é ilimitada, e só aqui fora se sabe quanto a tela realmente tem.
  final Widget Function(double height)? fit;
  final _Backdrop backdrop;

  static const double _padding = 24;

  @override
  Widget build(BuildContext context) {
    final body = SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(_padding),
          child: Center(
            child: child ?? fit!(constraints.maxHeight - 2 * _padding),
          ),
        ),
      ),
    );
    return Positioned.fill(
      // `ColoredBox` por fora em todos os casos: é ele que barra o toque no
      // tabuleiro por baixo, e o convite de movimentos depende disso para o
      // prêmio anunciado e o pago não divergirem (ver "Dynamic Extra Moves").
      child: switch (backdrop) {
        _Backdrop.veil => ColoredBox(
          color: Colors.black.withValues(alpha: 0.75),
          child: body,
        ),
        _Backdrop.sky => ColoredBox(
          color: NfColors.night1,
          child: NfBackground(child: body),
        ),
        _Backdrop.skyDim => ColoredBox(
          color: NfColors.night0,
          child: NfBackground(dim: 0.4, child: body),
        ),
      },
    );
  }
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

  /// O convite de migração para o Modo Recorde está aberto agora?
  ///
  /// Mesmo motivo de [_movesOfferOpen]: precisa ser separado de
  /// `GameState.shouldOfferEndless` porque abrir o convite não muda o
  /// contador — só `markEndlessOfferShown()` o gasta, e é a tela quem decide
  /// chamá-lo.
  bool _endlessSuggestionOpen = false;

  /// O convite de resgate de derrota está aberto agora?
  ///
  /// Mesmo motivo de [_movesOfferOpen]: `shouldOfferContinue` também é
  /// consumido por quem chama `grantContinueMoves` (que já muda o status para
  /// `playing` e apaga a condição), então só a tela sabe se o cartão chegou a
  /// subir.
  bool _continueOfferOpen = false;

  /// Onde o tabuleiro está na tela. A camada de mira do martelo precisa saber:
  /// é o que separa "bateu numa célula" de "tocou fora e desistiu".
  final GlobalKey _boardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    GameAudio.music(MusicTrack.game);
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
  void dispose() {
    // A fase sempre volta a uma tela de fora da partida (mapa ou menu).
    GameAudio.music(MusicTrack.menu);
    super.dispose();
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
      // O som do desfecho sai com o cartão, na transição — e não no cartão,
      // que é reconstruído a cada quadro das animações dele.
      if (previous != null && previous.status != next.status) {
        if (next.status == GameStatus.won) GameAudio.play(SoundEvent.victory);
        if (next.status == GameStatus.lost) GameAudio.play(SoundEvent.defeat);
      }

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

      // A Nova é a única fonte de moeda **dentro** de uma jogada. O
      // `GameNotifier` não tem `ref` (é um `StateNotifier` comum, não um
      // `Consumer`), então ele só acumula o total em `novaCoinsGranted` — é
      // a tela quem observa o quanto esse total **cresceu** desde o estado
      // anterior e credita a diferença na carteira. `previous` só é nulo no
      // primeiro build, quando não há diferença nenhuma a creditar.
      if (previous != null &&
          next.novaCoinsGranted > previous.novaCoinsGranted) {
        ref
            .read(walletProvider.notifier)
            .creditCoins(next.novaCoinsGranted - previous.novaCoinsGranted);
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
          _continueOfferOpen = false;
          _endlessSuggestionOpen = false;
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

      // O convite de resgate não depende de `_ready`: a fase já perdeu, o
      // cartão de início não está mais no caminho. Ao contrário do convite de
      // movimentos, `markContinueOfferShown()` não é chamado aqui: quem marca
      // `continueOfferShown` é `grantContinueMoves()` ao aceitar, ou o
      // `onDecline` abaixo ao recusar — marcar cedo demais faria
      // `grantContinueMoves()` recusar o próprio crédito, já que ele mesmo
      // usa `continueOfferShown` como guarda contra double-crédito.
      if (!_continueOfferOpen && next.shouldOfferContinue) {
        _continueOfferOpen = true;
      }

      // O convite de migração só sobe depois de a fase acabar em derrota —
      // diferente do de movimentos, que é pre-churn. `endlessIsUnlocked` lê o
      // progresso da campanha porque `GameState` não tem acesso a ele.
      if (!_endlessSuggestionOpen &&
          next.shouldOfferEndless &&
          endlessIsUnlocked(ref.read(campaignProgressProvider))) {
        _endlessSuggestionOpen = true;
        ref.read(gameProvider.notifier).markEndlessOfferShown();
      }
    });

    // O céu fica por trás do `Scaffold` inteiro — inclusive da `AppBar`
    // transparente —, para o topo não virar uma faixa de outra cor.
    return NfBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: playfieldAppBar(
          title: AppLocalizations.of(
            context,
          ).levelTitle(state.level.number).toUpperCase(),
        ),
        body: SafeArea(
          // O desfecho é sobreposto, não empilhado abaixo do tabuleiro: numa
          // tela de celular os botões cairiam fora da dobra e a ação principal
          // depois de vencer ficaria inalcançável sem rolar.
          child: Stack(
            children: [
              PlayfieldLayout(
                hud: LevelBanner(state: state),
                // O dock some com a fase encerrada — um booster oferecido
                // sobre o cartão de derrota promete o que já não pode cumprir.
                // O espaço dele fica (ver `PlayfieldLayout`).
                dock: state.isOver
                    ? null
                    : HammerBar(
                        buttonKey: hammerButtonKey,
                        targeting: state.isHammerTargeting,
                        count: state.hammerCount,
                        onPressed: notifier.toggleHammerTargeting,
                        bombButtonKey: bombButtonKey,
                        bombTargeting: state.isBombTargeting,
                        bombCount: state.bombCount,
                        onBombPressed: notifier.toggleBombTargeting,
                        brushButtonKey: brushButtonKey,
                        brushTargeting: state.isBrushTargeting,
                        brushCount: state.brushCount,
                        onBrushPressed: notifier.toggleBrushTargeting,
                      ),
                // Os efeitos ficam sobre o tabuleiro e compartilham a mesma
                // geometria, para a pontuação nascer na célula certa.
                //
                // O tranco do martelo sacode o tabuleiro **com** os efeitos e
                // a moldura, e não a tela: quem quebrou foi uma peça, e um
                // estilhaço que ficasse parado enquanto o tabuleiro anda
                // denunciaria as duas camadas.
                // A Bomba treme mais forte que o Martelo/dígito máximo — nove
                // células de uma vez pesam mais que uma —, e por isso vive num
                // `StrikeShake` **fora** do outro em vez de somar ao mesmo
                // `shakeSerial`: um tranco maior por cima de um menor ainda lê
                // como um tranco só, mas dois contadores independentes no
                // mesmo widget se cancelariam. A Nova treme mais forte ainda
                // (2.0x): é o clímax mais raro do jogo, e por isso vive na
                // camada mais externa das três.
                board: StrikeShake(
                  serial: state.novaStrikes,
                  amplitude: kStrikeShakeAmplitude * 2.0,
                  child: StrikeShake(
                    serial: state.bombStrikes,
                    amplitude: kStrikeShakeAmplitude * 1.8,
                    child: StrikeShake(
                      serial: state.shakeSerial,
                      // A moldura fica **fora** do `Stack` com a chave do
                      // tabuleiro: a camada de mira mede o tabuleiro por essa
                      // chave, e o aro de ouro não é célula.
                      child: BoardFrame(
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
                                // dica acende junto com o tabuleiro. Fase
                                // acabada também não sugere jogada. A dica
                                // não sugere troca durante a mira: o toque do
                                // jogador tem outro destino agora, e um par
                                // aceso apontaria para a ação errada.
                                hintEnabled:
                                    _ready &&
                                    !state.isOver &&
                                    !state.isHammerTargeting &&
                                    !state.isBombTargeting &&
                                    !state.isBrushTargeting,
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
                                bombStrike: state.bombStrike,
                                bombStrikeSerial: state.bombStrikes,
                                showSupernova: state.pendingSupernova,
                              ),
                            ),
                          ],
                        ),
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
              // Mesma camada, área maior: `areaRadius: 1` recorta o 3x3 em vez
              // da célula única. A Bomba também tem Modo Fantasma (mirar sem
              // estoque guarda o alvo), então a mira sai de cena assim que o
              // convite de aquisição sobe — mesma regra do Martelo.
              if (state.isBombTargeting && state.pendingBombTarget == null)
                HammerTargetingLayer(
                  boardKey: _boardKey,
                  areaRadius: 1,
                  onCell: notifier.useBomb,
                  onCancel: notifier.cancelBombTargeting,
                ),
              // O Pincel mira uma célula só, como o Martelo — `areaRadius`
              // padrão (0) — e tem o mesmo Modo Fantasma.
              if (state.isBrushTargeting && state.pendingBrushTarget == null)
                HammerTargetingLayer(
                  boardKey: _boardKey,
                  onCell: notifier.usePaint,
                  onCancel: notifier.cancelBrushTargeting,
                ),
              // A dica de mira vem **depois** das camadas de mira: o véu desfoca
              // tudo menos o tabuleiro, e é esta a frase que o jogador precisa
              // ler naquele instante. Some junto com a camada quando o convite
              // de aquisição sobe.
              if ((state.isHammerTargeting &&
                      state.pendingHammerTarget == null) ||
                  (state.isBombTargeting && state.pendingBombTarget == null) ||
                  (state.isBrushTargeting && state.pendingBrushTarget == null))
                const BoosterAimHint(),
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
                    onClose: () => Navigator.of(context).pop(),
                    onBuyHammer: notifier.grantHammer,
                    onBuyBomb: notifier.grantBomb,
                    onBuyBrush: notifier.grantBrush,
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
              if (state.pendingBombTarget != null && !state.isOver)
                _OutcomeOverlay(
                  child: BombOfferDialog(
                    onGranted: notifier.grantBomb,
                    onDecline: notifier.cancelBombTargeting,
                  ),
                ),
              if (state.pendingBrushTarget != null && !state.isOver)
                _OutcomeOverlay(
                  child: BrushOfferDialog(
                    onGranted: notifier.grantBrush,
                    onDecline: notifier.cancelBrushTargeting,
                  ),
                ),
              // Vem depois do funil dos três boosters e antes do desfecho: o
              // jogador que está mirando já escolheu o que fazer com a jogada, e
              // a fase encerrada não vende movimento nenhum (regra anti-churn).
              if (_movesOfferOpen &&
                  !state.isOver &&
                  state.pendingHammerTarget == null &&
                  state.pendingBombTarget == null &&
                  state.pendingBrushTarget == null)
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
                  backdrop: state.status == GameStatus.won
                      ? _Backdrop.sky
                      : _Backdrop.skyDim,
                  fit: (height) => LevelOutcomeCard(
                    availableHeight: height,
                    state: state,
                    onRetry: notifier.restartLevel,
                    onNext: notifier.nextLevel,
                    onBack: () => Navigator.of(context).maybePop(),
                    starsInChapter: chapterStars,
                    starsGained: _chapterStarsGained,
                  ),
                ),
              // Sobe **sobre** o cartão de derrota: recusar revela o mesmo
              // cartão, com o botão de tentar de novo intacto. Aceitar revive a
              // fase e `state.isOver` vira falso no mesmo estado.
              if (_continueOfferOpen && state.isOver)
                _OutcomeOverlay(
                  backdrop: _Backdrop.skyDim,
                  fit: (height) => ContinueOfferDialog(
                    availableHeight: height,
                    state: state,
                    onGranted: () {
                      ref.read(gameProvider.notifier).grantContinueMoves();
                      setState(() => _continueOfferOpen = false);
                    },
                    onDecline: () {
                      ref.read(gameProvider.notifier).markContinueOfferShown();
                      setState(() => _continueOfferOpen = false);
                    },
                  ),
                ),
              // Sobe **sobre** o cartão de desfecho: recusar revela o mesmo
              // cartão, com o botão de tentar de novo intacto.
              if (_endlessSuggestionOpen && state.isOver)
                _OutcomeOverlay(
                  child: EndlessSuggestionDialog(
                    onGoToEndless: () {
                      setState(() => _endlessSuggestionOpen = false);
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute(
                              builder: (_) => const EndlessScreen(),
                            ),
                          )
                          .then((_) {
                            if (mounted) {
                              ref
                                  .read(endlessHighScoreProvider.notifier)
                                  .refresh();
                              ref.read(walletProvider.notifier).refresh();
                            }
                          });
                    },
                    onDecline: () =>
                        setState(() => _endlessSuggestionOpen = false),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
