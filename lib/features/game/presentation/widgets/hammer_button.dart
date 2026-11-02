import 'package:flutter/material.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/core/theme/nf_tokens.dart';
import 'package:nine_fuse/core/widgets/coins_header_badge.dart';
import 'package:nine_fuse/core/widgets/sprite_icon.dart';
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

/// Diâmetro do slot circular de um booster. Bem acima do alvo mínimo de toque
/// (48dp): é o controle que o polegar procura sem olhar.
const double kHammerButtonSize = 78;

/// Altura da placa do dock. Fixa porque a dica de mira é posicionada pela tela
/// a partir dela (ver [BoosterAimHint]).
const double kBoosterDockHeight = 106;

/// Raio dos cantos da placa do dock.
const double kBoosterDockRadius = 30;

/// Vão entre a placa do dock e a borda inferior da área segura.
const double kBoosterDockBottomGap = 16;

/// Lado do ícone dentro do slot: ~75% do diâmetro, como no design.
const double _kIconSize = 58;

/// Dessatura e apaga o ícone do booster sem estoque.
///
/// Matriz de cor, e não `Opacity`: a suíte usa `Opacity` como marcador de
/// efeitos da peça, e um a mais em qualquer lugar da tela de jogo é o tipo de
/// coisa que quebra um `find` em silêncio. A última linha leva o alfa a 55%.
const ColorFilter _emptyIconFilter = ColorFilter.matrix(<double>[
  0.33, 0.59, 0.08, 0, 0, //
  0.33, 0.59, 0.08, 0, 0, //
  0.33, 0.59, 0.08, 0, 0, //
  0, 0, 0, 0.55, 0, //
]);

/// O slot do Martelo de Fusão dentro do dock: disco com aro de ouro e o
/// estoque em selo no canto.
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
    return _BoosterSlot(
      // O rótulo falado carrega o estoque, que o selo mostra em número: quem
      // ouve a tela precisa saber que o próximo toque pede um anúncio.
      semantics: targeting ? l10n.hammerCancel : l10n.hammerSemantics(count),
      targeting: targeting,
      count: count,
      asset: 'assets/images/ic_hammer.png',
      fallback: Icons.gavel_rounded,
      badgeKey: hammerBadgeKey,
      onPressed: onPressed,
    );
  }
}

/// O slot da Bomba: mesmo disco, mesmo selo e mesma saída em X do Martelo.
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
    return _BoosterSlot(
      semantics: targeting ? l10n.hammerCancel : l10n.bombSemantics(count),
      targeting: targeting,
      count: count,
      asset: 'assets/images/ic_bomb.png',
      fallback: Icons.local_fire_department_rounded,
      badgeKey: bombBadgeKey,
      onPressed: onPressed,
    );
  }
}

/// O slot do Pincel: mesmo disco, mesmo selo e mesma saída em X do Martelo.
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
    return _BoosterSlot(
      semantics: targeting ? l10n.hammerCancel : l10n.brushSemantics(count),
      targeting: targeting,
      count: count,
      asset: 'assets/images/ic_brush.png',
      fallback: Icons.brush_rounded,
      badgeKey: brushBadgeKey,
      onPressed: onPressed,
    );
  }
}

/// O disco de um booster, nos três estados: com estoque, sem estoque e em mira.
///
/// **Com estoque**: gema roxa em aro de ouro — ouro é o que se toca, roxo é o
/// que é mágico. **Sem estoque**: azul apagado, aro neutro e o ícone
/// dessaturado, com o selo verde de `+` no lugar do número. O toque continua
/// funcionando igual (Modo Fantasma: mira primeiro, convite depois — decisão de
/// produto); só o visual avisa que o próximo uso passa pelo convite.
/// **Em mira**: aro e miolo vermelhos com o X, e o selo sai — um estoque
/// pendurado no X diria que o X custa um item.
class _BoosterSlot extends StatelessWidget {
  const _BoosterSlot({
    required this.semantics,
    required this.targeting,
    required this.count,
    required this.asset,
    required this.fallback,
    required this.badgeKey,
    required this.onPressed,
  });

  final String semantics;
  final bool targeting;
  final int count;
  final String asset;
  final IconData fallback;
  final Key badgeKey;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final empty = count <= 0;

    final Gradient core;
    final Color rim;
    final Color base;
    if (targeting) {
      core = const RadialGradient(
        center: Alignment(-0.2, -0.4),
        colors: [Color(0xFF8A1F33), Color(0xFF3A0A18)],
        stops: [0, 0.72],
      );
      rim = NfColors.alert;
      base = const Color(0xFF4A0A14);
    } else if (empty) {
      core = const RadialGradient(
        center: Alignment(-0.2, -0.4),
        colors: [Color(0xFF2A3060), Color(0xFF141838)],
        stops: [0, 0.7],
      );
      rim = const Color(0xFF4A5080);
      base = const Color(0xFF05081C);
    } else {
      core = const RadialGradient(
        center: Alignment(-0.2, -0.4),
        colors: [Color(0xFF4A34A8), Color(0xFF1E1260)],
        stops: [0, 0.72],
      );
      rim = NfColors.goldDeep;
      base = const Color(0xFF4A2A00);
    }

