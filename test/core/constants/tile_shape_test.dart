import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/constants/tile_shape.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';

void main() {
  group('forma por dígito', () {
    test('a peça fica mais quadrada conforme o dígito cresce', () {
      // A silhueta é a segunda leitura do valor, ao lado da cor. Se ela
      // deixasse de ser monotônica, o formato pararia de significar magnitude
      // e viraria enfeite.
      var previous = double.infinity;

      for (int digit = 0; digit <= kMaxDigit; digit++) {
        final radius = TileShape.radiusFactorFor(digit);
        expect(radius, lessThan(previous), reason: 'dígito $digit');
        previous = radius;
      }
    });

    test('o extremo baixo é quase circular e o alto quase quadrado', () {
      expect(TileShape.radiusFactorFor(0), greaterThan(0.35));
      expect(TileShape.radiusFactorFor(kMaxDigit), lessThan(0.20));
    });

    test('nunca chega a círculo nem a quadrado perfeitos', () {
      // Circular de verdade abriria buracos entre as células; quadrada de
      // verdade endureceria o tabuleiro.
      for (int digit = 0; digit <= kMaxDigit; digit++) {
        expect(TileShape.radiusFactorFor(digit), lessThan(0.5));
        expect(TileShape.radiusFactorFor(digit), greaterThan(0.1));
      }
    });

    test('dígitos vizinhos têm formas distinguíveis', () {
      // Se o passo entre dois dígitos for pequeno demais, o formato não
      // acrescenta informação nenhuma.
      for (int digit = 0; digit < kMaxDigit; digit++) {
        final step =
            TileShape.radiusFactorFor(digit) -
            TileShape.radiusFactorFor(digit + 1);
        expect(step, greaterThan(0.02), reason: 'entre $digit e ${digit + 1}');
      }
    });

    test('o raio acompanha o tamanho da célula', () {
      expect(TileShape.radiusFor(5, 100), TileShape.radiusFactorFor(5) * 100);
      expect(TileShape.radiusFor(5, 44), TileShape.radiusFactorFor(5) * 44);
    });

    test('valor fora da escala é contido nas pontas', () {
      expect(TileShape.radiusFactorFor(-3), TileShape.radiusFactorFor(0));
      expect(
        TileShape.radiusFactorFor(99),
        TileShape.radiusFactorFor(kMaxDigit),
      );
    });
  });
}
