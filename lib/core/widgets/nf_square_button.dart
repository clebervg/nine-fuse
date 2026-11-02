import 'package:flutter/material.dart';
import 'package:nine_fuse/core/theme/nf_tokens.dart';

/// Chave do ponto de aviso de um [NfSquareButton].
const Key nfSquareButtonBadgeKey = Key('nf_square_button_badge');

/// Botão quadrado do topo: a mesma placa azul-noite com aro de ouro e base 3D
/// do [NfBackButton], para atalhos com ícone (roleta, privacidade).
///
/// Mesma linguagem do botão voltar de propósito: os cantos do topo são
/// equipamento do jogador, e um `IconButton` solto sobre o céu lia como
/// controle de sistema — some entre as estrelas.
class NfSquareButton extends StatelessWidget {
  const NfSquareButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.size = 42,
    this.badge = false,
  });

  final IconData icon;
  final VoidCallback onPressed;

  /// Rótulo para leitor de tela e toque longo.
  final String tooltip;

  final double size;

  /// Ponto vermelho no canto: há algo esperando o jogador ali.
  final bool badge;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    // O rótulo para leitor de tela vem do `Semantics` abaixo; o da dica
    // repetiria a mesma frase.
    excludeFromSemantics: true,
    child: Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.33),
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
              child: Icon(icon, color: NfColors.goldPale, size: size * 0.52),
            ),
            if (badge)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  key: nfSquareButtonBadgeKey,
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: NfColors.alert,
                    border: Border.all(color: NfColors.night1, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
