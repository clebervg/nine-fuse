/// Quantas estrelas uma fase vencida vale.
///
/// A nota mede **folga**, não velocidade: o que sobrou do saldo de movimentos
/// no instante da vitória. Vencer é sempre uma estrela — a nota gradua quão bem
/// se venceu, nunca transforma vitória em fracasso.
///
/// Fica no domínio, e não no cartão de fim de fase, porque é regra de jogo: a
/// tela de seleção de fases vai querer a mesma nota sem duplicar a fórmula.
library;

/// Folga mínima para três estrelas: 30% do saldo intacto.
const double kThreeStarSpare = 0.30;

/// Folga mínima para duas estrelas: 10% do saldo intacto.
const double kTwoStarSpare = 0.10;

/// Nota de 1 a 3 estrelas.
///
/// [movesLeft] é o saldo no fim da fase e [movesAvailable] é o total que a fase
/// ofereceu — o limite **mais** os movimentos-bônus ganhos com explosões, senão
/// o bônus inflaria a nota ao aumentar o numerador sem tocar o denominador.
int starRating({required int movesLeft, required int movesAvailable}) {
  if (movesAvailable <= 0) return 1;

  final spare = movesLeft / movesAvailable;
  if (spare >= kThreeStarSpare) return 3;
  if (spare >= kTwoStarSpare) return 2;
  return 1;
}
