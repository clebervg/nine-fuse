import 'dart:math';

import 'package:flutter/material.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/endless_progression.dart';
import 'package:nine_fuse/features/game/presentation/widgets/game_metric_card.dart';
import 'package:nine_fuse/features/game/presentation/widgets/tile_widget.dart';
import 'package:nine_fuse/features/game/providers/endless_state.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

const Key endlessScoreKey = Key('endless_score');
const Key endlessStepKey = Key('endless_step');

/// Chave do indicador do maior bloco criado.
const Key endlessBiggestKey = Key('endless_biggest');

/// Chave do selo em si — a peça desenhada dentro da pílula.
///
/// Separada de [endlessBiggestKey] porque a pílula do HUD também é um
/// `Container` com decoração própria: procurar o primeiro descendente acharia
/// a moldura, não a peça.
const Key endlessBiggestTileKey = Key('endless_biggest_tile');

/// Chave da barra de evolução da faixa.
const Key endlessBandProgressKey = Key('endless_band_progress');

/// Cabeçalho do Endless: pontos, recorde e o degrau da janela de sorteio.
class EndlessBanner extends StatelessWidget {
  const EndlessBanner({
    super.key,
    required this.state,
    required this.highScore,
    required this.progression,
  });

  final EndlessState state;
  final int highScore;
  final EndlessProgression progression;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        // Mesma moldura com volume do HUD da campanha: os dois modos precisam
        // parecer o mesmo jogo.
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
                // `Expanded` porque estes números crescem sem teto: numa partida
                // longa, seis dígitos em Pontos e Recorde estouram a linha numa
                // tela de 375pt.
                Expanded(
                  child: GameMetricCard(
                    key: endlessScoreKey,
                    label: l10n.endlessPoints,
                    icon: Icons.auto_awesome,
                    accent: AppColors.digit7,
                    compact: true,
                    value: '${state.score}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GameMetricCard(
                    label: l10n.endlessRecord,
                    icon: Icons.emoji_events,
                    accent: AppColors.digit3,
                    compact: true,
                    value:
                        '${highScore > state.score ? highScore : state.score}',
                  ),
                ),
                const SizedBox(width: 8),
                // "Maior" sozinho não dizia maior o quê — pontuação, faixa,
                // combo. E o número solto não se parecia com o que ele descreve:
                // uma peça do tabuleiro.
                Expanded(
                  child: GameMetricCard(
                    key: endlessBiggestKey,
                    label: l10n.endlessBiggestTile,
                    icon: Icons.grid_view_rounded,
                    accent: AppColors.getColorByDigit(
                      state.highestDigit <= 0 ? 1 : state.highestDigit,
                    ),
                    compact: true,
                    valueWidget: _BiggestTile(digit: state.highestDigit),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _StepIndicator(state: state, progression: progression),
        ],
      ),
    );
  }
}

/// O maior bloco criado na partida, desenhado como peça.
class _BiggestTile extends StatelessWidget {
  const _BiggestTile({required this.digit});

  final int digit;

  @override
  Widget build(BuildContext context) {
    // Zero é o valor inicial do estado, e nenhuma fusão devolve zero — a menor
    // peça que uma fusão cria é um 1. Então zero aqui só significa "o jogador
    // ainda não fundiu nada".
    final none = digit <= 0;
    final apex = digit >= kMaxDigit;

    return SizedBox(
      height: 32,
      child: none
          ? Center(
              child: Text(
                AppLocalizations.of(context).endlessNone,
                style: const TextStyle(color: Colors.white38, fontSize: 20),
              ),
            )
          // A chave amarrada ao dígito faz o `Tween` renascer a cada
          // promoção do maior bloco: é o que dispara a animação de entrada
          // sem precisar de estado nem de controlador.
          : TweenAnimationBuilder<double>(
              key: ValueKey(digit),
              tween: Tween(begin: 0, end: 1),
              // Meio ciclo de seno e para. Animação em repetição faria
              // `pumpAndSettle` nunca terminar e derrubaria a suíte de
              // widget — mesma regra do brilho da dica.
              duration: Duration(milliseconds: apex ? 900 : 420),
              builder: (context, t, child) {
                final wave = sin(t * pi);
                // O ápice merece mais: pulso maior e um giro leve, que dá
                // a sensação de a peça ter sido conquistada e não só
                // atualizada num contador.
                return Transform.rotate(
                  angle: apex ? wave * 0.14 : 0,
                  child: Transform.scale(
                    scale: 1 + wave * (apex ? 0.45 : 0.15),
                    child: child,
                  ),
                );
              },
              child: Container(
                key: endlessBiggestTileKey,
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: AppColors.tileGradient(digit),
                  borderRadius: BorderRadius.circular(7),
                  // O selo nunca pode ficar apagado: o brilho é o mesmo do
                  // tabuleiro, sem espalhamento, para não invadir os
                  // números vizinhos do cabeçalho.
                  boxShadow: apex
                      ? AppColors.apexGlow(scale: 0.6)
                      : [
                          BoxShadow(
                            color: AppColors.getColorByDigit(
                              digit,
                            ).withValues(alpha: 0.45),
                            blurRadius: 8,
                          ),
                        ],
                ),
                child: Center(
                  child: _OutlinedLabel(text: '$digit', fontSize: 16),
                ),
              ),
            ),
    );
  }
}

