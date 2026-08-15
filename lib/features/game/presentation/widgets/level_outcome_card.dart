import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/features/game/domain/campaign_chapter.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/presentation/widgets/game_dialog.dart';
import 'package:nine_fuse/features/game/domain/star_rating.dart';
import 'package:nine_fuse/features/game/presentation/widgets/chapter_star_progress.dart';
import 'package:nine_fuse/features/game/providers/game_state.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Chave da fileira de estrelas.
const Key starsKey = Key('level_stars');

/// Chave do selo de moedas ganhas na partida.
const Key coinRewardKey = Key('level_coin_reward');

/// Quantas estrelas a fileira sempre desenha. As não conquistadas ficam
/// apagadas em vez de sumir: o jogador precisa ver o que deixou na mesa.
const int kMaxStars = 3;

/// Cartão de fim de fase. Diz o que aconteceu e oferece a saída óbvia:
/// avançar quando venceu, tentar de novo quando perdeu.
class LevelOutcomeCard extends StatelessWidget {
  const LevelOutcomeCard({
    super.key,
    required this.state,
    required this.onRetry,
    required this.onNext,
    required this.onBack,
    this.starsInChapter,
    this.starsGained,
  });

  final GameState state;
  final VoidCallback onRetry;
  final VoidCallback onNext;
  final VoidCallback onBack;

  /// Estrelas acumuladas no capítulo desta fase, já contando esta partida, e
  /// quantas entraram agora.
  ///
  /// Opcionais porque quem os conhece é a tela, que lê o `CampaignRecords`;
  /// este cartão é `StatelessWidget` sem provider de propósito, e é isso que
  /// permite testá-lo sem `ProviderScope`. Nulos, a barra não é desenhada.
  final int? starsInChapter;
  final int? starsGained;

  bool get _won => state.status == GameStatus.won;

  int get _stars => starRating(
    movesLeft: state.movesLeft,
    movesAvailable: state.movesAvailable,
  );

  /// Título do cartão: o que aconteceu, em uma linha lida de relance.
  ///
  /// As duas derrotas têm títulos distintos e vêm de [GameState.lossReason],
  /// não do saldo de movimentos. Deduzir pelo saldo foi a origem do relato de
  /// falso fim de jogo: uma fase perdida no limite, com o tabuleiro ainda cheio
  /// de combinações à vista, anunciava tabuleiro travado.
  String _title(AppLocalizations l10n) {
    if (_won) return l10n.outcomeWonTitle;
    return switch (state.lossReason) {
      LossReason.moveLimitReached => l10n.outcomeMovesTitle,
      LossReason.boardStuck => l10n.outcomeStuckTitle,
      null => l10n.outcomeGenericTitle,
    };
  }

  /// Subtítulo: o que isso significa para o jogador.
  String _message(AppLocalizations l10n) {
    if (_won) return l10n.outcomeWonMessage(state.moves);

    return switch (state.lossReason) {
      LossReason.moveLimitReached => l10n.outcomeMovesMessage,
      LossReason.boardStuck => l10n.outcomeStuckMessage,
      null => l10n.outcomeGenericMessage,
    };
  }

