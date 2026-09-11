import 'package:nine_fuse/features/game/domain/obstacle.dart';
import 'package:nine_fuse/features/game/domain/position.dart';

/// Bônus de score estático da Nova, por tier (3, 4 ou 5+ peças de valor 9
/// alinhadas). É SOMADO ao placar genérico (`kMaxDigit * 100`) que a
/// combinação de 9s já rendia — não o substitui. Decisão do dono do produto:
/// "Somado ao stepScore... junto do placar normal das peças consumidas".
const int kNovaScoreTier1 = 500;
const int kNovaScoreTier2 = 1000;
const int kNovaScoreTier3 = 2000;

/// Bônus de placar da Nova para o [tier] informado (1, 2 ou 3+). Qualquer
/// valor fora de {1, 2, 3} — incluindo 0 ou negativo, que não deveria
/// acontecer — cai silenciosamente no tratamento do tier 3, o mais generoso.
/// O único chamador é interno (`_triggerNova`), onde o tier é sempre 1, 2 ou
/// 3 por construção; não há validação em tempo de execução aqui de propósito.
int novaScoreForTier(int tier) => switch (tier) {
  1 => kNovaScoreTier1,
  2 => kNovaScoreTier2,
  _ => kNovaScoreTier3,
};

/// Moedas por tier da Nova. Não existe hoje nenhuma torneira de moeda ligada
/// a uma fusão em jogo — moeda só vem de estrela nova (`kCoinsPerStar`) ou de
/// anúncio (`kCoinsPerRewardedAd`, ver `economy.dart`) — então estes três
/// valores são uma constante nova, calibrada pela mesma régua: o tier 1 vale
/// uma estrela nova, e o tier 3 (o clímax mais raro do jogo) vale quatro.
/// Pequeno perto do preço de um martelo (`kHammerCoinPrice = 100`), grande o
/// bastante para a recompensa se sentir rara.
const int kNovaCoinsTier1 = 10;
const int kNovaCoinsTier2 = 20;
const int kNovaCoinsTier3 = 40;

/// Moedas da Nova para o [tier] informado. Mesma régua de fallback de
/// [novaScoreForTier].
int novaCoinsForTier(int tier) => switch (tier) {
  1 => kNovaCoinsTier1,
  2 => kNovaCoinsTier2,
  _ => kNovaCoinsTier3,
};

/// Um evento Nova: 3+ peças de valor 9 já existentes no tabuleiro se
/// alinharam e se consumiram, disparando o terceiro clímax do jogo —
/// distinto e independente do Bloco 9 e do Super 9 (ver
/// `docs/superpowers/specs/2026-08-25-evento-nova-design.md`).
class NovaEvent {
  const NovaEvent({
    required this.at,
    required this.tier,
    required this.obstacleHits,
    required this.clearedTiles,
    required this.promoted,
  });

  /// Centro do evento — a mesma posição de sobrevivente que qualquer fusão
  /// normal usaria (`MatchEngine._fusionPosition`).
  final Position at;

  /// 1 (3 peças 9), 2 (4 peças) ou 3 (5+ peças).
  final int tier;

  /// Cobertura destruída no núcleo, mesmo formato de qualquer outro dano de
  /// obstáculo do motor.
  final List<ObstacleHit> obstacleHits;

  /// Peças normais destruídas no núcleo (posições: a peça deixa de existir,
  /// não há id para rastrear).
  final Set<Position> clearedTiles;

  /// Peças promovidas no anel externo: posição -> novo valor.
  final Map<Position, int> promoted;

  @override
  String toString() =>
      'NovaEvent(at: $at, tier: $tier, cleared: ${clearedTiles.length}, '
      'promoted: ${promoted.length})';
}
