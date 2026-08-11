import 'package:flutter/material.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Chave do botão do martelo no HUD da campanha.
const Key hammerButtonKey = Key('hammer_button');

/// Chave do botão do martelo no HUD do Modo Recorde.
///
/// Separada da campanha porque os dois HUDs são telas diferentes, e um teste que
/// procura "o botão" precisa saber em qual delas está olhando.
const Key endlessHammerButtonKey = Key('endless_hammer_button');

/// Chave do badge de quantidade, no canto do botão.
const Key hammerBadgeKey = Key('hammer_badge');

/// Diâmetro do botão. Acima do alvo mínimo de toque das duas plataformas, porque
/// ele é redondo: o canto do quadrado de 44pt não existe aqui.
const double kHammerButtonSize = 54;

/// Botão do Martelo de Fusão: círculo compacto com o estoque no canto.
///
/// **Por que redondo, e fora do card de métricas.** Dentro da moldura das
/// métricas ele lia como um quarto indicador — mais uma coisa a *saber*, quando é
/// a única coisa ali a *fazer*. O círculo é a forma que o resto do HUD não usa:
/// nenhuma métrica, nenhuma pílula e nenhuma barra é redonda, então o olho acha o
/// botão sem procurar rótulo.
///
/// O mesmo botão é a saída: em mira ele vira um X vermelho. Um botão de cancelar
/// em outro canto da tela obrigaria o jogador a procurar como desistir de uma
/// ação que ele começou aqui — e, num tabuleiro em modo de mira, o próximo toque
/// erra caro.
///
/// Serve aos dois modos, porque é o mesmo item: um botão por tela divergiria no
/// primeiro ajuste de rótulo ou de cor.
class HammerButton extends StatelessWidget {
  const HammerButton({
    super.key,
    required this.targeting,
    required this.count,
    required this.onPressed,
  });

  final bool targeting;
  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = targeting ? AppColors.digit0 : AppColors.digit5;

    return Semantics(
      button: true,
      // O rótulo falado carrega o estoque, que o badge mostra em número: quem
      // ouve a tela precisa saber que o próximo toque pede um anúncio.
      label: targeting ? l10n.hammerCancel : l10n.hammerSemantics(count),
      excludeSemantics: true,
      child: SizedBox(
        // A caixa é maior que o círculo para o badge caber sem ser recortado —
        // ele avança sobre a borda de propósito, senão parece um segundo botão.
        width: kHammerButtonSize + 10,
        height: kHammerButtonSize + 10,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 5,
              child: _Disc(
                color: color,
                icon: targeting ? Icons.close_rounded : Icons.gavel_rounded,
                onPressed: onPressed,
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              // Em mira o badge sai: o botão não é mais o martelo, é o cancelar,
              // e um estoque pendurado no X diria que o X custa um martelo.
              child: targeting ? const SizedBox.shrink() : _Badge(count: count),
            ),
          ],
        ),
      ),
    );
  }
}

/// O círculo em si: degradê, aro claro no topo e brilho da própria cor.
///
/// Mesmo material das peças do tabuleiro — um botão chapado num jogo de peças
/// com volume parece um controle de sistema operacional.
class _Disc extends StatelessWidget {
  const _Disc({
    required this.color,
    required this.icon,
    required this.onPressed,
  });

  final Color color;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.lighten(color, 0.22), color],
      ),
      border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 2),
      boxShadow: [
        BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 14),
        const BoxShadow(
          color: Color(0x99000000),
          blurRadius: 8,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: SizedBox.square(
      dimension: kHammerButtonSize,
      // `InkResponse` circular em vez de `InkWell`: o respingo de um retângulo
      // vazaria para fora do disco.
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkResponse(
          onTap: onPressed,
          radius: kHammerButtonSize / 2,
          containedInkWell: true,
          customBorder: const CircleBorder(),
          child: Center(child: Icon(icon, color: Colors.white, size: 26)),
        ),
      ),
    ),
  );
}

/// Badge de quantidade, ou o convite quando não há nenhum.
///
/// Com estoque zero ele mostra `+`, e não `0`: o botão continua servindo para
/// algo — mirar, e trocar a mira por um anúncio —, então o número que anuncia
/// "não faço nada" mentiria. O `+` é a promessa de que dá para conseguir mais.
class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final empty = count <= 0;

    return Container(
      key: hammerBadgeKey,
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // Verde no convite, escuro no saldo: um badge que muda de papel também
        // muda de cor, senão o `+` parece um `1` estilizado.
        color: empty ? AppColors.digit2 : const Color(0xFF17171D),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Text(
        empty ? '+' : '$count',
        style: const TextStyle(
          fontFamily: AppFonts.display,
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

/// A faixa onde o botão mora: fora do card de métricas, alinhada à direita.
///
/// Existe como widget para as duas telas montarem a mesma faixa — e para a dica
/// de mira ter onde aparecer. A dica é escrita porque o modo de mira muda o
/// significado do toque no tabuleiro, e nada no tabuleiro diz isso; o scrim diz
/// "o resto está fora", não "toque numa célula".
class HammerBar extends StatelessWidget {
  const HammerBar({
    super.key,
    required this.targeting,
    required this.count,
    required this.onPressed,
    required this.buttonKey,
  });

  final bool targeting;
  final int count;
  final VoidCallback onPressed;

  /// Chave do botão, que difere entre campanha e Endless.
  final Key buttonKey;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      // A dica ocupa a sobra à esquerda: sem o `Expanded` o texto empurraria o
      // botão para fora da direita em telas estreitas.
      Expanded(
        child: targeting
            ? Text(
                AppLocalizations.of(context).hammerAimHint,
                maxLines: 2,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              )
            : const SizedBox.shrink(),
      ),
      HammerButton(
        key: buttonKey,
        targeting: targeting,
        count: count,
        onPressed: onPressed,
      ),
    ],
  );
}
