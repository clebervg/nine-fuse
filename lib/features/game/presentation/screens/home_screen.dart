import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/core/ads/ad_providers.dart';
import 'package:nine_fuse/core/assets/tile_sprite_manager.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/core/theme/nf_tokens.dart';
import 'package:nine_fuse/core/widgets/coins_header_badge.dart';
import 'package:nine_fuse/core/widgets/nf_background.dart';
import 'package:nine_fuse/core/widgets/nf_modal.dart';
import 'package:nine_fuse/core/widgets/nf_square_button.dart';
import 'package:nine_fuse/core/widgets/nf_text.dart';
import 'package:nine_fuse/core/widgets/privacy_dialog.dart';
import 'package:nine_fuse/features/game/domain/campaign_chapter.dart';
import 'package:nine_fuse/features/game/domain/level_catalog.dart';
import 'package:nine_fuse/features/game/presentation/screens/level_select_screen.dart';
import 'package:nine_fuse/features/game/presentation/screens/shop_screen.dart';
import 'package:nine_fuse/features/game/presentation/widgets/daily_spin_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/game_dialog.dart';
import 'package:nine_fuse/features/game/providers/campaign_records.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';
import 'package:nine_fuse/features/game/providers/wallet.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Chave do CTA "JOGAR" do menu inicial.
const Key homePlayKey = Key('home_play');

/// Chave do botão LOJA do menu inicial.
const Key homeShopKey = Key('home_shop');

/// Chave do botão ROLETA do menu inicial.
const Key homeSpinKey = Key('home_spin');

/// Chave do selo vermelho da roleta, aceso enquanto há giro grátis.
const Key homeSpinBadgeKey = Key('home_spin_badge');

/// Chave da pílula "CAPÍTULO N · FASE M", que abre o mapa.
const Key homeMapKey = Key('home_map');

/// Chave da pílula de estrelas da campanha.
const Key homeStarsKey = Key('home_stars');

/// Chave do botão de privacidade do topo.
const Key homePrivacyKey = Key('home_privacy');

/// Duração da entrada do herói. Finita de propósito: uma órbita em repetição
/// deixaria `pumpAndSettle` sem fim e derrubaria a suíte de widget.
const Duration kHomeHeroEntrance = Duration(milliseconds: 900);

