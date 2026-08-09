import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';

/// Distância perceptual (CIE76) entre duas cores.
///
/// Diferença de canal RGB não serve aqui: o olho não separa vermelho de rosa
/// pela mesma régua com que separa azul de ciano. Lab aproxima a percepção, e
/// é nela que "parecidas na tela do celular" vira um número.
double _deltaE(Color a, Color b) {
  final la = _lab(a);
  final lb = _lab(b);
  return math.sqrt(
    math.pow(la[0] - lb[0], 2) +
        math.pow(la[1] - lb[1], 2) +
        math.pow(la[2] - lb[2], 2),
  );
}

List<double> _lab(Color c) {
  double linear(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

  final r = linear(c.r);
  final g = linear(c.g);
  final b = linear(c.b);

  // Branco D65.
  final x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047;
  final y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  final z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883;

  double f(double t) =>
      t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;

  final fx = f(x);
  final fy = f(y);
  final fz = f(z);
  return [116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
}

void main() {
  group('separação perceptual da paleta', () {
    test('o vermelho do 0 e o rosa do 6 não se confundem', () {
      // O par foi relatado como indistinguível em aparelho. Com o rosa choque
      // antigo (0xFFD81B60) a distância era ΔE 32; o piso aqui reprova
      // qualquer volta a essa vizinhança.
      expect(
        _deltaE(AppColors.digit0, AppColors.digit6),
        greaterThan(45),
        reason: 'vermelho e rosa precisam se separar de relance',
      );
    });

    test('o rosa do 6 não invade o roxo do 5', () {
      // Afastar o 6 do vermelho só resolve se ele não colidir do outro lado.
      expect(_deltaE(AppColors.digit5, AppColors.digit6), greaterThan(40));
    });
  });
}
