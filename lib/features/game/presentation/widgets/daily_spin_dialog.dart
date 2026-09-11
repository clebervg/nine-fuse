import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/notifications/local_notifications_port.dart';
import 'package:nine_fuse/core/notifications/notification_port.dart';
import 'package:nine_fuse/core/notifications/notification_service.dart';
import 'package:nine_fuse/features/game/domain/daily_spin.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import 'package:nine_fuse/features/game/providers/wallet.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Chave da caixa da roleta diária.
const Key dailySpinKey = Key('daily_spin');

/// Chave do botão de girar.
const Key dailySpinSpinButtonKey = Key('daily_spin_spin_button');

/// Chave do botão de girar de novo assistindo a um vídeo.
const Key dailySpinWatchAgainButtonKey = Key('daily_spin_watch_again_button');

/// Chave do botão de fechar.
const Key dailySpinCloseButtonKey = Key('daily_spin_close_button');

/// De onde vem o `GameStorage` usado pela roleta diária.
///
/// Provider próprio (e não uma instância direta) para o teste poder trocar
/// por `InMemoryGameStorage` sem tocar disco — mesmo padrão de
/// `rewardedAdPortProvider`.
final dailySpinStorageProvider = Provider<GameStorage>(
  (ref) => const PrefsGameStorage(),
);

/// De onde vem a porta de notificações locais. Real por padrão; o teste troca
/// por uma porta fake.
final notificationPortProvider = Provider<NotificationPort>(
  (ref) => LocalNotificationsPort(),
);

/// O relógio que a roleta diária usa. Injetável para o teste não depender do
/// instante real.
final dailySpinClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// O serviço que decide quando agendar cada lembrete.
///
/// Recebe o mesmo relógio injetável de [dailySpinClockProvider] — senão o
/// `now` interno de `NotificationService` (que tem seu próprio default de
/// `DateTime.now`) ficaria fora do controle do teste, e o horário do
/// lembrete agendado divergiria do `fixedNow` usado no resto do teste.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(
    port: ref.watch(notificationPortProvider),
    now: ref.watch(dailySpinClockProvider),
  ),
);

/// Como a roleta escolhe o índice sorteado em [kSpinWheelPrizes].
///
/// Provider de função, e não uma chamada direta a `Random`, pela mesma razão
/// de `hammerAdProvider`: é o ponto em que o teste força um resultado
/// determinístico sem precisar simular a animação até um ângulo exato.
final dailySpinPrizeIndexProvider = Provider<int Function()>(
  (ref) => () => Random().nextInt(kSpinWheelPrizes.length),
);

/// Como o jogo pede o anúncio premiado que libera um giro extra.
///
/// Mesmo padrão de `hammerAdProvider`/`coinAdProvider`: paga o jogador sem
/// rede nenhuma por padrão. Quem liga o AdMob de verdade é `admobOverrides()`.
final spinAdProvider = Provider<Future<bool> Function()>(
  (ref) => () async => true,
);

/// Se o jogador já pode girar a roleta hoje.
///
/// `FutureProvider` porque a resposta depende de uma leitura de disco — a
/// tela que decide se abre o diálogo automaticamente, e o ícone que mostra
/// disponibilidade, leem daqui em vez de duplicar a consulta.
final dailySpinEligibleProvider = FutureProvider<bool>((ref) async {
  final storage = ref.watch(dailySpinStorageProvider);
  final now = ref.watch(dailySpinClockProvider)();
  final lastSpin = await storage.readLastSpinTimestamp();
  return isSpinEligible(lastSpin, now);
});

String _prizeLabel(AppLocalizations l10n, SpinPrize prize) {
  switch (prize.type) {
    case SpinPrizeType.coins:
      return '${prize.amount} 🪙';
    case SpinPrizeType.hammer:
      return '${prize.amount} 🔨';
    case SpinPrizeType.bomb:
      return '${prize.amount} 💣';
    case SpinPrizeType.brush:
      return '${prize.amount} 🖌️';
  }
}

/// A roleta de recompensa diária, em frosted glass.
///
/// Fica em `showDialog` — não num `Positioned.fill` de algum `Stack` de
/// partida —, pela mesma razão já registrada para a loja de moedas do header:
/// não há tabuleiro nenhum a proteger no Saga Map, e os pontos de entrada
/// (auto-abertura + ícone manual) vivem em telas diferentes que não têm
/// motivo para hospedar a mesma máquina de estado cada uma.
class DailySpinDialog extends ConsumerStatefulWidget {
  const DailySpinDialog({super.key});

  @override
  ConsumerState<DailySpinDialog> createState() => _DailySpinDialogState();
}

