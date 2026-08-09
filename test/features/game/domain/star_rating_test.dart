import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/star_rating.dart';

void main() {
  group('nota da fase', () {
    test('sobrando 30% ou mais do saldo, vale três estrelas', () {
      expect(starRating(movesLeft: 6, movesAvailable: 20), 3);
      expect(starRating(movesLeft: 20, movesAvailable: 20), 3);
    });

    test('sobrando de 10% a 30%, vale duas estrelas', () {
      expect(starRating(movesLeft: 2, movesAvailable: 20), 2);
      expect(starRating(movesLeft: 5, movesAvailable: 20), 2);
    });

    test('vencer no limite ainda vale uma estrela', () {
      expect(starRating(movesLeft: 0, movesAvailable: 20), 1);
      expect(starRating(movesLeft: 1, movesAvailable: 20), 1);
    });

    test('a nota nunca sai da faixa de 1 a 3', () {
      for (int limit = 1; limit <= 60; limit++) {
        for (int left = 0; left <= limit; left++) {
          final stars = starRating(movesLeft: left, movesAvailable: limit);
          expect(
            stars,
            inInclusiveRange(1, 3),
            reason: 'saldo $left de $limit rendeu $stars',
          );
        }
      }
    });

    // Sem isso o bônus de movimentos da explosão viraria nota de graça: ele
    // engorda o saldo restante, então precisa engordar também o total.
    test('o bônus de movimentos não infla a nota sozinho', () {
      // Fase de 20 movimentos, gastou 18, ganhou 3 de bônus: sobram 5 de 23.
      expect(starRating(movesLeft: 5, movesAvailable: 23), 2);
    });

    test('saldo total zero não quebra a divisão', () {
      expect(starRating(movesLeft: 0, movesAvailable: 0), 1);
    });
  });
}
