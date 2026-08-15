import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
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
  const CoinsHeaderBadge({super.key, this.hammers});

  /// Estoque de martelos a exibir ao lado das moedas, ou nulo para omitir.
  final int? hammers;

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
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        padding: const EdgeInsets.only(left: 10, right: 4),
        decoration: BoxDecoration(
          color: const Color(0xE60E0E13),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: AppColors.digit3.withValues(alpha: 0.45),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Amount(emoji: '🪙', value: coins),
            if (hammers case final count?) ...[
              const _Divider(),
              _Amount(emoji: '🔨', value: count),
            ],
            const SizedBox(width: 6),
            _AddButton(onPressed: () => showCoinStore(context)),
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

/// Um valor da pílula: emoji e número.
class _Amount extends StatelessWidget {
  const _Amount({required this.emoji, required this.value});

  final String emoji;
  final int value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(emoji, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 5),
      Text(
        '$value',
        style: const TextStyle(
          fontFamily: AppFonts.display,
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    ],
  );
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 14,
    margin: const EdgeInsets.symmetric(horizontal: 8),
    color: Colors.white.withValues(alpha: 0.18),
  );
}

/// O `+`: discreto de propósito.
///
/// Ele divide a pílula com um número que o jogador vem ler; um botão chamativo
/// ali transformaria um indicador em anúncio, e o indicador é o que justifica a
/// pílula existir em todas as telas.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    shape: const CircleBorder(),
    child: InkResponse(
      key: coinsHeaderAddKey,
      onTap: onPressed,
      radius: 16,
      containedInkWell: true,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.digit3,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.add_rounded, size: 14, color: Colors.black),
        ),
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
          accent: AppColors.digit3,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🪙', style: TextStyle(fontSize: 40)),
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
                color: AppColors.digit3,
                foreground: Colors.black,
                icon: Icons.ondemand_video_rounded,
                onPressed: _earnCoins,
              ),
              if (_earned) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.hammerOfferEarnedCoins(kCoinsPerRewardedAd),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.digit2,
                    fontSize: 12,
                  ),
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