class _DailySpinDialogState extends ConsumerState<DailySpinDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;
  SpinPrize? _wonPrize;
  bool _spinning = false;
  bool _watchOfferUsed = false;

  /// Já girou pelo menos uma vez nesta sessão do diálogo, mesmo que o giro
  /// grátis já tenha virado a elegibilidade para `false` no meio da animação
  /// do giro extra. Sem isto, `build` leria "não elegível e sem prêmio ainda"
  /// e mostraria a tela de espera por baixo da roleta girando.
  bool _hasSpunThisSession = false;

  @override
  void initState() {
    super.initState();
    // Finito: gira até o alvo e para. Nada de repetição — a suíte de widget
    // usa `pumpAndSettle`, que trava com animação em loop.
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _spin({required bool countsAsDailySpin}) async {
    if (_spinning) return;
    setState(() {
      _spinning = true;
      _hasSpunThisSession = true;
    });

    final index = ref.read(dailySpinPrizeIndexProvider)();
    final prize = kSpinWheelPrizes[index];

    await _spinController.forward(from: 0);

    final storage = ref.read(dailySpinStorageProvider);
    await _creditPrize(storage, prize);

    if (countsAsDailySpin) {
      final now = ref.read(dailySpinClockProvider)();
      await storage.writeLastSpinTimestamp(now);
      await ref.read(notificationServiceProvider).onDailySpinCompleted();
      ref.invalidate(dailySpinEligibleProvider);
    }

    // O crédito já foi para o disco; o header (moedas/martelo) só reflete o
    // saldo novo depois de reler — mesmo remédio de `EndlessHighScore.refresh`.
    await ref.read(walletProvider.notifier).refresh();

    if (!mounted) return;
    setState(() {
      _wonPrize = prize;
      _spinning = false;
    });
  }

  Future<void> _creditPrize(GameStorage storage, SpinPrize prize) async {
    switch (prize.type) {
      case SpinPrizeType.coins:
        await storage.writeCoins(await storage.readCoins() + prize.amount);
      case SpinPrizeType.hammer:
        await storage.writeHammerCount(
          await storage.readHammerCount() + prize.amount,
        );
      case SpinPrizeType.bomb:
        await storage.writeBombCount(
          await storage.readBombCount() + prize.amount,
        );
      case SpinPrizeType.brush:
        await storage.writeBrushCount(
          await storage.readBrushCount() + prize.amount,
        );
    }
  }

  Future<void> _watchAgain() async {
    if (_watchOfferUsed) return;
    // Marcado ANTES do await, de forma síncrona: duas invocações rápidas
    // (dois toques antes do primeiro `await` resolver) não podem ambas
    // passar pela guarda acima — um anúncio de rede de verdade é lento o
    // bastante para isso acontecer.
    setState(() => _watchOfferUsed = true);
    final granted = await ref.read(spinAdProvider)();
    if (!mounted) return;
    if (!granted) {
      // Anúncio não concedido: devolve a chance de tentar de novo.
      setState(() => _watchOfferUsed = false);
      return;
    }

    setState(() => _wonPrize = null);
    await _spin(countsAsDailySpin: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final eligibleAsync = ref.watch(dailySpinEligibleProvider);

    return Dialog(
      key: dailySpinKey,
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.16),
                  AppColors.darkSurface.withValues(alpha: 0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
            ),
            child: eligibleAsync.when(
              loading: () => const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) {
                // Falha de leitura de disco não pode esconder a roleta —
                // o jogador não perde nada sendo deixado tentar (a escrita
                // do último giro continua travando a próxima leitura real),
                // e é o mesmo tratamento que o resto do projeto dá a falha
                // de armazenamento: assume o estado "vazio" e segue, com
                // diagnóstico (ver `WalletNotifier.refresh`).
                debugPrint(
                  'Falha ao ler elegibilidade da roleta diária: $error\n$stack',
                );
                return _spinContent(l10n);
              },
              data: (eligible) {
                if (!eligible && !_hasSpunThisSession) {
                  return _WaitContent(hoursLeft: 24, l10n: l10n);
                }
                return _spinContent(l10n);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _spinContent(AppLocalizations l10n) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        l10n.dailySpinTitle,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        l10n.dailySpinSubtitle,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
      ),
      const SizedBox(height: 20),
      RotationTransition(
        turns: Tween<double>(begin: 0, end: 4).animate(
          CurvedAnimation(parent: _spinController, curve: Curves.easeOutCubic),
        ),
        child: Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const SweepGradient(
              colors: [
                AppColors.digit9,
                AppColors.digit9Deep,
                AppColors.digit9,
              ],
            ),
            border: Border.all(color: Colors.white, width: 3),
          ),
        ),
      ),
      const SizedBox(height: 20),
      if (_wonPrize != null) ...[
        Text(
          l10n.dailySpinPrizeWon(_prizeLabel(l10n, _wonPrize!)),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        if (!_watchOfferUsed)
          OutlinedButton(
            key: dailySpinWatchAgainButtonKey,
            onPressed: _spinning ? null : _watchAgain,
            child: Text(l10n.dailySpinWatchAgainButton),
          ),
        TextButton(
          key: dailySpinCloseButtonKey,
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(l10n.dailySpinCloseButton),
        ),
      ] else
        ElevatedButton(
          key: dailySpinSpinButtonKey,
          onPressed: _spinning ? null : () => _spin(countsAsDailySpin: true),
          child: Text(l10n.dailySpinSpinButton),
        ),
    ],
  );
}

class _WaitContent extends StatelessWidget {
  const _WaitContent({required this.hoursLeft, required this.l10n});

  final int hoursLeft;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        l10n.dailySpinTitle,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        l10n.dailySpinComeBackIn(hoursLeft),
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
      ),
      const SizedBox(height: 16),
      TextButton(
        key: dailySpinCloseButtonKey,
        onPressed: () => Navigator.of(context).maybePop(),
        child: Text(l10n.dailySpinCloseButton),
      ),
    ],
  );
}