/// Mostra a faixa de peças que está caindo e o quanto falta para a próxima.
///
/// Vale explicar na tela: a janela subindo é o que mantém a corrida viva, e sem
/// aviso o jogador estranharia as peças baixas pararem de aparecer.
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.state, required this.progression});

  final EndlessState state;
  final EndlessProgression progression;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final atTop = state.step >= EndlessProgression.lastStep;
    final spawnMax = progression.spawnMaxFor(state.step);
    final promotion = progression.promotionDigitFor(state.step);

    // A promoção é um evento, não um acúmulo: ela dispara ao criar o dígito
    // [promotion]. O que dá para medir honestamente é a **distância** — o maior
    // bloco já criado contra o que promove. Fundir o dígito logo acima da faixa
    // é meio caminho; o seguinte promove.
    final climbed = (state.highestDigit - spawnMax).clamp(
      0,
      promotion - spawnMax,
    );
    final fraction = atTop ? 1.0 : climbed / (promotion - spawnMax);

    return Column(
      key: endlessStepKey,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (
              int digit = progression.spawnMinFor(state.step);
              digit <= spawnMax;
              digit++
            )
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.getColorByDigit(digit),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Center(
                    child: Text(
                      '$digit',
                      style: TextStyle(
                        color: AppColors.getTextColorForDigit(digit),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (atTop)
          // Pelo mesmo motivo do outro selo: este rótulo é o mais longo dos
          // dois e estouraria antes dele numa tela estreita.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: _BandBadge(
              label: l10n.endlessBandTop,
              color: Colors.white70,
            ),
          )
        else ...[
          // A frase e a peça encolhem **juntas** quando a tela é estreita: a
          // peça é parte da frase, e deixá-la de tamanho fixo enquanto o texto
          // some quebraria a leitura de "crie um 5".
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.endlessNextBand,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                // Espaço explícito, e não no fim da frase traduzida: espaço
                // à direita de um valor de ARB some numa revisão distraída e
                // a peça cola no texto sem ninguém notar.
                const SizedBox(width: 6),
                _BandBadge(
                  label: '$promotion',
                  color: AppColors.getColorByDigit(promotion),
                  filled: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              key: endlessBandProgressKey,
              value: fraction,
              minHeight: 6,
              backgroundColor: AppColors.darkBackground,
              valueColor: AlwaysStoppedAnimation(
                AppColors.getColorByDigit(promotion),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Número branco com contorno escuro, para o selo do maior bloco.
///
/// Mesma técnica do número da peça (ver `TileWidget`): o preenchimento é
/// sempre branco e quem garante a leitura é o traço. Sem ele, o `9` dourado
/// deixaria o selo do HUD praticamente ilegível — o branco sobre dourado dá
/// 1,4:1, bem abaixo do mínimo de 3:1.
class _OutlinedLabel extends StatelessWidget {
  const _OutlinedLabel({required this.text, required this.fontSize});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    TextStyle style(Paint? paint, Color? color) => TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      color: color,
      foreground: paint,
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          text,
          style: style(
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = fontSize * 0.16
              ..strokeJoin = StrokeJoin.round
              ..color = kDigitOutline,
            null,
          ),
        ),
        Text(text, style: style(null, Colors.white)),
      ],
    );
  }
}

/// Selo compacto: destaca o próximo alvo sem virar mais uma linha de texto.
class _BandBadge extends StatelessWidget {
  const _BandBadge({
    required this.label,
    required this.color,
    this.filled = false,
  });

  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: filled ? color.withValues(alpha: 0.22) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.7)),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: filled ? Colors.white : color,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
