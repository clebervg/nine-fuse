import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nine_fuse/core/assets/tile_sprite_manager.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/core/theme/nf_tokens.dart';
import 'package:nine_fuse/core/widgets/nf_text.dart';
import 'package:nine_fuse/core/widgets/sprite_icon.dart';
import 'package:nine_fuse/features/game/domain/campaign_chapter.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/presentation/widgets/game_dialog.dart';
import 'package:nine_fuse/features/game/domain/star_rating.dart';
import 'package:nine_fuse/features/game/presentation/widgets/chapter_star_progress.dart';
import 'package:nine_fuse/features/game/presentation/widgets/objective_disc.dart';
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
    this.availableHeight,
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

  /// Altura útil da camada onde o desfecho é montado, sem rolagem.
  ///
  /// A vitória encolhe medalhão, título e estrelas para o botão de avançar
  /// caber na dobra de um iPhone SE: é a regra que `game_screen_test` trava, e
  /// um botão principal que pede rolagem é um botão escondido. Nula (cartão
  /// montado isolado), vale a altura da tela.
  final double? availableHeight;

  /// O que a vitória ocupa fora do medalhão, do título e das estrelas:
  /// rótulos, placa, botões e espaçamentos. Medido no layout, com folga.
  static const double _victoryFixed = 385;

  /// O que escala: medalhão (170), título (52) e estrelas com o pódio (118).
  static const double _victoryScalable = 340;

  /// De 0,5 a 1: o quanto medalhão e estrelas encolhem para tudo caber.
  double _fit(BuildContext context) {
    final height = availableHeight ?? MediaQuery.sizeOf(context).height - 48;
    return ((height - _victoryFixed) / _victoryScalable).clamp(0.5, 1.0);
  }

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

    // Largura de leitura: esticada numa tela larga a vitória vira cartaz e o
    // botão principal foge do polegar. A chave fica aqui, no bloco inteiro,
    // porque a tela deixou de ser uma caixa: o que os testes medem é o desfecho
    // todo caber na largura da tela.
    final content = ConstrainedBox(
      key: const Key('level_outcome'),
      constraints: const BoxConstraints(maxWidth: 360),
      child: _won ? _victory(l10n, _fit(context)) : _defeat(l10n),
    );

    if (!_won) return content;

    // Os confetes ficam **atrás** do conteúdo e não interceptam toque: a festa
    // não pode ficar entre o dedo e o botão de avançar.
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        const Positioned.fill(child: IgnorePointer(child: _Confetti())),
        content,
      ],
    );
  }

  /// "04 Vitória": o 9 no medalhão, a nota em estrelas, a placa dos pontos e
  /// um botão só para seguir.
  ///
  /// Sem caixa em volta, de propósito: a vitória é o único momento em que a
  /// tela inteira é recompensa, e um cartão no meio dela a reduziria a aviso.
  Widget _victory(AppLocalizations l10n, double fit) {
    final gained = starsGained ?? 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _VictoryMedal(size: 170 * fit),
        const SizedBox(height: 4),
        NfText.label(
          l10n.levelTitle(state.level.number).toUpperCase(),
          size: 15,
          color: const Color(0xFFE9E3FF),
        ),
        const SizedBox(height: 8),
        // O título é estático, e por isso pode ter a sombra empilhada: quem
        // entra com escala é o medalhão (imagem) e as estrelas (glifo sem
        // sombra) — ver o aviso do Impeller em `NfText`.
        FittedBox(
          fit: BoxFit.scaleDown,
          // O título encolhe menos que o medalhão: é ele que se lê.
          child: NfText.titleGold(
            l10n.outcomeWonHeadline,
            size: 52 * math.max(fit, 0.75),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _message(l10n),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppFonts.display,
            color: NfColors.textSoft,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _StarRow(stars: _stars, scale: fit),
        const SizedBox(height: 12),
        _ScorePlate(
          score: state.score,
          // O prêmio em moeda mora na placa, ao lado dos pontos que a nota
          // rendeu: é a única coisa da tela que liga a partida ao inventário.
          // Só aparece com estrela nova (ver [_CoinReward]).
          coins: gained > 0 ? gained * kCoinsPerStar : null,
          // Do imediato (o que esta partida rendeu) para o acumulado (o que o
          // capítulo já tem), sem empurrar o botão para fora da dobra.
          chapterProgress: starsInChapter != null && starsGained != null
              ? ChapterStarProgress(
                  chapter: chapterOf(state.level.number),
                  starsInChapter: starsInChapter!,
                  starsGained: starsGained!,
                )
              : null,
        ),
        const SizedBox(height: 22),
        GameButton(
          key: const Key('next_level'),
          label: l10n.nextLevelButton,
          color: AppColors.uiGold,
          fontSize: 24,
          onPressed: onNext,
        ),
        const SizedBox(height: 6),
        GameTextButton(
          key: const Key('back_to_levels'),
          label: l10n.backToLevels,
          onPressed: onBack,
        ),
      ],
    );
  }

  /// O desfecho de uma derrota: o que aconteceu, do que o jogador ficou perto
  /// e a saída óbvia, tentar de novo.
  ///
  /// É o que sobra depois de recusar o resgate (ou o único cartão, quando o
  /// tabuleiro travou e não há resgate a oferecer). Sem raios nem placa: a
  /// derrota não pode competir com a vitória em brilho.
  Widget _defeat(AppLocalizations l10n) {
    final detail = _detail(l10n);
    final missing = state.objectiveTarget - state.objectiveProgress;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        NfText.title(_title(l10n), size: 38, maxLines: 2),
        const SizedBox(height: 10),
        Text(
          _message(l10n),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppFonts.display,
            color: NfColors.textSoft,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (detail != null) ...[
          const SizedBox(height: 6),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppFonts.display,
              color: Colors.white54,
              fontSize: 13,
            ),
          ),
        ],
        if (missing > 0) ...[
          const SizedBox(height: 22),
          ObjectiveDisc(
            objective: state.level.objective,
            progress: state.objectiveProgress,
            target: state.objectiveTarget,
          ),
        ],
        const SizedBox(height: 28),
        GameButton(
          key: const Key('retry_level'),
          label: l10n.tryAgainButton,
          icon: Icons.refresh_rounded,
          color: AppColors.uiGold,
          fontSize: 22,
          onPressed: onRetry,
        ),
        const SizedBox(height: 6),
        GameTextButton(
          key: const Key('back_to_levels'),
          label: l10n.backToLevels,
          onPressed: onBack,
        ),
      ],
    );
  }
}

