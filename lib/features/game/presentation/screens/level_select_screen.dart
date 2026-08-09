import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/features/game/domain/campaign_chapter.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/presentation/screens/endless_screen.dart';
import 'package:nine_fuse/features/game/presentation/screens/game_screen.dart';
import 'package:nine_fuse/features/game/presentation/widgets/campaign_header.dart';
import 'package:nine_fuse/features/game/presentation/widgets/endless_highlight.dart';
import 'package:nine_fuse/features/game/presentation/widgets/saga_map.dart';
import 'package:nine_fuse/features/game/providers/campaign_records.dart';
import 'package:nine_fuse/features/game/providers/endless_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Quanto tempo o caminho leva para se preencher até a fase recém-liberada.
const Duration kPathRevealDuration = Duration(milliseconds: 900);

/// Mapa da campanha: trilha de pins, cabeçalho de progresso e a ilha do
/// Endless.
class LevelSelectScreen extends ConsumerStatefulWidget {
  const LevelSelectScreen({super.key});

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
      _centerOnCurrentLevel(animated: false);
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
      levelCount: kCampaign.length,
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

  /// Índice da primeira fase ainda não vencida.
  int _currentIndex(int progress) {
    for (int i = 0; i < kCampaign.length; i++) {
      if (kCampaign[i].number > progress) return i;
    }
    return kCampaign.length - 1;
  }

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

    final chapter = chapterOf(kCampaign[_currentIndex(progress)].number);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).appTitle),
        centerTitle: true,
        backgroundColor: AppColors.darkSurface,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Cabeçalho e Endless ficam **fora** da rolagem: são o status e a
            // porta do modo infinito, e sumir de vista ao rolar o mapa faria o
            // jogador ter de voltar ao topo para consultá-los.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Column(
                children: [
                  CampaignHeader(
                    chapter: chapter,
                    totalStars: records.totalStars,
                    starTotal: kCampaignStarTotal,
                  ),
                  const SizedBox(height: 10),
                  EndlessHighlight(
                    isUnlocked: progress >= kEndlessUnlockLevel,
                    unlockedAt: kEndlessUnlockLevel,
                    highScore: highScore,
                    onTap: () => Navigator.of(context)
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
                          }
                        }),
                  ),
                ],
              ),
            ),
            Expanded(
              // Fade nas bordas da rolagem. O cabeçalho e a ilha do Endless
              // são fixos, então a trilha desliza por baixo deles: sem a
              // máscara, a linha e os pins morrem num corte seco na borda. O
              // fade de baixo vem junto porque o corte é o mesmo problema nas
              // duas pontas.
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
                  stops: [0, 0.06, 0.94, 1],
                ).createShader(rect),
                blendMode: BlendMode.dstIn,
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    controller: _scroll,
                    child: Padding(
                      // Num tablet o mapa esticado deixaria os pins longe demais
                      // uns dos outros; a trilha tem largura de leitura própria.
                      padding: EdgeInsets.symmetric(
                        horizontal: ((constraints.maxWidth - 460) / 2).clamp(
                          12,
                          220,
                        ),
                      ),
                      child: AnimatedBuilder(
                        animation: _reveal,
                        builder: (context, _) => SagaMapWidget(
                          levels: kCampaign,
                          progress: progress,
                          starsOf: records.starsFor,
                          revealTo: _reveal.isAnimating ? _revealTo : null,
                          revealProgress: _reveal.value,
                          onTapLevel: (level) => _openLevel(level, unlocked),
                        ),
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

  void _openLevel(GameLevel level, CampaignProgress unlocked) {
    if (!unlocked.isUnlocked(level)) return;

    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => GameScreen(level: level)))
        .then((_) {
          // Ao voltar, reposiciona o mapa na fase da vez — que pode ser outra.
          if (mounted) _centerOnCurrentLevel();
        });
  }
}
