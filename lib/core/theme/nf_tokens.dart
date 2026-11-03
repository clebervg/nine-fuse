import 'package:flutter/material.dart';

/// Tokens da direção visual "Observatório Real".
///
/// Céu cósmico azul profundo, moldura de ouro e gema roxa — a mesma linguagem
/// do ícone e do tile 9. **Ouro marca o que é tocável e valioso, roxo marca o
/// que é mágico.** Compra com moedas usa o dourado; o verde fica reservado
/// para compra com dinheiro (quando houver billing).
///
/// Widgets novos leem daqui. Hex solto pelo código é como a paleta deriva: o
/// dia em que o ouro mudar de tom, ele muda num lugar só.
class NfColors {
  const NfColors._();

  // Céu, do mais fundo ao mais claro.
  static const Color night0 = Color(0xFF04061A);
  static const Color night1 = Color(0xFF080D2A);
  static const Color night2 = Color(0xFF111C52);
  static const Color night3 = Color(0xFF1B2A6B);

  /// Brilho do centro do céu (topo do gradiente radial do fundo).
  static const Color nightGlow = Color(0xFF2A3A8A);

  // Ouro: o que é tocável e valioso.
  static const Color gold = Color(0xFFFFD84A);
  static const Color goldLight = Color(0xFFFFF0A0);
  static const Color goldPale = Color(0xFFFFE7A0);
  static const Color goldDeep = Color(0xFFE3A41A);
  static const Color goldShadow = Color(0xFF9A5A00);
  static const Color goldText = Color(0xFF5A2E00);
  static const Color bronze = Color(0xFF3D2200);

  // Gema: o que é mágico.
  /// Também é a cor de todo botão de vídeo premiado: o prêmio "aparece" sem
  /// custo de moeda nem de dinheiro, e cada convite usando a cor da sua peça
  /// fazia o mesmo gesto ("assistir") parecer cinco ações diferentes.
  static const Color gem = Color(0xFF9B3FEA);
  static const Color gemDeep = Color(0xFF3A0C7A);
  static const Color gemTitleShadow = Color(0xFF7B2FD6);

  /// Compra com dinheiro real. Sem billing no projeto, ainda não é usado em
  /// botão de compra — fica nomeado para a regra "verde = dinheiro" não ser
  /// quebrada por um sucesso/confirmar qualquer.
  static const Color buyGreen = Color(0xFF2FA84A);

  /// Selo verde de "+" (adquirir mais) nos boosters e na pílula de moedas.
  static const Color plusGreen = Color(0xFF3CCB5A);

  static const Color textSoft = Color(0xFFC9C3EE);
  static const Color textMuted = Color(0xFFB9B2E8);

  /// Contorno escuro dos números com traço (sobre fatia da roleta, placar).
  static const Color numberStroke = Color(0xFF1E0640);

  /// Alerta (jogadas acabando, badge de notificação).
  static const Color alert = Color(0xFFFF4D5E);
}

/// Raios de canto da direção visual.
class NfRadii {
  const NfRadii._();

  static const double sm = 14;
  static const double md = 20;
  static const double lg = 26;
  static const double xl = 30;
}

/// Durações padrão.
class NfDurations {
  const NfDurations._();

  /// Afundar de botão.
  static const Duration press = Duration(milliseconds: 120);

  /// Entrada de modal.
  static const Duration modal = Duration(milliseconds: 320);

  /// Saída de modal: mais curta e sem elástico — sair não é evento.
  static const Duration modalOut = Duration(milliseconds: 180);

  /// Giro da roleta.
  static const Duration wheel = Duration(milliseconds: 4200);
}

/// Superfícies recorrentes, para cada tela não reinventar o próprio painel.
class NfDecorations {
  const NfDecorations._();

  /// O céu de fundo de todas as telas.
  static const Gradient sky = RadialGradient(
    center: Alignment(0, -0.1),
    radius: 1.15,
    colors: [NfColors.nightGlow, NfColors.night2, NfColors.night0],
    stops: [0, 0.45, 1],
  );

  /// Degradê dos botões e cubos dourados.
  static const Gradient goldFill = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [NfColors.goldLight, Color(0xFFFFD033), Color(0xFFF5A600)],
    stops: [0, 0.4, 1],
  );

  /// Gradiente do aro dourado (moldura do tabuleiro, roleta, medalhões).
  static const Gradient goldRim = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFF4B8),
      NfColors.goldDeep,
      Color(0xFF8A5300),
      Color(0xFFF6C54A),
    ],
    stops: [0, 0.3, 0.6, 1],
  );

  /// Gradiente das gemas roxas (fase atual, medalhão de jogadas, selos).
  static const Gradient gemFill = RadialGradient(
    center: Alignment(-0.3, -0.4),
    radius: 0.9,
    colors: [Color(0xFFC77DFF), NfColors.gem, NfColors.gemDeep],
    stops: [0, 0.5, 1],
  );

  /// Painel principal: azul da noite com aro dourado e base 3D bronze.
  static BoxDecoration panel({
    double radius = NfRadii.lg,
    double borderWidth = 2.5,
    bool glow = false,
  }) => BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    gradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [NfColors.night3, Color(0xFF0B1236)],
    ),
    border: Border.all(color: NfColors.goldDeep, width: borderWidth),
    boxShadow: [
      // Blur zero: é a espessura da placa, não uma sombra.
      const BoxShadow(color: NfColors.bronze, offset: Offset(0, 6)),
      const BoxShadow(
        color: Color(0x80000000),
        blurRadius: 30,
        offset: Offset(0, 16),
      ),
      if (glow)
        BoxShadow(color: NfColors.gem.withValues(alpha: 0.35), blurRadius: 50),
    ],
  );

  /// Cartão secundário dentro de um painel: azul mais escuro, borda neutra.
  ///
  /// A borda é branco a 12%, não neon: o que tem cor é o ícone e o rótulo,
  /// para o tabuleiro continuar sendo o elemento de maior destaque.
  static BoxDecoration card({double radius = NfRadii.sm}) => BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    gradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF16205A), Color(0xFF0C1440)],
    ),
    border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.5),
  );
}
