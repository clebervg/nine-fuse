import 'package:flutter/material.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/features/game/presentation/widgets/game_dialog.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Chave do botão do martelo no HUD da campanha.
const Key hammerButtonKey = Key('hammer_button');

/// Chave do botão do martelo no HUD do Modo Recorde.
///
/// Separada da campanha porque os dois HUDs são telas diferentes, e um teste que
/// procura "o botão" precisa saber em qual delas está olhando.
const Key endlessHammerButtonKey = Key('endless_hammer_button');

/// Botão do Martelo de Fusão, que troca de papel durante a mira.
///
/// O mesmo botão é a saída: em mira ele lê "CANCELAR" em vermelho, com o ícone
/// de X. Um botão de cancelar em outro canto da tela obrigaria o jogador a
/// procurar como desistir de uma ação que ele começou aqui — e, num tabuleiro em
/// modo de mira, o próximo toque erra caro.
///
/// Serve aos dois modos, porque é o mesmo item: um botão por tela divergiria no
/// primeiro ajuste de rótulo ou de cor.
class HammerButton extends StatelessWidget {
  const HammerButton({
    super.key,
    required this.targeting,
    required this.count,
    required this.onPressed,
  });

  final bool targeting;
  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Semantics(
      button: true,
      label: l10n.hammerSemantics(count),
      child: GameButton(
        // O rótulo carrega o estoque: um "0" visível é o que torna o convite de
        // aquisição uma consequência, e não uma surpresa.
        label: targeting ? l10n.hammerCancel : l10n.hammerButton(count),
        color: targeting ? AppColors.digit0 : AppColors.digit5,
        icon: targeting ? Icons.close_rounded : Icons.gavel_rounded,
        fontSize: 15,
        onPressed: onPressed,
      ),
    );
  }
}
