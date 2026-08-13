import 'dart:math';

import 'package:flutter/material.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';

/// Cobertura desenhada por cima da peça presa.
///
/// Fica **acima** do número de propósito: o dígito continua legível, porque o
/// jogador precisa saber o que vai ganhar ao quebrar a cobertura — se ele não
/// enxerga o valor, o obstáculo vira só um buraco no tabuleiro.
///
/// Nada de `Opacity` nem `FadeTransition` aqui dentro: os testes de saída de
/// peça e de clarão de combinação grande usam esses dois tipos como marcadores
/// dentro da peça, e um a mais os quebraria em silêncio. A translucidez vem de
/// cores com alfa.
class ObstacleOverlay extends StatelessWidget {
  const ObstacleOverlay({
    super.key,
    required this.type,
    required this.radius,
    this.cracked = false,
  });

  final ObstacleType type;

  /// Acompanha a silhueta da peça, senão a cobertura vaza pelos cantos.
  final BorderRadius radius;

  /// A cobertura já levou pelo menos um impacto. É o que o vidro usa para
  /// mostrar a trinca — o aviso de que o próximo golpe resolve.
  final bool cracked;

  @override
  Widget build(BuildContext context) {
    if (type == ObstacleType.none) return const SizedBox.shrink();

    return IgnorePointer(
      child: ClipRRect(
        borderRadius: radius,
        child: CustomPaint(
          painter: _ObstaclePainter(type: type, cracked: cracked),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Cor que assina cada cobertura fora do tabuleiro: aro da pílula do HUD,
/// destaque do cartão de início, barra de progresso do objetivo.
///
/// Não sai do `_ObstaclePainter` porque lá a cobertura é degradê e faceta, e o
/// HUD precisa de **uma** cor. Manter as duas coisas juntas faria a pílula ter
/// de renderizar uma peça inteira só para descobrir de que cor se pinta.
Color obstacleAccent(ObstacleType type) => switch (type) {
  ObstacleType.none => Colors.white54,
  ObstacleType.ice => const Color(0xFF7FC7EF),
  ObstacleType.glass => const Color(0xFFCBD6E0),
  ObstacleType.stone => const Color(0xFF9AA0A9),
};

/// Ícone da cobertura, para o rótulo do objetivo.
IconData obstacleIcon(ObstacleType type) => switch (type) {
  ObstacleType.none => Icons.adjust,
  ObstacleType.ice => Icons.ac_unit,
  ObstacleType.glass => Icons.blur_on,
  ObstacleType.stone => Icons.terrain,
};

/// A cobertura como amostra, fora do tabuleiro.
///
/// Desenha a **mesma** textura do [ObstacleOverlay] sobre um fundo escuro, e não
/// um ícone chapado: é o que faz o jogador reconhecer no tabuleiro a coisa que o
/// objetivo lhe pediu. Um ícone de floco de neve e um bloco de gelo facetado não
/// se parecem o bastante para fechar essa ligação.
class ObstacleBadge extends StatelessWidget {
  const ObstacleBadge({super.key, required this.type, this.size = 24});

  final ObstacleType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.25);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A20),
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: obstacleAccent(type).withValues(alpha: 0.45),
            blurRadius: size * 0.33,
          ),
        ],
      ),
      child: ObstacleOverlay(type: type, radius: radius),
    );
  }
}

/// Pinta as três coberturas.
///
/// Um `CustomPainter` só, e não três widgets: as trincas e as facetas são
/// traçado geométrico derivado do tamanho da célula, e desenhá-las com caixas
/// aninhadas custaria layout em 64 peças por quadro.
class _ObstaclePainter extends CustomPainter {
  const _ObstaclePainter({required this.type, required this.cracked});

  final ObstacleType type;
  final bool cracked;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    switch (type) {
      case ObstacleType.none:
        return;
      case ObstacleType.ice:
        _paintIce(canvas, rect);
      case ObstacleType.glass:
        _paintGlass(canvas, rect);
      case ObstacleType.stone:
        _paintStone(canvas, rect);
    }

    // Contorno comum: é ele que faz a cobertura ler como uma camada por cima
    // da peça, e não como uma mudança de cor da própria peça.
    canvas.drawRect(
      rect.deflate(0.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(
          alpha: type == ObstacleType.stone ? 0.10 : 0.45,
        ),
    );
  }

