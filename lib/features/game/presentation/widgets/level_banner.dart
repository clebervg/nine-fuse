import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nine_fuse/core/assets/tile_sprite_manager.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/core/theme/nf_tokens.dart';
import 'package:nine_fuse/core/widgets/nf_text.dart';
import 'package:nine_fuse/features/game/domain/star_rating.dart';
import 'package:nine_fuse/features/game/presentation/widgets/obstacle_overlay.dart';
import 'package:nine_fuse/features/game/presentation/widgets/game_metric_card.dart';
import 'package:nine_fuse/features/game/presentation/l10n_labels.dart';
import 'package:nine_fuse/features/game/providers/game_state.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Chave do contador de movimentos restantes.
const Key movesLeftKey = Key('moves_left');

/// Chave da barra de estrelas.
const Key starBarKey = Key('star_bar');

/// Chave do placar compacto do HUD.
const Key hudScoreKey = Key('hud_score');

/// Chave da pílula do objetivo.
const Key hudObjectiveKey = Key('hud_objective');

/// Saldo a partir do qual o medalhão de jogadas alarma.
///
/// Cinco, e não três: com o medalhão no centro do HUD o alerta é lido de canto
/// de olho, e o jogador precisa dele **antes** do convite de reforço (que sobe
/// com dois) para ainda ter jogadas em que mudar de plano.
const int kUrgentMovesLeft = 5;

/// Duração de uma batida do medalhão em reta final.
///
/// O pulso é **finito** de propósito: uma animação em repetição faria
/// `pumpAndSettle` nunca terminar e derrubaria a suíte de widget inteira. Cada
/// movimento gasto dispara uma batida, o que dá urgência sem virar relógio.
const Duration kMovesPulseDuration = kMetricPulseDuration;

/// Diâmetro do medalhão de jogadas.
const double kMovesMedallionSize = 104;

/// Quanto o medalhão sobe acima da placa do HUD.
///
/// O medalhão é maior que a placa de propósito: é o único número que **decide**
/// a fase, e saltar para fora da moldura é o que o tira do empate visual com
/// objetivo e pontos sem precisar de um rótulo dizendo "olhe aqui".
const double kMovesMedallionRise = 30;

/// Altura da faixa de colunas da placa (objetivo, medalhão, pontos).
const double _kRowHeight = 92;

/// Onde a faixa "JOGADAS" começa, medido do topo da placa. Ela termina junto
/// com a faixa de colunas, encaixada sobre a base do medalhão.
const double _kRibbonTop = _kRowHeight - 24;

/// Largura da coluna central, a do medalhão.
const double _kCenterColumn = 112;

