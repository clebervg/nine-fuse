import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';
import 'package:nine_fuse/features/game/presentation/l10n_labels.dart';
import 'package:nine_fuse/features/game/presentation/widgets/game_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/obstacle_overlay.dart';
import 'package:nine_fuse/features/game/providers/wallet.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Chave do botão que compra um Martelo direto no início de fase.
const Key levelStartBuyHammerKey = Key('level_start_buy_hammer');

/// Chave do botão que compra uma Bomba direto no início de fase.
const Key levelStartBuyBombKey = Key('level_start_buy_bomb');

/// Chave do botão que compra um Pincel direto no início de fase.
const Key levelStartBuyBrushKey = Key('level_start_buy_brush');

/// Chave do cartão de início de fase.
const Key levelStartKey = Key('level_start');

/// Chave do botão que libera o tabuleiro.
const Key startLevelKey = Key('start_level');

/// Chave do 'X' que fecha o cartão sem jogar, voltando ao mapa.
const Key levelStartCloseKey = Key('level_start_close');

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
class LevelStartDialog extends ConsumerWidget {
  const LevelStartDialog({
    super.key,
    required this.level,
    required this.onPlay,
    this.onClose,
    this.onBuyHammer,
    this.onBuyBomb,
    this.onBuyBrush,
  });

  final GameLevel level;
  final VoidCallback onPlay;

  /// Fecha o cartão sem começar a fase, voltando à tela anterior (o mapa).
  /// Nulo omite o 'X' — hoje só a `GameScreen` sabe voltar ao mapa.
  final VoidCallback? onClose;

  /// Credita o item no notifier da partida em curso (campanha ou Endless).
  ///
  /// É a tela quem passa cada um — `notifier.grantHammer`/`grantBomb`/
  /// `grantBrush` —, o mesmo jeito que `HammerOfferDialog`/`BombOfferDialog`/
  /// `BrushOfferDialog` já recebem `onGranted`. Campanha e Endless são
  /// notifiers irmãos, sem uma classe-mãe comum a que este widget pudesse
  /// amarrar um único provider; nulo (nos testes de tela que montam o cartão
  /// isolado) só mantém o botão sempre desabilitado.
  final VoidCallback? onBuyHammer;
  final VoidCallback? onBuyBomb;
  final VoidCallback? onBuyBrush;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final wallet = ref.watch(walletProvider);
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
      onClose: onClose,
      closeKey: levelStartCloseKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // O saldo não se repete aqui: a pílula global da AppBar continua
          // visível por cima do véu do modal, e um segundo contador do mesmo
          // número só competiria com o objetivo, que é o que o cartão existe
          // para dizer.
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

          const SizedBox(height: 20),
          // A mini-loja: comprar aqui não passa pelo Modo Fantasma dos
          // convites de aquisição (Bomba/Pincel/Martelo) — não há tabuleiro
          // para mirar antes de "JOGAR", então a compra credita direto, sem
          // alvo pendente nenhum.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: _BoosterShopButton(
                  buttonKey: levelStartBuyHammerKey,
                  label: l10n.levelStartShopHammer,
                  icon: Icons.gavel_rounded,
                  canAfford:
                      wallet.canAfford(kHammerCoinPrice) && onBuyHammer != null,
                  buyLabel: l10n.levelStartShopBuy(kHammerCoinPrice),
                  onBuy: () => _buy(ref, kHammerCoinPrice, onBuyHammer),
                ),
              ),
              Expanded(
                child: _BoosterShopButton(
                  buttonKey: levelStartBuyBombKey,
                  label: l10n.levelStartShopBomb,
                  icon: Icons.gps_fixed_rounded,
                  canAfford:
                      wallet.canAfford(kBombCoinPrice) && onBuyBomb != null,
                  buyLabel: l10n.levelStartShopBuy(kBombCoinPrice),
                  onBuy: () => _buy(ref, kBombCoinPrice, onBuyBomb),
                ),
              ),
              Expanded(
                child: _BoosterShopButton(
                  buttonKey: levelStartBuyBrushKey,
                  label: l10n.levelStartShopBrush,
                  icon: Icons.brush_rounded,
                  canAfford:
                      wallet.canAfford(kBrushCoinPrice) && onBuyBrush != null,
                  buyLabel: l10n.levelStartShopBuy(kBrushCoinPrice),
                  onBuy: () => _buy(ref, kBrushCoinPrice, onBuyBrush),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
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

  /// Debita a carteira e só então credita o item — a mesma ordem de
  /// `HammerOfferDialog`: se `spendCoins` recusar (saldo caiu por fora entre
  /// o build e o toque), nada é creditado.
  void _buy(WidgetRef ref, int price, VoidCallback? grant) {
    if (grant == null) return;
    if (ref.read(walletProvider.notifier).spendCoins(price)) grant();
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

/// Um item da mini-loja: ícone, rótulo e um [GameButton] de preço.
///
/// Compacto de propósito — este cartão já tem o alvo, o objetivo e o
/// orçamento de movimentos disputando espaço; a mini-loja é um atalho de
/// conveniência, não o funil principal de aquisição (que continua sendo os
/// convites de Modo Fantasma, com o anúncio recompensado em primeiro lugar).
class _BoosterShopButton extends StatelessWidget {
  const _BoosterShopButton({
    required this.buttonKey,
    required this.label,
    required this.icon,
    required this.canAfford,
    required this.buyLabel,
    required this.onBuy,
  });

  final Key buttonKey;
  final String label;
  final IconData icon;
  final bool canAfford;
  final String buyLabel;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: canAfford ? Colors.white70 : Colors.white24, size: 22),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      const SizedBox(height: 4),
      GameButton(
        key: buttonKey,
        label: buyLabel,
        color: canAfford ? AppColors.digit3 : AppColors.darkSurface,
        foreground: canAfford ? Colors.black : Colors.white38,
        fontSize: 13,
        expand: false,
        onPressed: canAfford ? onBuy : null,
      ),
    ],
  );
}
