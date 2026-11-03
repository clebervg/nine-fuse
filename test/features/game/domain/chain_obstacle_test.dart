import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';

Position p(int row, int col) => Position(row: row, col: col);

/// Base diagonal sem combinação, com [overrides] de valor e [chained] presas.
Board chainBoard({
  Map<Position, int> overrides = const {},
  Set<Position> chained = const {},
}) {
  var board = Board.empty();
  for (int row = 0; row < Board.boardSize; row++) {
    for (int col = 0; col < Board.boardSize; col++) {
      final position = p(row, col);
      var tile = Tile(
        id: 'r${row}c$col',
        value: overrides[position] ?? (row + col) % 3,
        position: position,
      );
      if (chained.contains(position)) {
        tile = tile.withObstacle(ObstacleType.chain);
      }
      board = board.updateTile(position, tile);
    }
  }
  return board;
}

void main() {
  late MatchEngine engine;
  setUp(() => engine = MatchEngine(random: Random(5)));

  test('a corrente tem um impacto, combina e segura a peça no lugar', () {
    expect(ObstacleType.chain.hitPoints, 1);
    expect(ObstacleType.chain.blocksMatch, isFalse);
    expect(ObstacleType.chain.isAnchored, isTrue);
    for (final type in [
      ObstacleType.ice,
      ObstacleType.glass,
      ObstacleType.stone,
    ]) {
      expect(type.blocksMatch, isTrue, reason: '$type');
      expect(type.isAnchored, isFalse, reason: '$type');
    }
  });

  test('peça acorrentada entra em combinação', () {
    final board = chainBoard(
      overrides: {p(3, 0): 5, p(3, 1): 5, p(3, 2): 5},
      chained: {p(3, 1)},
    );
    expect(engine.detectMatches(board), hasLength(1));
  });

  test('peça acorrentada não pode ser trocada', () {
    final board = chainBoard(chained: {p(3, 3)});
    expect(engine.tryMove(board, p(3, 3), p(3, 4)), isA<MoveImpossible>());
    expect(engine.tryMove(board, p(3, 4), p(3, 3)), isA<MoveImpossible>());
    for (final (a, b) in engine.candidateSwaps(board)) {
      expect(a == p(3, 3) || b == p(3, 3), isFalse);
    }
  });

  test('a peça acorrentada não cai, e as de cima empilham sobre ela', () {
    // Coluna 4: corrente na linha 5. Esvaziar a linha 6 (abaixo da corrente)
    // não puxa a corrente nem nada acima dela; esvaziar a linha 2 (acima)
    // faz as linhas 0-1 descerem até encostar na corrente.
    final board = chainBoard(chained: {p(5, 4)});
    final chained = board.getTileAt(p(5, 4))!;
    final top = board.getTileAt(p(0, 4))!;

    final settled = engine.applyGravity(
      board.updateTile(p(6, 4), null).updateTile(p(2, 4), null),
    );

    expect(settled.getTileAt(p(5, 4))?.id, chained.id);
    expect(settled.getTileAt(p(6, 4)), isNull, reason: 'abaixo só repõe');
    expect(settled.getTileAt(p(1, 4))?.id, top.id);
    expect(settled.getTileAt(p(0, 4)), isNull);
    expect(engine.refill(settled).isFull, isTrue);
  });

  test('entrar na combinação rompe a corrente e conta como quebra', () {
    // Trio de 5 na linha 3, a do meio acorrentada; a troca (4,3)↔(3,3)
    // traz o terceiro 5.
    final board = chainBoard(
      overrides: {p(3, 1): 5, p(3, 2): 5, p(4, 3): 5},
      chained: {p(3, 2)},
    );

    final result = engine.tryMove(board, p(4, 3), p(3, 3));

    expect(result, isA<MoveResolved>());
    final resolution = (result as MoveResolved).resolution;
    expect(resolution.countCleared(ObstacleType.chain), 1);
    expect(resolution.board.countObstacles(ObstacleType.chain), 0);
  });

  test('a peça que nasce de uma sobrevivente acorrentada nasce livre', () {
    final board = chainBoard(
      overrides: {p(3, 0): 5, p(3, 1): 5, p(3, 2): 5},
      chained: {p(3, 1)},
    );
    // Sem âncora, a fusão nasce no meio do trio: justamente a acorrentada.
    final outcome = engine.fuse(board);
    final born = outcome.board.getTileAt(p(3, 1))!;
    expect(born.value, 6);
    expect(born.isBlocked, isFalse);
    expect(outcome.obstacleHits.single.type, ObstacleType.chain);
  });

  test('fusão encostada rompe a corrente vizinha, um impacto por passo', () {
    final board = chainBoard(
      overrides: {p(3, 1): 5, p(3, 2): 5, p(4, 3): 5},
      chained: {p(2, 2)},
    );
    final result = engine.tryMove(board, p(4, 3), p(3, 3)) as MoveResolved;
    final first = result.resolution.steps.first;
    final chainHits = first.obstacleHits.where(
      (h) => h.type == ObstacleType.chain,
    );
    expect(chainHits, hasLength(1));
    expect(chainHits.single.cleared, isTrue);
  });

  test('o sorteio espalha correntes e o tabuleiro continua jogável', () {
    for (int seed = 0; seed < 10; seed++) {
      final e = MatchEngine(random: Random(seed));
      final board = e.generateBoard(
        obstacles: const ObstacleLayout(ice: 2, chain: 3),
      );
      expect(board.countObstacles(ObstacleType.chain), 3, reason: 'seed $seed');
      expect(e.hasValidMoves(board), isTrue, reason: 'seed $seed');
    }
  });
}