  /// Linha extra que separa as duas derrotas para quem quiser entender por quê.
  ///
  /// Vale principalmente no limite de movimentos: sem dizer que ainda havia
  /// jogadas, "movimentos esgotados" segue sendo lido como "o tabuleiro morreu".
  String? _detail(AppLocalizations l10n) {
    if (_won) return null;
    return switch (state.lossReason) {
      LossReason.moveLimitReached => l10n.outcomeMovesDetail(
        state.movesAvailable,
      ),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = _won ? AppColors.digit2 : AppColors.digit0;

    final card = GameDialog(
      cardKey: const Key('level_outcome'),
      // O título sai da caixa, num selo curvo. Dentro de um retângulo ele lia
      // como aviso de sistema; pregado no alto, lê como resultado de partida.
      title: _title(l10n),
      accent: accent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_won)
            _StarRow(stars: _stars)
          else
            Icon(Icons.replay_circle_filled, color: accent, size: 40),
          const SizedBox(height: 12),
          Text(
            _message(l10n),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          if (_detail(l10n) case final detail?) ...[
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
          // Abaixo das estrelas da fase e acima do placar: a ordem vai do
          // imediato (o que esta partida rendeu) para o acumulado (o que o
          // capítulo já tem), sem empurrar "PRÓXIMA FASE" para fora da dobra.
          if (_won && starsInChapter != null && starsGained != null) ...[
            const SizedBox(height: 14),
            ChapterStarProgress(
              chapter: chapterOf(state.level.number),
              starsInChapter: starsInChapter!,
              starsGained: starsGained!,
            ),
          ],
          // O prêmio em moeda vem logo abaixo das estrelas que o pagaram: é a
          // única coisa da tela que liga a nota da partida ao inventário, e
          // separá-la do placar (cinza, pequeno) é o que a faz ler como
          // recompensa em vez de mais uma métrica.
          if (_won && (starsGained ?? 0) > 0) ...[
            const SizedBox(height: 12),
            _CoinReward(coins: starsGained! * kCoinsPerStar),
          ],
          const SizedBox(height: 6),
          Text(
            l10n.outcomeScore(state.score),
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 18),
          if (_won)
            _FullWidthButton(
              key: const Key('next_level'),
              label: l10n.nextLevelButton,
              icon: Icons.arrow_forward,
              color: accent,
              onPressed: onNext,
            )
          else
            _FullWidthButton(
              key: const Key('retry_level'),
              label: _won ? l10n.playAgainButton : l10n.tryAgainButton,
              icon: Icons.refresh,
              color: accent,
              onPressed: onRetry,
            ),
          const SizedBox(height: 8),
          GameTextButton(
            key: const Key('back_to_levels'),
            label: l10n.backToLevels,
            onPressed: onBack,
          ),
        ],
      ),
    );

    if (!_won) return card;

    // Os confetes ficam **atrás** do cartão e não interceptam toque: a festa
    // não pode ficar entre o dedo e o botão de avançar.
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        const Positioned.fill(child: IgnorePointer(child: _Confetti())),
        card,
      ],
    );
  }
}

/// Selo do que a partida rendeu em moedas.
///
/// Só aparece quando houve **estrela nova**: rejogar uma fase já dominada rende
/// zero (é a regra anti-farm que `CampaignRecords.record()` já garantia), e um
/// selo escrito "+0 🪙" anunciaria que o jogo esqueceu de pagar.
class _CoinReward extends StatelessWidget {
  const _CoinReward({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      key: coinRewardKey,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.digit3.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.digit3.withValues(alpha: 0.55)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.outcomeCoins(coins),
            style: const TextStyle(
              color: AppColors.digit3,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            l10n.outcomeCoinsLabel,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Três estrelas, as conquistadas acesas.
class _StarRow extends StatelessWidget {
  const _StarRow({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) => Row(
    key: starsKey,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (int i = 0; i < kMaxStars; i++)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: _Star(earned: i < stars, index: i),
        ),
    ],
  );
}

/// Uma estrela que entra saltando. As três entram em sequência, o que faz o
/// jogador contar junto em vez de receber a nota pronta.
class _Star extends StatefulWidget {
  const _Star({required this.earned, required this.index});

  final bool earned;
  final int index;

  @override
  State<_Star> createState() => _StarState();
}

class _StarState extends State<_Star> with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    // Criado aqui, e não como `late final`: um campo preguiçoso pode acabar
    // sendo inicializado pelo próprio `dispose()`, construindo um controlador
    // no meio do desmonte da árvore.
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );

    // Estrela apagada não tem o que comemorar: já nasce no lugar. A animação é
    // **finita** e o atraso de cada estrela vem do próprio controlador, não de
    // um `Future.delayed` — temporizador solto não respeita o relógio do teste
    // e reprova qualquer `pumpAndSettle`.
    if (widget.earned) {
      _c.forward();
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Cada estrela ocupa a sua fatia da animação, então elas entram em
    // sequência da esquerda para a direita.
    final slot = CurvedAnimation(
      parent: _c,
      curve: Interval(
        widget.index / kMaxStars,
        (widget.index + 1) / kMaxStars,
        curve: Curves.easeOutBack,
      ),
    );

    return AnimatedBuilder(
      animation: slot,
      builder: (context, child) => Transform.scale(
        scale: widget.earned ? 0.4 + slot.value * 0.6 : 1,
        child: child,
      ),
      child: Icon(
        widget.earned ? Icons.star_rounded : Icons.star_outline_rounded,
        size: widget.earned ? 46 : 38,
        color: widget.earned
            ? AppColors.digit3
            : Colors.white.withValues(alpha: 0.22),
      ),
    );
  }
}

/// Confetes caindo atrás do cartão de vitória.
///
/// Desenhados num `CustomPainter` em vez de um widget por peça: são dezenas
/// deles, e cada widget custaria layout a cada quadro para algo puramente
/// decorativo.
class _Confetti extends StatefulWidget {
  const _Confetti();

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  /// Sorteados uma vez, na criação. Sorteados no `build`, cada quadro
  /// desenharia confetes diferentes e o efeito viraria chuvisco.
  late final List<_Fleck> _flecks;

