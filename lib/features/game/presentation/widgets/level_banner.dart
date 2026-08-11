import 'package:flutter/material.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
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

/// Saldo a partir do qual o contador de movimentos alarma.
const int kUrgentMovesLeft = 3;

/// Duração de uma batida do contador em reta final.
///
/// O pulso é **finito** de propósito: uma animação em repetição faria
/// `pumpAndSettle` nunca terminar e derrubaria a suíte de widget inteira. Cada
/// movimento gasto dispara uma batida, o que dá urgência sem virar relógio.
const Duration kMovesPulseDuration = kMetricPulseDuration;

/// Cabeçalho da fase: objetivo, progresso, nota parcial, pontos e movimentos.
///
/// Cada métrica mora numa [GameMetricCard] própria. Antes eram textos soltos
/// sobre um retângulo preto, o que dava ao jogo cara de barra de aplicativo —
/// a moldura individual é o que faz o olho ler três informações com função em
/// vez de uma linha de legenda.
class LevelBanner extends StatelessWidget {
  const LevelBanner({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final objective = state.level.objective;
    // Numa fase de cobertura não há dígito-alvo; a assinatura de cor do HUD
    // passa a ser a da própria cobertura, a mesma que ela tem no tabuleiro.
    final targetColor = objective.isObstacleGoal
        ? obstacleAccent(objective.obstacle)
        : AppColors.getColorByDigit(objective.digit!);

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

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        // Degradê em vez de cor chapada, e um aro claro no topo: o cabeçalho
        // passa a ter volume, como as peças do tabuleiro.
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF262631), Color(0xFF17171D)],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: GameMetricCard(
                    key: hudObjectiveKey,
                    label: l10n.hudObjective,
                    // O ícone da pílula diz de que meta se trata antes de o
                    // jogador ler o número: floco de gelo e alvo não se
                    // confundem.
                    icon: objective.isObstacleGoal
                        ? obstacleIcon(objective.obstacle)
                        : Icons.adjust,
                    accent: targetColor,
                    compact: true,
                    valueWidget: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (objective.isObstacleGoal)
                          ObstacleBadge(type: objective.obstacle)
                        else
                          _TargetChip(digit: objective.digit!),
                        const SizedBox(width: 6),
                        Text(
                          l10n.objectiveProgress(
                            state.objectiveProgress,
                            // O alvo do estado, e não o da fase: em "limpe
                            // todas" quem manda é o tabuleiro sorteado.
                            state.objectiveTarget,
                          ),
                          style: const TextStyle(
                            fontFamily: AppFonts.display,
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GameMetricCard(
                    key: hudScoreKey,
                    label: l10n.hudScore,
                    icon: Icons.auto_awesome,
                    accent: AppColors.digit7,
                    compact: true,
                    // O placar morava sozinho no rodapé, abaixo do tabuleiro,
                    // fora do campo de visão de quem está jogando.
                    value: l10n.hudScoreValue(state.score),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GameMetricCard(
                    label: l10n.hudMoves,
                    icon: Icons.bolt,
                    accent: AppColors.digit3,
                    compact: true,
                    urgent: urgent,
                    // A batida vem do próprio saldo: cada movimento gasto monta
                    // um builder novo, que anima uma vez e para.
                    pulseSeed: urgent ? state.movesLeft : null,
                    valueWidget: Text(
                      '${state.movesLeft}',
                      // Chave própria: o tabuleiro também tem textos de dígito,
                      // então procurar pelo número acharia peças em vez do
                      // contador.
                      key: movesLeftKey,
                      style: TextStyle(
                        fontFamily: AppFonts.display,
                        color: urgent ? AppColors.digit0 : Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.objectiveLabel(objective, target: state.objectiveTarget),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _ObjectiveBar(fraction: state.objectiveFraction, color: targetColor),
          const SizedBox(height: 10),
          // A nota parcial no lugar do texto fixo: é o dado que muda a cada
          // jogada, e mostra o custo de enrolar antes de o jogador chegar ao
          // cartão de fim de fase e descobrir que perdeu uma estrela.
          _StarBar(
            stars: starRating(
              movesLeft: state.movesLeft,
              movesAvailable: state.movesAvailable,
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
                    padding: const EdgeInsets.only(top: 10),
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
  }
}

/// A peça-alvo em miniatura, dentro da pílula do objetivo.
///
/// Usa o mesmo degradê das peças do tabuleiro para o jogador reconhecer o alvo
/// quando ele aparecer na grade — uma amostra de cor chapada não faria essa
/// ligação.
class _TargetChip extends StatelessWidget {
  const _TargetChip({required this.digit});

  final int digit;

  @override
  Widget build(BuildContext context) => Container(
    width: 24,
    height: 24,
    decoration: BoxDecoration(
      gradient: AppColors.tileGradient(digit),
      borderRadius: BorderRadius.circular(6),
      boxShadow: [
        BoxShadow(
          color: AppColors.getColorByDigit(digit).withValues(alpha: 0.5),
          blurRadius: 8,
        ),
      ],
    ),
    child: Center(
      child: Text(
        '$digit',
        style: TextStyle(
          fontFamily: AppFonts.display,
          color: AppColors.getTextColorForDigit(digit),
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );
}

/// Barra do objetivo, com trilho fundo e brilho na parte preenchida.
class _ObjectiveBar extends StatelessWidget {
  const _ObjectiveBar({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    height: 9,
    decoration: BoxDecoration(
      color: const Color(0xFF0D0D11),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(999),
      // `heightFactor: 1` não é enfeite: sem ele o `DecoratedBox` fica sem
      // filho **e** sem altura imposta, colapsa para zero e a barra some
      // inteira. Mesma armadilha dos anéis de impacto dentro de um `Stack`.
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        heightFactor: 1,
        // `LinearProgressIndicator` não aceita trilho com borda nem
        // brilho na parte cheia; a barra é desenhada à mão pelos mesmos
        // motivos que as peças ganharam degradê.
        widthFactor: fraction.clamp(0.0, 1.0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.lighten(color, 0.18), color],
            ),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Nota que a fase valeria se fosse vencida agora.
///
/// Usa a mesma [starRating] do cartão de fim de fase — duplicar a fórmula faria
/// o HUD prometer três estrelas e a vitória entregar duas.
class _StarBar extends StatelessWidget {
  const _StarBar({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) => Row(
    key: starBarKey,
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (int i = 1; i <= 3; i++)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Icon(
            i <= stars ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 20,
            color: i <= stars ? AppColors.digit3 : Colors.white24,
            shadows: i <= stars
                ? [
                    BoxShadow(
                      color: AppColors.digit3.withValues(alpha: 0.7),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
        ),
    ],
  );
}
