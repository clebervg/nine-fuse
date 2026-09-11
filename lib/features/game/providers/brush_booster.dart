import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';

/// O Pincel, do ponto de vista do estado.
///
/// Espelha [HammerState]/[BombState] de propósito, mas é uma classe **irmã**,
/// não uma generalização: as três mecânicas divergem (célula, área, valor),
/// e a regra do projeto de "não duplicar" vale entre as **duas telas** do
/// mesmo booster, não entre boosters distintos.
///
/// Sem campo de `strike`: ao contrário do Martelo e da Bomba, o Pincel não
/// destrói nada — o `+1` na peça já dispara sozinho o pulo/squash que
/// `TileWidget` toca para qualquer mudança de valor, e não há partícula
/// própria (obstáculo não é afetado) nem tranco de tela a sincronizar.
@immutable
class BrushState {
  const BrushState({this.count = 0, this.isTargeting = false});

  /// Pincéis em estoque. Inventário do jogador, como os outros dois.
  final int count;

  /// O jogador está escolhendo a peça a pintar.
  ///
  /// Sem Modo Fantasma, como a Bomba: estoque zero recusa o toque no dock em
  /// vez de entrar em mira.
  final bool isTargeting;

  BrushState copyWith({int? count, bool? isTargeting}) => BrushState(
    count: count ?? this.count,
    isTargeting: isTargeting ?? this.isTargeting,
  );

  /// O mesmo estoque, sem nada de uma partida.
  BrushState get inventoryOnly => BrushState(count: count);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushState &&
          count == other.count &&
          isTargeting == other.isTargeting;

  @override
  int get hashCode => Object.hash(count, isTargeting);

  @override
  String toString() => 'BrushState($count em estoque, mirando: $isTargeting)';
}

/// A regra do Pincel, compartilhada pelos dois modos de jogo — mesmo desenho
/// de [HammerBooster]/[BombBooster], sem funil de aquisição.
mixin BrushBooster<S> on StateNotifier<S> {
  /// Mesmos dois avisos dos outros boosters: engajar a mira e errar a mira.
  static void Function() targetingFeedback = () {
    HapticFeedback.selectionClick();
    SystemSound.play(SystemSoundType.click);
  };

  static void Function() rejectionFeedback = () =>
      SystemSound.play(SystemSoundType.alert);

  /// Pintar não é destruir — o toque leve de seleção é o suficiente, ao
  /// contrário do `heavyImpact` do Martelo/Bomba.
  static void Function() paintFeedback = HapticFeedback.selectionClick;

  // --- o que cada notifier fornece -------------------------------------------

  GameStorage get brushStorage;

  MatchEngine? get brushEngine;

  Board get brushBoard;

  BrushState get brush;

  void writeBrush(BrushState value);

  bool get acceptsBrush;

  /// Aplica a resolução da pintura. Não conta como movimento, igual aos
  /// outros dois boosters.
  void playBrushResolution(MatchEngine engine, Resolution resolution);

  // --- ações -----------------------------------------------------------------

  void toggleBrushTargeting() {
    if (!acceptsBrush) return;

    if (brush.isTargeting) {
      cancelBrushTargeting();
      return;
    }

    if (brush.count <= 0) {
      rejectionFeedback();
      return;
    }

    targetingFeedback();
    writeBrush(brush.copyWith(isTargeting: true));
    onBrushTargetingStarted();
  }

  void onBrushTargetingStarted() {}

  void cancelBrushTargeting() {
    writeBrush(brush.copyWith(isTargeting: false));
  }

  /// Pinta a peça em [pos]: soma 1 ao valor. Mira errada (fora do tabuleiro,
  /// casa vazia, obstáculo, peça especial, dígito já máximo) avisa e não
  /// cobra — mesma régua do Martelo/Bomba.
  void usePaint(Position pos) {
    if (brushEngine == null || !acceptsBrush || brush.count <= 0) return;

    final engine = brushEngine!;
    final resolution = engine.paintTile(brushBoard, pos);
    if (resolution == null) {
      rejectionFeedback();
      return;
    }

    paintFeedback();
    _setBrushCount(brush.count - 1);
    writeBrush(brush.copyWith(isTargeting: false));

    playBrushResolution(engine, resolution);
  }

  /// Credita pincéis ao inventário do jogador.
  void grantBrush({int count = 1}) => _setBrushCount(brush.count + count);

  void _setBrushCount(int count) {
    writeBrush(brush.copyWith(count: count));
    _persistBrushes(count);
  }

  Future<void> _persistBrushes(int count) async {
    try {
      await brushStorage.writeBrushCount(count);
    } catch (error, stack) {
      debugPrint('Falha ao gravar o inventário de pincéis: $error\n$stack');
    }
  }

  /// Relê o estoque do disco — mesmo remédio dos outros dois boosters.
  Future<void> refreshBrushes() async {
    final before = brush.count;
    try {
      final saved = await brushStorage.readBrushCount();
      if (!mounted || brush.count != before) return;
      writeBrush(brush.copyWith(count: saved));
    } catch (error, stack) {
      debugPrint('Falha ao ler o inventário de pincéis: $error\n$stack');
    }
  }
}
