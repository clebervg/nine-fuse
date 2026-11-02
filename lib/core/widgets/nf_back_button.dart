import 'package:flutter/material.dart';
import 'package:nine_fuse/core/theme/nf_tokens.dart';

/// Chave do botão voltar do topo das telas de partida.
const Key nfBackButtonKey = Key('nf_back_button');

/// Largura que a `AppBar` precisa reservar para o [NfBackButton] com a margem
/// esquerda do topo (18pt, a mesma da pílula de moedas do outro lado).
const double kNfBackButtonLeadingWidth = 18 + 46 + 4;

/// Botão voltar do topo: placa azul-noite com aro de ouro e base 3D.
///
/// Substitui a seta solta do Material: sobre o céu transparente da `AppBar` a
/// seta fina sumia entre as estrelas, e o controle lia como sistema, não como
/// jogo. A placa é a mesma linguagem da pílula de moedas do canto oposto — os
/// dois cantos do topo são equipamento do jogador.
class NfBackButton extends StatelessWidget {
  const NfBackButton({super.key, this.onPressed});

  /// Padrão: `Navigator.maybePop`, o mesmo do `BackButton` do Material.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 18),
    child: Center(
      child: Semantics(
        button: true,
        label: MaterialLocalizations.of(context).backButtonTooltip,
        excludeSemantics: true,
        child: GestureDetector(
          key: nfBackButtonKey,
          behavior: HitTestBehavior.opaque,
          onTap: onPressed ?? () => Navigator.of(context).maybePop(),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [NfColors.night3, Color(0xFF0E1640)],
              ),
              border: Border.all(color: const Color(0xFFC98A18), width: 2),
              boxShadow: const [
                // Blur zero: é a espessura da placa, não uma sombra.
                BoxShadow(color: Color(0xFF05081C), offset: Offset(0, 4)),
              ],
            ),
            child: const Icon(
              Icons.chevron_left_rounded,
              color: NfColors.goldPale,
              size: 30,
            ),
          ),
        ),
      ),
    ),
  );
}