/// Cabeçalho da fase: objetivo, medalhão de jogadas e pontos numa placa só.
///
/// **Uma placa, três colunas, sem molduras internas.** Antes cada métrica tinha
/// a sua caixa, e três caixas tingidas empilhadas sobre uma quarta disputavam a
/// atenção com o tabuleiro. Agora a cor fica no que importa: o alvo (a peça ou a
/// cobertura que a fase pede), a gema roxa das jogadas e as estrelas — o resto é
/// rótulo lilás sobre azul-noite.
class LevelBanner extends StatelessWidget {
  const LevelBanner({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final objective = state.level.objective;

    // A dica escrita da fase ocupa espaço permanente no HUD para dizer algo que
    // só vale antes da primeira jogada — e o cartão de início já a mostra em
    // toda fase que tem uma. Aqui ela sobrevive apenas na fase 1, onde o
    // jogador ainda não sabe nem qual é o gesto, e some no primeiro movimento.
    final hint = state.level.number == 1
        ? l10n.levelTip(state.level.teaches)
        : null;
    final showHint = hint != null && state.moves == 0;

    // Depois de a fase acabar não há mais urgência: manter o contador vermelho
    // na tela de vitória é alarme falso.
    final urgent = !state.isOver && state.movesLeft <= kUrgentMovesLeft;

    final plate = Container(
      decoration: NfDecorations.panel(borderWidth: 2),
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: _kRowHeight,
            child: Row(
              children: [
                Expanded(
                  child: _ObjectiveColumn(key: hudObjectiveKey, state: state),
                ),
                // A coluna do meio fica vazia: o medalhão é desenhado por cima,
                // no `Stack` de fora, porque transborda a placa.
                const SizedBox(width: _kCenterColumn),
                Expanded(
                  child: _ScoreColumn(key: hudScoreKey, state: state),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // A frase do objetivo fica **colada** à faixa de cima: o vão que
          // havia entre ela e a barra lia como um tracinho solto, e era só a
          // barra vazia (ver [_ObjectiveColumn]).
          Text(
            l10n.objectiveLabel(objective, target: state.objectiveTarget),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppFonts.number,
              color: NfColors.textSoft,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          // `AnimatedSize` em volta do vazio: a dica não pode sumir de um
          // quadro para o outro, senão o tabuleiro salta para cima junto.
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: showHint
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                    child: Text(
                      hint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );

    // O booster **não** mora aqui. Dentro desta moldura ele lia como uma
    // quarta métrica — mais uma coisa a saber, quando é a única coisa ali a
    // fazer. Ele é a [HammerBar], numa placa própria abaixo do tabuleiro.
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: kMovesMedallionRise),
          child: plate,
        ),
        Positioned(
          top: 0,
          child: _MovesMedallion(
            movesLeft: state.movesLeft,
            urgent: urgent,
            label: l10n.hudMoves,
            // A batida vem do próprio saldo: cada movimento gasto monta um
            // builder novo, que anima uma vez e para.
            pulseSeed: urgent ? state.movesLeft : null,
          ),
        ),
      ],
    );
  }
}

/// Coluna do objetivo: rótulo, alvo e progresso.
class _ObjectiveColumn extends StatelessWidget {
  const _ObjectiveColumn({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final objective = state.level.objective;
    // Numa fase de cobertura não há dígito-alvo; a assinatura de cor passa a
    // ser a da própria cobertura, a mesma que ela tem no tabuleiro.
    final targetColor = objective.isObstacleGoal
        ? obstacleAccent(objective.obstacle)
        : AppColors.getColorByDigit(objective.digit!);
    final fraction = state.objectiveFraction.clamp(0.0, 1.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        NfText.label(l10n.hudObjective, color: NfColors.textMuted),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              objective.isObstacleGoal
                  ? ObstacleBadge(type: objective.obstacle, size: 34)
                  : _TargetTile(digit: objective.digit!),
              const SizedBox(width: 6),
              Text(
                l10n.objectiveProgress(
                  state.objectiveProgress,
                  // O alvo do estado, e não o da fase: em "limpe todas" quem
                  // manda é o tabuleiro sorteado.
                  state.objectiveTarget,
                ),
                style: const TextStyle(
                  fontFamily: AppFonts.title,
                  color: Colors.white,
                  fontSize: 24,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        // **A barra só existe com progresso.** Vazia, ela era um trilho escuro
        // de 9pt sob o texto que lia como um tracinho solto — resto de layout,
        // não informação. Com o primeiro alvo cumprido ela nasce já com algo
        // aceso, e aí diz quanto falta.
        if (fraction > 0) ...[
          const SizedBox(height: 7),
          _ObjectiveBar(fraction: fraction, color: targetColor),
        ],
      ],
    );
  }
}

/// Coluna dos pontos: rótulo, placar e o trilho de estrelas.
///
/// As estrelas moram **aqui dentro**, e não numa linha própria: nota parcial e
/// pontos respondem à mesma pergunta ("como estou indo?"), e separá-las
/// obrigava o olho a juntar duas coisas que o jogo já tratava como uma.
class _ScoreColumn extends StatelessWidget {
  const _ScoreColumn({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        NfText.label(l10n.hudScore, color: NfColors.textMuted),
        const SizedBox(height: 5),
        // Encolhe em vez de cortar: um placar com reticências não é placar.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            l10n.hudScoreValue(state.score),
            maxLines: 1,
            style: const TextStyle(
              fontFamily: AppFonts.title,
              color: Colors.white,
              fontSize: 24,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _StarMeter(
          stars: starRating(
            movesLeft: state.movesLeft,
            movesAvailable: state.movesAvailable,
          ),
        ),
      ],
    );
  }
}

/// O medalhão de jogadas: gema roxa em aro de ouro, com a faixa "JOGADAS".
///
/// **O alerta muda a gema, não só o número.** Em reta final o aro e a faixa
/// viram vermelho e o miolo escurece, para o número vermelho ter contraste —
/// vermelho sobre a gema roxa ficaria ilegível justamente quando importa.
///
/// **A batida é de brilho, não de escala.** O número usa sombra sólida
/// empilhada, e sombra de texto dentro de `Transform` animado borra no Impeller
/// (ver `NfText`). O halo do aro pulsa uma vez por jogada gasta e para.
class _MovesMedallion extends StatelessWidget {
  const _MovesMedallion({
    required this.movesLeft,
    required this.urgent,
    required this.label,
    this.pulseSeed,
  });

  final int movesLeft;
  final bool urgent;
  final String label;
  final Object? pulseSeed;

  @override
  Widget build(BuildContext context) {
    final number = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '$movesLeft',
          // Chave própria: o tabuleiro também tem textos de dígito, então
          // procurar pelo número acharia peças em vez do contador.
          key: movesLeftKey,
          maxLines: 1,
          style: TextStyle(
            fontFamily: AppFonts.title,
            fontSize: 44,
            height: 1.05,
            color: urgent ? NfColors.alert : Colors.white,
            shadows: urgent
                ? const [Shadow(offset: Offset(0, 3), color: Color(0xFF3A0610))]
                : const [
                    Shadow(
                      offset: Offset(0, 3),
                      color: NfColors.gemTitleShadow,
                    ),
                    Shadow(offset: Offset(0, 6), color: NfColors.gemDeep),
                  ],
          ),
        ),
      ),
    );

    Widget medallion(double pulse) => Container(
      width: kMovesMedallionSize,
      height: kMovesMedallionSize,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: urgent ? _alertRim : NfDecorations.goldRim,
        boxShadow: [
          // Blur zero: a base 3D da moeda, não uma sombra.
          const BoxShadow(color: NfColors.bronze, offset: Offset(0, 7)),
          BoxShadow(
            color: (urgent ? NfColors.alert : const Color(0xFFC77BFF))
                .withValues(alpha: urgent ? 0.55 + 0.35 * pulse : 0.45),
            blurRadius: 30 + 14 * pulse,
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: urgent ? _alertCore : NfDecorations.gemFill,
        ),
        child: Center(child: number),
      ),
    );

    final ribbon = Container(
      width: _kCenterColumn - 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: urgent ? NfColors.alert : NfColors.gold,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: urgent ? const Color(0xFF7A0F1C) : NfColors.goldShadow,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          style: NfText.styleFor(NfTextVariant.label).copyWith(
            letterSpacing: 1.3,
            color: urgent ? Colors.white : NfColors.goldText,
          ),
        ),
      ),
    );

