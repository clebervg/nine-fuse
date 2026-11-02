import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';
import 'package:nine_fuse/features/game/providers/bomb_booster.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';

/// Tabuleiro estável com uma peça no valor [value] em [target], e ruído nas
/// demais células (fora da janela de sorteio do motor de teste) para nenhuma
/// combinação nascer por acidente.
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

/// Harness mínimo do mixin [BombBooster], sem passar por [GameNotifier] nem
/// pela árvore de widgets — testa só a regra do booster.
class _BombTestNotifier extends StateNotifier<BombState> with BombBooster {
  _BombTestNotifier() : super(const BombState());

  Board _board = Board.empty();
  Board? _boardAfterStrike;
  final MatchEngine _engine = MatchEngine(random: Random(1));
  Resolution? lastResolution;

  void setBoard(Board board) => _board = board;

  /// O tabuleiro logo após o estouro, **antes** da gravidade/reabastecimento
  /// reencherem o buraco — é o instante em que a explosão em si pode ser
  /// verificada, sem depender do sorteio aleatório que a completa em seguida.
  Board get boardAfter => _boardAfterStrike ?? _board;

  @override
  GameStorage get bombStorage => InMemoryGameStorage();

  @override
  MatchEngine? get bombEngine => _engine;

  @override
  Board get bombBoard => _board;

  @override
  BombState get bomb => state;

  @override
  void writeBomb(BombState value) => state = value;

  @override
  bool get acceptsBomb => true;

  @override
  void playBombResolution(MatchEngine engine, Resolution resolution) {
    lastResolution = resolution;
    _boardAfterStrike = resolution.steps.first.boardAfterFusion;
    _board = resolution.board;
  }
}

void main() {
  late void Function() realTargeting;
  late void Function() realRejection;
  late void Function() realStrike;

  setUp(() {
    realTargeting = BombBooster.targetingFeedback;
    realRejection = BombBooster.rejectionFeedback;
    realStrike = BombBooster.strikeFeedback;
    BombBooster.targetingFeedback = () {};
    BombBooster.rejectionFeedback = () {};
    BombBooster.strikeFeedback = () {};
  });

  tearDown(() {
    BombBooster.targetingFeedback = realTargeting;
    BombBooster.rejectionFeedback = realRejection;
    BombBooster.strikeFeedback = realStrike;
  });

  group('Modo Fantasma', () {
    test('mirar sem estoque guarda o alvo pendente, sem explodir', () {
      final harness = _BombTestNotifier();
      harness.setBoard(
        _boardWithTileAt(const Position(row: 2, col: 2), value: 3),
      );
      harness.toggleBombTargeting();
      harness.useBomb(const Position(row: 2, col: 2));

      expect(harness.bomb.pendingTarget, const Position(row: 2, col: 2));
      expect(harness.bomb.count, 0);
      expect(
        harness.boardAfter.getTileAt(const Position(row: 2, col: 2)),
        isNotNull,
      );
    });

    test('grantBomb credita e explode o alvo pendente', () {
      final harness = _BombTestNotifier();
      harness.setBoard(
        _boardWithTileAt(const Position(row: 2, col: 2), value: 3),
      );
      harness.toggleBombTargeting();
      harness.useBomb(const Position(row: 2, col: 2));

      harness.grantBomb();

      expect(harness.bomb.count, 0); // creditou 1 e já gastou no golpe
      expect(harness.bomb.pendingTarget, isNull);
      expect(
        harness.boardAfter.getTileAt(const Position(row: 2, col: 2)),
        isNull,
      );
    });
  });
}
