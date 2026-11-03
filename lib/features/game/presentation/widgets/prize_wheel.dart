import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/core/theme/nf_tokens.dart';
import 'package:nine_fuse/core/widgets/nf_text.dart';
import 'package:nine_fuse/features/game/domain/daily_spin.dart';

/// Chave do cubo central da roleta (também gira a roda).
const Key prizeWheelHubKey = Key('prize_wheel_hub');

/// Voltas completas que todo giro dá antes de parar na fatia sorteada.
const int kWheelFullTurns = 5;

/// Quanto o ponto de parada pode fugir do centro da fatia, em fração da
/// largura dela. ±30% mantém a parada longe da divisória (que fica a ±50%):
/// um ponteiro em cima da linha faria o jogador duvidar do que ganhou.
const double kWheelMaxJitter = 0.3;

/// Onde a roda tem de terminar (em voltas, sentido horário) para a fatia
/// [index] parar sob o ponteiro.
///
/// A fatia `i` está centrada em `i / count` de volta a partir do topo, no
/// referencial da roda; girar a roda `t` voltas a leva para `i / count + t`.
/// Ela fica sob o ponteiro (topo) quando isso é inteiro, ou seja quando a
/// parte fracionária de `t` vale `-i / count`. [jitter], em fração da largura
/// da fatia, desloca a parada dentro dela.
///
/// O resultado parte de [from] arredondado para cima e soma [fullTurns]
/// voltas inteiras: todo giro anda pelo menos isso, inclusive o segundo giro
/// (por vídeo), que começa de onde o primeiro parou.
double targetTurnsFor(
  int index,
  int count, {
  double jitter = 0,
  double from = 0,
  int fullTurns = kWheelFullTurns,
}) {
  assert(count > 0 && index >= 0 && index < count);
  assert(jitter.abs() <= 0.5);
  final residue = ((-index - jitter) / count) % 1.0;
  return from.ceilToDouble() + fullTurns + residue;
}

/// Qual fatia está sob o ponteiro com a roda girada [turns] voltas.
int sliceUnderPointer(double turns, int count) {
  // O ponteiro, no referencial da roda, está em `-turns` voltas.
  final position = (-turns % 1.0) * count;
  return position.round() % count;
}

/// Quantas divisórias já passaram pelo ponteiro depois de [turns] voltas.
///
/// As divisórias ficam a meia fatia do centro; é a mudança deste número que
/// dispara o clique tátil do giro.
int dividersPassed(double turns, int count) => (turns * count + 0.5).floor();

/// A roda de prêmios do observatório: aro dourado com lâmpadas, fatias
/// alternando roxo e azul (o maior prêmio em moedas em ouro), ponteiro fixo
/// no topo e cubo central que gira junto.
///
/// Sem estado: quem anima é o diálogo, que passa [turns], [lampsAlternate] e
/// [pointerKick] a cada quadro. Assim o widget não esconde nenhum
/// `AnimationController` próprio — toda animação aqui é finita porque o dono
/// dela é finito.
class PrizeWheel extends StatelessWidget {
  const PrizeWheel({
    super.key,
    required this.prizes,
    required this.turns,
    required this.hubLabel,
    this.lampsAlternate = false,
    this.pointerKick = 0,
    this.onHubTap,
  });

  final List<SpinPrize> prizes;

  /// Rotação da roda, em voltas no sentido horário.
  final double turns;

  /// Rótulo do cubo central.
  final String hubLabel;

  /// Troca as cores das lâmpadas. O diálogo alterna isto enquanto gira.
  final bool lampsAlternate;

  /// Inclinação do ponteiro em radianos (o tranco da parada).
  final double pointerKick;

  /// Toque no cubo. Nulo deixa o cubo decorativo.
  final VoidCallback? onHubTap;

  /// Medidas no espaço de 390pt do design.
  static const double _rim = 174;
  static const double _slices = 150;
  static const double _labelDistance = 104;
  static const double _hub = 50;
  static const double _iconSize = 42;

  /// Largura da caixa: o aro mais a sombra deslocada.
  static const double width = 352;

  /// Altura: do topo do ponteiro (197 acima do centro) à base da sombra.
  static const double height = 384;

  /// Centro da roda dentro da caixa.
  static const Offset center = Offset(width / 2, 197);

