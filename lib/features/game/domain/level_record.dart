import 'package:nine_fuse/features/game/domain/campaign_chapter.dart';

/// O que ficou de uma fase já vencida.
///
/// Guarda **o melhor** de cada coisa, não o último: rejogar uma fase para tentar
/// a terceira estrela não pode custar a estrela que já se tinha. É a mesma regra
/// do recorde do Endless, aplicada por fase.
class LevelRecord {
  const LevelRecord({required this.stars, required this.bestScore})
    : assert(stars >= 1 && stars <= kStarsPerLevel),
      assert(bestScore >= 0);

  final int stars;
  final int bestScore;

  /// O melhor entre este resultado e outro.
  ///
  /// As duas grandezas são comparadas **em separado**: uma partida pode render
  /// mais estrelas e menos pontos que a anterior (sobrar movimento não é a
  /// mesma coisa que pontuar), e o jogador merece ficar com o melhor de cada.
  LevelRecord mergedWith(LevelRecord other) => LevelRecord(
    stars: stars > other.stars ? stars : other.stars,
    bestScore: bestScore > other.bestScore ? bestScore : other.bestScore,
  );

  Map<String, int> toJson() => {'stars': stars, 'score': bestScore};

  /// Lê um registro gravado, ou devolve nulo se o conteúdo não fizer sentido.
  ///
  /// Nulo em vez de exceção porque isto lê disco: um arquivo corrompido ou
  /// gravado por uma versão futura não pode impedir o jogador de abrir o mapa.
  static LevelRecord? tryFromJson(Object? json) {
    if (json is! Map) return null;

    final stars = json['stars'];
    final score = json['score'];
    if (stars is! int || score is! int) return null;
    if (stars < 1 || stars > kStarsPerLevel || score < 0) return null;

    return LevelRecord(stars: stars, bestScore: score);
  }

  @override
  bool operator ==(Object other) =>
      other is LevelRecord &&
      other.stars == stars &&
      other.bestScore == bestScore;

  @override
  int get hashCode => Object.hash(stars, bestScore);

  @override
  String toString() => 'LevelRecord($stars★, $bestScore pts)';
}
