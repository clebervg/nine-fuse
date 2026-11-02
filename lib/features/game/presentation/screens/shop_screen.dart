import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/core/theme/nf_tokens.dart';
import 'package:nine_fuse/core/widgets/coins_header_badge.dart';
import 'package:nine_fuse/core/widgets/nf_back_button.dart';
import 'package:nine_fuse/core/widgets/nf_background.dart';
import 'package:nine_fuse/core/widgets/nf_text.dart';
import 'package:nine_fuse/core/widgets/sprite_icon.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/presentation/widgets/coin_sources_card.dart';
import 'package:nine_fuse/features/game/presentation/widgets/game_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_offer_dialog.dart'
    show coinAdProvider;
import 'package:nine_fuse/features/game/providers/wallet.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Chave da tela da Loja.
const Key shopScreenKey = Key('shop_screen');

/// Chave do botão de compra de cada booster na Loja.
Key shopBuyKey(BoosterKind kind) => Key('shop_buy_${kind.name}');

/// Chave do estoque de cada booster na Loja.
Key shopStockKey(BoosterKind kind) => Key('shop_stock_${kind.name}');

/// Chave do botão do vídeo que paga moedas, na Loja.
const Key shopWatchKey = Key('shop_watch');

/// Abre a Loja por cima da tela atual.
///
/// Só é chamada de fora de uma partida (menu e mapa): ver
/// [CoinsHeaderBadge.onAdd] para o porquê.
Future<void> openShop(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const ShopScreen()));

