import 'package:flutter/material.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/core/widgets/sprite_icon.dart';
import 'package:nine_fuse/features/game/presentation/widgets/glass_panel.dart';
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

/// Chave do botão da Bomba no HUD da campanha.
const Key bombButtonKey = Key('bomb_button');

/// Chave do botão da Bomba no HUD do Modo Recorde.
const Key endlessBombButtonKey = Key('endless_bomb_button');

/// Chave do badge de quantidade da Bomba.
const Key bombBadgeKey = Key('bomb_badge');

/// Chave do botão do Pincel no HUD da campanha.
const Key brushButtonKey = Key('brush_button');

/// Chave do botão do Pincel no HUD do Modo Recorde.
const Key endlessBrushButtonKey = Key('endless_brush_button');

/// Chave do badge de quantidade do Pincel.
const Key brushBadgeKey = Key('brush_badge');

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
                // Só o martelo tem sprite planejado — o X de cancelar não tem
                // arte própria no checklist de produção.
                asset: targeting ? null : 'assets/images/ic_hammer.png',
                onPressed: onPressed,
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              // Em mira o badge sai: o botão não é mais o martelo, é o cancelar,
              // e um estoque pendurado no X diria que o X custa um martelo.
              child: targeting
                  ? const SizedBox.shrink()
                  : _Badge(key: hammerBadgeKey, count: count),
            ),
          ],
        ),
      ),
    );
  }
}

