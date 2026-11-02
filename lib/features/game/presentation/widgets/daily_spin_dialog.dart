import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/core/audio/audio_service.dart';
import 'package:nine_fuse/core/audio/sound_event.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/feedback/haptics.dart';
import 'package:nine_fuse/core/notifications/local_notifications_port.dart';
import 'package:nine_fuse/core/notifications/notification_port.dart';
import 'package:nine_fuse/core/notifications/notification_service.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/core/theme/nf_tokens.dart';
import 'package:nine_fuse/core/widgets/nf_text.dart';
import 'package:nine_fuse/features/game/domain/daily_spin.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/presentation/widgets/game_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/prize_wheel.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import 'package:nine_fuse/features/game/providers/wallet.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Chave da caixa da roleta diária.
const Key dailySpinKey = Key('daily_spin');

/// Chave do botão de girar ("GIRAR GRÁTIS").
const Key dailySpinSpinButtonKey = Key('daily_spin_spin_button');

/// Chave do botão de girar de novo assistindo a um vídeo.
const Key dailySpinWatchAgainButtonKey = Key('daily_spin_watch_again_button');

/// Chave do botão de fechar (o X do canto).
const Key dailySpinCloseButtonKey = Key('daily_spin_close_button');

/// Chave do popup de prêmio.
const Key dailySpinPrizePopupKey = Key('daily_spin_prize_popup');

/// Chave do botão "Coletar" do popup de prêmio.
const Key dailySpinCollectButtonKey = Key('daily_spin_collect_button');

/// Chave da linha "Próximo giro grátis em HH:MM:SS".
const Key dailySpinCountdownKey = Key('daily_spin_countdown');

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
  (ref) =>
      () => Random().nextInt(kSpinWheelPrizes.length),
);

/// Onde, dentro da fatia sorteada, a roda para — fração da largura da fatia,
/// entre -[kWheelMaxJitter] e +[kWheelMaxJitter].
///
/// O prêmio já vem decidido por [dailySpinPrizeIndexProvider]; o deslocamento
/// é só para a parada não cair sempre no mesmo ponto (o que denunciaria a
/// roleta como enfeite). Injetável para o teste fixar a parada.
final dailySpinJitterProvider = Provider<double Function()>((ref) {
  final random = Random();
  return () => (random.nextDouble() * 2 - 1) * kWheelMaxJitter;
});

/// Como o jogo pede o anúncio premiado que libera um giro extra.
///
/// Mesmo padrão de `hammerAdProvider`/`coinAdProvider`: paga o jogador sem
/// rede nenhuma por padrão. Quem liga o AdMob de verdade é `admobOverrides()`.
final spinAdProvider = Provider<Future<bool> Function()>(
  (ref) =>
      () async => true,
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

/// Quando foi o último giro grátis — a base da contagem "próximo giro em".
///
/// Separado de [dailySpinEligibleProvider] porque a elegibilidade é um sim/não
/// lido por outras telas, e só a roleta precisa do instante.
final dailySpinLastSpinProvider = FutureProvider<DateTime?>(
  (ref) => ref.watch(dailySpinStorageProvider).readLastSpinTimestamp(),
);

/// Formata o tempo restante como `HH:MM:SS` (negativo vira zero).
String formatSpinCountdown(Duration remaining) {
  final total = remaining.isNegative ? 0 : remaining.inSeconds;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(total ~/ 3600)}:${two(total % 3600 ~/ 60)}:${two(total % 60)}';
}

/// O que um giro efetivamente pagou: o prêmio da fatia e, se era booster com
/// o estoque no teto, quanto dele virou moeda.
typedef _SpinPayout = ({SpinPrize prize, int credited, int overflowCoins});