  @override
  Widget build(BuildContext context) {
    final count = prizes.length;
    final slice = 2 * math.pi / count;
    const square = _rim * 2;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _WheelFramePainter(
                center: center,
                lampsAlternate: lampsAlternate,
              ),
            ),
          ),
          // Só a parte de dentro do aro gira: aro e lâmpadas ficam parados,
          // e é o pisca delas que conta que a roda está viva.
          Positioned(
            left: center.dx - _rim,
            top: center.dy - _rim,
            width: square,
            height: square,
            child: Transform.rotate(
              angle: turns * 2 * math.pi,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _SlicesPainter(prizes)),
                  ),
                  // Ícones em `Image.asset` por cima do painter, e não
                  // `ui.Image` desenhada no canvas: o PNG entra pelo cache de
                  // imagens do Flutter sem carregamento assíncrono à mão, e o
                  // teste acha cada fatia como widget.
                  for (var i = 0; i < count; i++)
                    Positioned.fill(
                      child: Transform.rotate(
                        angle: i * slice,
                        child: Stack(
                          children: [
                            // Topo do ícone 30pt acima do ponto da fatia,
                            // como no design (ícone em -30, número em +28).
                            Positioned(
                              top: _rim - _labelDistance - 30,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: _SliceLabel(prize: prizes[i]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Center(
                    child: _Hub(label: hubLabel, onTap: onHubTap),
                  ),
                ],
              ),
            ),
          ),
          // Fora do que gira: o ponteiro é a referência fixa da parada.
          // `IgnorePointer` porque a pintura cobre a caixa inteira e engoliria
          // o toque no cubo.
          Positioned.fill(
            child: IgnorePointer(
              child: Transform.rotate(
                angle: pointerKick,
                // Gira em torno do pino do topo, como um ponteiro preso.
                // `origin` é relativo ao centro da caixa; o pino fica 186 acima
                // do centro da roda.
                origin: Offset(0, center.dy - 186 - height / 2),
                child: CustomPaint(painter: _PointerPainter(center)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _assetFor(SpinPrizeType type) => switch (type) {
    SpinPrizeType.coins => 'assets/images/ic_coin.png',
    SpinPrizeType.hammer => 'assets/images/ic_hammer.png',
    SpinPrizeType.bomb => 'assets/images/ic_bomb.png',
    SpinPrizeType.brush => 'assets/images/ic_brush.png',
  };

  static IconData _fallbackFor(SpinPrizeType type) => switch (type) {
    SpinPrizeType.coins => Icons.monetization_on,
    SpinPrizeType.hammer => Icons.gavel,
    SpinPrizeType.bomb => Icons.brightness_high,
    SpinPrizeType.brush => Icons.brush,
  };

  /// Quantidade como aparece na fatia: moeda pelo valor, booster como "×N".
  static String amountLabel(SpinPrize prize) =>
      prize.type == SpinPrizeType.coins
      ? '${prize.amount}'
      : '×${prize.amount}';

  /// Ícone do prêmio, reusado pelo popup de prêmio.
  static Widget iconFor(SpinPrizeType type, {double size = _iconSize}) =>
      Image.asset(
        _assetFor(type),
        width: size,
        height: size,
        errorBuilder: (context, error, stack) =>
            Icon(_fallbackFor(type), size: size, color: NfColors.gold),
      );
}

/// Índice da fatia "jackpot": a de moedas de maior valor.
int _jackpotIndex(List<SpinPrize> prizes) {
  var best = -1;
  for (var i = 0; i < prizes.length; i++) {
    final p = prizes[i];
    if (p.type != SpinPrizeType.coins) continue;
    if (best < 0 || p.amount > prizes[best].amount) best = i;
  }
  return best;
}

class _SliceLabel extends StatelessWidget {
  const _SliceLabel({required this.prize});

  final SpinPrize prize;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      PrizeWheel.iconFor(prize.type),
      // Contorno por traço (não sombra): vale dentro do `Transform` animado.
      NfText.number(PrizeWheel.amountLabel(prize), size: 17),
    ],
  );
}

class _Hub extends StatelessWidget {
  const _Hub({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  static const double _size = PrizeWheel._hub * 2;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: prizeWheelHubKey,
    onTap: onTap,
    child: SizedBox(
      width: _size,
      height: _size + 5,
      child: Stack(
        children: [
          // Base bronze 5pt abaixo: a espessura do cubo.
          Positioned(
            top: 5,
            left: 0,
            child: Container(
              width: _size,
              height: _size,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: NfColors.bronze,
              ),
            ),
          ),
          Container(
            width: _size,
            height: _size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _hubGradient,
              border: Border.all(color: const Color(0xFFFFF6C8), width: 3),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(
                    fontFamily: AppFonts.title,
                    fontSize: 26,
                    color: NfColors.goldText,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// O "wHub" do design: ouro radial com o brilho no alto à esquerda.
const RadialGradient _hubGradient = RadialGradient(
  center: Alignment(-0.2, -0.4),
  radius: 0.8,
  colors: [Color(0xFFFFF6C8), Color(0xFFFFC21F), Color(0xFFB56E00)],
  stops: [0, 0.45, 1],
);

/// Aro, sombra e lâmpadas — a parte que não gira.
class _WheelFramePainter extends CustomPainter {
  const _WheelFramePainter({
    required this.center,
    required this.lampsAlternate,
  });

  final Offset center;
  final bool lampsAlternate;

  static const int _lamps = 16;
  static const double _lampRadius = 4.6;
  static const double _lampOrbit = 165;
  static const Color _lampAmber = Color(0xFFFFB000);
  static const Color _lampPale = Color(0xFFFFF6C8);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      center + const Offset(0, 10),
      176,
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );
    final rimRect = Rect.fromCircle(center: center, radius: PrizeWheel._rim);
    canvas.drawCircle(
      center,
      PrizeWheel._rim,
      Paint()..shader = NfDecorations.goldRim.createShader(rimRect),
    );
    canvas.drawCircle(center, 156, Paint()..color = NfColors.bronze);

    for (var k = 0; k < _lamps; k++) {
      final angle = k * 2 * math.pi / _lamps;
      final amber = k.isEven != lampsAlternate;
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * _lampOrbit,
        _lampRadius,
        Paint()..color = amber ? _lampAmber : _lampPale,
      );
    }
  }

  @override
  bool shouldRepaint(_WheelFramePainter old) =>
      old.lampsAlternate != lampsAlternate || old.center != center;
}

/// Fatias, sombreamento radial, divisórias e anel interno.
class _SlicesPainter extends CustomPainter {
  const _SlicesPainter(this.prizes);

  final List<SpinPrize> prizes;

  static const Color _purple = Color(0xFF7328C4);
  static const Color _blue = Color(0xFF1F4FD6);
  static const Color _jackpot = Color(0xFFC98A18);
  static const Color _line = NfColors.goldPale;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    const r = PrizeWheel._slices;
    final rect = Rect.fromCircle(center: c, radius: r);
    final count = prizes.length;
    final sweep = 2 * math.pi / count;
    final jackpot = _jackpotIndex(prizes);

    for (var i = 0; i < count; i++) {
      // A fatia `i` é centrada no topo girado `i` fatias no sentido horário.
      final start = -math.pi / 2 + (i - 0.5) * sweep;
      final color = i == jackpot ? _jackpot : (i.isEven ? _purple : _blue);
      canvas.drawArc(rect, start, sweep, true, Paint()..color = color);
    }

    // O "wSh": escurece o miolo e a borda e clareia o meio, para as fatias
    // lerem como cúpula e não como pizza chapada.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.black.withValues(alpha: 0.25),
            Colors.black.withValues(alpha: 0.25),
            Colors.white.withValues(alpha: 0.06),
            Colors.black.withValues(alpha: 0.25),
          ],
          stops: const [0, 0.25, 0.75, 1],
        ).createShader(rect),
    );

    final line = Paint()
      ..color = _line
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < count; i++) {
      final angle = -math.pi / 2 + (i - 0.5) * sweep;
      canvas.drawLine(
        c,
        c + Offset(math.cos(angle), math.sin(angle)) * r,
        line,
      );
    }
    canvas.drawCircle(c, r, line);
  }

  @override
  bool shouldRepaint(_SlicesPainter old) => old.prizes != prizes;
}

/// Ponteiro dourado fixo no topo, com base de sombra e pino.
class _PointerPainter extends CustomPainter {
  const _PointerPainter(this.center);

  final Offset center;

  @override
  void paint(Canvas canvas, Size size) {
    Path triangle(double dy) => Path()
      ..moveTo(center.dx - 24, center.dy - 188 + dy)
      ..lineTo(center.dx + 24, center.dy - 188 + dy)
      ..lineTo(center.dx, center.dy - 140 + dy)
      ..close();

    canvas.drawPath(triangle(4), Paint()..color = const Color(0xFF6B3E00));

    final bounds = Rect.fromLTRB(
      center.dx - 24,
      center.dy - 197,
      center.dx + 24,
      center.dy - 140,
    );
    final fill = Paint()..shader = _hubGradient.createShader(bounds);
    final stroke = Paint()
      ..color = const Color(0xFFFFF6C8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;

    final body = triangle(0);
    canvas
      ..drawPath(body, fill)
      ..drawPath(body, stroke);

    final pin = center + const Offset(0, -186);
    canvas
      ..drawCircle(pin, 11, fill)
      ..drawCircle(pin, 11, stroke);
  }

  @override
  bool shouldRepaint(_PointerPainter old) => old.center != center;
}
