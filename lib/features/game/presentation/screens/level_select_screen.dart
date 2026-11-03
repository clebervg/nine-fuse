import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/core/ads/ad_providers.dart';
import 'package:nine_fuse/core/ads/interstitial_ad_service.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/feedback/haptics.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/core/theme/nf_tokens.dart';
import 'package:nine_fuse/core/widgets/coins_header_badge.dart';
import 'package:nine_fuse/core/widgets/nf_back_button.dart';
import 'package:nine_fuse/core/widgets/nf_background.dart';
import 'package:nine_fuse/core/widgets/nf_modal.dart';
import 'package:nine_fuse/core/widgets/nf_square_button.dart';
import 'package:nine_fuse/core/widgets/privacy_dialog.dart';
import 'package:nine_fuse/core/widgets/sprite_icon.dart';
import 'package:nine_fuse/features/game/domain/campaign_chapter.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/domain/level_catalog.dart';
import 'package:nine_fuse/features/game/domain/level_generator.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';
import 'package:nine_fuse/features/game/domain/obstacle_debut.dart';
import 'package:nine_fuse/features/game/presentation/l10n_labels.dart';
import 'package:nine_fuse/features/game/presentation/screens/endless_screen.dart';
import 'package:nine_fuse/features/game/presentation/screens/game_screen.dart';
import 'package:nine_fuse/features/game/presentation/screens/shop_screen.dart';
import 'package:nine_fuse/features/game/presentation/widgets/campaign_header.dart';
import 'package:nine_fuse/features/game/presentation/widgets/chapter_chest.dart';
import 'package:nine_fuse/features/game/presentation/widgets/daily_spin_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/endless_highlight.dart';
import 'package:nine_fuse/features/game/presentation/widgets/game_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/saga_map.dart';
import 'package:nine_fuse/features/game/providers/campaign_records.dart';
import 'package:nine_fuse/features/game/providers/endless_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_state.dart';
import 'package:nine_fuse/features/game/providers/wallet.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Quanto tempo o caminho leva para se preencher até a fase recém-liberada.
const Duration kPathRevealDuration = Duration(milliseconds: 900);

/// Quantas fases o mapa mostra à frente do progresso do jogador.
///
/// Mais de uma tela de pins, para a trilha nunca terminar dentro do campo de
/// visão: o jogador precisa ver que há continuação sem precisar rolar para
/// descobrir.
const int kLookahead = 8;

/// Quantas fases vencidas a trilha mostra **atrás** da fase da vez.
///
/// A trilha é uma janela que desliza com o progresso, e não um prefixo desde a
/// fase 1: na fase 500 o prefixo montava 508 pins, e o custo crescia com o
/// tempo de jogo em vez de com o que cabe na tela. Trinta é bem mais de uma
/// tela de rolagem para trás — dá para rever as estrelas do capítulo atual e
/// do anterior — e o resto vira o marcador "Fases 1–N concluídas".
const int kLookbehind = 30;

/// A janela de fases que a trilha monta para o progresso [progress]: da
/// primeira à última, inclusive.
///
/// O fim nunca fica antes da última fase artesanal (com progresso zero o mapa
/// já mostra as dez), e o início fica [kLookbehind] fases atrás da fase da
/// vez, nunca antes da 1.
({int first, int last}) mapWindowFor(int progress) {
  final current = progress + 1;
  final wanted = progress + kLookahead;
  final last = wanted < kHandcraftedLevels ? kHandcraftedLevels : wanted;
  final first = current - kLookbehind < 1 ? 1 : current - kLookbehind;
  return (first: first, last: last);
}

/// Chave do ícone de privacidade, na AppBar.
const levelSelectPrivacyIconKey = Key('level_select_privacy_icon');

/// Chave do ícone de atalho da roleta diária, na AppBar.
const Key levelSelectDailySpinIconKey = Key('level_select_daily_spin_icon');

/// Chave do botão fixo "JOGAR FASE N", no pé do mapa.
const Key levelSelectPlayButtonKey = Key('level_select_play_button');