/// A Loja ("06 Loja" do Observatório Real), só com o que se paga em moeda.
///
/// **Sem o "Baú Real" e sem pacotes em dinheiro do design**: não há compra
/// in-app no projeto, e um botão com preço em reais que não faz nada é pior do
/// que a ausência dele. A seção de moedas mostra a única torneira acionável
/// daqui — o vídeo premiado — e a lista das outras (sem valores, pelo motivo
/// registrado no [CoinSourcesCard]).
///
/// Os preços são os do código (`kHammerCoinPrice`...), não os do design.
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  /// Um booster sendo comprado. Trava os três botões: a carteira já encadeia
  /// as compras, mas um botão que aceita o segundo toque antes de o primeiro
  /// responder parece não ter registrado o primeiro.
  BoosterKind? _buying;

  /// A última compra falhou no disco (moedas devolvidas).
  bool _buyFailed = false;

  /// O vídeo está no ar: dois toques pagariam dois prêmios por uma exibição.
  bool _watching = false;
  bool _adFailed = false;
  bool _adEarned = false;

  @override
  void initState() {
    super.initState();
    // O estoque espelhado pode estar velho: uma partida grava o dela direto
    // no disco.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(walletProvider.notifier).refresh();
    });
  }

  Future<void> _buy(BoosterKind kind) async {
    if (_buying != null) return;
    setState(() {
      _buying = kind;
      _buyFailed = false;
    });
    final wallet = ref.read(walletProvider);
    final bought = await ref.read(walletProvider.notifier).buyBooster(kind);
    if (!mounted) return;
    setState(() {
      _buying = null;
      // Recusa por falta de saldo não é falha: o botão já estava apagado, e
      // só um saldo mudado por fora chega aqui. Falha é ter saldo e não levar.
      _buyFailed = !bought && wallet.canAfford(kind.coinPrice);
    });
  }

  Future<void> _watchVideo() async {
    if (_watching) return;
    setState(() {
      _watching = true;
      _adFailed = false;
      _adEarned = false;
    });
    final granted = await ref.read(coinAdProvider)();
    if (!mounted) return;
    // `creditCoins` já persiste: o saldo sobrevive a fechar o jogo.
    if (granted) {
      ref.read(walletProvider.notifier).creditCoins(kCoinsPerRewardedAd);
    }
    setState(() {
      _watching = false;
      _adFailed = !granted;
      _adEarned = granted;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wallet = ref.watch(walletProvider);

    return NfBackground(
      child: Scaffold(
        key: shopScreenKey,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          leadingWidth: kNfBackButtonLeadingWidth,
          leading: const NfBackButton(),
          centerTitle: true,
          title: NfText.title(l10n.shopTitle, size: 30),
          // Sem o `+`: aqui ele só reabriria esta mesma tela.
          actions: const [
            CoinsHeaderBadge(showAdd: false),
            SizedBox(width: 14),
          ],
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              // Num tablet, três cartões esticados ficariam com o preço
              // perdido no meio de um painel vazio.
              constraints: const BoxConstraints(maxWidth: 460),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionLabel(l10n.shopBoosters),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final kind in BoosterKind.values) ...[
                          if (kind != BoosterKind.values.first)
                            const SizedBox(width: 10),
                          Expanded(
                            child: _BoosterCard(
                              kind: kind,
                              stock: wallet.stockOf(kind),
                              onBuy:
                                  _buying == null &&
                                      wallet.canAfford(kind.coinPrice)
                                  ? () => _buy(kind)
                                  : null,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (_buyFailed) ...[
                      const SizedBox(height: 10),
                      _Notice(l10n.shopBuyFailed, color: AppColors.digit0),
                    ],
                    const SizedBox(height: 26),
                    _SectionLabel(l10n.shopCoins),
                    const SizedBox(height: 10),
                    _VideoOffer(onWatch: _watching ? null : _watchVideo),
                    if (_adFailed) ...[
                      const SizedBox(height: 8),
                      _Notice(l10n.hammerOfferFailed, color: AppColors.digit0),
                    ],
                    if (_adEarned) ...[
                      const SizedBox(height: 8),
                      _Notice(
                        l10n.hammerOfferEarnedCoins(kCoinsPerRewardedAd),
                        color: AppColors.digit2,
                      ),
                    ],
                    const SizedBox(height: 14),
                    const CoinSourcesCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rótulo de seção ("BOOSTERS", "MOEDAS"): pequeno, espaçado, lilás apagado.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 6),
    child: NfText.label(
      text,
      color: NfColors.textMuted,
      textAlign: TextAlign.start,
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: TextStyle(
      fontFamily: AppFonts.display,
      fontWeight: FontWeight.w700,
      color: color,
      fontSize: 13,
    ),
  );
}

/// Placa azul-noite com aro de ouro esmaecido e a base 3D das peças.
BoxDecoration _plate({double rimAlpha = 0.6}) => BoxDecoration(
  borderRadius: BorderRadius.circular(22),
  gradient: const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [NfColors.night3, Color(0xFF0E1640)],
  ),
  border: Border.all(
    color: const Color(0xFFC98A18).withValues(alpha: rimAlpha),
    width: 2,
  ),
  boxShadow: const [
    // Blur zero: é a espessura da placa, não uma sombra.
    BoxShadow(color: Color(0xFF05081C), offset: Offset(0, 5)),
  ],
);

/// Um booster à venda: arte, nome, quanto o jogador já tem e o preço.
///
/// O estoque está no cartão porque é ele que decide a compra — "tenho 4
/// martelos" e "não tenho nenhum" pedem decisões diferentes diante do mesmo
/// preço.
class _BoosterCard extends StatelessWidget {
  const _BoosterCard({
    required this.kind,
    required this.stock,
    required this.onBuy,
  });

  final BoosterKind kind;
  final int stock;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (name, asset, icon) = switch (kind) {
      BoosterKind.hammer => (
        l10n.levelStartShopHammer,
        'assets/images/ic_hammer.png',
        Icons.gavel_rounded,
      ),
      BoosterKind.bomb => (
        l10n.levelStartShopBomb,
        'assets/images/ic_bomb.png',
        Icons.gps_fixed_rounded,
      ),
      BoosterKind.brush => (
        l10n.levelStartShopBrush,
        'assets/images/ic_brush.png',
        Icons.brush_rounded,
      ),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
      decoration: _plate(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SpriteIcon(
            asset: asset,
            fallback: icon,
            size: 58,
            color: Colors.white70,
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppFonts.number,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              height: 1,
              color: Color(0xFFE9E3FF),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.shopStock(stock),
            key: shopStockKey(kind),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppFonts.number,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              height: 1,
              color: NfColors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          // Ouro, como todo preço em moeda; sem saldo o `GameButton` cai
          // sozinho no azul apagado — o botão não promete uma compra que não
          // vem.
          GameButton(
            key: shopBuyKey(kind),
            label: '${kind.coinPrice}',
            color: AppColors.uiGold,
            fontSize: 17,
            leading: Image.asset(
              'assets/images/ic_coin.png',
              width: 20,
              height: 20,
              errorBuilder: (_, _, _) => const SizedBox(width: 20),
            ),
            onPressed: onBuy,
          ),
        ],
      ),
    );
  }
}

/// O vídeo premiado, no lugar dos pacotes de moeda por dinheiro do design.
///
/// Verde, como os botões "de adquirir" do jogo (o `+` da pílula): é a ação que
/// traz moeda, não a que gasta.
class _VideoOffer extends StatelessWidget {
  const _VideoOffer({required this.onWatch});

  final VoidCallback? onWatch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: _plate(rimAlpha: 1),
      child: Row(
        children: [
          Image.asset(
            'assets/images/ic_coin.png',
            width: 40,
            height: 40,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.monetization_on, color: NfColors.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Encolhe em vez de cortar: "+25 moe..." esconderia justamente
                // quanto o vídeo paga.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: NfText.title(
                    l10n.shopVideoTitle(kCoinsPerRewardedAd),
                    size: 22,
                    shadows: false,
                    textAlign: TextAlign.start,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.shopVideoSubtitle,
                  maxLines: 2,
                  style: const TextStyle(
                    fontFamily: AppFonts.display,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: NfColors.textSoft,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GameButton(
            key: shopWatchKey,
            label: l10n.shopWatch,
            color: NfColors.gem,
            foreground: Colors.white,
            icon: Icons.ondemand_video_rounded,
            fontSize: 15,
            expand: false,
            onPressed: onWatch,
          ),
        ],
      ),
    );
  }
}