    return SizedBox(
      width: _kCenterColumn,
      // A faixa fica sob a base do medalhão, como na placa de um troféu.
      height: kMovesMedallionRise + _kRibbonTop + 24 + 3,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          if (pulseSeed == null)
            medallion(0)
          else
            // A chave é a semente: cada mudança monta um builder novo, que anima
            // uma vez e para. É o que dá batida por jogada sem repetição.
            TweenAnimationBuilder<double>(
              key: ValueKey(pulseSeed),
              tween: Tween(begin: 0, end: 1),
              duration: kMovesPulseDuration,
              curve: Curves.easeOut,
              // Meio ciclo de seno: sai de 0, acende e volta a 0 no fim.
              builder: (context, t, _) => medallion(math.sin(math.pi * t)),
            ),
          Positioned(top: kMovesMedallionRise + _kRibbonTop, child: ribbon),
        ],
      ),
    );
  }
}

/// Aro do medalhão em alerta: o mesmo desenho do ouro, em vermelho.
const Gradient _alertRim = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFFFFB3BB),
    NfColors.alert,
    Color(0xFF8A1020),
    Color(0xFFFF7A88),
  ],
  stops: [0, 0.3, 0.6, 1],
);

/// Miolo do medalhão em alerta: escuro, para o número vermelho ter contraste.
const Gradient _alertCore = RadialGradient(
  center: Alignment(-0.3, -0.4),
  radius: 0.9,
  colors: [Color(0xFF3A1640), Color(0xFF1E0A2E), Color(0xFF0C0418)],
  stops: [0, 0.5, 1],
);

/// O alvo da fase como peça: o sprite do tabuleiro quando já carregado, ou a
/// miniatura em degradê.
///
/// É a mesma arte que o jogador vai procurar na grade — uma amostra de cor
/// chapada não faria essa ligação.
class _TargetTile extends StatelessWidget {
  const _TargetTile({required this.digit});

  final int digit;

