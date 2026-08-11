import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';

void main() {
  /// Peças cobertas de um tabuleiro, na ordem de varredura.
  List<Tile> blockedTiles(Board board) =>
      board.getAllTiles().where((tile) => tile.isBlocked).toList();

  group('ObstacleLayout', () {
    test('o desenho vazio não pede cobertura nenhuma', () {
      expect(ObstacleLayout.none.total, 0);
      expect(ObstacleLayout.none.isEmpty, isTrue);
      expect(ObstacleLayout.none.types, isEmpty);
    });

    test('total soma as coberturas dos três tipos', () {
      const layout = ObstacleLayout(ice: 2, glass: 1, stone: 3);

      expect(layout.total, 6);
      expect(layout.isEmpty, isFalse);
    });

    test('types expande as quantidades em pedidos individuais', () {
      const layout = ObstacleLayout(ice: 1, glass: 2);

      expect(layout.types, [
        ObstacleType.glass,
        ObstacleType.glass,
        ObstacleType.ice,
      ]);
    });

    test('types entrega o mais duro primeiro', () {
      const layout = ObstacleLayout(ice: 1, glass: 1, stone: 1);

      expect(layout.types, [
        ObstacleType.stone,
        ObstacleType.glass,
        ObstacleType.ice,
      ]);
    });
  });

  group('generateBoard com obstáculos', () {
    test('sem desenho de obstáculo o tabuleiro nasce todo livre', () {
      final board = MatchEngine(random: Random(7)).generateBoard();

      expect(blockedTiles(board), isEmpty);
    });

    test('coloca exatamente as coberturas pedidas', () {
      final board = MatchEngine(
        random: Random(7),
      ).generateBoard(obstacles: const ObstacleLayout(ice: 2, stone: 1));

      final blocked = blockedTiles(board);

      expect(blocked, hasLength(3));
      expect(
        blocked.where((t) => t.obstacle == ObstacleType.ice),
        hasLength(2),
      );
      expect(
        blocked.where((t) => t.obstacle == ObstacleType.stone),
        hasLength(1),
      );
    });

    test('a cobertura nasce com a resistência cheia do tipo', () {
      final board = MatchEngine(
        random: Random(3),
      ).generateBoard(obstacles: const ObstacleLayout(glass: 2));

      for (final tile in blockedTiles(board)) {
        expect(tile.obstacleHp, tile.obstacle.hitPoints);
        expect(tile.isDamaged, isFalse);
      }
    });

    test('duas coberturas nunca nascem encostadas', () {
      // A área de dano é ortogonal: um bloco maciço de coberturas teria células
      // internas que nenhuma fusão alcança até as de fora cederem. Espalhar é
      // o que mantém todo obstáculo atacável desde o primeiro movimento.
      for (int seed = 0; seed < 20; seed++) {
        final board = MatchEngine(
          random: Random(seed),
        ).generateBoard(obstacles: const ObstacleLayout(ice: 3, stone: 2));

        for (final tile in blockedTiles(board)) {
          for (final neighbour in tile.position.orthogonalNeighbours) {
            expect(
              board.getTileAt(neighbour)?.isBlocked ?? false,
              isFalse,
              reason: '${tile.position} encosta em $neighbour (semente $seed)',
            );
          }
        }
      }
    });

    test('o tabuleiro coberto ainda nasce com jogada possível', () {
      // Peça coberta não entra em combinação nem pode ser trocada, então a
      // cobertura entra antes da checagem de jogabilidade — não depois.
      final engine = MatchEngine(random: Random(5));

      for (int seed = 0; seed < 20; seed++) {
        final board = MatchEngine(
          random: Random(seed),
        ).generateBoard(obstacles: const ObstacleLayout(ice: 2, glass: 2));

        expect(engine.hasValidMoves(board), isTrue, reason: 'semente $seed');
      }
    });

    test('o dígito continua embaixo da cobertura', () {
      final board = MatchEngine(
        random: Random(9),
      ).generateBoard(obstacles: const ObstacleLayout(stone: 3));

      for (final tile in blockedTiles(board)) {
        expect(tile.value, inInclusiveRange(kSpawnMin, kSpawnMax));
      }
    });

    test('sementes diferentes espalham as coberturas em lugares diferentes', () {
      Set<Position> spots(int seed) => MatchEngine(random: Random(seed))
          .generateBoard(obstacles: const ObstacleLayout(ice: 3))
          .getAllTiles()
          .where((t) => t.isBlocked)
          .map((t) => t.position)
          .toSet();

      expect(spots(1), isNot(spots(2)));
    });
  });

  group('placeObstacles no tabuleiro em jogo', () {
    test('acrescenta cobertura sem tocar nas que já existem', () {
      final engine = MatchEngine(random: Random(4));
      final start = engine.generateBoard(
        obstacles: const ObstacleLayout(stone: 1),
      );
      final before = blockedTiles(start).single;

      final after = engine.placeObstacles(
        start,
        const ObstacleLayout(ice: 2),
      );

      expect(after.getTileAt(before.position), before);
      expect(blockedTiles(after), hasLength(3));
    });

    test('respeita a não-adjacência contra as coberturas já postas', () {
      final engine = MatchEngine(random: Random(4));
      var board = engine.generateBoard(
        obstacles: const ObstacleLayout(stone: 2),
      );

      board = engine.placeObstacles(board, const ObstacleLayout(ice: 3));

      for (final tile in blockedTiles(board)) {
        for (final neighbour in tile.position.orthogonalNeighbours) {
          expect(board.getTileAt(neighbour)?.isBlocked ?? false, isFalse);
        }
      }
    });

    test('desiste da cobertura que deixaria a partida sem jogada', () {
      // No Endless o tabuleiro é o do jogador, não um recém-sorteado: cobrir
      // demais aqui seria um fim de jogo fabricado pelo próprio jogo.
      final engine = MatchEngine(random: Random(4));
      final start = engine.generateBoard();

      final after = engine.placeObstacles(
        start,
        const ObstacleLayout(stone: 99),
      );

      expect(engine.hasValidMoves(after), isTrue);
    });

    test('o desenho vazio devolve o mesmo tabuleiro', () {
      final engine = MatchEngine(random: Random(4));
      final start = engine.generateBoard();

      expect(engine.placeObstacles(start, ObstacleLayout.none), same(start));
    });
  });
}
