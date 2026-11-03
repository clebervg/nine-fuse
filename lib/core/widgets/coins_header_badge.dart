import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/core/theme/nf_tokens.dart';
import 'package:nine_fuse/core/widgets/sprite_icon.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/presentation/widgets/game_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_offer_dialog.dart';
import 'package:nine_fuse/features/game/providers/wallet.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Chave da pílula de saldo do header.
const Key coinsHeaderBadgeKey = Key('coins_header_badge');

/// Chave do `+` que abre a loja de moedas.
const Key coinsHeaderAddKey = Key('coins_header_add');

/// Chave do cartão da loja de moedas.
const Key coinStoreKey = Key('coin_store');

/// Chave do botão que assiste a um vídeo por moedas, dentro da loja.
const Key coinStoreWatchKey = Key('coin_store_watch');

/// Chave do botão que fecha a loja.
const Key coinStoreCloseKey = Key('coin_store_close');

/// Ouro escuro do aro das pílulas e do botão voltar do topo.
const Color _rimGold = Color(0xFFC98A18);

/// Pílula de saldo do jogador, para o header de qualquer tela.
///
/// **Por que em todas as telas.** O saldo só aparecia dentro do convite do
/// martelo — ou seja, o jogador descobria quanto tinha no instante em que
/// precisava gastar, tarde demais para a moeda influenciar qualquer decisão.
/// Um recurso que não é visível não é um recurso: é uma surpresa.
///
/// **Zero é mostrado, não escondido.** Uma pílula que some com saldo zero
/// esconde justamente o estado em que o `+` importa — e ensina o jogador que a
/// moeda é um detalhe que aparece de vez em quando.
///
/// O segmento do martelo é opcional ([hammers]) porque dentro de uma partida a
/// autoridade do estoque é o `GameState`, relido a cada `startLevel`; o espelho
/// da carteira serve às telas que vivem **fora** de uma partida. Mostrar o
/// espelho durante a fase arriscaria dois números diferentes do mesmo item na
/// mesma tela — o do HUD e o do header.
class CoinsHeaderBadge extends ConsumerWidget {
  const CoinsHeaderBadge({
    super.key,
    this.hammers,
    this.onAdd,
    this.showAdd = true,
  });

  /// Estoque de martelos a exibir ao lado das moedas, ou nulo para omitir.
  final int? hammers;

  /// O que o `+` abre. Nulo abre a caixa de moedas ([showCoinStore]).
  ///
  /// Fora de uma partida (menu e mapa) quem chama passa a tela da Loja; dentro
  /// dela (fase, Endless) fica a caixa, porque a Loja vende booster gravando
  /// no disco, e o estoque da partida viva é o do `GameState`, que não relê o
  /// disco até o próximo `startLevel`.
  final VoidCallback? onAdd;

  /// Sem o `+`: na própria Loja ele só reabriria a tela em que o jogador está.
  final bool showAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final coins = ref.watch(walletProvider.select((w) => w.coins));

    return Semantics(
      label: hammers == null
          ? l10n.coinsBadgeSemantics(coins)
          : '${l10n.coinsBadgeSemantics(coins)}, '
                '${l10n.hammersBadgeSemantics(hammers!)}',
      excludeSemantics: true,
      child: Container(
        key: coinsHeaderBadgeKey,
        height: 42,
        margin: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        // Mesmo navy de fundo das placas e o aro de ouro escuro do botão
        // voltar: a pílula é parte do equipamento do topo, não uma etiqueta
        // de sistema colada na barra.
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF111A4A), Color(0xFF0A1033)],
          ),
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: _rimGold, width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0x73000000), offset: Offset(0, 3)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Amount(glyph: const _CoinGlyph(size: 28), value: coins),
            if (hammers case final count?) ...[
              const _Divider(),
              _Amount(
                glyph: const SpriteIcon(
                  asset: 'assets/images/ic_hammer.png',
                  fallback: Icons.gavel_rounded,
                  size: 24,
                ),
                value: count,
              ),
            ],
            if (showAdd) ...[
              const SizedBox(width: 8),
              _AddButton(onPressed: onAdd ?? () => showCoinStore(context)),
            ] else
              const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }
}

/// Abre a loja de moedas por cima da tela atual.
///
/// É `showDialog` — e não uma camada do `Stack`, como o resto das caixas do
/// jogo — porque este ponto de entrada nasce na `AppBar` de **quatro** telas
/// diferentes: pedir a cada uma que hospede a camada e guarde o estado de
/// aberto/fechado espalharia a mesma máquina por todas elas. Aqui não há
/// tabuleiro a tirar da árvore de foco: a caixa é informativa e o jogo por
/// baixo está parado.
Future<void> showCoinStore(BuildContext context) => showDialog<void>(
  context: context,
  barrierColor: const Color(0xCC000000),
  builder: (_) => const _CoinStoreDialog(),
);

/// Um valor da pílula: glifo (emoji ou ícone) e número.
class _Amount extends StatelessWidget {
  const _Amount({required this.glyph, required this.value});

