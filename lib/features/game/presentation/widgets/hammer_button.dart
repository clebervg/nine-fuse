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

/// Chave do dock de boosters.
const Key boosterDockKey = Key('booster_dock');

/// Chave da pílula com a dica de mira.
const Key hammerAimHintKey = Key('hammer_aim_hint');

/// Lado do slot do booster dentro do dock. Acima do alvo mínimo de toque das
/// duas plataformas.
const double kHammerButtonSize = 54;

/// Raio dos cantos do slot e do próprio dock.
const double kBoosterDockRadius = 18;

/// O slot do Martelo de Fusão dentro do dock: quadrado arredondado com o
/// estoque em badge no canto.
///
/// **Era um disco roxo flutuando solto sobre o fundo da tela**, e o problema
/// não era a cor: um controle sem chão não pertence a lugar nenhum da
/// interface, então o olho o lia como sobreposição do sistema — algo que caiu
/// por cima do jogo — em vez de como parte do equipamento do jogador. Dentro do
/// dock ele passa a ser um item guardado numa prateleira, que é exatamente o
/// que um booster é, e ganha vizinhos: o dia em que houver um segundo booster,
/// ele entra ao lado sem redesenhar nada.
///
/// O mesmo slot é a saída: em mira ele vira um X vermelho. Um botão de cancelar
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
        // A caixa é maior que o slot para o badge caber sem ser recortado — ele
        // avança sobre a borda de propósito, senão parece um segundo botão.
        width: kHammerButtonSize + 10,
        height: kHammerButtonSize + 10,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 5,
              child: _Slot(
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

/// O slot em si: degradê, aro claro no topo e brilho da própria cor.
///
/// Mesmo material — e agora o mesmo **formato** — das peças do tabuleiro: um
/// quadrado arredondado do tamanho de uma célula. É o que faz o booster ler
/// como algo que age sobre as peças, e não como um controle de sistema
/// operacional pousado sobre o jogo.
class _Slot extends StatelessWidget {
  const _Slot({
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
      borderRadius: BorderRadius.circular(kBoosterDockRadius),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.lighten(color, 0.22), color],
      ),
      border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 2),
      boxShadow: [
        // O halo encolheu junto com a mudança de casa: dentro do dock o slot
        // já tem contraste contra a barra, e o brilho que antes o separava do
        // fundo da tela agora só sangraria para fora da prateleira.
        BoxShadow(color: color.withValues(alpha: 0.40), blurRadius: 10),
        const BoxShadow(
          color: Color(0x99000000),
          blurRadius: 8,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: SizedBox.square(
      dimension: kHammerButtonSize,
      // O respingo é recortado no mesmo raio do slot: um `InkWell` retangular
      // vazaria pelos cantos arredondados.
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(kBoosterDockRadius),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(kBoosterDockRadius),
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

/// O dock de boosters: a prateleira onde os itens do jogador moram.
///
/// Fica **entre** o card de métricas e o tabuleiro, e fora dos dois: o card
/// informa, o dock age. Dentro da moldura das métricas o booster lia como uma
/// quarta métrica — mais uma coisa a *saber*, quando é a única coisa ali a
/// *fazer* —, e solto sobre o fundo lia como sobreposição de sistema. A barra
/// com cantos arredondados e chão próprio é o que o faz pertencer ao jogo.
///
/// Também é onde a dica de mira cabe. O véu diz "o resto da tela está fora";
/// ele não diz "toque numa célula". Sem a frase, o modo de mira mudava o
/// significado do toque no tabuleiro sem nada na tela dizer isso.
///
/// **A dica é uma pílula, e não texto solto.** Ela nasce exatamente quando o véu
/// escurece o fundo: um cinza sobre preto desfocado é a única coisa da tela que o
/// jogador *precisa* ler naquele instante e a que menos se destaca. A pílula lhe
/// dá fundo próprio, então a legibilidade não depende do que ficou atrás.
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
  Widget build(BuildContext context) => Container(
    key: boosterDockKey,
    padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(kBoosterDockRadius + 4),
      // Um degrau mais escuro que o card de métricas: a prateleira fica atrás
      // do que ela guarda, senão disputa com o próprio item.
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF20202A), Color(0xFF141419)],
      ),
      border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x99000000),
          blurRadius: 12,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Row(
      children: [
        // A sobra à esquerda é da dica em mira, e do rótulo fora dela: sem o
        // `Expanded` o texto empurraria o slot para fora da direita em telas
        // estreitas.
        Expanded(
          child: targeting
              ? const Align(alignment: Alignment.center, child: _AimHintPill())
              : const _DockLabel(),
        ),
        HammerButton(
          key: buttonKey,
          targeting: targeting,
          count: count,
          onPressed: onPressed,
        ),
      ],
    ),
  );
}

/// O que a prateleira é, dito uma vez e em voz baixa.
///
/// Um dock com um item só e nenhuma legenda pode ser lido como um botão avulso
/// com moldura — que é justamente o que ele deixou de ser. O rótulo é discreto
/// porque não é informação de jogo: ele nomeia a área, e sai de cena assim que
/// a mira começa e a dica assume o espaço.
class _DockLabel extends StatelessWidget {
  const _DockLabel();

  @override
  Widget build(BuildContext context) => Text(
    AppLocalizations.of(context).boostersLabel.toUpperCase(),
    style: TextStyle(
      color: Colors.white.withValues(alpha: 0.45),
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
    ),
  );
}

/// A dica de mira, com fundo próprio.
///
/// Branco puro sobre pílula escura de borda acesa: as duas coisas juntas, porque
/// nenhuma sozinha resolve — texto branco continuaria disputando com os dígitos
/// coloridos que passam atrás, e a pílula sem contraste de texto só mudaria de
/// cinza. Nada de `Opacity` aqui: a suíte usa esse tipo como marcador de outros
/// efeitos dentro da peça, e a translucidez sai de cores com alfa.
class _AimHintPill extends StatelessWidget {
  const _AimHintPill();

  @override
  Widget build(BuildContext context) => Container(
    key: hammerAimHintKey,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xE60E0E13),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: AppColors.digit0.withValues(alpha: 0.55),
        width: 1.5,
      ),
      boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 8)],
    ),
    child: Text(
      AppLocalizations.of(context).hammerAimHint,
      maxLines: 2,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