/// Menu inicial ("01 Menu inicial" do Observatório Real) — a primeira tela
/// depois da abertura.
///
/// É a home de fato, e por isso concentra o que acontece "ao abrir o app": o
/// aviso ao serviço de notificações e a roleta diária automática, que antes
/// viviam no mapa (quando o mapa era a primeira tela).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: kHomeHeroEntrance)
      ..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      ref.read(walletProvider.notifier).refresh();
      // O botão de vídeo da roleta e da loja nascem daqui: anúncio frio no
      // primeiro toque é a espera que o preload existe para evitar.
      preloadRewardedAds(ref);
      // O app acabou de abrir: reagenda o lembrete de inatividade para a
      // frente a partir de agora. `unawaited` porque o serviço já trata falha
      // de plugin internamente — isto é rede de segurança, não garantia nova.
      unawaited(ref.read(notificationServiceProvider).onAppOpened());

      bool eligible;
      try {
        eligible = await ref.read(dailySpinEligibleProvider.future);
      } catch (error, stack) {
        // Falha de disco na elegibilidade não pode travar o primeiro quadro:
        // vale como "não elegível", e a roleta não abre sozinha.
        debugPrint(
          'Falha ao ler elegibilidade da roleta diária: $error\n$stack',
        );
        eligible = false;
      }
      if (!mounted || !eligible) return;
      _openDailySpin();
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  void _openDailySpin() {
    showNfModal<void>(
      context,
      barrierDismissible: false,
      builder: (_) => const DailySpinDialog(),
    );
  }

  /// O JOGAR empurra o mapa já pedindo a fase da vez, em vez de abrir a fase
  /// direto daqui: o fim de partida volta "às fases", e com o mapa por baixo é
  /// lá que o jogador cai — vendo a trilha liberar a fase seguinte. O fluxo
  /// de abrir fase continua existindo num lugar só (`_openLevel` do mapa).
  void _openMap({bool play = false}) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => LevelSelectScreen(autoOpenCurrent: play),
          ),
        )
        .then((_) {
          // A fase gasta e ganha booster gravando direto no disco.
          if (mounted) ref.read(walletProvider.notifier).refresh();
        });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final progress = ref.watch(campaignProgressProvider);
    // Observado para a pílula de estrelas se atualizar quando uma fase é
    // registrada: o notifier sozinho não notifica.
    ref.watch(campaignRecordsProvider);
    final stars = ref.read(campaignRecordsProvider.notifier).totalStars;
    final current = levelAt(progress + 1);
    final chapter = chapterOf(current.number);
    // Falha de leitura vale como "sem giro": um aviso falso é pior que nenhum.
    final spinWaiting =
        ref.watch(dailySpinEligibleProvider).asData?.value ?? false;
    // Tela curta (iPhone SE): o logo encolhe para sobrar palco ao herói.
    final compact = MediaQuery.sizeOf(context).height < 740;

    return NfBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 18, 0),
                    child: Row(
                      children: [
                        CoinsHeaderBadge(onAdd: () => openShop(context)),
                        const SizedBox(width: 6),
                        _StarsPill(stars: stars),
                        const Spacer(),
                        // Não há tela de ajustes: o botão do topo leva à única
                        // configuração que existe fora da partida, a política
                        // de privacidade — com o ícone dela, para não
                        // prometer ajustes que não vêm.
                        NfSquareButton(
                          key: homePrivacyKey,
                          icon: Icons.privacy_tip_outlined,
                          tooltip: l10n.privacyTooltip,
                          size: 46,
                          onPressed: () => showPrivacyDialog(context),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: compact ? 6 : 14),
                  _Logo(size: compact ? 56 : 72),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      // Mais perto do logo que do botão: no design o palco
                      // nasce logo abaixo do FUSE, e a folga de telas altas
                      // vai para cima da pílula do capítulo.
                      child: FittedBox(
                        alignment: const Alignment(0, -0.5),
                        child: _HeroStage(
                          entrance: _entrance,
                          spinWaiting: spinWaiting,
                          onShop: () => openShop(context),
                          onSpin: _openDailySpin,
                        ),
                      ),
                    ),
                  ),
                  _ChapterPill(
                    label: l10n.homeChapterLevel(
                      chapter.number,
                      current.number,
                    ),
                    mapLabel: l10n.homeMap,
                    onTap: _openMap,
                  ),
                  SizedBox(height: compact ? 14 : 20),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 18),
                    // O único elemento de maior peso da tela.
                    child: GameButton(
                      key: homePlayKey,
                      label: l10n.playButton,
                      color: AppColors.uiGold,
                      fontSize: compact ? 28 : 32,
                      onPressed: () => _openMap(play: true),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pílula de estrelas da campanha inteira, irmã visual da de moedas.
class _StarsPill extends StatelessWidget {
  const _StarsPill({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) => Semantics(
    label: AppLocalizations.of(context).homeStarsSemantics(stars),
    excludeSemantics: true,
    child: Container(
      key: homeStarsKey,
      height: 42,
      padding: const EdgeInsets.fromLTRB(6, 0, 14, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF111A4A), Color(0xFF0A1033)],
        ),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFFC98A18), width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x73000000), offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Color(0xFFFFC93C), size: 28),
          const SizedBox(width: 6),
          Text(
            '$stars',
            style: const TextStyle(
              fontFamily: AppFonts.number,
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ],
      ),
    ),
  );
}

