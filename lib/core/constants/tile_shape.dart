import 'dart:ui';

import 'package:nine_fuse/features/game/domain/match_engine.dart';

/// Forma da peça por dígito.
///
/// Hoje as 64 peças têm todas a mesma silhueta e variam só de cor — é o que
/// mais separa o tabuleiro de um Candy Crush, onde cada doce tem formato
/// próprio e o olho identifica pela silhueta antes de processar a cor.
///
/// Aqui a forma **codifica magnitude**: quanto maior o dígito, mais quadrada a
/// peça. Isso dá duas leituras independentes do mesmo valor — cor e formato —
/// o que ajuda quem não distingue as cores, e faz a evolução de uma peça ser
/// visível mesmo pelo canto do olho.
class TileShape {
  const TileShape._();

  /// Raio do canto, em fração do lado da peça.
  ///
  /// Quase circular no `0`, quase quadrada no `9`. Circular de verdade abriria
  /// buracos entre as células; quadrada de verdade endureceria o tabuleiro.
  static const double _roundest = 0.42;
  static const double _squarest = 0.15;

  static double radiusFactorFor(int digit) {
    final t = (digit.clamp(0, kMaxDigit)) / kMaxDigit;
    return lerpDouble(_roundest, _squarest, t)!;
  }

  /// Raio absoluto para uma peça de lado [side].
  static double radiusFor(int digit, double side) =>
      radiusFactorFor(digit) * side;
}