  final Widget glyph;
  final int value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      glyph,
      const SizedBox(width: 6),
      Padding(
        padding: const EdgeInsets.only(right: 2),
        child: Text(
          '$value',
          style: const TextStyle(
            fontFamily: AppFonts.number,
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    ],
  );
}

/// Glifo da moeda: o ícone em imagem, quando existir, com o emoji atual como
/// fallback.
///
/// `assets/images/` já é uma pasta inteira declarada no `pubspec.yaml`, então
/// não há nada a registrar ali para este asset entrar em vigor — só precisa
/// existir no disco. Até lá, `Image.asset` falha ao carregar e o
/// `errorBuilder` cai de volta no emoji, sem propagar erro para a tela.
class _CoinGlyph extends StatelessWidget {
  const _CoinGlyph({this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/images/ic_coin.png',
    width: size,
    height: size,
    errorBuilder: (context, error, stackTrace) =>
        Text('🪙', style: TextStyle(fontSize: size * 0.85)),
  );
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 20,
    margin: const EdgeInsets.symmetric(horizontal: 8),
    color: Colors.white.withValues(alpha: 0.18),
  );
}

/// O `+`: o selo verde de "adquirir mais", o mesmo dos boosters sem estoque.
///
/// Verde, e não ouro, porque é o sinal que o jogo inteiro usa para "dá para
/// conseguir mais"; o ouro da pílula já diz "isto é valioso". O toque cobre o
/// selo com folga: um círculo de 28pt sozinho fica abaixo do alvo mínimo.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: coinsHeaderAddKey,
    behavior: HitTestBehavior.opaque,
    onTap: onPressed,
    child: const PlusSeal(size: 28),
  );
}

/// Selo verde de `+`: degradê, base 3D e o sinal em Baloo 2.
///
/// Público porque é o mesmo selo no dock de boosters sem estoque — duas cópias
/// divergiriam no primeiro ajuste de tom, e o jogador leria dois convites
/// diferentes para a mesma ação.
class PlusSeal extends StatelessWidget {
  const PlusSeal({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF9BF07A), NfColors.buyGreen],
      ),
      boxShadow: [BoxShadow(color: Color(0xFF176B2B), offset: Offset(0, 2))],
    ),
    child: Text(
      '+',
      style: TextStyle(
        fontFamily: AppFonts.number,
        fontWeight: FontWeight.w800,
        fontSize: size * 0.78,
        color: Colors.white,
        height: 1.05,
        shadows: const [Shadow(color: Color(0xFF176B2B), offset: Offset(0, 1))],
      ),
    ),
  );
}

/// A loja de moedas: saldo, um vídeo que paga, e de onde mais vem moeda.
///
/// Não vende nada além do próprio vídeo, e isso é deliberado: pacotes de moeda
/// por dinheiro real dependem de compra in-app, que o projeto ainda não tem. O
/// que a caixa entrega hoje é a resposta à pergunta que o `+` provoca — "como
/// eu consigo mais?".
class _CoinStoreDialog extends ConsumerStatefulWidget {
  const _CoinStoreDialog();

  @override
  ConsumerState<_CoinStoreDialog> createState() => _CoinStoreDialogState();
}

class _CoinStoreDialogState extends ConsumerState<_CoinStoreDialog> {
  /// O anúncio está no ar. Trava o botão: dois toques pagariam dois prêmios
  /// por uma exibição só.
  bool _waiting = false;

  /// O anúncio não veio. Dito aqui dentro, e não num `SnackBar`: o jogador está
  /// olhando para cá, e a resposta pertence à pergunta que ele fez.
  bool _failed = false;

  /// Assistiu e recebeu. Some no toque seguinte.
  bool _earned = false;

  Future<void> _earnCoins() async {
    if (_waiting) return;
    setState(() {
      _waiting = true;
      _failed = false;
      _earned = false;
    });

    final granted = await ref.read(coinAdProvider)();
    if (!mounted) return;

    // `creditCoins` já persiste: o saldo sobrevive a fechar o jogo.
    if (granted) {
      ref.read(walletProvider.notifier).creditCoins(kCoinsPerRewardedAd);
    }

    setState(() {
      _waiting = false;
      _failed = !granted;
      _earned = granted;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Observado, e não lido: o crédito do vídeo tem de aparecer no saldo desta
    // caixa no mesmo quadro — é o que faz o botão parecer ter funcionado.
    final coins = ref.watch(walletProvider.select((w) => w.coins));

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: GameDialog(
          cardKey: coinStoreKey,
          title: l10n.coinStoreTitle,
          accent: AppColors.uiGold,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // O mesmo asset da pílula do header, e não o emoji: a loja é a
              // tela em que o jogador olha mais de perto para a moeda, e um
              // glifo diferente ali leria como uma moeda diferente.
              const SizedBox(
                width: 40,
                height: 40,
                child: _CoinGlyph(size: 40),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.hammerOfferBalance(coins),
                style: const TextStyle(color: Colors.white, fontSize: 17),
              ),
              if (_failed) ...[
                const SizedBox(height: 10),
                Text(
                  l10n.hammerOfferFailed,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.digit0, fontSize: 13),
                ),
              ],
              const SizedBox(height: 16),
              GameButton(
                key: coinStoreWatchKey,
                label: l10n.hammerOfferEarnCoins(kCoinsPerRewardedAd),
                color: AppColors.uiGold,
                foreground: Colors.black,
                icon: Icons.ondemand_video_rounded,
                onPressed: _earnCoins,
              ),
              if (_earned) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.hammerOfferEarnedCoins(kCoinsPerRewardedAd),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.digit2, fontSize: 12),
                ),
              ],
              const SizedBox(height: 14),
              const CoinSourcesCard(),
              const SizedBox(height: 10),
              GameButton(
                key: coinStoreCloseKey,
                label: l10n.coinStoreClose,
                color: AppColors.darkSurface,
                foreground: Colors.white70,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
