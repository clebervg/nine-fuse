import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';
import 'package:nine_fuse/features/game/providers/brush_booster.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';

/// Tabuleiro estável com uma peça no valor [value] em [target], e ruído nas
/// demais células (fora da janela de sorteio do motor de teste) para nenhuma
/// combinação nascer por acidente — nem antes, nem depois de pintar.
Board _boardWithTileAt(Position target, {required int value}) {
  var board = Board.empty();
  for (int row = 0; row < Board.boardSize; row++) {
    for (int col = 0; col < Board.boardSize; col++) {
      final position = Position(row: row, col: col);
      board = board.updateTile(
        position,
        Tile(
          id: 'r${row}c$col',
          value: position == target ? value : (row + col) % 3,
          position: position,
        ),
      );
    }
  }
  return board;
}

/// Harness mínimo do mixin [BrushBooster], sem passar por [GameNotifier] nem
/// pela árvore de widgets — testa só a regra do booster.
class _BrushTestNotifier extends StateNotifier<BrushState> with BrushBooster {
  _BrushTestNotifier() : super(const BrushState());

  Board _board = Board.empty();
  final MatchEngine _engine = MatchEngine(random: Random(1));
  Resolution? lastResolution;

  void setBoard(Board board) => _board = board;

  /// O tabuleiro depois de pintar. Ao contrário do Martelo/Bomba, pintar não
  /// remove peça nenhuma — sem combinação formada não há fusão nem gravidade
  /// a esconder, então `resolution.board` já é o instante certo a conferir,
  /// sem precisar do snapshot pré-queda que os outros dois boosters exigem.
  Board get boardAfter => _board;

  @override
  GameStorage get brushStorage => InMemoryGameStorage();

  @override
  MatchEngine? get brushEngine => _engine;

  @override
  Board get brushBoard => _board;

  @override
  BrushState get brush => state;

  @override
  void writeBrush(BrushState value) => state = value;

  @override
  bool get acceptsBrush => true;

  @override
  void playBrushResolution(MatchEngine engine, Resolution resolution) {
    lastResolution = resolution;
    _board = resolution.board;
  }
}

void main() {
  late void Function() realTargeting;
  late void Function() realRejection;
  late void Function() realPaint;

  setUp(() {
    realTargeting = BrushBooster.targetingFeedback;
    realRejection = BrushBooster.rejectionFeedback;
    realPaint = BrushBooster.paintFeedback;
    BrushBooster.targetingFeedback = () {};
    BrushBooster.rejectionFeedback = () {};
    BrushBooster.paintFeedback = () {};
  });

  tearDown(() {
    BrushBooster.targetingFeedback = realTargeting;
    BrushBooster.rejectionFeedback = realRejection;
    BrushBooster.paintFeedback = realPaint;
  });

  group('Modo Fantasma', () {
    test('mirar sem estoque guarda o alvo pendente, sem pintar', () {
      final harness = _BrushTestNotifier();
      harness.setBoard(
        _boardWithTileAt(const Position(row: 1, col: 1), value: 2),
      );
      harness.toggleBrushTargeting();
      harness.usePaint(const Position(row: 1, col: 1));

      expect(harness.brush.pendingTarget, const Position(row: 1, col: 1));
      expect(harness.brush.count, 0);
      expect(
        harness.boardAfter.getTileAt(const Position(row: 1, col: 1))!.value,
        2,
      );
    });

    test(
      'mirar em alvo inválido com estoque zero rejeita na hora, sem guardar '
      'pendência',
      () {
        final harness = _BrushTestNotifier();
        harness.setBoard(
          _boardWithTileAt(const Position(row: 1, col: 1), value: kMaxDigit),
        );
        var rejections = 0;
        BrushBooster.rejectionFeedback = () => rejections++;

        harness.toggleBrushTargeting();
        harness.usePaint(const Position(row: 1, col: 1));

        expect(rejections, 1);
        expect(harness.brush.pendingTarget, isNull);
        expect(harness.brush.count, 0);
      },
    );

    test('grantBrush credita e pinta o alvo pendente', () {
      final harness = _BrushTestNotifier();
      harness.setBoard(
        _boardWithTileAt(const Position(row: 1, col: 1), value: 2),
      );
      harness.toggleBrushTargeting();
      harness.usePaint(const Position(row: 1, col: 1));

      harness.grantBrush();

      expect(harness.brush.count, 0);
      expect(harness.brush.pendingTarget, isNull);
      expect(
        harness.boardAfter.getTileAt(const Position(row: 1, col: 1))!.value,
        3,
      );
    });
  });
}
