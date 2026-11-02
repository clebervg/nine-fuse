import 'package:flutter/material.dart';
import 'package:nine_fuse/core/assets/tile_sprite_manager.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/core/theme/nf_tokens.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';
import 'package:nine_fuse/features/game/presentation/widgets/obstacle_overlay.dart';

/// Chave do disco do objetivo nas telas de derrota.
const Key objectiveDiscKey = Key('objective_disc');

/// O alvo da fase grande, num disco, com o placar "feito/pedido" embaixo.
///
/// Mora nas duas telas de derrota (o convite de resgate e o cartão de
/// desfecho): é o que diz ao jogador **do que** ele ficou perto. A frase
/// "faltou pouco" sem a peça na frente é consolo genérico; com a pedra e o
/// "0/1" embaixo, vira uma meta concreta — e é ela que faz o "+5 jogadas"
/// parecer suficiente.
class ObjectiveDisc extends StatelessWidget {
  const ObjectiveDisc({
    super.key,
    required this.objective,
    required this.progress,
    required this.target,
  });

  final Objective objective;
  final int progress;
  final int target;

  static const double _disc = 128;
  static const double _art = 92;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: objectiveDiscKey,
    width: _disc,
    // Espaço para o placar que pende da borda de baixo do disco.
    height: _disc + 16,
    child: Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: _disc,
          height: _disc,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                NfColors.night3.withValues(alpha: 0.9),
                NfColors.night1.withValues(alpha: 0.6),
              ],
            ),
            border: Border.all(color: const Color(0xFF3A4380), width: 2),
          ),
          alignment: Alignment.center,
          child: SizedBox.square(dimension: _art, child: _artwork()),
        ),
        Positioned(
          bottom: 0,
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFF3A4380), width: 2.5),
            ),
            child: Text(
              '$progress/$target',
              style: const TextStyle(
                fontFamily: AppFonts.title,
                fontSize: 18,
                height: 1,
                color: NfColors.night3,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  /// A mesma arte do tabuleiro: o jogador tem de reconhecer no disco a peça
  /// que procurou a fase inteira. Sem o PNG, cai no desenho vetorial.
  Widget _artwork() {
    if (objective.isObstacleGoal) {
      final type = objective.obstacle;
      return Image.asset(
        TileSpriteManager.assetKeyForObstacle(type, type.hitPoints),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) =>
            ObstacleBadge(type: type, size: _art * 0.8),
      );
    }
    final digit = objective.digit!;
    return Image.asset(
      TileSpriteManager.assetKeyFor(digit),
      fit: BoxFit.contain,
      errorBuilder: (context, error, stack) => Center(
        child: Container(
          width: _art * 0.8,
          height: _art * 0.8,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppColors.tileGradient(digit),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            '$digit',
            style: TextStyle(
              fontFamily: AppFonts.number,
              fontWeight: FontWeight.w800,
              fontSize: 40,
              color: AppColors.getTextColorForDigit(digit),
            ),
          ),
        ),
      ),
    );
  }
}