/// Chave do aviso de obstáculo novo nas próximas fases.
const Key obstacleDebutNoticeKey = Key('obstacle_debut_notice');

/// Mapa da campanha: trilha de pins, cabeçalho de progresso e a ilha do
/// Endless.
class LevelSelectScreen extends ConsumerStatefulWidget {
  const LevelSelectScreen({super.key, this.autoOpenCurrent = false});

  /// Abre a fase da vez assim que o mapa monta — o JOGAR do menu inicial.
  ///
  /// O menu não abre a fase sozinho porque o fim de partida volta "às fases":
  /// com o mapa por baixo, voltar cai na trilha, com a animação da fase
  /// liberada; sem ele, cairia no menu, desmentindo o rótulo do botão.
  final bool autoOpenCurrent;

  @override
  ConsumerState<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends ConsumerState<LevelSelectScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  late final AnimationController _reveal;

  /// Índice do trecho que está sendo preenchido, ou nulo fora da animação.
  int? _revealTo;

  /// Progresso conhecido no último quadro, para detectar a fase recém-vencida.
  int? _lastProgress;

  @override
  void initState() {
    super.initState();

    // Finito e disparado sob demanda: uma animação que se repete deixaria
    // `pumpAndSettle` sem fim.
    _reveal = AnimationController(vsync: this, duration: kPathRevealDuration);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // A sessão de Endless que acabou de terminar pode ter batido o recorde,
      // e quem gravou foi o outro notifier.
      ref.read(endlessHighScoreProvider.notifier).refresh();
      // O mapa fica fora de cena enquanto a fase roda, e a fase gasta e ganha
      // martelo escrevendo direto no disco. Sem reler, a barra de recursos
      // mostraria o saldo de antes da partida.
      ref.read(walletProvider.notifier).refresh();
      _centerOnCurrentLevel(animated: false);
      // O botão de anúncio da roleta diária também vive nesta tela (o atalho
      // do topo), e a fase aberta daqui pede os anúncios aquecidos.
      preloadRewardedAds(ref);

      // Vindo do JOGAR do menu: a fase da vez abre por cima do mapa, pelo
      // mesmo caminho do pin, para o "voltar às fases" do fim de partida
      // cair aqui — e a trilha tocar a liberação da fase recém-vencida.
      //
      // O aviso de app aberto e a roleta diária automática saíram daqui: a
      // primeira tela agora é o menu inicial (`HomeScreen`), e é ele quem os
      // faz. Repetir aqui abriria a roleta duas vezes na mesma sessão.
      if (widget.autoOpenCurrent) {
        final progress = ref.read(campaignProgressProvider);
        _openLevel(
          levelAt(progress + 1),
          ref.read(campaignProgressProvider.notifier),
        );
      }
    });
  }

  @override
  void dispose() {
    _reveal.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Abre o mapa já mostrando a fase que o jogador deve jogar agora.
  ///
  /// Sem isto, com a campanha adiantada o jogador abre o mapa no pé da trilha e
  /// precisa rolar para achar onde estava — e o pin que pulsa fica fora da
  /// tela, sem cumprir a função de chamar a atenção.
  void _centerOnCurrentLevel({bool animated = true}) {
    if (!_scroll.hasClients) return;

    final progress = ref.read(campaignProgressProvider);
    final index = _currentIndex(progress);

    final geometry = SagaGeometry(
      // A largura não altera a posição **vertical**, que é a única de que a
      // rolagem precisa — daí não haver problema em usar a da tela.
      width: MediaQuery.of(context).size.width,
      levelCount: _visibleCount(progress),
    );

    final viewport = _scroll.position.viewportDimension;
    final target = (geometry.centerOf(index).dy - viewport / 2).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );

    if (animated) {
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scroll.jumpTo(target);
    }
  }

  /// Quantas fases a trilha mostra agora.
  int _visibleCount(int progress) {
    final window = mapWindowFor(progress);
    return window.last - window.first + 1;
  }

  /// Índice da primeira fase ainda não vencida, dentro da janela visível.
  ///
  /// O índice conta a partir do **início móvel** da janela: a fase da vez
  /// (`progress + 1`) menos a primeira fase montada.
  int _currentIndex(int progress) =>
      (progress + 1 - mapWindowFor(progress).first).clamp(
        0,
        _visibleCount(progress) - 1,
      );

  /// Toca a animação de liberação do trecho que leva à fase recém-aberta.
  void _playReveal(int progress) {
    final index = _currentIndex(progress);
    if (index <= 0) return;

    setState(() => _revealTo = index);
    _reveal.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(campaignProgressProvider);
    final unlocked = ref.read(campaignProgressProvider.notifier);
    final records = ref.watch(campaignRecordsProvider.notifier);
    // Observado para o cabeçalho se atualizar quando uma fase é registrada:
    // o notifier sozinho não notifica.
    ref.watch(campaignRecordsProvider);
    final highScore = ref.watch(endlessHighScoreProvider);

    // O progresso muda por dois motivos, e os dois precisam reposicionar o
    // mapa: o jogador venceu uma fase, ou a **leitura do disco** chegou. A
    // segunda é fácil de esquecer — a leitura é assíncrona, então o primeiro
    // quadro do mapa sempre mostra progresso zero, e sem recentralizar depois
    // dela quem já jogou abre o mapa no pé da trilha.
    if (_lastProgress != progress) {
      final previous = _lastProgress;
      _lastProgress = progress;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Só é vitória se já havia um valor anterior: a chegada da leitura não
        // é conquista nenhuma e não merece a animação de liberação.
        if (previous != null && progress > previous) _playReveal(progress);
        _centerOnCurrentLevel(animated: previous != null);
      });
    }

    final window = mapWindowFor(progress);
    final visible = [
      for (int n = window.first; n <= window.last; n++) levelAt(n),
    ];
    final current = levelAt(progress + 1);
    final chapter = chapterOf(current.number);
    final debut = upcomingObstacleDebut(current.number);
    final l10n = AppLocalizations.of(context);
    // Ponto vermelho na roleta enquanto há giro grátis esperando. Falha de
    // leitura vale como "sem giro": é aviso, e um aviso falso é pior que
    // nenhum.
    final spinWaiting =
        ref.watch(dailySpinEligibleProvider).asData?.value ?? false;
    // O mapa é empilhado pelo menu inicial, então o voltar aparece; a guarda
    // fica para o caso de ele ser a raiz (testes, deep link futuro). Pela rota, e não por `Navigator.canPop`: com um diálogo aberto por cima
    // (a roleta) o navegador "pode voltar", mas o mapa continua sendo a raiz.
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    // Tela curta (iPhone SE): o topo fixo aperta os respiros para sobrar
    // trilha entre ele e o botão de jogar.
    final gap = MediaQuery.sizeOf(context).height < 720 ? 8.0 : 12.0;

    // O céu fica por trás do `Scaffold` inteiro — inclusive da `AppBar`
    // transparente —, para o topo não virar uma faixa de outra cor.
    return NfBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          leadingWidth: canPop ? kNfBackButtonLeadingWidth : 0,
          leading: canPop ? const NfBackButton() : null,
          titleSpacing: canPop ? 4 : 18,
          centerTitle: false,
          // Os atalhos ficam à esquerda, na mesma placa do botão voltar; a
          // direita é da carteira, como em todas as telas.
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              NfSquareButton(
                key: levelSelectDailySpinIconKey,
                icon: Icons.casino_rounded,
                tooltip: l10n.mapDailySpinTooltip,
                badge: spinWaiting,
                onPressed: _openDailySpin,
              ),
              const SizedBox(width: 10),
              NfSquareButton(
                key: levelSelectPrivacyIconKey,
                icon: Icons.privacy_tip_outlined,
                tooltip: l10n.privacyTooltip,
                onPressed: () => showPrivacyDialog(context),
              ),
            ],
          ),
          // Fora de uma partida não há `GameState`, então aqui o espelho da
          // carteira é a única leitura possível do estoque — e é a tela em que
          // saber quantos martelos restam decide se vale comprar antes de
          // entrar. Ocupa o lugar da pílula de estrelas do design: o total de
          // estrelas que importa (o do capítulo) já está na placa logo abaixo.
          actions: [
            CoinsHeaderBadge(
              hammers: ref.watch(walletProvider).hammers,
              // Fora de uma partida, o `+` leva à Loja de verdade.
              onAdd: () => openShop(context),
            ),
            const SizedBox(width: 14),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Placa, aviso e Endless ficam **fora** da rolagem: são o status
              // e a porta do modo infinito, e sumir de vista ao rolar o mapa
              // faria o jogador ter de voltar ao topo para consultá-los.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: _capped(
                  Column(
                    // Esticada: a placa do capítulo ocupa a largura toda, como
                    // a do Endless logo abaixo.
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CampaignHeader(
                        chapter: chapter,
                        totalStars: records.starsInChapter(chapter),
                        starTotal: chapter.starTotal,
                        currentLevel: current.number,
                      ),
                      if (debut != null) ...[
                        SizedBox(height: gap),
                        Center(
                          child: _ObstacleDebutNotice(
                            level: debut.level,
                            type: debut.type,
                          ),
                        ),
                      ],
                      SizedBox(height: gap),
                      EndlessHighlight(
                        isUnlocked: endlessIsUnlocked(progress),
                        unlockedAt: kEndlessUnlockLevel,
                        highScore: highScore,
                        onTap: _openEndless,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                // Fade nas bordas da rolagem. O topo e o botão de jogar são
                // fixos, então a trilha desliza por baixo deles: sem a
                // máscara, a linha e os pins morrem num corte seco na borda.
                //
                // `dstIn` usa **o alfa** do degradê como recorte, daí as cores
                // serem branco opaco → transparente e não uma cor de fundo: um
                // fade pintado por cima só funcionaria sobre fundo chapado.
                child: ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.white,
                      Colors.white,
                      Colors.transparent,
                    ],
                    stops: [0, 0.08, 0.92, 1],
                  ).createShader(rect),
                  blendMode: BlendMode.dstIn,
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      controller: _scroll,
                      child: Padding(
                        // Num tablet o mapa esticado deixaria os pins longe
                        // demais uns dos outros; a trilha tem largura de
                        // leitura própria.
                        padding: EdgeInsets.symmetric(
                          horizontal: ((constraints.maxWidth - 460) / 2).clamp(
                            12,
                            220,
                          ),
                        ),
                        child: AnimatedBuilder(
                          animation: _reveal,
                          builder: (context, _) => SagaMapWidget(
                            levels: visible,
                            progress: progress,
                            starsOf: records.starsFor,
                            revealTo: _reveal.isAnimating ? _revealTo : null,
                            revealProgress: _reveal.value,
                            onTapLevel: (level) => _openLevel(level, unlocked),
                            claimedChests: ref.watch(
                              walletProvider.select((w) => w.claimedChests),
                            ),
                            onTapChest: _onTapChest,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // O botão grande fica fixo no alcance do polegar: é a ação da
              // tela, e não pode depender de o pin da vez estar à vista.
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 4, 28, 14),
                child: _capped(
                  GameButton(
                    key: levelSelectPlayButtonKey,
                    label: l10n.mapPlayLevel(current.number),
                    subtitle: l10n
                        .objectiveLabel(current.objective)
                        .toUpperCase(),
                    color: AppColors.uiGold,
                    fontSize: 26,
                    // O mesmo caminho do toque no pin da vez — cartão de
                    // início incluído —, para os dois nunca divergirem.
                    onPressed: () => _openLevel(current, unlocked),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Limita a largura dos blocos fixos num tablet: a placa esticada de borda
  /// a borda deixaria o nome do capítulo perdido no meio de um painel vazio.
  Widget _capped(Widget child) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: child,
    ),
  );

  void _openEndless() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const EndlessScreen())).then((_) {
      if (!mounted) return;
      ref.read(endlessHighScoreProvider.notifier).refresh();
      // A corrida do Endless também gasta e ganha martelo, gravado direto
      // no disco.
      ref.read(walletProvider.notifier).refresh();
    });
  }

  /// Toque num baú da trilha.
  ///
  /// Pronto: paga e anuncia. Trancado: diz o que falta. Aberto: nada — o
  /// cinza dele já é a resposta.
  Future<void> _onTapChest(CampaignChapter chapter, ChestState state) async {
    switch (state) {
      case ChestState.locked:
        await showNfModal<void>(
          context,
          builder: (_) => ChestLockedPopup(chapter: chapter.number),
        );
      case ChestState.ready:
        final wallet = ref.read(walletProvider.notifier);
        // Relê o disco **antes** de pagar. A carteira nasce zerada e a
        // leitura do mapa é assíncrona: um toque que chegasse antes dela
        // veria o baú como não pago (e o repagaria) e gravaria um saldo
        // montado sobre zero por cima das moedas de verdade. Com a carteira
        // já carregada a releitura não muda nada; `claimChapterChest` segue
        // sendo a trava de "uma vez só", inclusive contra toque duplo.
        await wallet.refresh();
        if (!mounted || !wallet.claimChapterChest(chapter.number)) return;
        Haptics.medium();
        await showNfModal<void>(
          context,
          elastic: true,
          builder: (_) =>
              ChestRewardPopup(coins: chapterChestReward(chapter.number)),
        );
      case ChestState.opened:
        break;
    }
  }

  void _openDailySpin() {
    showNfModal<void>(
      context,
      barrierDismissible: false,
      builder: (_) => const DailySpinDialog(),
    );
  }

  void _openLevel(GameLevel level, CampaignProgress unlocked) {
    if (!unlocked.isUnlocked(level)) return;

    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => GameScreen(level: level)))
        .then((_) {
          // Ao voltar, reposiciona o mapa na fase da vez — que pode ser outra.
          if (!mounted) return;
          _centerOnCurrentLevel();
          // A fase pode ter gasto martelo e ganho moeda por estrela nova.
          ref.read(walletProvider.notifier).refresh();
          // A saída da fase para o mapa é o outro momento do intersticial.
          // O desfecho da última partida decide: derrota nunca mostra.
          final moment = switch (ref.read(gameProvider).status) {
            GameStatus.won => InterstitialMoment.afterVictory,
            GameStatus.lost => InterstitialMoment.afterDefeat,
            _ => InterstitialMoment.exitToMap,
          };
          maybeShowInterstitial(ref, moment);
        });
  }
}

