import 'package:flutter/material.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';
import 'package:nine_fuse/features/game/presentation/l10n_labels.dart';
import 'package:nine_fuse/features/game/presentation/widgets/game_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/obstacle_overlay.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Chave do cartão de início de fase.
const Key levelStartKey = Key('level_start');

/// Chave do botão que libera o tabuleiro.
const Key startLevelKey = Key('start_level');

/// Cartão que abre a fase: o que fazer, com quantos movimentos, e um botão.
///
/// Existe porque o jogador entrava direto num tabuleiro cheio, com o objetivo
/// escrito num canto que ninguém lê antes da primeira jogada — e descobria o
/// que a fase pedia depois de já ter gastado movimentos. Aqui a informação
/// chega **antes** de o toque valer, sem competir com o tabuleiro.
///
/// Não usa `AlertDialog` nem `showDialog`: uma rota separada por cima da tela
/// tira o tabuleiro da árvore de foco e complica o teste de widget, além de
/// obrigar a coordenar duas navegações no `Navigator` a cada reinício de fase.
/// Aqui é só uma camada do `Stack` da tela, ligada e desligada por estado.
class LevelStartDialog extends StatelessWidget {
  const LevelStartDialog({
    super.key,
    required this.level,
    required this.onPlay,
  });

  final GameLevel level;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final objective = level.objective;
    // Numa fase de cobertura não há dígito-alvo, e pintar o cartão com a cor de
    // um dígito qualquer prometeria uma peça que a fase não pede.
    final accent = objective.isObstacleGoal
        ? obstacleAccent(objective.obstacle)
        : AppColors.getColorByDigit(objective.digit!);

    // Numa fase "limpe todas" o tabuleiro ainda não existe quando este cartão
    // abre, então o número vem do pedido da fase — e o motor só poda para
    // menos, nunca para mais.
    final target = objective.type == ObjectiveType.clearAllObstacles
        ? level.obstacles.countOf(objective.obstacle)
        : objective.count;

    return GameDialog(
      cardKey: levelStartKey,
      title: l10n.levelTitle(level.number),
      titleFontSize: 24,
      accent: accent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // O alvo em tamanho grande. É a tradução visual do objetivo: "crie
          // **esta** peça" — ou "quebre **isto**" — diz mais rápido do que
          // qualquer frase.
          if (objective.isObstacleGoal)
            _TargetObstacle(
              type: objective.obstacle,
              count: target,
              color: accent,
            )
          else
            _TargetTile(digit: objective.digit!, color: accent),
          const SizedBox(height: 16),

          Text(
            l10n.objectiveLabel(objective, target: target),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),

          _MoveBudget(label: l10n.moveBudget(level.moveLimit)),

          if (l10n.levelTip(level.teaches) case final hint?) ...[
            const SizedBox(height: 18),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],

          const SizedBox(height: 24),
          GameButton(
            key: startLevelKey,
            label: l10n.playButton,
            color: accent,
            foreground: objective.isObstacleGoal
                ? AppColors.darkBackground
                : AppColors.getTextColorForDigit(objective.digit!),
            fontSize: 18,
            onPressed: onPlay,
          ),
        ],
      ),
    );
  }
}

/// A peça do objetivo, desenhada grande e com o mesmo volume das do tabuleiro.
class _TargetTile extends StatelessWidget {
  const _TargetTile({required this.digit, required this.color});

  final int digit;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 84,
    height: 84,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      // O mesmo degradê vertical das peças do tabuleiro, para o jogador
      // reconhecer o alvo quando ele aparecer na grade.
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(color, Colors.white, 0.25)!,
          color,
          Color.lerp(color, Colors.black, 0.25)!,
        ],
        stops: const [0, 0.55, 1],
      ),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.45),
          blurRadius: 22,
          spreadRadius: 2,
        ),
      ],
    ),
    child: Center(
      child: Text(
        '$digit',
        style: TextStyle(
          fontFamily: AppFonts.display,
          color: AppColors.getTextColorForDigit(digit),
          fontSize: 44,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );
}

/// Chave do alvo de cobertura do cartão de início.
const Key levelStartObstacleKey = Key('level_start_obstacle');

/// A cobertura-alvo, do tamanho da peça-alvo, com a contagem por cima.
///
/// Usa a textura de verdade ([ObstacleBadge]), e não um ícone: o jogador precisa
/// reconhecer no tabuleiro exatamente a coisa que o cartão lhe mostrou.
class _TargetObstacle extends StatelessWidget {
  const _TargetObstacle({
    required this.type,
    required this.count,
    required this.color,
  });

  final ObstacleType type;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    key: levelStartObstacleKey,
    mainAxisSize: MainAxisSize.min,
    children: [
      ObstacleBadge(type: type, size: 84),
      const SizedBox(height: 10),
      // O número separado da textura, e não por cima: a cobertura já é clara e
      // facetada, e um dígito sobreposto some contra o vidro.
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(obstacleIcon(type), color: color, size: 20),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: TextStyle(
              fontFamily: AppFonts.display,
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    ],
  );
}

/// "22 Movimentos", com a mesma unidade que o contador do jogo usa.
///
/// Recebe o texto pronto: o plural mora no ARB ("1 Movimento" / "N
/// Movimentos"), e resolvê-lo aqui fixaria a regra de plural do português.
class _MoveBudget extends StatelessWidget {
  const _MoveBudget({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.darkBackground,
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: AppColors.darkBorder),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.swap_horiz, color: Colors.white54, size: 20),
        const SizedBox(width: 8),
        // `Flexible` porque o rótulo cresce com o limite da fase: numa fase
        // de três dígitos, numa tela de 375pt, o texto passava da borda do
        // cartão. Aqui ele encolhe em vez de estourar.
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}
