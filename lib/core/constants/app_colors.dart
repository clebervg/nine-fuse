import 'package:flutter/material.dart';

/// Paleta de cores para o NineFuse
/// Cada dígito (0-9) possui uma cor vibrante e bem definida
class AppColors {
  // Cores dos dígitos (0-9)
  //
  // Iguais às dos sprites do pacote de arte (`docs/brand/asset-manifest.json`).
  // A peça vem desenhada no PNG, mas partículas, halo e a vitrine do objetivo
  // continuam pintados por estas constantes — se divergirem, o estilhaço sai
  // numa cor diferente da peça que quebrou.
  static const Color digit0 = Color(0xFFFF3B30); // Vermelho
  static const Color digit1 = Color(0xFF007AFF); // Azul
  static const Color digit2 = Color(0xFF34C759); // Verde
  static const Color digit3 = Color(0xFF00B3A6); // Verde-água
  static const Color digit4 = Color(0xFFFF9500); // Laranja
  static const Color digit5 = Color(0xFFAF52DE); // Roxo
  /// Rosa. A distância do vermelho do `0` é travada em
  /// `palette_distance_test`: o "rosa choque" de uma paleta antiga ficava a
  /// ΔE 32 dele, perto demais para peças de ~44pt comparadas de relance.
  static const Color digit6 = Color(0xFFFF5CA8);
  static const Color digit7 = Color(0xFF5AC8FA); // Azul-céu
  static const Color digit8 = Color(0xFF4B3FD1); // Índigo
  /// Dígito máximo: dourado, não mais branco/prata.
  ///
  /// O prateado dava 1,15:1 de contraste com o número branco — o pior da
  /// paleta — e, sobre o fundo escuro do tabuleiro, a peça mais rara do jogo
  /// lia como um bloco chapado e apagado. O dourado mantém a leitura de
  /// "recompensa lendária" e ainda serve de cor de brilho: neon amarelo em
  /// volta da peça, em qualquer lugar em que ela seja desenhada.
  static const Color digit9 = Color(0xFFFFD700); // Dourado

  /// Ponta escura do degradê da peça 9 — laranja reluzente.
  static const Color digit9Deep = Color(0xFFFF8C00);

  // Cores gerais
  static const Color darkBackground = Color(0xFF121212); // Dark Mode padrão

  /// Dourado da interface: moedas, estrelas, botões de compra, recorde, o
  /// card de jogadas. Token próprio porque já foi `digit3` — quando o 3 deixou
  /// de ser amarelo, toda essa UI mudou de cor junto sem ninguém pedir.
  /// Mesmo tom do `9`, a peça de recompensa.
  static const Color uiGold = digit9;

  /// Fundo da splash nativa e da tela de carregamento: o azul-marinho da arte
  /// do pacote. Tem de bater com `flutter_native_splash.yaml`, senão a troca
  /// de uma para a outra pisca.
  static const Color splashBackground = Color(0xFF080D2A);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkBorder = Color(0xFF404040);

  /// Retorna a cor correspondente ao dígito (0-9)
  static Color getColorByDigit(int digit) {
    switch (digit) {
      case 0:
        return digit0;
      case 1:
        return digit1;
      case 2:
        return digit2;
      case 3:
        return digit3;
      case 4:
        return digit4;
      case 5:
        return digit5;
      case 6:
        return digit6;
      case 7:
        return digit7;
      case 8:
        return digit8;
      case 9:
        return digit9;
      default:
        return Colors.grey; // Fallback
    }
  }

  /// Retorna a cor de texto adequada (branco ou preto) baseado na luminância
  static Color getTextColorForDigit(int digit) {
    final color = getColorByDigit(digit);
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  /// Clareia [color] em [amount] (0 a 1), preservando a matiz.
  static Color lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  /// Escurece [color] em [amount] (0 a 1), preservando a matiz.
  static Color darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  /// Degradê de uma peça: mais clara em cima, mais escura embaixo.
  ///
  /// É o que faz a peça parecer um objeto com volume em vez de um retângulo
  /// pintado — a luz vem de cima, como o olho espera.
  static LinearGradient tileGradient(int digit) {
    // A peça 9 não é uma cor com volume: é um degradê próprio, de dourado a
    // laranja reluzente. É o ápice da fusão e precisa se distinguir de todas
    // as outras à primeira vista, e não só pelo número escrito nela.
    if (digit >= 9) return apexGradient;

    final base = getColorByDigit(digit);
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [lighten(base, 0.10), base, darken(base, 0.07)],
      stops: const [0, 0.55, 1],
    );
  }

  /// Degradê místico do dígito máximo: dourado em cima, laranja reluzente
  /// embaixo. Diagonal, e não vertical como as demais peças — a inclinação é
  /// o que dá a ela ar de metal polido em vez de plástico.
  static const LinearGradient apexGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFE680), digit9, digit9Deep],
    stops: [0, 0.45, 1],
  );

  /// Brilho neon do dígito máximo.
  ///
  /// Fica aqui, e não em cada widget, porque a regra é "em qualquer lugar em
  /// que a peça 9 for desenhada" — tabuleiro, HUD do Endless, selos. Duplicar
  /// a fórmula faria o brilho descolar entre as telas ao primeiro ajuste.
  ///
  /// [spread] é o único parâmetro: no tabuleiro o halo pode passar da célula
  /// (é o clímax do jogo e paga esse preço), num selo de HUD não deve.
  static List<BoxShadow> apexGlow({double scale = 1, double spread = 0}) => [
    BoxShadow(
      color: digit9.withValues(alpha: 0.85),
      blurRadius: 18 * scale,
      spreadRadius: spread,
    ),
    BoxShadow(
      color: digit9Deep.withValues(alpha: 0.45),
      blurRadius: 30 * scale,
      spreadRadius: spread,
    ),
  ];
}
