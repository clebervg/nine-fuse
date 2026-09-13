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
  const BrushState({this.count = 0, this.isTargeting = false, this.pendingTarget});

  /// Pincéis em estoque. Inventário do jogador, como os outros dois.
  final int count;

  /// O jogador está escolhendo a peça a pintar.
  ///
  /// Modo Fantasma, mesma regra do Martelo/Bomba: liga mesmo com estoque
  /// zero. `usePaint` é quem decide, na hora do toque, se pinta de verdade
  /// ou só guarda o alvo.
  final bool isTargeting;

  /// Peça escolhida no Modo Fantasma, à espera do pincel.
  ///
  /// Mesma regra do Martelo/Bomba: guardá-la evita cobrar duas vezes pela
  /// mesma pintura, e quem assistiu ao anúncio (ou comprou) não precisa
  /// mirar de novo.
  final Position? pendingTarget;

  BrushState copyWith({
    int? count,
    bool? isTargeting,
    Position? pendingTarget,
    bool clearPendingTarget = false,
  }) => BrushState(
    count: count ?? this.count,
    isTargeting: isTargeting ?? this.isTargeting,
    pendingTarget: clearPendingTarget
        ? null
        : (pendingTarget ?? this.pendingTarget),
  );

  /// O mesmo estoque, sem nada de uma partida.
  BrushState get inventoryOnly => BrushState(count: count);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushState &&
          count == other.count &&
          isTargeting == other.isTargeting &&
          pendingTarget == other.pendingTarget;

  @override
  int get hashCode => Object.hash(count, isTargeting, pendingTarget);

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

    // Modo Fantasma: entra em mira mesmo com estoque zero — mesma regra do
    // Martelo/Bomba. `usePaint` é quem decide, na hora do toque, se pinta
    // de verdade ou só guarda o alvo.
    targetingFeedback();
    writeBrush(brush.copyWith(isTargeting: true));
    onBrushTargetingStarted();
  }

  void onBrushTargetingStarted() {}

  /// Sai do modo de mira, descartando o alvo pendente.
  void cancelBrushTargeting() {
    writeBrush(brush.copyWith(isTargeting: false, clearPendingTarget: true));
  }

  /// Pinta a peça em [pos]: soma 1 ao valor. Mira errada (fora do tabuleiro,
  /// casa vazia, obstáculo, peça especial, dígito já máximo) avisa e não
  /// cobra — mesma régua do Martelo/Bomba.
  ///
  /// Com estoque zero o alvo é apenas guardado, e quem abre o convite de
  /// aquisição é a tela. A pintura sai depois, em [grantBrush].
  void usePaint(Position pos) {
    if (brushEngine == null || !acceptsBrush) return;

    if (!_isPaintable(pos)) {
      rejectionFeedback();
      return;
    }

    if (brush.count <= 0) {
      writeBrush(brush.copyWith(pendingTarget: pos));
      return;
    }

    _paint(pos);
  }

  /// Mesma checagem de [MatchEngine.paintTile], repetida aqui para poder
  /// recusar **antes** do Modo Fantasma guardar um alvo que o motor já sabe
  /// que nunca vai pintar — mesma régua do Martelo/Bomba.
  bool _isPaintable(Position pos) {
    if (!Board.contains(pos)) return false;
    final tile = brushBoard.getTileAt(pos);
    return tile != null &&
        !tile.isBlocked &&
        tile.specialType == null &&
        tile.value < kMaxDigit;
  }

  /// Credita pincéis e, se havia alvo escolhido no Modo Fantasma, pinta
  /// nele.
  void grantBrush({int count = 1}) {
    _setBrushCount(brush.count + count);

    final pending = brush.pendingTarget;
    if (pending == null || brushEngine == null || !acceptsBrush) return;

    _paint(pending);
  }

  void _paint(Position pos) {
    final engine = brushEngine!;
    final resolution = engine.paintTile(brushBoard, pos);
    if (resolution == null) {
      // O alvo pode ter ficado inválido (peça já no teto, virou especial,
      // sumiu) enquanto o anúncio rodava — mesmo caso que `grantBomb` trata.
      // O pincel já foi creditado; só a mira falha, sem cobrar de novo.
      rejectionFeedback();
      writeBrush(brush.copyWith(clearPendingTarget: true));
      return;
    }

    paintFeedback();
    _setBrushCount(brush.count - 1);
    writeBrush(brush.copyWith(isTargeting: false, clearPendingTarget: true));

    playBrushResolution(engine, resolution);
  }

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