  static const List<Color> _palette = [
    AppColors.digit1,
    AppColors.digit2,
    AppColors.digit3,
    AppColors.digit5,
    AppColors.digit6,
    AppColors.digit7,
  ];

  @override
  void initState() {
    super.initState();

    // Semente fixa: um efeito decorativo não justifica tornar o widget
    // não-determinístico, e assim um golden desta tela não treme entre rodadas.
    final random = math.Random(7);
    _flecks = [
      for (int i = 0; i < 42; i++)
        _Fleck(
          x: random.nextDouble(),
          delay: random.nextDouble() * 0.35,
          speed: 0.75 + random.nextDouble() * 0.5,
          drift: random.nextDouble() * 2 - 1,
          spin: random.nextDouble() * 6 - 3,
          size: 5 + random.nextDouble() * 6,
          color: _palette[i % _palette.length],
        ),
    ];

    // Toca uma vez e para. Repetir deixaria `pumpAndSettle` sem fim e
    // derrubaria toda a suíte de widget.
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) => CustomPaint(
      painter: _ConfettiPainter(flecks: _flecks, t: _c.value),
      size: Size.infinite,
    ),
  );
}

/// Um confete: por onde entra, quando, e como cai.
class _Fleck {
  const _Fleck({
    required this.x,
    required this.delay,
    required this.speed,
    required this.drift,
    required this.spin,
    required this.size,
    required this.color,
  });

  /// Posição horizontal de partida, de 0 a 1 da largura.
  final double x;
  final double delay;
  final double speed;

  /// Deriva lateral enquanto cai, de -1 a 1.
  final double drift;
  final double spin;
  final double size;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({required this.flecks, required this.t});

  final List<_Fleck> flecks;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    for (final fleck in flecks) {
      // Cada confete tem a sua linha do tempo dentro da animação: sem isso
      // todos caem em bloco, o que parece uma cortina, não uma festa.
      final progress = ((t - fleck.delay) * fleck.speed).clamp(0.0, 1.0);
      if (progress <= 0) continue;

      // Some no último terço da queda, para não empilhar no rodapé.
      final fade = progress < 0.7 ? 1.0 : 1 - (progress - 0.7) / 0.3;

      final dx = size.width * fleck.x + fleck.drift * 40 * progress;
      final dy = -20 + (size.height + 40) * Curves.easeIn.transform(progress);

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(fleck.spin * progress * math.pi);
      paint.color = fleck.color.withValues(alpha: fade.clamp(0, 1) * 0.9);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: fleck.size,
          height: fleck.size * 0.55,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => oldDelegate.t != t;
}

/// A ação principal do cartão, em pílula 3D.
///
/// Passou a ser [GameButton] para o botão afundar sob o dedo — é o feedback
/// físico que o `ElevatedButton` não dá, e o que separa um botão de jogo de um
/// botão de formulário.
class _FullWidthButton extends StatelessWidget {
  const _FullWidthButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) =>
      GameButton(label: label, icon: icon, color: color, onPressed: onPressed);
}