    final Widget icon;
    if (targeting) {
      icon = const Icon(Icons.close_rounded, color: Colors.white, size: 40);
    } else {
      final sprite = SpriteIcon(
        asset: asset,
        fallback: fallback,
        size: _kIconSize,
      );
      icon = empty
          ? ColorFiltered(colorFilter: _emptyIconFilter, child: sprite)
          : sprite;
    }

    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: kHammerButtonSize,
        child: Stack(
          // O selo avança sobre a borda do disco de propósito: dentro dele
          // pareceria um segundo botão.
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: core,
                  border: Border.all(color: rim, width: 3),
                  boxShadow: [
                    // Blur zero: é a espessura do disco, não uma sombra.
                    BoxShadow(color: base, offset: const Offset(0, 6)),
                  ],
                ),
                // O respingo é recortado no círculo: um `InkWell` retangular
                // vazaria pela borda redonda.
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onPressed,
                    customBorder: const CircleBorder(),
                    child: Center(child: icon),
                  ),
                ),
              ),
            ),
            if (!targeting)
              Positioned(
                right: -6,
                bottom: -4,
                child: IgnorePointer(
                  child: empty
                      ? KeyedSubtree(
                          key: badgeKey,
                          child: const PlusSeal(size: 30),
                        )
                      : _CountBadge(key: badgeKey, count: count),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Selo de quantidade: gema roxa com aro de ouro e o número em branco.
class _CountBadge extends StatelessWidget {
  const _CountBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
    padding: const EdgeInsets.symmetric(horizontal: 7),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      gradient: NfDecorations.gemFill,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: NfColors.goldDeep, width: 2.5),
      boxShadow: const [
        BoxShadow(color: NfColors.gemDeep, offset: Offset(0, 2)),
      ],
    ),
    child: Text(
      '$count',
      style: const TextStyle(
        fontFamily: AppFonts.number,
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w800,
        height: 1.1,
      ),
    ),
  );
}

/// O dock de boosters: a prateleira onde os itens do jogador moram.
///
/// **Fica abaixo do tabuleiro, no alcance do polegar.** Antes ele ficava entre
/// o card de métricas e o tabuleiro; com o HUD compactado numa placa só e o
/// tabuleiro em moldura própria, o fundo da tela ficou livre — e é ali que o
/// polegar já está quando o jogador segura o celular com uma mão. Continua
/// **fora** do card de métricas, pela regra de sempre: o card informa, o dock
/// age.
///
/// A dica de mira não mora mais aqui: o véu da mira cobre o dock, e uma pílula
/// desenhada por baixo dele ficava desfocada justamente quando precisa ser
/// lida. Ela é o [BoosterAimHint], que a tela monta **por cima** do véu.
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
  Widget build(BuildContext context) => Container(
    key: boosterDockKey,
    height: kBoosterDockHeight,
    decoration: BoxDecoration(
      color: NfColors.night1.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(kBoosterDockRadius),
      border: Border.all(
        color: const Color(0xFFC98A18).withValues(alpha: 0.35),
        width: 2,
      ),
    ),
    child: FittedBox(
      // Em tela muito estreita os três discos encolhem juntos, em vez de o
      // último ser empurrado para fora da placa.
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrushButton(
              key: brushButtonKey,
              targeting: brushTargeting,
              count: brushCount,
              onPressed: onBrushPressed,
            ),
            const SizedBox(width: 28),
            BombButton(
              key: bombButtonKey,
              targeting: bombTargeting,
              count: bombCount,
              onPressed: onBombPressed,
            ),
            const SizedBox(width: 28),
            HammerButton(
              key: buttonKey,
              targeting: targeting,
              count: count,
              onPressed: onPressed,
            ),
          ],
        ),
      ),
    ),
  );
}

/// A dica de mira, assentada na borda de cima do dock e **acima** do véu.
///
/// Vai como filho direto do `Stack` da tela, depois da camada de mira: o véu
/// escurece e desfoca tudo menos o tabuleiro, e a frase "toque numa célula" é a
/// única coisa da tela que o jogador precisa ler naquele instante. A posição é
/// medida do fundo da área segura, com a mesma folga com que a tela assenta o
/// dock. Ignora toques: quem decide o destino do dedo é a camada de mira.
class BoosterAimHint extends StatelessWidget {
  const BoosterAimHint({super.key});

  @override
  Widget build(BuildContext context) => Positioned(
    left: 16,
    right: 16,
    bottom: kBoosterDockBottomGap + kBoosterDockHeight - 18,
    child: const IgnorePointer(child: Center(child: _AimHintPill())),
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
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: NfColors.night0.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: NfColors.alert.withValues(alpha: 0.7),
        width: 1.5,
      ),
      boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 8)],
    ),
    child: Text(
      AppLocalizations.of(context).hammerAimHint,
      maxLines: 2,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontFamily: AppFonts.number,
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.15,
      ),
    ),
  );
}