/// Aviso "Novo obstáculo na fase N: vidro", logo abaixo da placa do capítulo.
///
/// Chega antes da fase, e não só no cartão de início dela: no cartão o
/// jogador já decidiu jogar; aqui ele ainda pode contar com o que vem — e a
/// estreia de uma cobertura é exatamente o tipo de mudança de regra que
/// surpreende mal quando aparece sem aviso.
class _ObstacleDebutNotice extends StatelessWidget {
  const _ObstacleDebutNotice({required this.level, required this.type});

  final int level;
  final ObstacleType type;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      key: obstacleDebutNoticeKey,
      height: 34,
      padding: const EdgeInsets.fromLTRB(5, 0, 14, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        color: NfColors.night1.withValues(alpha: 0.85),
        border: Border.all(
          color: const Color(0xFF5AC8FA).withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // A cobertura intacta, a mesma arte que ela terá no tabuleiro: o
          // jogador reconhece a peça quando a encontrar.
          SpriteIcon(
            asset:
                'assets/sprites/obstacles/obstacle_${type.name}_'
                '${type.hitPoints}.png',
            fallback: Icons.layers_rounded,
            size: 26,
            color: const Color(0xFFBFE9FF),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              l10n.mapNewObstacle(level, l10n.obstacleName(type, 1)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppFonts.number,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                height: 1,
                color: Color(0xFFBFE9FF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
