/// Tipos de peça especial. `wildcard` é reservado para um efeito de fusão
/// futuro (fora de escopo aqui); `superNine` é o Super 9 (ver
/// `MatchEngine`), que converte todo um valor do tabuleiro ao ser trocado
/// com um vizinho elegível.
enum SpecialTileType { wildcard, superNine }

/// Quantas jogadas do jogador uma peça especial sobrevive sem ser usada
/// antes de reverter para uma peça normal do mesmo valor (anti-hoarding).
const int kSpecialTileLifespan = 3;
