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
    this.cellIndex = 0,
  });

  final ObstacleType type;

  /// Acompanha a silhueta da peça, senão a cobertura vaza pelos cantos.
  final BorderRadius radius;

  /// A cobertura já levou pelo menos um impacto. É o que o vidro usa para
  /// mostrar a trinca — o aviso de que o próximo golpe resolve.
  final bool cracked;

  /// Semente do traçado irregular desta célula.
  ///
  /// Existe para que duas coberturas vizinhas não sejam a mesma estampa
  /// espelhada — e, sendo derivada da posição e não sorteada, o desenho é o
  /// mesmo em todo quadro reconstruído. Trinca que dança a cada repaint é o
  /// bug que a semente fixa das faíscas já evitava.
  final int cellIndex;

  @override
  Widget build(BuildContext context) {
    final painter = switch (type) {
      ObstacleType.none => null,
      ObstacleType.ice => IceObstaclePainter(cellIndex: cellIndex),
      ObstacleType.glass => GlassObstaclePainter(
        cracked: cracked,
        cellIndex: cellIndex,
      ),
      ObstacleType.stone => const StoneObstaclePainter(),
    };
    if (painter == null) return const SizedBox.shrink();

    return IgnorePointer(
      child: ClipRRect(
        borderRadius: radius,
        child: CustomPaint(painter: painter, child: const SizedBox.expand()),
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

/// Gelo: **massa leitosa com bordas congeladas**.
///
/// O eixo que separa gelo de vidro é o *volume*. O gelo tem corpo — preenche,
/// avança da borda para dentro em pontas irregulares e é atravessado por
/// trincas internas. O vidro é uma lâmina: quase invisível no meio, definido
/// só pelo contorno e pelo reflexo. Duas texturas translúcidas com o mesmo
/// grau de preenchimento seriam indistinguíveis à distância de um toque, que é
/// a única distância que importa num tabuleiro de 64 células.
///
/// Nada de `Opacity` aqui: o alfa mora na cor do [Paint], e por isso não há
/// camada de composição extra nem repaint de subárvore.
class IceObstaclePainter extends CustomPainter {
  const IceObstaclePainter({this.cellIndex = 0});

  /// Semente do traçado irregular. Fixa por célula, nunca sorteada por quadro.
  final int cellIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Base leitosa: é ela que dá o volume que o vidro não tem.
    canvas.drawRect(
      rect,
      Paint()..color = const Color(0xFFE0F7FA).withValues(alpha: 0.32),
    );

    // Um degradê frio por cima da base, só para a massa não ler como chapada.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x40BFEBFF), Color(0x3359B0E8)],
        ).createShader(rect),
    );

    _paintIcicles(canvas, rect);
    _paintCracks(canvas, rect);

    // Contorno: é ele que faz a cobertura ler como camada por cima da peça, e
    // não como mudança de cor da própria peça.
    canvas.drawRect(
      rect.deflate(0.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.45),
    );
  }

  /// Pontas de gelo descendo da borda superior (e subindo da inferior) para o
  /// interior da célula.
  ///
  /// São o que faz a silhueta do gelo ser irregular enquanto a do vidro é uma
  /// moldura reta — diferença que se lê antes de qualquer cor.
  void _paintIcicles(Canvas canvas, Rect rect) {
    final random = Random(cellIndex * 31 + 11);
    final fill = Paint()..color = Colors.white.withValues(alpha: 0.38);

    const count = 4;
    for (int i = 0; i < count; i++) {
      // Passo regular com folga sorteada: espalha sem deixar duas pontas
      // coladas, que leriam como uma mancha só.
      final base = rect.width * ((i + 0.15 + random.nextDouble() * 0.7) / count);
      final half = rect.width * (0.045 + random.nextDouble() * 0.035);
      final drop = rect.height * (0.16 + random.nextDouble() * 0.22);

      canvas.drawPath(
        Path()
          ..moveTo(base - half, 0)
          ..lineTo(base + half, 0)
          ..lineTo(base, drop)
          ..close(),
        fill,
      );
    }

    // Duas pontas menores vindas de baixo: o gelo cerca a peça, não a cobre
    // só pelo topo.
    for (int i = 0; i < 2; i++) {
      final base = rect.width * (0.25 + i * 0.42 + random.nextDouble() * 0.12);
      final half = rect.width * 0.05;
      final rise = rect.height * (0.10 + random.nextDouble() * 0.10);

      canvas.drawPath(
        Path()
          ..moveTo(base - half, rect.height)
          ..lineTo(base + half, rect.height)
          ..lineTo(base, rect.height - rise)
          ..close(),
        fill..color = Colors.white.withValues(alpha: 0.26),
      );
    }
  }

  /// Trincas internas: dois caminhos quebrados, com cotovelo, atravessando a
  /// massa. Traço reto leria como reflexo; o cotovelo é o que lê como fratura.
  void _paintCracks(Canvas canvas, Rect rect) {
    final random = Random(cellIndex * 17 + 5);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.42);

    for (int i = 0; i < 2; i++) {
      final start = Offset(
        rect.width * (0.12 + random.nextDouble() * 0.25),
        rect.height * (0.20 + i * 0.38),
      );
      final elbow =
          start +
          Offset(
            rect.width * (0.22 + random.nextDouble() * 0.14),
            rect.height * (0.14 + random.nextDouble() * 0.12),
          );
      final tip =
          elbow +
          Offset(
            rect.width * (0.16 + random.nextDouble() * 0.18),
            rect.height * (random.nextDouble() * 0.20 - 0.12),
          );

      canvas.drawPath(
        Path()
          ..moveTo(start.dx, start.dy)
          ..lineTo(elbow.dx, elbow.dy)
          ..lineTo(tip.dx, tip.dy),
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(IceObstaclePainter old) => old.cellIndex != cellIndex;
}

/// Vidro: **lâmina quase invisível, definida pela borda e pelo reflexo**.
///
/// O desenho original era um véu branco — e um véu com o mesmo papel do véu do
/// gelo, o que apagava a distinção entre as duas coberturas justamente onde
/// ela custa caro: numa fase de "quebre 1 vidro", quebrar gelo a fase inteira
/// sem o contador andar. O remédio nunca foi mais opacidade (isso apagaria o
/// dígito, que é a razão de a cobertura ser translúcida): é **silhueta**.
///
/// Daí o preenchimento a 6% e todo o peso visual na borda de 1,5px em degradê
/// (branco → ciano transparente) e nas duas faixas especulares do canto
/// superior direito. Borda nítida lê como camada por cima; véu chapado leria
/// como peça apagada.
class GlassObstaclePainter extends CustomPainter {
  const GlassObstaclePainter({required this.cracked, this.cellIndex = 0});

  /// Já levou um impacto. O vidro aguenta dois, e a trinca é o aviso de que o
  /// próximo golpe resolve.
  final bool cracked;
  final int cellIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()..color = Colors.white.withValues(alpha: 0.06),
    );

    _paintEdge(canvas, rect);

    if (cracked) {
      _paintCracks(canvas, rect);
      return;
    }
    _paintSpecular(canvas, rect);
  }

  /// Borda em degradê: branca no alto, dissolvendo em ciano transparente
  /// embaixo. É ela que carrega quase toda a leitura de "há algo aqui".
  void _paintEdge(Canvas canvas, Rect rect) {
    canvas.drawRect(
      rect.deflate(0.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xF2FFFFFF), Color(0x2200E5FF)],
        ).createShader(rect),
    );
  }

  /// Duas faixas diagonais finas e paralelas no canto superior direito.
  ///
  /// Duas e não uma porque um traço só se confunde com o reflexo que a própria
  /// peça já tem; o par lê como superfície plana refletindo uma fonte de luz.
  void _paintSpecular(Canvas canvas, Rect rect) {
    void streak(double offset, double width, double alpha) {
      final from = Offset(rect.width * (0.52 + offset), 0);
      final to = Offset(rect.width, rect.height * (0.48 - offset));

      canvas.drawLine(
        from,
        to,
        Paint()
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..shader =
              LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: alpha),
                  Colors.white.withValues(alpha: 0),
                ],
              ).createShader(
                Rect.fromPoints(from, to),
              ),
      );
    }

    streak(0, 2.4, 0.95);
    streak(0.16, 1.2, 0.65);
  }

  /// A trinca: caminhos partindo do centro, com cotovelo. Semente fixa, senão
  /// a rachadura dança a cada quadro reconstruído.
  void _paintCracks(Canvas canvas, Rect rect) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.85);

    final centre = rect.center;
    final random = Random(cellIndex * 13 + 7);
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

  @override
  bool shouldRepaint(GlassObstaclePainter old) =>
      old.cracked != cracked || old.cellIndex != cellIndex;
}

/// Pedra: opaca. É a única cobertura que esconde o dígito quase por completo —
/// e é justamente por isso que ela custa três impactos.
class StoneObstaclePainter extends CustomPainter {
  const StoneObstaclePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

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

    canvas.drawRect(
      rect.deflate(0.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.10),
    );
  }

  /// A pedra não tem estado: nada nela muda entre um quadro e o seguinte.
  @override
  bool shouldRepaint(StoneObstaclePainter old) => false;
}