/// A roleta de recompensa diária ("07 Roleta diária" do Observatório Real).
///
/// Aberta por `showNfModal` — não num `Positioned.fill` de algum `Stack` de
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
    with TickerProviderStateMixin {
  /// Medidas do painel no espaço de 390pt do design.
  static const double _panelWidth = 362;

  /// Intervalo mínimo entre dois cliques táteis de divisória. No começo do
  /// giro passam dezenas de divisórias por segundo; um clique por divisória
  /// viraria um zumbido, não um tique.
  static const Duration _tickGap = Duration(milliseconds: 60);

  /// Meia batida das lâmpadas: elas trocam de cor a cada 500ms enquanto gira.
  static const int _lampBlinkMs = 500;

  /// Giro da roda: 4200ms, `decelerate` (pedido do dono do produto — o
  /// designer sugeriu `easeOutQuart`). Finito: a suíte de widget usa
  /// `pumpAndSettle`, que trava com animação em loop.
  late final AnimationController _spinController;

  /// O tranco do ponteiro ao parar (-8° → 0°, 200ms, `elasticOut`).
  late final AnimationController _kickController;

  late Animation<double> _turns;

  /// Onde a roda está parada, em voltas. O giro extra parte daqui.
  double _restTurns = 0;

  int _lastDivider = 0;
  Duration _lastTickAt = Duration.zero;

  _SpinPayout? _payout;
  bool _popupOpen = false;
  bool _spinning = false;
  bool _watchOfferUsed = false;

  /// Já girou pelo menos uma vez nesta sessão do diálogo, mesmo que o giro
  /// grátis já tenha virado a elegibilidade para `false` no meio da animação
  /// do giro extra.
  bool _hasSpunThisSession = false;

  /// Atualiza a contagem regressiva uma vez por segundo. `Timer` e não
  /// `Ticker`: um ticker pede quadro a cada vsync e o `pumpAndSettle` nunca
  /// assentaria; o timer só pede quadro quando o texto muda.
  Timer? _countdownTimer;
  String? _shownCountdown;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: NfDurations.wheel,
    )..addListener(_onSpinTick);
    _kickController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1,
    );
    _turns = const AlwaysStoppedAnimation(0);
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refreshCountdown(),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _spinController.dispose();
    _kickController.dispose();
    super.dispose();
  }

  /// Clique tátil a cada divisória que passa pelo ponteiro, com teto de um a
  /// cada [_tickGap].
  void _onSpinTick() {
    final divider = dividersPassed(_turns.value, kSpinWheelPrizes.length);
    if (divider == _lastDivider) return;
    _lastDivider = divider;
    final elapsed = NfDurations.wheel * _spinController.value;
    if (elapsed - _lastTickAt < _tickGap) return;
    _lastTickAt = elapsed;
    // O tique sonoro segue a mesma régua do tátil (`_tickGap`): sem ela, o
    // começo do giro viraria uma metralhadora de cliques.
    Haptics.selection();
    GameAudio.play(SoundEvent.spinTick);
  }

  void _refreshCountdown() {
    if (!mounted) return;
    final text = _countdownText();
    if (text == null && _shownCountdown != null && !_hasSpunThisSession) {
      // O prazo venceu com a roleta aberta: relê a elegibilidade para o
      // botão acender sozinho, sem o jogador precisar fechar e reabrir.
      ref.invalidate(dailySpinEligibleProvider);
    }
    if (text == _shownCountdown) return;
    setState(() {});
  }

  /// O texto da contagem, ou nulo quando não há o que contar.
  String? _countdownText() {
    final lastSpin = ref.read(dailySpinLastSpinProvider).valueOrNull;
    if (lastSpin == null) return null;
    final now = ref.read(dailySpinClockProvider)();
    final remaining = lastSpin.add(const Duration(hours: 24)).difference(now);
    if (remaining <= Duration.zero) return null;
    return formatSpinCountdown(remaining);
  }

  Future<void> _spin({required bool countsAsDailySpin}) async {
    if (_spinning) return;
    setState(() {
      _spinning = true;
      _hasSpunThisSession = true;
      _popupOpen = false;
    });

    final index = ref.read(dailySpinPrizeIndexProvider)();
    final prize = kSpinWheelPrizes[index];
    final target = targetTurnsFor(
      index,
      kSpinWheelPrizes.length,
      jitter: ref.read(dailySpinJitterProvider)(),
      from: _restTurns,
    );
    _turns = Tween<double>(begin: _restTurns, end: target).animate(
      CurvedAnimation(parent: _spinController, curve: Curves.decelerate),
    );
    _lastDivider = dividersPassed(_restTurns, kSpinWheelPrizes.length);
    _lastTickAt = -_tickGap;

    await _spinController.forward(from: 0);
    _restTurns = target;

    Haptics.medium();
    GameAudio.play(SoundEvent.spinPrize);
    final kick = _kickController.forward(from: 0);

    final storage = ref.read(dailySpinStorageProvider);
    final payout = await _creditPrize(storage, prize);

    if (countsAsDailySpin) {
      final now = ref.read(dailySpinClockProvider)();
      await storage.writeLastSpinTimestamp(now);
      await ref.read(notificationServiceProvider).onDailySpinCompleted();
      ref
        ..invalidate(dailySpinEligibleProvider)
        ..invalidate(dailySpinLastSpinProvider);
    }

    // O crédito já foi para o disco; o header (moedas/martelo) só reflete o
    // saldo novo depois de reler — mesmo remédio de `EndlessHighScore.refresh`.
    await ref.read(walletProvider.notifier).refresh();
    await kick;

    if (!mounted) return;
    setState(() {
      _payout = payout;
      _popupOpen = true;
      _spinning = false;
    });
  }

  Future<_SpinPayout> _creditPrize(GameStorage storage, SpinPrize prize) async {
    switch (prize.type) {
      case SpinPrizeType.coins:
        await storage.writeCoins(await storage.readCoins() + prize.amount);
        return (prize: prize, credited: prize.amount, overflowCoins: 0);
      case SpinPrizeType.hammer:
        return _creditBooster(
          storage,
          prize,
          storage.readHammerCount,
          storage.writeHammerCount,
        );
      case SpinPrizeType.bomb:
        return _creditBooster(
          storage,
          prize,
          storage.readBombCount,
          storage.writeBombCount,
        );
      case SpinPrizeType.brush:
        return _creditBooster(
          storage,
          prize,
          storage.readBrushCount,
          storage.writeBrushCount,
        );
    }
  }

  /// Booster de prêmio respeita o teto de estoque; o excedente vira moeda
  /// (`capBoosterReward`), para o giro nunca "não pagar". Devolve o que foi
  /// creditado de fato, para o popup não anunciar um martelo que virou moeda.
  Future<_SpinPayout> _creditBooster(
    GameStorage storage,
    SpinPrize prize,
    Future<int> Function() read,
    Future<void> Function(int) write,
  ) async {
    final current = await read();
    final credit = capBoosterReward(current: current, amount: prize.amount);
    await write(credit.count);
    if (credit.overflowCoins > 0) {
      await storage.writeCoins(
        await storage.readCoins() + credit.overflowCoins,
      );
    }
    return (
      prize: prize,
      credited: credit.count - current,
      overflowCoins: credit.overflowCoins,
    );
  }

  Future<void> _watchAgain() async {
    if (_watchOfferUsed || _spinning) return;
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

    await _spin(countsAsDailySpin: false);
  }

  void _collect() => setState(() => _popupOpen = false);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final eligibleAsync = ref.watch(dailySpinEligibleProvider);
    // Assinado para o `build` refazer a contagem quando o instante chega.
    ref.watch(dailySpinLastSpinProvider);

    // Falha de leitura de disco não pode esconder a roleta — o jogador não
    // perde nada sendo deixado tentar (a escrita do último giro continua
    // travando a próxima leitura real), e é o mesmo tratamento que o resto
    // do projeto dá a falha de armazenamento: assume o estado "vazio" e
    // segue, com diagnóstico (ver `WalletNotifier.refresh`).
    if (eligibleAsync case AsyncError(:final error, :final stackTrace)) {
      debugPrint(
        'Falha ao ler elegibilidade da roleta diária: $error\n$stackTrace',
      );
    }
    final freeAvailable =
        !_hasSpunThisSession &&
        (eligibleAsync.hasError || (eligibleAsync.valueOrNull ?? false));
    final canSpinFree = freeAvailable && !_spinning;
    void spinFree() => _spin(countsAsDailySpin: true);

    final countdown = freeAvailable || _spinning ? null : _countdownText();
    _shownCountdown = countdown;

    final panel = Container(
      width: _panelWidth,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [NfColors.night3, Color(0xFF0B1236)],
        ),
        border: Border.all(color: NfColors.goldDeep, width: 3),
        boxShadow: [
          // Blur zero: é a espessura da placa, não uma sombra.
          const BoxShadow(color: NfColors.bronze, offset: Offset(0, 8)),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 60,
            offset: const Offset(0, 30),
          ),
          BoxShadow(
            color: NfColors.gem.withValues(alpha: 0.35),
            blurRadius: 60,
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(19, 31, 19, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NfText.titleGold(l10n.dailySpinTitle.toUpperCase()),
                const SizedBox(height: 8),
                Text(
                  l10n.dailySpinSubtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppFonts.number,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: NfColors.textSoft,
                  ),
                ),
                const SizedBox(height: 40),
                AnimatedBuilder(
                  animation: Listenable.merge([
                    _spinController,
                    _kickController,
                  ]),
                  builder: (context, _) => PrizeWheel(
                    prizes: kSpinWheelPrizes,
                    turns: _turns.value,
                    hubLabel: l10n.dailySpinSpinButton,
                    lampsAlternate:
                        _spinning &&
                        (NfDurations.wheel.inMilliseconds *
                                _spinController.value ~/
                                _lampBlinkMs)
                            .isOdd,
                    pointerKick:
                        -8 *
                        pi /
                        180 *
                        (1 -
                            Curves.elasticOut.transform(_kickController.value)),
                    onHubTap: canSpinFree ? spinFree : null,
                  ),
                ),
                const SizedBox(height: 36),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _hasSpunThisSession && !_watchOfferUsed && !_spinning
                      ? GameButton(
                          key: dailySpinWatchAgainButtonKey,
                          label: l10n.dailySpinWatchAgainButton,
                          color: NfColors.gem,
                          icon: Icons.play_circle_fill,
                          fontSize: 20,
                          onPressed: _watchAgain,
                        )
                      : GameButton(
                          key: dailySpinSpinButtonKey,
                          label: l10n.dailySpinFreeButton,
                          // Desativado lê como secundário: ouro é só para o
                          // que está ao alcance do toque.
                          color: canSpinFree
                              ? AppColors.uiGold
                              : AppColors.darkSurface,
                          fontSize: 26,
                          onPressed: canSpinFree ? spinFree : null,
                        ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 18,
                  child: countdown == null
                      ? null
                      : FittedBox(
                          // Tradução longa encolhe em vez de estourar a linha.
                          fit: BoxFit.scaleDown,
                          child: Row(
                            key: dailySpinCountdownKey,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.dailySpinNextFreeIn,
                                style: const TextStyle(
                                  fontFamily: AppFonts.number,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: NfColors.textMuted,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                countdown,
                                style: const TextStyle(
                                  fontFamily: AppFonts.number,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: NfColors.gold,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 11,
            top: 13,
            child: _CloseButton(
              // Fechar no meio do giro descartaria o `forward` pendente e o
              // prêmio nunca seria creditado.
              onPressed: _spinning
                  ? null
                  : () => Navigator.of(context).maybePop(),
            ),
          ),
          if (_popupOpen && _payout != null)
            Positioned.fill(
              child: _PrizePopup(
                payout: _payout!,
                l10n: l10n,
                onCollect: _collect,
              ),
            ),
        ],
      ),
    );

    return Material(
      key: dailySpinKey,
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(14),
          // O painel é desenhado em 362pt (tela de 390); em tela mais baixa
          // que o design ele encolhe inteiro em vez de cortar o botão.
          child: FittedBox(fit: BoxFit.scaleDown, child: panel),
        ),
      ),
    );
  }
}