/// A placa dos pontos: número grande, o prêmio em moedas e o capítulo.
class _ScorePlate extends StatelessWidget {
  const _ScorePlate({
    required this.score,
    required this.coins,
    required this.chapterProgress,
  });

  final int score;
  final int? coins;
  final Widget? chapterProgress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [NfColors.night3, Color(0xFF0D1440)],
        ),
        border: Border.all(color: NfColors.goldDeep, width: 2),
        // Blur zero: a espessura da placa, como no resto do observatório.
        boxShadow: const [
          BoxShadow(color: Color(0xFF05081C), offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pontos e moedas lado a lado, e não empilhados como no design: as
          // duas respostas de "o que esta partida rendeu" cabem numa linha, e a
          // altura poupada é o que deixa o botão de avançar na dobra.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NfText.label(l10n.hudScore),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: NfText.title('$score', size: 44),
                    ),
                  ],
                ),
              ),
              if (coins case final coins?) ...[
                const SizedBox(width: 18),
                _CoinReward(coins: coins),
              ],
            ],
          ),
          if (chapterProgress case final progress?) ...[
            const SizedBox(height: 14),
            progress,
          ],
        ],
      ),
    );
  }
}

/// Ficha do que a partida rendeu em moedas.
///
/// Só aparece quando houve **estrela nova**: rejogar uma fase já dominada rende
/// zero (é a regra anti-farm que `CampaignRecords.record()` já garantia), e uma
/// ficha escrita "+0" anunciaria que o jogo esqueceu de pagar.
class _CoinReward extends StatelessWidget {
  const _CoinReward({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // O rótulo semântico diz a frase inteira ("+30 moedas ganhas"): sem ele o
    // leitor de tela anunciaria só "+30", e a moeda é desenho.
    return Semantics(
      label: '${l10n.outcomeCoins(coins)} ${l10n.outcomeCoinsLabel}',
      excludeSemantics: true,
      child: Container(
        key: coinRewardKey,
        width: 84,
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
        decoration: BoxDecoration(
          color: NfColors.night1.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(NfRadii.md),
          border: Border.all(
            color: const Color(0xFFC98A18).withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SpriteIcon(
              asset: 'assets/images/ic_coin.png',
              fallback: Icons.monetization_on_rounded,
              size: 34,
              color: NfColors.gold,
            ),
            const SizedBox(height: 2),
            Text(
              '+$coins',
              style: const TextStyle(
                fontFamily: AppFonts.title,
                color: NfColors.gold,
                fontSize: 22,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// O tile 9 num halo dourado, com os raios girando atrás.
///
/// É o clímax do jogo como selo da vitória: a mesma peça que o jogador persegue
/// no tabuleiro. Entra com `elasticOut` — o único elástico do desfecho, porque
/// é o único momento que pede comemoração —, e tudo para em 1,8s: raio girando
/// sem fim seria uma animação em loop, e `pumpAndSettle` nunca terminaria.
class _VictoryMedal extends StatefulWidget {
  const _VictoryMedal({required this.size});

  final double size;

  @override
  State<_VictoryMedal> createState() => _VictoryMedalState();
}

class _VictoryMedalState extends State<_VictoryMedal>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _scale;

  /// Diâmetro dos raios: passa das bordas da tela de propósito, para o leque
  /// ler como luz vinda do medalhão e não como um disco atrás dele.
  static const double _raysSize = 760;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();
    _scale = CurvedAnimation(
      parent: _c,
      curve: const Interval(0, 0.6, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.size,
    child: Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Os raios não interceptam toque e passam por baixo de tudo que vem
        // depois na coluna (título, estrelas, placa).
        IgnorePointer(
          child: OverflowBox(
            maxWidth: _raysSize,
            maxHeight: _raysSize,
            child: CustomPaint(
              size: const Size.square(_raysSize),
              painter: _RaysPainter(_c),
            ),
          ),
        ),
        ScaleTransition(
          scale: _scale,
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x99FFD66E),
                  blurRadius: 40,
                  spreadRadius: -18,
                ),
              ],
            ),
            child: Image.asset(
              TileSpriteManager.assetKeyFor(kMaxDigit),
              width: widget.size,
              height: widget.size,
              errorBuilder: (context, error, stack) => Icon(
                Icons.emoji_events_rounded,
                color: NfColors.gold,
                size: widget.size * 0.7,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// O leque de raios dourados: fatias de 8° a cada 20°, apagando para fora.
///
/// Gira um quarto de volta desacelerando e para — é o "girando devagar" do
/// design reduzido a uma entrada, pela regra das animações finitas.
class _RaysPainter extends CustomPainter {
  _RaysPainter(this.t) : super(repaint: t);

  final Animation<double> t;

  static const double _step = 20 * math.pi / 180;
  static const double _wedge = 8 * math.pi / 180;

  /// Um ouro mais quente que o do texto: a 20% sobre o azul-noite, o ouro
  /// claro vira cinza; o âmbar continua lendo como luz dourada.
  static const Color _ray = Color(0xFFFFB82E);

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.value;
    final appear = Curves.easeOut.transform((v / 0.3).clamp(0.0, 1.0));
    if (appear <= 0) return;

    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final turn = (1 - Curves.easeOutCubic.transform(v)) * -math.pi / 2;

    final path = Path();
    for (double a = 0; a < 2 * math.pi; a += _step) {
      path
        ..moveTo(center.dx, center.dy)
        ..arcTo(rect, a + turn, _wedge, false)
        ..close();
    }

    // A máscara radial do design (opaco até 30%, some aos 75%) vira o próprio
    // degradê da tinta: um shader só para o leque inteiro.
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          _ray.withValues(alpha: 0.2 * appear),
          _ray.withValues(alpha: 0.2 * appear),
          _ray.withValues(alpha: 0),
        ],
        stops: const [0, 0.3, 0.75],
      ).createShader(rect);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_RaysPainter oldDelegate) => oldDelegate.t != t;
}

/// Três estrelas, a do meio maior e mais alta, as laterais inclinadas.
class _StarRow extends StatelessWidget {
  const _StarRow({required this.stars, this.scale = 1});

  final int stars;
  final double scale;

  static const List<double> _sizes = [76, 98, 76];
  static const List<double> _tilt = [-0.21, 0, 0.21];

  @override
  Widget build(BuildContext context) => Row(
    key: starsKey,
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      for (int i = 0; i < kMaxStars; i++)
        Padding(
          // A do meio sobe: o pódio lê de relance que ela é a principal.
          padding: EdgeInsets.fromLTRB(2, 0, 2, i == 1 ? 20 * scale : 0),
          child: Transform.rotate(
            angle: _tilt[i],
            child: _Star(earned: i < stars, index: i, size: _sizes[i] * scale),
          ),
        ),
    ],
  );
}

/// Uma estrela que entra saltando. As três entram em sequência, depois do
/// medalhão, o que faz o jogador contar junto em vez de receber a nota pronta.
class _Star extends StatefulWidget {
  const _Star({required this.earned, required this.index, required this.size});

  final bool earned;
  final int index;
  final double size;

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
      duration: const Duration(milliseconds: 1100),
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
    // O primeiro quarto é do medalhão; depois cada estrela ocupa a sua fatia,
    // da esquerda para a direita.
    const lead = 0.25;
    const slotLength = (1 - lead) / kMaxStars;
    final slot = CurvedAnimation(
      parent: _c,
      curve: Interval(
        lead + widget.index * slotLength,
        lead + (widget.index + 1) * slotLength,
        curve: Curves.easeOutBack,
      ),
    );

    return AnimatedBuilder(
      animation: slot,
      builder: (context, child) =>
          Transform.scale(scale: widget.earned ? slot.value : 1, child: child),
      child: _StarGlyph(earned: widget.earned, size: widget.size),
    );
  }
}

/// A estrela desenhada: contorno âmbar, aresta de baixo e miolo dourado.
///
/// Contorno e aresta são o mesmo glifo em **traço** (`Paint.stroke`), não
/// `shadows`: a estrela entra com escala, e sombra de texto dentro de
/// `Transform` animado é o bug do Impeller registrado em `NfText`. Ficam em
/// `Text`, e só o miolo é `Icon` — a fileira continua com exatamente um ícone
/// por lugar, que é como os testes leem a nota.
class _StarGlyph extends StatelessWidget {
  const _StarGlyph({required this.earned, required this.size});

  final bool earned;
  final double size;

  static const IconData _star = Icons.star_rounded;

  TextStyle _glyph({Color? color, Paint? foreground}) => TextStyle(
    inherit: false,
    fontFamily: _star.fontFamily,
    package: _star.fontPackage,
    fontSize: size,
    height: 1,
    color: color,
    foreground: foreground,
  );

  Paint _stroke(Color color, double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeJoin = StrokeJoin.round
    ..color = color;

  @override
  Widget build(BuildContext context) {
    final glyph = String.fromCharCode(_star.codePoint);
    final edge = size * 0.06;

    if (!earned) {
      // Apagada: o encaixe vazio, escuro, com um contorno discreto. O jogador
      // precisa ver o que deixou na mesa.
      return SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(glyph, style: _glyph(color: const Color(0xCC0A1038))),
            Icon(
              Icons.star_outline_rounded,
              size: size,
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ],
        ),
      );
    }

    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Aresta inferior: o volume da estrela.
          Transform.translate(
            offset: Offset(0, edge),
            child: Text(
              glyph,
              style: _glyph(
                foreground: _stroke(NfColors.goldShadow, size * 0.09),
              ),
            ),
          ),
          Text(
            glyph,
            style: _glyph(
              foreground: _stroke(NfColors.goldShadow, size * 0.09),
            ),
          ),
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFE57A), Color(0xFFFFC93C), Color(0xFFF5A600)],
              stops: [0, 0.5, 1],
            ).createShader(bounds),
            child: Icon(_star, size: size, color: const Color(0xFFFFC93C)),
          ),
        ],
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
    AppColors.uiGold,
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