  @override
  Widget build(BuildContext context) {
    final sprite = TileSpriteManager.spriteFor(digit);
    if (sprite == null) return _TargetChip(digit: digit);
    return Image(
      image: sprite,
      width: 38,
      height: 38,
      fit: BoxFit.contain,
      gaplessPlayback: true,
    );
  }
}

/// A peça-alvo em miniatura, para quando o sprite ainda não carregou.
class _TargetChip extends StatelessWidget {
  const _TargetChip({required this.digit});

  final int digit;

  @override
  Widget build(BuildContext context) => Container(
    width: 30,
    height: 30,
    decoration: BoxDecoration(
      gradient: AppColors.tileGradient(digit),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Center(
      child: Text(
        '$digit',
        style: TextStyle(
          fontFamily: AppFonts.number,
          color: AppColors.getTextColorForDigit(digit),
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

/// Barra do objetivo: trilho fundo e a parte cumprida na cor do alvo.
class _ObjectiveBar extends StatelessWidget {
  const _ObjectiveBar({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 96,
    height: 8,
    decoration: BoxDecoration(
      color: NfColors.night1,
      borderRadius: BorderRadius.circular(4),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(4),
      // `heightFactor: 1` não é enfeite: sem ele o `DecoratedBox` fica sem
      // filho **e** sem altura imposta, colapsa para zero e a barra some
      // inteira. Mesma armadilha dos anéis de impacto dentro de um `Stack`.
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        heightFactor: 1,
        widthFactor: fraction,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.lighten(color, 0.18), color],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Nota que a fase valeria se fosse vencida agora, sobre um trilho.
///
/// Usa a mesma [starRating] do cartão de fim de fase — duplicar a fórmula faria
/// o HUD prometer três estrelas e a vitória entregar duas.
///
/// **O preenchimento é proporcional, e existe porque três ícones sozinhos são
/// um estado, não um progresso.** Apagar a terceira estrela diz que ela se
/// perdeu; o trilho por baixo diz *quanto* do caminho ainda está de pé, que é
/// a informação que muda o que o jogador faz no movimento seguinte. Cada
/// estrela fica no ponto do trilho em que ela é ganha.
class _StarMeter extends StatelessWidget {
  const _StarMeter({required this.stars});

  final int stars;

  static const double _width = 96;
  static const double _star = 17;

  @override
  Widget build(BuildContext context) {
    final fraction = (stars / 3).clamp(0.0, 1.0);

    return SizedBox(
      key: starBarKey,
      width: _width,
      height: _star,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          Container(
            height: 10,
            decoration: BoxDecoration(
              color: NfColors.night1,
              borderRadius: BorderRadius.circular(5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              // `heightFactor: 1` não é enfeite: sem ele o `DecoratedBox` fica
              // sem filho **e** sem altura imposta e colapsa para zero.
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                heightFactor: 1,
                widthFactor: fraction,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFFE680), Color(0xFFF5A600)],
                    ),
                  ),
                ),
              ),
            ),
          ),
          for (int i = 1; i <= 3; i++)
            Positioned(
              left: _width * i / 3 - _star + (i == 3 ? 2 : _star / 2 - 2),
              child: i <= stars
                  ? const Icon(
                      Icons.star_rounded,
                      size: _star,
                      // Branca com base âmbar, e não dourada: sobre o trilho
                      // dourado uma estrela dourada some. A sombra é sólida
                      // (sem blur) e o trilho não anima, então não há o borrão
                      // de sombra em `Transform` do Impeller.
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: NfColors.goldText,
                          offset: Offset(0, 1.5),
                        ),
                      ],
                    )
                  // Apagada é uma estrela escura desenhada, e não um ícone:
                  // ela continua ocupando o lugar onde a nota é ganha.
                  : const CustomPaint(
                      size: Size.square(_star),
                      painter: _DimStarPainter(),
                    ),
            ),
        ],
      ),
    );
  }
}

/// Estrela apagada: miolo azul-escuro com contorno mais escuro ainda.
class _DimStarPainter extends CustomPainter {
  const _DimStarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.width / 2;
    final inner = outer * 0.48;
    final path = Path();
    for (int i = 0; i < 10; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = c + Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas
      ..drawPath(path, Paint()..color = const Color(0xFF2A3266))
      ..drawPath(
        path,
        Paint()
          ..color = const Color(0xFF141A40)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeJoin = StrokeJoin.round,
      );
  }

  @override
  bool shouldRepaint(_DimStarPainter oldDelegate) => false;
}
