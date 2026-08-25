/// Tempos da encenação de uma jogada.
///
/// Ficam num lugar só porque o notifier (que avança os passos) e a UI (que os
/// desenha) precisam concordar: se divergirem, a animação é cortada no meio ou
/// o tabuleiro fica parado esperando.
///
/// O total por cascata é [cascadeDuration]. Uma jogada com três cascatas leva
/// ~1,1 s — tempo suficiente para o olho acompanhar sem que o jogo pareça
/// lento. Acima disso a espera passa a incomodar quem já entendeu o que houve.
class JuiceTimings {
  const JuiceTimings._();

  /// Resolve a jogada de uma vez, sem encenação nem espera.
  ///
  /// Ligado para a suíte inteira em `test/flutter_test_config.dart`: quase todo
  /// teste verifica **regra de jogo**, e para esses a encenação só acrescenta
  /// assincronia e segundos de espera. Os testes da encenação desligam isto
  /// explicitamente.
  ///
  /// Fica aqui, e não num dos notifiers, porque campanha e Endless dependem do
  /// mesmo ajuste.
  static bool instantResolution = false;

  /// Peças absorvidas encolhendo em direção ao ponto de fusão, e a peça nova
  /// pulando.
  static const Duration fusion = Duration(milliseconds: 240);

  /// Queda das peças e reposição do topo.
  static const Duration settle = Duration(milliseconds: 220);

  static const Duration cascadeDuration = Duration(milliseconds: 460);

  /// Quanto tempo a pontuação flutuante fica visível.
  static const Duration floatingScore = Duration(milliseconds: 900);

  /// Quanto tempo o aviso de combo ou de super fusão fica na tela.
  static const Duration banner = Duration(milliseconds: 1000);

  /// Anel de impacto de uma combinação grande.
  static const Duration impactWave = Duration(milliseconds: 520);

  /// Clarão da explosão do dígito máximo.
  static const Duration explosionFlash = Duration(milliseconds: 420);

  /// Faíscas da explosão. Duram mais que o clarão de propósito: o clarão marca
  /// o impacto, os estilhaços mostram a energia se dissipando depois dele.
  static const Duration explosionParticles = Duration(milliseconds: 700);

  /// Aviso de movimentos ganhos na explosão. É a recompensa mais rara do jogo e
  /// a única que muda o saldo da fase — precisa de tempo para ser lida.
  static const Duration bonusMoves = Duration(milliseconds: 1400);

  /// Hitstop do evento Supernova: o jogo "segura a respiração" antes do
  /// payoff. 250ms, conforme o desenho do clímax do Super 9.
  static const Duration supernovaHitstop = Duration(milliseconds: 250);

  /// Quanto tempo o banner e o véu do Supernova ficam na tela depois do
  /// hitstop.
  static const Duration supernovaPayoff = Duration(milliseconds: 900);
}