/// "NINE / FUSE" empilhado: NINE branco com a sombra roxa dos títulos, FUSE em
/// ouro com os traços laterais que o enquadram.
class _Logo extends StatelessWidget {
  const _Logo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    Widget dash({required bool left}) => Container(
      width: size * 0.45,
      height: 5,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        gradient: LinearGradient(
          colors: left
              ? const [Color(0x00FFD84A), NfColors.gold]
              : const [NfColors.gold, Color(0x00FFD84A)],
        ),
      ),
    );

    return ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NfText.title('NINE', size: size),
          Transform.translate(
            offset: const Offset(0, -4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                dash(left: true),
                const SizedBox(width: 12),
                NfText.titleGold('FUSE', size: size),
                const SizedBox(width: 12),
                dash(left: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// O palco do herói, desenhado nas coordenadas do design (390 de largura) e
/// escalado inteiro por um `FittedBox`: as peças em órbita, o pedestal e os
/// botões laterais guardam as proporções entre si em qualquer tela.
class _HeroStage extends StatelessWidget {
  const _HeroStage({
    required this.entrance,
    required this.spinWaiting,
    required this.onShop,
    required this.onSpin,
  });

  static const Size _size = Size(390, 316);

  final Animation<double> entrance;
  final bool spinWaiting;
  final VoidCallback onShop;
  final VoidCallback onSpin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SizedBox.fromSize(
      size: _size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Halo dourado-lilás por trás do medalhão.
          Positioned(
            left: 45,
            top: 0,
            width: 300,
            height: 300,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFD66E).withValues(alpha: 0.55),
                    const Color(0xFFC77BFF).withValues(alpha: 0.28),
                    const Color(0x00C77BFF),
                  ],
                  stops: const [0, 0.55, 1],
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: CustomPaint(painter: _PedestalPainter()),
          ),
          // O herói e as peças em órbita entram juntos, uma vez: o medalhão
          // cresce com um leve elástico e as peças saem de trás dele para os
          // seus lugares. Sem texto dentro da escala animada (bug do Impeller).
          AnimatedBuilder(
            animation: entrance,
            builder: (context, _) {
              final t = entrance.value;
              final grow = Curves.easeOutBack.transform(
                const Interval(0, 0.7).transform(t),
              );
              final fly = Curves.easeOutCubic.transform(
                const Interval(0.25, 1).transform(t),
              );
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final orbit in _orbits.take(2)) _orbitTile(orbit, fly),
                  Positioned(
                    left: 87,
                    top: 52 + 14 * (1 - grow),
                    width: 216,
                    height: 216,
                    child: Transform.scale(
                      scale: 0.82 + 0.18 * grow,
                      child: _sprite(9, 216),
                    ),
                  ),
                  for (final orbit in _orbits.skip(2)) _orbitTile(orbit, fly),
                ],
              );
            },
          ),
          Positioned(
            left: 14,
            top: 56,
            child: _SideButton(
              key: homeShopKey,
              label: l10n.homeShop,
              onTap: onShop,
              child: Image.asset(
                'assets/images/ic_coin.png',
                width: 44,
                height: 44,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.storefront_rounded,
                  color: NfColors.gold,
                  size: 34,
                ),
              ),
            ),
          ),
          Positioned(
            right: 10,
            top: 56,
            width: 96,
            child: Center(
              child: _SideButton(
                key: homeSpinKey,
                label: l10n.homeSpin,
                badge: spinWaiting,
                onTap: onSpin,
                child: const Icon(
                  Icons.casino_rounded,
                  color: NfColors.gold,
                  size: 36,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Uma peça em órbita, voando do centro do medalhão até o seu lugar.
  Widget _orbitTile(_Orbit orbit, double fly) {
    const center = Offset(195 - 24, 160 - 24);
    final pos = Offset.lerp(center, orbit.position, fly)!;
    return Positioned(
      left: pos.dx,
      top: pos.dy,
      width: orbit.size,
      height: orbit.size,
      child: Transform.rotate(
        angle: orbit.angle * fly,
        child: Transform.scale(
          scale: 0.3 + 0.7 * fly,
          child: _sprite(orbit.digit, orbit.size),
        ),
      ),
    );
  }

  static Widget _sprite(int digit, double size) => Image.asset(
    TileSpriteManager.assetKeyFor(digit),
    width: size,
    height: size,
    // Sem o PNG, uma gema chapada da cor do dígito — o palco não pode cair
    // num quadrado de erro.
    errorBuilder: (_, _, _) => DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.getColorByDigit(digit),
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
    ),
  );
}

/// Posição final (canto superior esquerdo, no palco de 390), tamanho e
/// inclinação de uma peça em órbita.
class _Orbit {
  const _Orbit(this.digit, this.position, this.size, this.angle);

  final int digit;
  final Offset position;
  final double size;
  final double angle;
}

/// As duas primeiras ficam atrás do medalhão (topo da órbita), as duas
/// últimas na frente (base dela) — é o que dá profundidade ao anel.
const List<_Orbit> _orbits = [
  _Orbit(5, Offset(96, 22), 48, -14 * math.pi / 180),
  _Orbit(3, Offset(262, 30), 42, 12 * math.pi / 180),
  _Orbit(1, Offset(92, 200), 44, 10 * math.pi / 180),
  _Orbit(6, Offset(258, 188), 50, -8 * math.pi / 180),
];

/// A órbita tracejada e o pedestal elíptico (sombra, aro de ouro e o brilho
/// de gema), nas medidas do design.
class _PedestalPainter extends CustomPainter {
  const _PedestalPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Órbita tracejada, inclinada 10°.
    canvas.save();
    canvas.translate(195, 152);
    canvas.rotate(-10 * math.pi / 180);
    final orbit = Rect.fromCenter(center: Offset.zero, width: 336, height: 88);
    final dash = Paint()
      ..color = NfColors.gold.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const steps = 64;
    for (var i = 0; i < steps; i++) {
      final a = 2 * math.pi * i / steps;
      final b = a + 2 * math.pi / steps * 0.25;
      final path = Path()..addArc(orbit, a, b - a);
      canvas.drawPath(path, dash);
    }
    canvas.restore();

    // Sombra do pedestal.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(195, 284), width: 236, height: 48),
      Paint()..color = const Color(0xFF05081C).withValues(alpha: 0.7),
    );
    // Brilho de gema dentro do aro.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(195, 276), width: 196, height: 32),
      Paint()..color = NfColors.gem.withValues(alpha: 0.35),
    );
    // Aro de ouro.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(195, 278), width: 224, height: 44),
      Paint()
        ..color = NfColors.goldDeep
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
  }

  @override
  bool shouldRepaint(_PedestalPainter oldDelegate) => false;
}