/// O X circular azul-noite com aro dourado.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: MaterialLocalizations.of(context).closeButtonTooltip,
    child: GestureDetector(
      key: dailySpinCloseButtonKey,
      onTap: onPressed,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3A4380), NfColors.night3],
          ),
          border: Border.all(color: const Color(0xFFC98A18), width: 2),
        ),
        child: Icon(
          Icons.close_rounded,
          size: 22,
          color: onPressed == null
              ? NfColors.goldPale.withValues(alpha: 0.35)
              : NfColors.goldPale,
        ),
      ),
    ),
  );
}

/// O prêmio que acabou de cair: ícone grande, quantidade e "Coletar".
///
/// Camada dentro do próprio painel, e não um segundo modal: o crédito já foi
/// feito antes de ele subir, então o popup é só anúncio — empilhar outra rota
/// só para isso duplicaria véu e transição sem ganho.
class _PrizePopup extends StatelessWidget {
  const _PrizePopup({
    required this.payout,
    required this.l10n,
    required this.onCollect,
  });

  final _SpinPayout payout;
  final AppLocalizations l10n;
  final VoidCallback onCollect;

  @override
  Widget build(BuildContext context) {
    // Booster que virou moeda inteiro (estoque no teto): o popup mostra a
    // moeda que de fato entrou, não o martelo que não coube.
    final allOverflow = payout.credited == 0 && payout.overflowCoins > 0;
    final type = allOverflow ? SpinPrizeType.coins : payout.prize.type;
    final amount = allOverflow
        ? '+${payout.overflowCoins}'
        : (type == SpinPrizeType.coins
              ? '+${payout.prize.amount}'
              : '×${payout.credited}');

    return DecoratedBox(
      key: dailySpinPrizePopupKey,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(31),
        color: NfColors.night0.withValues(alpha: 0.72),
      ),
      child: Center(
        // Entrada finita (escala 0,85 → 1). Os títulos aqui dentro saem sem
        // sombra empilhada — sombra de texto em `Transform` animado borra no
        // Impeller (ver `NfText`).
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.85, end: 1),
          duration: NfDurations.modal,
          curve: Curves.easeOutBack,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Container(
            width: 264,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
            decoration: NfDecorations.panel(glow: true),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NfText.titleGold(
                  l10n.dailySpinPrizeTitle,
                  size: 28,
                  shadows: false,
                ),
                const SizedBox(height: 16),
                PrizeWheel.iconFor(type, size: 88),
                const SizedBox(height: 6),
                NfText.number(amount, size: 36),
                if (payout.overflowCoins > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.dailySpinStockFull(payout.overflowCoins),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: AppFonts.number,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: NfColors.textSoft,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                GameButton(
                  key: dailySpinCollectButtonKey,
                  label: l10n.dailySpinCollectButton,
                  color: AppColors.uiGold,
                  fontSize: 20,
                  onPressed: onCollect,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
