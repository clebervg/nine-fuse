import 'package:flutter/material.dart';
import 'package:nine_fuse/core/theme/nf_tokens.dart';
import 'package:nine_fuse/features/game/presentation/widgets/board_grid_widget.dart';

/// Espessura do aro de ouro em volta do tabuleiro.
///
/// Entra na conta da largura disponível: a tela dá ao tabuleiro a largura
/// menos 2x(margem + aro), e é essa a mesma largura que os testes de tamanho
/// de célula assumem (tela - 16pt).
const double kBoardRimWidth = 5;

/// Diâmetro dos rebites dos cantos.
const double _kRivet = 18;

/// A moldura de ouro do tabuleiro, com rebites nos quatro cantos.
///
/// **Por fora do tabuleiro, não dentro dele.** A geometria das células
/// (`BoardGeometry`) é compartilhada pelo tabuleiro, pelos efeitos e pela
/// camada de mira; desenhar o aro dentro do `BoardGridWidget` roubaria espaço
/// dessa conta e obrigaria as três a saberem dele. Aqui ele é só uma borda em
/// volta de quem já está pronto.
///
/// O ouro é o que diz "isto é o jogo": é a única moldura dourada grossa da
/// tela, e por isso o tabuleiro continua sendo o elemento mais forte mesmo com
/// o HUD e o dock também em placas.
class BoardFrame extends StatelessWidget {
  const BoardFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    // Os rebites avançam sobre o canto de propósito, como pregos de verdade.
    clipBehavior: Clip.none,
    children: [
      DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            kBoardWellRadius + kBoardRimWidth - 1,
          ),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFE9A0),
              NfColors.goldDeep,
              Color(0xFF9C5F0A),
              Color(0xFFF6C54A),
              Color(0xFF8A5300),
            ],
            stops: [0, 0.28, 0.55, 0.8, 1],
          ),
          boxShadow: [
            // Blur zero: é a espessura da moldura, não uma sombra.
            const BoxShadow(color: NfColors.bronze, offset: Offset(0, 10)),
            const BoxShadow(
              color: Color(0x99000000),
              blurRadius: 40,
              offset: Offset(0, 24),
            ),
            BoxShadow(
              color: NfColors.gem.withValues(alpha: 0.35),
              blurRadius: 60,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(kBoardRimWidth),
          child: child,
        ),
      ),
      for (final alignment in const [
        Alignment.topLeft,
        Alignment.topRight,
        Alignment.bottomLeft,
        Alignment.bottomRight,
      ])
        Positioned(
          left: alignment.x < 0 ? -5 : null,
          right: alignment.x > 0 ? -5 : null,
          top: alignment.y < 0 ? -5 : null,
          bottom: alignment.y > 0 ? -5 : null,
          child: const IgnorePointer(child: _Rivet()),
        ),
    ],
  );
}

class _Rivet extends StatelessWidget {
  const _Rivet();

  @override
  Widget build(BuildContext context) => Container(
    width: _kRivet,
    height: _kRivet,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        center: Alignment(-0.3, -0.4),
        colors: [Color(0xFFFFF6C8), NfColors.goldDeep, Color(0xFF8A5300)],
        stops: [0, 0.6, 1],
      ),
      boxShadow: [BoxShadow(color: Color(0x66000000), offset: Offset(0, 1.5))],
    ),
  );
}