  /// Gelo: azul translúcido com um brilho diagonal.
  void _paintIce(Canvas canvas, Rect rect) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x99BFEBFF), Color(0x6659B0E8)],
        ).createShader(rect),
    );

    // Faixa clara atravessando: é o que dá a leitura de superfície gelada em
    // vez de simples véu azul.
    final gleam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = rect.width * 0.09
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.45);

    canvas.drawLine(
      Offset(rect.width * 0.18, rect.height * 0.72),
      Offset(rect.width * 0.66, rect.height * 0.20),
      gleam,
    );
  }

  /// Vidro: mais limpo que o gelo, e trincado depois do primeiro impacto.
  ///
  /// **A leitura "isto está coberto" vem antes da leitura "isto é liso".** O
  /// desenho original era tão discreto (véu branco em alfa 0x73→0x40, uma
  /// faceta a 35%) que a peça envidraçada ficava indistinguível de uma peça
  /// **sem cobertura nenhuma** — só um leve clareado sobre a mesma moldura
  /// colorida. Numa fase de "quebre 1 vidro" com dois gelos no tabuleiro, o
  /// gelo é o único obstáculo que o jogador acha, e ele quebra gelo a fase
  /// inteira sem o contador andar. O objetivo estava certo e a tela é que não
  /// dizia onde estava o alvo.
  ///
  /// O remédio é dar ao vidro uma **silhueta**, não mais opacidade: o dígito
  /// por baixo continua sendo a razão de a cobertura ser translúcida. Daí o
  /// canto de brilho chapado e as duas facetas fortes — bordas leem como
  /// camada por cima, véu chapado leria como peça apagada.
  void _paintGlass(Canvas canvas, Rect rect) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x8CFFFFFF), Color(0x59C9D6E0)],
        ).createShader(rect),
    );

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cracked ? 1.2 : 1.6
      ..color = Colors.white.withValues(alpha: cracked ? 0.85 : 0.75);

    // Sem dano, o vidro é liso: duas facetas paralelas e o canto de brilho.
    // Duas e não uma porque um traço só se confunde com o reflexo que a
    // própria peça já tem; o par lê como painel.
    if (!cracked) {
      canvas.drawPath(
        Path()
          ..moveTo(rect.width * 0.62, 0)
          ..lineTo(rect.width, 0)
          ..lineTo(rect.width, rect.height * 0.42)
          ..close(),
        Paint()..color = Colors.white.withValues(alpha: 0.30),
      );

      canvas.drawLine(
        Offset(rect.width * 0.62, 0),
        Offset(rect.width * 0.92, rect.height),
        stroke,
      );
      canvas.drawLine(
        Offset(rect.width * 0.24, 0),
        Offset(rect.width * 0.54, rect.height),
        stroke..color = Colors.white.withValues(alpha: 0.45),
      );
      return;
    }

    final centre = rect.center;
    // Semente fixa: a trinca não pode dançar a cada quadro reconstruído.
    final random = Random(7);
    for (int i = 0; i < 5; i++) {
      final angle = (i / 5) * 2 * pi + random.nextDouble() * 0.5;
      final reach = rect.shortestSide * (0.42 + random.nextDouble() * 0.16);
      final elbow = centre + Offset(cos(angle), sin(angle)) * (reach * 0.5);
      final tip =
          elbow + Offset(cos(angle + 0.4), sin(angle + 0.4)) * (reach * 0.5);

      canvas.drawPath(
        Path()
          ..moveTo(centre.dx, centre.dy)
          ..lineTo(elbow.dx, elbow.dy)
          ..lineTo(tip.dx, tip.dy),
        stroke,
      );
    }
  }

  /// Pedra: opaca. É a única cobertura que esconde o dígito quase por
  /// completo — e é justamente por isso que ela custa três impactos.
  void _paintStone(Canvas canvas, Rect rect) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xF0787C85), Color(0xF03E4249)],
        ).createShader(rect),
    );

    // Duas veias claras dão granulação; sem elas a pedra vira um retângulo
    // cinza chapado, que é o que o acabamento do jogo evita em toda parte.
    final vein = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Colors.white.withValues(alpha: 0.16);

    canvas.drawLine(
      Offset(rect.width * 0.10, rect.height * 0.32),
      Offset(rect.width * 0.55, rect.height * 0.46),
      vein,
    );
    canvas.drawLine(
      Offset(rect.width * 0.45, rect.height * 0.72),
      Offset(rect.width * 0.92, rect.height * 0.58),
      vein,
    );
  }

  @override
  bool shouldRepaint(_ObstaclePainter old) =>
      old.type != type || old.cracked != cracked;
}
