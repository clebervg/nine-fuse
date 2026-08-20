import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/features/game/presentation/screens/level_select_screen.dart';

/// Duração total da animação de entrada da splash.
const Duration kSplashDuration = Duration(milliseconds: 1800);

/// Tela de abertura animada, exibida uma única vez entre a splash nativa
/// (`flutter_native_splash`, ver `main.dart`) e o menu de fases.
///
/// Reaproveita o ícone já existente do app (a peça 9 dourada) em vez de criar
/// uma identidade visual nova — ver
/// `docs/superpowers/specs/2026-08-20-splash-screen-design.md`.
///
/// Toda a timeline roda num único `AnimationController`, fatiado em estágios
/// por fração do valor do controller (entrada, power-up, idle, saída) — não
/// em `Future.delayed` nem em controllers separados, e a duração é finita
/// para não travar `pumpAndSettle` em teste.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.onSplashComplete});

  /// Chamado quando a animação termina. Por padrão navega para
  /// [LevelSelectScreen]; testes podem substituir para observar o fim sem
  /// depender de navegação.
  final VoidCallback? onSplashComplete;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // Fronteiras dos estágios, como frações do controller (0..1) — ver spec.
  static const double _entranceEnd = 0.22;
  static const double _powerUpEnd = 0.44;
  static const double _idleEnd = 0.78;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: kSplashDuration)
      ..addStatusListener(_onStatusChanged)
      ..forward();
  }

  void _onStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final onComplete = widget.onSplashComplete;
    if (onComplete != null) {
      onComplete();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LevelSelectScreen()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Progresso (0..1) dentro da janela [start, end] do controller.
  double _stageT(double start, double end) {
    final t = _controller.value;
    if (t <= start) return 0;
    if (t >= end) return 1;
    return (t - start) / (end - start);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final entrance = Curves.easeOut.transform(_stageT(0, _entranceEnd));
    final powerUp = _stageT(_entranceEnd, _powerUpEnd);
    final idle = _stageT(_powerUpEnd, _idleEnd);
    final exit = _stageT(_idleEnd, 1.0);

    final logoScale = 0.7 + 0.3 * entrance;
    final logoOpacity = entrance;

    // Pisca 2x rápido dentro do estágio power-up, e assenta aceso.
    final glowOpacity =
        powerUp >= 1.0 ? 1.0 : math.sin(powerUp * math.pi * 4).abs();

    // Gira rápido e desacelera (ease-out) dentro do estágio power-up.
    final ringRotation = (1 - math.pow(1 - powerUp, 3)) * math.pi * 2;

    final exitScale = 1.0 + 0.15 * exit;
    final exitOpacity = 1.0 - exit;

    final size = MediaQuery.of(context).size;
    final logoSize = math.min(size.width, size.height) * 0.4;
    final haloSize = logoSize * 1.6;

    return Opacity(
      opacity: exitOpacity,
      child: Transform.scale(
        scale: exitScale,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: haloSize,
                height: haloSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.rotate(
                      angle: ringRotation,
                      child: _ring(haloSize, AppColors.digit5),
                    ),
                    Transform.rotate(
                      angle: -ringRotation * 0.6,
                      child: _ring(haloSize * 0.8, AppColors.digit4),
                    ),
                    Opacity(
                      opacity: glowOpacity,
                      child: Container(
                        width: logoSize * 1.1,
                        height: logoSize * 1.1,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.digit9.withValues(alpha: 0.6),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                    ClipOval(
                      child: SizedBox(
                        width: logoSize,
                        height: logoSize,
                        child: Opacity(
                          opacity: logoOpacity,
                          child: Transform.scale(
                            scale: logoScale,
                            child: Image.asset('assets/images/logo.png'),
                          ),
                        ),
                      ),
                    ),
                    if (idle > 0 && idle < 1) _shimmer(logoSize, idle),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Opacity(
                opacity: powerUp.clamp(0.0, 1.0),
                child: const Text(
                  'NineFuse',
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: haloSize,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: idle,
                    minHeight: 4,
                    backgroundColor: AppColors.darkSurface,
                    valueColor: const AlwaysStoppedAnimation(AppColors.digit9),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ring(double diameter, Color color) => Container(
    width: diameter,
    height: diameter,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: SweepGradient(
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.8),
          color.withValues(alpha: 0.0),
        ],
      ),
    ),
  );

  /// Faixa diagonal translúcida cruzando o logo uma vez, de fora a fora,
  /// durante o estágio idle.
  Widget _shimmer(double diameter, double idle) {
    final dx = (idle * 2 - 0.5) * diameter;
    return ClipOval(
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: diameter * 0.25,
              height: diameter * 2,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
        ),
      ),
    );
  }
}