/// O botão da Bomba: mesmo slot, mesmo badge do Martelo, mesma saída em X
/// durante a mira — a diferença é só a cor (âmbar, não roxo) e a ausência de
/// Modo Fantasma: estoque zero mostra `0`, não `+`, porque não há convite de
/// aquisição atrás do toque.
class BombButton extends StatelessWidget {
  const BombButton({
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
    final color = targeting ? AppColors.digit0 : AppColors.digit4;

    return Semantics(
      button: true,
      label: targeting ? l10n.hammerCancel : l10n.bombSemantics(count),
      excludeSemantics: true,
      child: SizedBox(
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
                icon: targeting
                    ? Icons.close_rounded
                    : Icons.local_fire_department_rounded,
                asset: targeting ? null : 'assets/images/ic_bomb.png',
                onPressed: onPressed,
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: targeting
                  ? const SizedBox.shrink()
                  : _Badge(
                      key: bombBadgeKey,
                      count: count,
                      showPlusWhenEmpty: false,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// O slot em si: vidro fosco tingido pela cor do booster.
///
/// Mesmo material das pílulas do HUD — vidro, não mais o preenchimento em
/// degradê sólido de antes —, e o mesmo **formato** das peças do tabuleiro: um
/// quadrado arredondado do tamanho de uma célula. É o que faz o booster ler
/// como algo que age sobre as peças, e não como um controle de sistema
/// operacional pousado sobre o jogo.
class _Slot extends StatelessWidget {
  const _Slot({
    required this.color,
    required this.icon,
    required this.onPressed,
    this.asset,
  });

  final Color color;
  final IconData icon;
  final VoidCallback onPressed;

  /// Caminho do sprite do booster, ou nulo para os estados sem arte própria
  /// (o X de cancelar da mira).
  final String? asset;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: kHammerButtonSize,
    child: GlassPanel(
      padding: EdgeInsets.zero,
      borderRadius: kBoosterDockRadius,
      tint: color,
      emphasis: true,
      // O respingo é recortado no mesmo raio do slot: um `InkWell` retangular
      // vazaria pelos cantos arredondados.
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(kBoosterDockRadius),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(kBoosterDockRadius),
          child: Center(
            child: asset == null
                ? Icon(icon, color: Colors.white, size: 26)
                : SpriteIcon(asset: asset!, fallback: icon, size: 32),
          ),
        ),
      ),
    ),
  );
}

/// O botão do Pincel: mesmo slot dos outros dois, cor própria (ciano) e sem
/// funil de aquisição — estoque zero mostra `0`, como a Bomba.
class BrushButton extends StatelessWidget {
  const BrushButton({
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
    final color = targeting ? AppColors.digit0 : AppColors.digit7;

    return Semantics(
      button: true,
      label: targeting ? l10n.hammerCancel : l10n.brushSemantics(count),
      excludeSemantics: true,
      child: SizedBox(
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
                icon: targeting ? Icons.close_rounded : Icons.brush_rounded,
                asset: targeting ? null : 'assets/images/ic_brush.png',
                onPressed: onPressed,
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: targeting
                  ? const SizedBox.shrink()
                  : _Badge(
                      key: brushBadgeKey,
                      count: count,
                      showPlusWhenEmpty: false,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Badge de quantidade, ou o convite quando não há nenhum.
///
/// Com estoque zero ele mostra `+`, e não `0`: o botão continua servindo para
/// algo — mirar, e trocar a mira por um anúncio —, então o número que anuncia
/// "não faço nada" mentiria. O `+` é a promessa de que dá para conseguir mais.
class _Badge extends StatelessWidget {
  const _Badge({super.key, required this.count, this.showPlusWhenEmpty = true});

  final int count;

  /// O Martelo mostra `+` no estoque zero — a promessa de que o Modo
  /// Fantasma e o convite de aquisição dão um jeito de conseguir mais. A
  /// Bomba não tem esse funil hoje, e um `+` sem convite nenhum atrás
  /// prometeria algo que o toque não cumpre — por isso ela mostra `0` puro.
  final bool showPlusWhenEmpty;

  @override
  Widget build(BuildContext context) {
    final empty = count <= 0;
    final showPlus = empty && showPlusWhenEmpty;

    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // Verde no convite, escuro no saldo: um badge que muda de papel também
        // muda de cor, senão o `+` parece um `1` estilizado.
        color: showPlus ? AppColors.digit2 : const Color(0xFF17171D),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Text(
        showPlus ? '+' : '$count',
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
    required this.bombTargeting,
    required this.bombCount,
    required this.onBombPressed,
    required this.bombButtonKey,
    required this.brushTargeting,
    required this.brushCount,
    required this.onBrushPressed,
    required this.brushButtonKey,
  });

  final bool targeting;
  final int count;
  final VoidCallback onPressed;

  /// Chave do botão, que difere entre campanha e Endless.
  final Key buttonKey;

  final bool bombTargeting;
  final int bombCount;
  final VoidCallback onBombPressed;

  /// Chave do botão da Bomba, que também difere entre campanha e Endless.
  final Key bombButtonKey;

  final bool brushTargeting;
  final int brushCount;
  final VoidCallback onBrushPressed;

  /// Chave do botão do Pincel, que também difere entre campanha e Endless.
  final Key brushButtonKey;

  @override
  Widget build(BuildContext context) {
    // Um véu de mira suprime os outros: os três boosters miram no mesmo
    // tabuleiro, e mostrar mais de uma dica ao mesmo tempo não pode
    // acontecer — `toggle*Targeting` já se excluem no notifier, então nunca
    // dois `targeting` chegam `true` juntos aqui.
    final anyTargeting = targeting || bombTargeting || brushTargeting;

    return GlassPanel(
      key: boosterDockKey,
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      borderRadius: kBoosterDockRadius + 4,
      child: Row(
        children: [
          // A sobra à esquerda é da dica em mira, e do rótulo fora dela: sem o
          // `Expanded` o texto empurraria os slots para fora da direita em
          // telas estreitas.
          Expanded(
            child: anyTargeting
                ? const Align(
                    alignment: Alignment.center,
                    child: _AimHintPill(),
                  )
                : const _DockLabel(),
          ),
          BrushButton(
            key: brushButtonKey,
            targeting: brushTargeting,
            count: brushCount,
            onPressed: onBrushPressed,
          ),
          const SizedBox(width: 8),
          BombButton(
            key: bombButtonKey,
            targeting: bombTargeting,
            count: bombCount,
            onPressed: onBombPressed,
          ),
          const SizedBox(width: 8),
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