/// Botão lateral do palco (LOJA, ROLETA): placa de 68 com a arte e o rótulo
/// pequeno embaixo.
class _SideButton extends StatelessWidget {
  const _SideButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
    this.badge = false,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;
  final bool badge;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 68,
                height: 68,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(21),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF22327A), Color(0xFF0E1640)],
                  ),
                  border: Border.all(color: const Color(0xFFC98A18), width: 2),
                  boxShadow: const [
                    // Blur zero: é a espessura da placa, não uma sombra.
                    BoxShadow(color: Color(0xFF05081C), offset: Offset(0, 5)),
                  ],
                ),
                child: child,
              ),
              // "1": um giro grátis esperando. Número, e não ponto, porque é
              // literalmente quantos giros a roleta tem para dar.
              if (badge)
                Positioned(
                  right: -8,
                  top: -8,
                  child: Container(
                    key: homeSpinBadgeKey,
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFF3B5C),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Text(
                      '1',
                      style: TextStyle(
                        fontFamily: AppFonts.number,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        height: 1,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            label,
            style: const TextStyle(
              fontFamily: AppFonts.number,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              height: 1,
              letterSpacing: 1.2,
              color: Color(0xFFEDE8FF),
              shadows: [Shadow(color: Colors.black, offset: Offset(0, 2))],
            ),
          ),
        ],
      ),
    ),
  );
}

/// "CAPÍTULO N · FASE M" com o chip MAPA. A pílula inteira abre o mapa: o chip
/// sozinho seria um alvo pequeno demais.
class _ChapterPill extends StatelessWidget {
  const _ChapterPill({
    required this.label,
    required this.mapLabel,
    required this.onTap,
  });

  final String label;
  final String mapLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$label, $mapLabel',
    excludeSemantics: true,
    child: GestureDetector(
      key: homeMapKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.fromLTRB(18, 0, 5, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: NfColors.night1.withValues(alpha: 0.85),
          border: Border.all(
            color: const Color(0xFFC98A18).withValues(alpha: 0.7),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Encolhe em vez de estourar: na campanha infinita a fase chega a
            // quatro dígitos, e o inglês ("CHAPTER · LEVEL") é mais longo.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: AppFonts.number,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    height: 1,
                    letterSpacing: 1.4,
                    color: NfColors.goldPale,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFB57BFF), Color(0xFF7328C4)],
                ),
              ),
              child: Text(
                mapLabel,
                style: const TextStyle(
                  fontFamily: AppFonts.number,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  height: 1,
                  letterSpacing: 1.3,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
