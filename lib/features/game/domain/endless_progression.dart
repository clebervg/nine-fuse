import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';

/// Como a janela de sorteio sobe ao longo de uma partida Endless.
///
/// Existe porque a simulação (`tool/simulate_economy.dart`) mostrou que uma
/// janela fixa em 0-3 **sempre** trava: peças de valor médio ficam sem parceiro
/// e assoreiam o tabuleiro até não haver mais troca possível — 10 partidas de
/// 10, em ~274 movimentos. Subir a janela é o que aproxima o jogador da única
/// saída definitiva, a explosão do dígito máximo.
///
/// A janela sobe quando o jogador cria uma peça **dois níveis acima** do topo
/// da janela atual: é a prova de que ele domina a faixa em que está. Assim o
/// ritmo é ditado por habilidade, não por tempo de jogo.
class EndlessProgression {
  const EndlessProgression();

  /// Degrau inicial.
  static const int firstStep = 0;

  /// Último degrau. A janela para em 3-6 de propósito: com o topo em 7 ou mais,
  /// dígitos máximos cairiam prontos do sorteio e explodiriam sozinhos, sem
  /// mérito nenhum do jogador.
  static const int lastStep = 3;

  int spawnMinFor(int step) => step.clamp(firstStep, lastStep);

  int spawnMaxFor(int step) => spawnMinFor(step) + 3;

  /// As coberturas que o degrau [step] acrescenta ao tabuleiro.
  ///
  /// O primeiro degrau é limpo de propósito: o jogador entra no Endless para
  /// bater recorde, e a pressão do modo já vem da janela que sobe. O obstáculo
  /// é o que passa a ocupar o tabuleiro quando ele **prova** que domina a
  /// faixa — mesma lógica da promoção, aplicada ao espaço em vez do sorteio.
  ///
  /// A pedra fica para o último degrau porque a saída dela é a onda de choque
  /// do dígito máximo, e só ali ele é alcançável de fato.
  ObstacleLayout obstaclesFor(int step) =>
      switch (step.clamp(firstStep, lastStep)) {
        1 => const ObstacleLayout(ice: 2),
        2 => const ObstacleLayout(ice: 2, glass: 1),
        3 => const ObstacleLayout(ice: 1, glass: 2, stone: 1),
        _ => ObstacleLayout.none,
      };

  /// O dígito que promove o jogador do degrau [step] para o seguinte.
  int promotionDigitFor(int step) => spawnMaxFor(step) + 2;

  /// O degrau depois de criar os dígitos [produced], estando em [step].
  ///
  /// Sobe no máximo um degrau por movimento, mesmo que uma cascata gigante
  /// produza vários dígitos altos de uma vez — subir dois de uma vez cortaria
  /// o fornecimento das peças que alimentam o tabuleiro.
  int advance({required int step, required Iterable<int> produced}) {
    if (step >= lastStep) return lastStep;

    final promotion = promotionDigitFor(step);
    return produced.any((digit) => digit >= promotion) ? step + 1 : step;
  }
}

/// O dígito máximo continua sendo o teto da escala.
const int kEndlessTopDigit = kMaxDigit;
