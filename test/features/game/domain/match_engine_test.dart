import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/fusion_rule.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';

/// Monta um tabuleiro 8x8 a partir de uma matriz de valores.
Board boardFromValues(List<List<int>> values) {
  var board = Board.empty();
  for (int row = 0; row < Board.boardSize; row++) {
    for (int col = 0; col < Board.boardSize; col++) {
      final position = Position(row: row, col: col);
      board = board.updateTile(
        position,
        Tile(id: 'r${row}c$col', value: values[row][col], position: position),
      );
    }
  }
  return board;
}

/// Base sem nenhuma combinação: faixas diagonais de período 3 nunca produzem
/// três valores iguais seguidos em linha ou coluna.
List<List<int>> baseGrid() => [
  for (int row = 0; row < Board.boardSize; row++)
    [for (int col = 0; col < Board.boardSize; col++) (row + col) % 3],
];

List<List<int>> valuesOf(Board board) => [
  for (int row = 0; row < Board.boardSize; row++)
    [
      for (int col = 0; col < Board.boardSize; col++)
        board.getTileAt(Position(row: row, col: col))?.value ?? -1,
    ],
];

void main() {
  late MatchEngine engine;

  setUp(() {
    engine = MatchEngine(random: Random(7));
  });

  group('detectMatches', () {
    test('base diagonal não tem nenhuma combinação', () {
      expect(engine.detectMatches(boardFromValues(baseGrid())), isEmpty);
    });

    test('encontra combinação horizontal', () {
      final grid = baseGrid();
      grid[3][1] = 5;
      grid[3][2] = 5;
      grid[3][3] = 5;

      final matches = engine.detectMatches(boardFromValues(grid));

      expect(matches, hasLength(1));
      expect(
        matches.single,
        containsAll([
          Position(row: 3, col: 1),
          Position(row: 3, col: 2),
          Position(row: 3, col: 3),
        ]),
      );
    });

    test('encontra combinação vertical', () {
      final grid = baseGrid();
      grid[2][4] = 6;
      grid[3][4] = 6;
      grid[4][4] = 6;

      final matches = engine.detectMatches(boardFromValues(grid));

      expect(matches, hasLength(1));
      expect(matches.single, hasLength(3));
    });

    test('combinações retornadas nunca compartilham peças', () {
      final grid = baseGrid();
      for (final col in [2, 3, 4]) {
        grid[4][col] = 7;
      }
      for (final row in [4, 5, 6]) {
        grid[row][3] = 7;
      }

      final matches = engine.detectMatches(boardFromValues(grid));
      final seen = <Position>{};

      for (final match in matches) {
        for (final position in match) {
          expect(
            seen.add(position),
            isTrue,
            reason: '$position apareceu em duas combinações',
          );
        }
      }
    });

    group('formatos cruzados', () {
      test('um T conta como uma combinação só, com todas as peças', () {
        // Trio horizontal na linha 4 cruzando um trio vertical na coluna 3.
        final grid = baseGrid();
        for (final col in [2, 3, 4]) {
          grid[4][col] = 7;
        }
        for (final row in [4, 5, 6]) {
          grid[row][3] = 7;
        }

        final matches = engine.detectMatches(boardFromValues(grid));

        expect(
          matches,
          hasLength(1),
          reason: 'os dois braços deveriam formar uma combinação só',
        );
        // 3 + 3 com uma casa em comum = 5 peças.
        expect(matches.single, hasLength(5));
      });

      test('um L também junta os dois braços', () {
        final grid = baseGrid();
        for (final col in [1, 2, 3]) {
          grid[2][col] = 6;
        }
        for (final row in [2, 3, 4]) {
          grid[row][1] = 6;
        }

        final matches = engine.detectMatches(boardFromValues(grid));

        expect(matches, hasLength(1));
        expect(matches.single, hasLength(5));
      });

      test('uma cruz junta os quatro braços', () {
        final grid = baseGrid();
        for (final col in [2, 3, 4]) {
          grid[4][col] = 5;
        }
        for (final row in [3, 4, 5]) {
          grid[row][3] = 5;
        }

        final matches = engine.detectMatches(boardFromValues(grid));

        expect(matches, hasLength(1));
        expect(matches.single, hasLength(5));
      });

      test('sequências do mesmo valor que não se tocam ficam separadas', () {
        final grid = baseGrid();
        for (final col in [1, 2, 3]) {
          grid[1][col] = 6;
        }
        grid[1][4] = 0;
        for (final col in [1, 2, 3]) {
          grid[6][col] = 6;
        }
        grid[6][4] = 0;

        expect(engine.detectMatches(boardFromValues(grid)), hasLength(2));
      });

      test('o L paga por tamanho, não pelo braço mais longo', () {
        // É o ganho de verdade: com 5 peças a regra graduada dá V+2, enquanto
        // antes o braço perdido rendia apenas V+1.
        final grid = baseGrid();
        for (final col in [1, 2, 3]) {
          grid[2][col] = 4;
        }
        for (final row in [2, 3, 4]) {
          grid[row][1] = 4;
        }

        final outcome = engine.fuse(boardFromValues(grid));

        expect(outcome.produced, [6], reason: '4 + 2 níveis, não 4 + 1');
      });

      test('a fusão de um L nasce no cruzamento', () {
        final grid = baseGrid();
        for (final col in [1, 2, 3]) {
          grid[2][col] = 4;
        }
        for (final row in [2, 3, 4]) {
          grid[row][1] = 4;
        }

        final outcome = engine.fuse(boardFromValues(grid));

        // (2,1) é a única casa que pertence aos dois braços.
        expect(outcome.board.getTileAt(Position(row: 2, col: 1))?.value, 6);
      });

      test('a âncora do jogador ainda tem prioridade sobre o cruzamento', () {
        final grid = baseGrid();
        for (final col in [1, 2, 3]) {
          grid[2][col] = 4;
        }
        for (final row in [2, 3, 4]) {
          grid[row][1] = 4;
        }
        const anchor = Position(row: 4, col: 1);

        final outcome = engine.fuse(boardFromValues(grid), anchor: anchor);

        expect(outcome.board.getTileAt(anchor)?.value, 6);
      });
    });
  });

  group('fuse (uma passada, sem gravidade)', () {
    // Este grupo cobre a contagem exata de peças que uma combinação consome e
    // devolve. Faltava — e um bug em que o match-3 produzia TRÊS peças de V+1
    // em vez de uma passou por 77 testes sem ser notado, porque todos olhavam
    // efeitos agregados (cascatas, tabuleiro cheio) em vez do contrato.

    test('match-3 troca três peças por exatamente uma de V+1', () {
      final grid = baseGrid();
      for (final col in [2, 3, 4]) {
        grid[4][col] = 5;
      }
      final board = boardFromValues(grid);

      final outcome = engine.fuse(board);

      expect(outcome.produced, [6], reason: 'uma única peça, de valor 6');

      // Duas das três casas ficam vazias, uma recebe o 6.
      final cells = [
        for (final col in [2, 3, 4])
          outcome.board.getTileAt(Position(row: 4, col: col))?.value,
      ];
      expect(cells.where((v) => v == 6), hasLength(1));
      expect(cells.where((v) => v == null), hasLength(2));
      expect(outcome.board.tileCount, board.tileCount - 2);
    });

    test('match-4 graduado devolve V+1 e V, consumindo duas casas', () {
      final grid = baseGrid();
      for (final col in [2, 3, 4, 5]) {
        grid[4][col] = 5;
      }
      final board = boardFromValues(grid);

      final outcome = MatchEngine(
        random: Random(1),
        fusionRule: const TieredFusion(),
      ).fuse(board);

      expect(outcome.produced, containsAll([6, 5]));
      expect(outcome.produced, hasLength(2));
      expect(outcome.board.tileCount, board.tileCount - 2);
    });

    test('match-5 graduado devolve uma só peça de V+2', () {
      final grid = baseGrid();
      for (final col in [1, 2, 3, 4, 5]) {
        grid[4][col] = 4;
      }
      final board = boardFromValues(grid);

      final outcome = MatchEngine(
        random: Random(1),
        fusionRule: const TieredFusion(),
      ).fuse(board);

      expect(outcome.produced, [6]);
      expect(outcome.board.tileCount, board.tileCount - 4);
    });

    test('match-3 neutro em sequência longa ainda devolve uma peça', () {
      final grid = baseGrid();
      for (final col in [1, 2, 3, 4, 5]) {
        grid[4][col] = 4;
      }

      final outcome = MatchEngine(
        random: Random(1),
        fusionRule: const NeutralFusion(),
      ).fuse(boardFromValues(grid));

      expect(outcome.produced, [5]);
    });

    test('tabuleiro sem combinação não produz nada', () {
      final outcome = engine.fuse(boardFromValues(baseGrid()));

      expect(outcome.isEmpty, isTrue);
      expect(outcome.produced, isEmpty);
      expect(outcome.score, 0);
    });

    test('duas combinações separadas produzem duas peças', () {
      final grid = baseGrid();
      for (final col in [1, 2, 3]) {
        grid[1][col] = 5;
      }
      grid[1][4] = 0;
      for (final col in [1, 2, 3]) {
        grid[6][col] = 2;
      }
      grid[6][4] = 0;

      final outcome = engine.fuse(boardFromValues(grid));

      expect(outcome.produced, hasLength(2));
      expect(outcome.produced, containsAll([6, 3]));
    });

    test('a peça da fusão nasce na âncora quando ela participa', () {
      final grid = baseGrid();
      for (final col in [2, 3, 4]) {
        grid[4][col] = 5;
      }
      const anchor = Position(row: 4, col: 4);

      final outcome = engine.fuse(boardFromValues(grid), anchor: anchor);

      expect(outcome.board.getTileAt(anchor)?.value, 6);
    });
  });

  group('applyGravity', () {
    test('empurra as peças para a base da coluna', () {
      var board = Board.empty();
      for (final row in [0, 3, 5]) {
        final position = Position(row: row, col: 2);
        board = board.updateTile(
          position,
          Tile(id: 'v$row', value: row, position: position),
        );
      }

      final result = engine.applyGravity(board);
      final column = result.getTilesInCol(2);

      // Três peças caem para as três últimas linhas, na ordem original.
      expect(column.map((t) => t.position.row), [5, 6, 7]);
      expect(column.map((t) => t.value), [0, 3, 5]);
    });

    test('a posição da peça é atualizada junto com a queda', () {
      var board = Board.empty();
      const origin = Position(row: 1, col: 0);
      board = board.updateTile(
        origin,
        const Tile(id: 'x', value: 4, position: origin),
      );

      final moved = engine
          .applyGravity(board)
          .getTileAt(Position(row: Board.boardSize - 1, col: 0));

      expect(moved, isNotNull);
      expect(moved!.position, Position(row: Board.boardSize - 1, col: 0));
    });
  });

  group('refill', () {
    test('preenche todas as células vazias', () {
      var board = boardFromValues(baseGrid());
      board = board.updateTile(Position(row: 0, col: 0), null);
      board = board.updateTile(Position(row: 0, col: 1), null);

      final filled = engine.refill(board);

      expect(filled.isFull, isTrue);
      expect(filled.getEmptyPositions(), isEmpty);
    });

    test('só sorteia valores dentro da janela de spawn', () {
      final filled = engine.refill(Board.empty());

      for (final tile in filled.getAllTiles()) {
        expect(tile.value, inInclusiveRange(engine.spawnMin, engine.spawnMax));
      }
    });

    test('respeita uma janela de spawn deslocada', () {
      final elevated = MatchEngine(random: Random(5), spawnMin: 3, spawnMax: 6);

      for (final tile in elevated.refill(Board.empty()).getAllTiles()) {
        expect(tile.value, inInclusiveRange(3, 6));
      }
    });

    test('a janela deslocada também vale na criação do tabuleiro', () {
      final elevated = MatchEngine(random: Random(5), spawnMin: 2, spawnMax: 5);

      for (final tile in elevated.generateBoard().getAllTiles()) {
        expect(tile.value, inInclusiveRange(2, 5));
      }
    });
  });

  group('resolve', () {
    /// Trio horizontal no canto inferior esquerdo. Ao fundir, as peças de
    /// valor 2 logo acima caem e formam um novo trio — uma cascata.
    List<List<int>> cascadeGrid() {
      final grid = baseGrid();
      grid[7][0] = 1;
      grid[7][1] = 1;
      grid[7][2] = 1;
      grid[7][3] = 0; // impede que o trio virasse uma sequência de 4
      grid[6][0] = 2;
      grid[6][1] = 0;
      grid[6][2] = 2;
      return grid;
    }

    test('o tabuleiro de cascata começa com exatamente uma combinação', () {
      final matches = engine.detectMatches(boardFromValues(cascadeGrid()));

      expect(matches, hasLength(1));
      expect(matches.single.map((p) => p.col), containsAll([0, 1, 2]));
      expect(matches.single.every((p) => p.row == 7), isTrue);
    });

    test('resolve encadeia cascatas em vez de parar na primeira fusão', () {
      final resolution = engine.resolve(boardFromValues(cascadeGrid()));

      expect(
        resolution.cascades,
        greaterThanOrEqualTo(2),
        reason: 'a queda das peças deveria formar uma nova combinação',
      );
      expect(resolution.fusions, greaterThanOrEqualTo(2));
      expect(resolution.score, greaterThan(0));
    });

    test('deixa o tabuleiro cheio e estável', () {
      final resolution = engine.resolve(boardFromValues(cascadeGrid()));

      expect(
        resolution.board.isFull,
        isTrue,
        reason: 'sem reposição no topo o tabuleiro esvazia',
      );
      expect(
        engine.detectMatches(resolution.board),
        isEmpty,
        reason: 'resolve deve parar só quando não há mais combinação',
      );
    });

    test('sem âncora, a peça evoluída nasce no centro da combinação', () {
      final grid = baseGrid();
      for (final col in [2, 3, 4]) {
        grid[0][col] = 5;
      }
      // Só a primeira fusão interessa: gravidade e reposição vêm depois.
      final fused = engine.resolve(boardFromValues(grid));

      expect(fused.fusions, greaterThanOrEqualTo(1));
    });

    test('com âncora, a peça evoluída nasce na posição tocada', () {
      final grid = baseGrid();
      for (final col in [2, 3, 4]) {
        grid[0][col] = 5;
      }
      const anchor = Position(row: 0, col: 2);

      final resolution = engine.resolve(boardFromValues(grid), anchor: anchor);

      // A peça 6 nasce em (0,2) e, como está no topo, a gravidade a derruba
      // pela coluna 2 — logo ela deve terminar na coluna 2.
      final six = resolution.board
          .getAllTiles()
          .where((t) => t.value == 6)
          .toList();

      expect(six, isNotEmpty, reason: 'a fusão de três 5 deveria gerar um 6');
      expect(
        six.any((t) => t.position.col == anchor.col),
        isTrue,
        reason: 'a peça evoluída deveria ter nascido na coluna da âncora',
      );
    });

    test('combinação no dígito máximo é consumida sem estourar a escala', () {
      final grid = baseGrid();
      for (final col in [2, 3, 4]) {
        grid[5][col] = kMaxDigit;
      }

      final resolution = engine.resolve(boardFromValues(grid));

      for (final tile in resolution.board.getAllTiles()) {
        expect(tile.value, lessThanOrEqualTo(kMaxDigit));
      }
    });

    test('tabuleiro sem combinação não é alterado', () {
      final board = boardFromValues(baseGrid());
      final resolution = engine.resolve(board);

      expect(resolution.cascades, 0);
      expect(resolution.score, 0);
      expect(valuesOf(resolution.board), valuesOf(board));
    });

    test('o orçamento de cascata para o loop em 4 passos, mesmo com match pendente', () {
      // Corrente de match-3 que se realimenta: cada fusão de "1" cria um "2"
      // que completa outro trio na linha de baixo, e assim por diante — sem
      // limite, isso rodaria mais de 4 vezes.
      final grid = baseGrid();
      for (int row = 0; row < 6; row++) {
        grid[row][0] = 1;
        grid[row][1] = 1;
        grid[row][2] = 0;
      }
      grid[6][0] = 9;
      grid[6][1] = 9;
      grid[6][2] = 9;
      grid[7][0] = 9;
      grid[7][1] = 9;
      grid[7][2] = 9;

      final resolution = engine.resolve(boardFromValues(grid));

      expect(resolution.steps.length, lessThanOrEqualTo(kCascadeBudgetPerTurn));
    });
  });

  group('configuração padrão', () {
    // Decisões de produto tomadas com base em tool/simulate_economy.dart.
    // Estão fixadas aqui para que uma mudança de padrão seja deliberada.
    test('usa a regra graduada, que nunca destrói valor', () {
      final engine = MatchEngine(random: Random(0));

      expect(engine.fusionRule, isA<TieredFusion>());
      expect(engine.fusionRule.valueMultiplier(4), greaterThanOrEqualTo(1.0));
      expect(engine.fusionRule.valueMultiplier(5), greaterThanOrEqualTo(1.0));
    });

    test('o dígito máximo explode em área', () {
      expect(
        MatchEngine(random: Random(0)).explosionShape,
        ExplosionShape.area,
      );
    });

    test('começa sorteando 0-3, como pede o design do MVP', () {
      final engine = MatchEngine(random: Random(0));

      expect(engine.spawnMin, 0);
      expect(engine.spawnMax, 3);
    });
  });

  group('explosão do dígito máximo', () {
    /// Trio de 8 no meio do tabuleiro: fundir gera um 9, que deve estourar.
    /// Fica na linha 3 para que a explosão tenha vizinhança em todos os lados.
    List<List<int>> nineGrid() {
      final grid = baseGrid();
      for (final col in [2, 3, 4]) {
        grid[3][col] = kMaxDigit - 1;
      }
      grid[3][5] = 0; // impede que o trio se torne uma sequência de 4
      return grid;
    }

    test('a fusão de três 8 realmente cria um 9', () {
      final engine = MatchEngine(
        random: Random(1),
        explosionShape: ExplosionShape.none,
      );

      final resolution = engine.resolve(boardFromValues(nineGrid()));

      expect(resolution.highestProduced, kMaxDigit);
    });

    test('sem explosão, o 9 permanece ocupando célula', () {
      final engine = MatchEngine(
        random: Random(1),
        spawnMin: 0,
        spawnMax: 3,
        explosionShape: ExplosionShape.none,
      );

      final resolution = engine.resolve(boardFromValues(nineGrid()));

      expect(resolution.explosions, 0);
      // O spawn nunca gera 9, então um 9 no tabuleiro só pode ser o da fusão.
      expect(
        resolution.board.getAllTiles().where((t) => t.value == kMaxDigit),
        hasLength(1),
      );
    });

    test('com explosão, o 9 se consome em vez de ficar no tabuleiro', () {
      final engine = MatchEngine(
        random: Random(1),
        spawnMin: 0,
        spawnMax: 3,
        explosionShape: ExplosionShape.area,
      );

      final resolution = engine.resolve(boardFromValues(nineGrid()));

      expect(resolution.explosions, 1);
      expect(
        resolution.board.getAllTiles().where((t) => t.value == kMaxDigit),
        isEmpty,
        reason: 'a peça no topo da escala deveria ter saído do tabuleiro',
      );
    });

    test('a explosão em cruz limpa mais que a em área', () {
      // Mesmo tabuleiro e mesma semente: a diferença é só o formato.
      var areaScore = 0;
      var crossScore = 0;

      for (final shape in [ExplosionShape.area, ExplosionShape.cross]) {
        final resolution = MatchEngine(
          random: Random(2),
          explosionShape: shape,
        ).resolve(boardFromValues(nineGrid()));

        if (shape == ExplosionShape.area) {
          areaScore = resolution.score;
        } else {
          crossScore = resolution.score;
        }
      }

      expect(crossScore, greaterThan(areaScore));
    });

    test('o tabuleiro volta a ficar cheio depois de estourar', () {
      final engine = MatchEngine(
        random: Random(3),
        explosionShape: ExplosionShape.cross,
      );

      final resolution = engine.resolve(boardFromValues(nineGrid()));

      expect(resolution.explosions, greaterThanOrEqualTo(1));
      expect(
        resolution.board.isFull,
        isTrue,
        reason: 'a reposição deve preencher o rastro da explosão',
      );
      expect(engine.detectMatches(resolution.board), isEmpty);
    });

    test('a explosão não deixa nenhuma peça acima do dígito máximo', () {
      // Com a regra graduada um match-5 de 8 pediria 10; precisa ser contido.
      final grid = baseGrid();
      for (final col in [1, 2, 3, 4, 5]) {
        grid[3][col] = kMaxDigit - 1;
      }

      final resolution = MatchEngine(
        random: Random(6),
        fusionRule: const TieredFusion(),
      ).resolve(boardFromValues(grid));

      for (final tile in resolution.board.getAllTiles()) {
        expect(tile.value, lessThanOrEqualTo(kMaxDigit));
      }
    });

    test('nenhuma explosão acontece quando nada alcança o topo', () {
      final engine = MatchEngine(random: Random(1));
      final grid = baseGrid();
      for (final col in [2, 3, 4]) {
        grid[3][col] = 4;
      }

      expect(engine.resolve(boardFromValues(grid)).explosions, 0);
    });
  });

  group('findHint', () {
    test('devolve uma troca que realmente forma combinação', () {
      final grid = baseGrid();
      grid[4][2] = 8;
      grid[4][3] = 8;
      grid[3][4] = 8;
      final board = boardFromValues(grid);

      final hint = engine.findHint(board);

      expect(hint, isNotNull);
      expect(
        engine.swapCreatesMatch(board, hint!.$1, hint.$2),
        isTrue,
        reason: 'a dica apontou uma jogada que não funciona',
      );
    });

    test('a dica é entre peças adjacentes', () {
      final board = MatchEngine(random: Random(3)).generateBoard();
      final hint = engine.findHint(board)!;

      expect(hint.$1.isAdjacentTo(hint.$2), isTrue);
    });

    test('devolve null no tabuleiro travado', () {
      final grid = [
        for (int row = 0; row < Board.boardSize; row++)
          [
            for (int col = 0; col < Board.boardSize; col++)
              (row ~/ 2 % 2) * 2 + (col ~/ 2 % 2),
          ],
      ];

      expect(engine.findHint(boardFromValues(grid)), isNull);
    });

    test('hasValidMoves concorda com findHint', () {
      // Os dois derivam da mesma varredura; divergir seria contradição.
      for (int seed = 0; seed < 20; seed++) {
        final board = MatchEngine(random: Random(seed)).generateBoard();
        expect(
          engine.hasValidMoves(board),
          engine.findHint(board) != null,
          reason: 'seed $seed',
        );
      }
    });
  });

  group('passos da resolução', () {
    // A UI anima a partir daqui. Sem os passos ela só vê o tabuleiro antes e
    // depois, e a cascata inteira vira um salto instantâneo.

    test('um movimento simples produz um passo', () {
      final grid = baseGrid();
      for (final col in [2, 3, 4]) {
        grid[0][col] = 5;
      }

      final resolution = engine.resolve(boardFromValues(grid));

      expect(resolution.steps, hasLength(resolution.cascades));
      expect(resolution.steps.first.cascade, 1);
    });

    test('as cascatas vêm numeradas em ordem', () {
      final grid = baseGrid();
      grid[7][0] = 1;
      grid[7][1] = 1;
      grid[7][2] = 1;
      grid[7][3] = 0;
      grid[6][0] = 2;
      grid[6][1] = 0;
      grid[6][2] = 2;

      final resolution = engine.resolve(boardFromValues(grid));

      expect(resolution.cascades, greaterThanOrEqualTo(2));
      for (int i = 0; i < resolution.steps.length; i++) {
        expect(resolution.steps[i].cascade, i + 1);
      }
    });

    test('o evento de fusão diz de onde veio e onde nasceu', () {
      final grid = baseGrid();
      for (final col in [2, 3, 4]) {
        grid[0][col] = 5;
      }

      final fusion = engine
          .resolve(boardFromValues(grid))
          .steps
          .first
          .fusions
          .firstWhere((f) => f.value == 6);

      expect(fusion.consumed, hasLength(3));
      expect(fusion.consumed, contains(fusion.at));
      expect(fusion.matchLength, 3);
      expect(fusion.isBig, isFalse);
      // As absorvidas são as que a UI encolhe em direção ao ponto de fusão.
      expect(fusion.absorbed, hasLength(2));
      expect(fusion.absorbed, isNot(contains(fusion.at)));
    });

    test('combinação de quatro é marcada como grande', () {
      final grid = baseGrid();
      for (final col in [2, 3, 4, 5]) {
        grid[0][col] = 5;
      }

      final step = engine.resolve(boardFromValues(grid)).steps.first;

      expect(step.hasBigFusion, isTrue);
      expect(step.fusions.first.matchLength, 4);
    });

    test('o id da peça nascida permite segui-la depois da queda', () {
      final grid = baseGrid();
      for (final col in [2, 3, 4]) {
        grid[0][col] = 5;
      }

      final resolution = engine.resolve(boardFromValues(grid));
      final fusion = resolution.steps.first.fusions.first;

      expect(fusion.tileId, isNotEmpty);
      expect(resolution.bigFusionTileIds, isNot(contains(fusion.tileId)));
    });

    test('o quadro pós-fusão ainda não teve gravidade', () {
      final grid = baseGrid();
      for (final col in [2, 3, 4]) {
        grid[0][col] = 5;
      }

      final step = engine.resolve(boardFromValues(grid)).steps.first;

      // É esse quadro que mostra as casas vazias deixadas pela fusão; depois
      // da queda elas já teriam sumido.
      expect(
        step.boardAfterFusion.tileCount,
        lessThan(step.boardAfterSettle.tileCount),
      );
      expect(step.boardAfterSettle.isFull, isTrue);
    });

    test('a pontuação total é a soma dos passos', () {
      final grid = baseGrid();
      grid[7][0] = 1;
      grid[7][1] = 1;
      grid[7][2] = 1;
      grid[7][3] = 0;
      grid[6][0] = 2;
      grid[6][1] = 0;
      grid[6][2] = 2;

      final resolution = engine.resolve(boardFromValues(grid));

      expect(
        resolution.score,
        resolution.steps.fold<int>(0, (total, s) => total + s.score),
      );
    });

    test('a explosão registra o centro e as células varridas', () {
      final grid = baseGrid();
      for (final col in [2, 3, 4]) {
        grid[3][col] = kMaxDigit - 1;
      }
      grid[3][5] = 0;

      final resolution = MatchEngine(
        random: Random(1),
        explosionShape: ExplosionShape.area,
      ).resolve(boardFromValues(grid));

      final step = resolution.steps.firstWhere(
        (s) => s.explosionCentres.isNotEmpty,
      );

      expect(step.explosionCentres, hasLength(1));
      // Área 3x3 no meio do tabuleiro.
      expect(step.clearedByExplosion, hasLength(9));
      expect(step.clearedByExplosion, contains(step.explosionCentres.first));
    });

    test('sem explosão configurada, nenhum centro é registrado', () {
      final grid = baseGrid();
      for (final col in [2, 3, 4]) {
        grid[3][col] = kMaxDigit - 1;
      }
      grid[3][5] = 0;

      final resolution = MatchEngine(
        random: Random(1),
        explosionShape: ExplosionShape.none,
      ).resolve(boardFromValues(grid));

      expect(resolution.explosions, 0);
      for (final step in resolution.steps) {
        expect(step.explosionCentres, isEmpty);
        expect(step.clearedByExplosion, isEmpty);
      }
    });

    test('tabuleiro sem combinação não gera passo nenhum', () {
      final resolution = engine.resolve(boardFromValues(baseGrid()));

      expect(resolution.steps, isEmpty);
      expect(resolution.cascades, 0);
      expect(resolution.score, 0);
    });
  });

  /// Varredura ingênua: testa as **4** direções em cada uma das 64 células,
  /// sem otimização. É a referência contra a qual o motor é comparado.
  bool exhaustiveHasMove(MatchEngine e, Board board) {
    for (int row = 0; row < Board.boardSize; row++) {
      for (int col = 0; col < Board.boardSize; col++) {
        final from = Position(row: row, col: col);
        if (board.getTileAt(from) == null) continue;

        for (final to in [
          Position(row: row - 1, col: col),
          Position(row: row + 1, col: col),
          Position(row: row, col: col - 1),
          Position(row: row, col: col + 1),
        ]) {
          if (!Board.contains(to)) continue;
          if (board.getTileAt(to) == null) continue;
          if (e.swapCreatesMatch(board, from, to)) return true;
        }
      }
    }
    return false;
  }

  group('hasValidMoves', () {
    test('concorda com a varredura exaustiva das 4 direções', () {
      // A varredura do motor percorre só direita e abaixo, porque trocar (a,b)
      // é a mesma jogada que trocar (b,a). Este teste **prova** a equivalência
      // em vez de confiar no argumento — e é a regressão para a suspeita de
      // falso fim de jogo.
      var comMovimento = 0;

      for (int seed = 0; seed < 200; seed++) {
        final e = MatchEngine(random: Random(seed));
        var board = e.generateBoard();

        // Também em tabuleiros já mexidos, não só nos recém-gerados.
        for (int move = 0; move < seed % 5; move++) {
          final hint = e.findHint(board);
          if (hint == null) break;
          board = e
              .resolve(e.swap(board, hint.$1, hint.$2), anchor: hint.$2)
              .board;
        }

        expect(
          e.hasValidMoves(board),
          exhaustiveHasMove(e, board),
          reason: 'divergiram na seed $seed',
        );
        if (e.hasValidMoves(board)) comMovimento++;
      }

      expect(comMovimento, greaterThan(150), reason: 'amostra pouco variada');
    });

    test('um tabuleiro com jogada óbvia nunca é declarado travado', () {
      // Regressão do relato de "falso fim de jogo": dois 8 lado a lado e um
      // terceiro logo acima fecham trio com uma troca.
      final grid = baseGrid();
      grid[4][2] = 8;
      grid[4][3] = 8;
      grid[3][4] = 8;
      final board = boardFromValues(grid);

      expect(engine.hasValidMoves(board), isTrue);
      expect(engine.findHint(board), isNotNull);
    });

    test('detecta jogada disponível', () {
      final grid = baseGrid();
      // Dois 8 na linha 4 e um terceiro logo acima: trocar (3,4) com (4,4)
      // fecha o trio.
      grid[4][2] = 8;
      grid[4][3] = 8;
      grid[3][4] = 8;

      expect(engine.hasValidMoves(boardFromValues(grid)), isTrue);
    });

    test('blocos 2x2 formam tabuleiro travado', () {
      // Padrão clássico de deadlock: nenhuma troca adjacente forma trio.
      final grid = [
        for (int row = 0; row < Board.boardSize; row++)
          [
            for (int col = 0; col < Board.boardSize; col++)
              (row ~/ 2 % 2) * 2 + (col ~/ 2 % 2),
          ],
      ];
      final board = boardFromValues(grid);

      expect(engine.detectMatches(board), isEmpty);
      expect(engine.hasValidMoves(board), isFalse);
    });
  });

  group('invariância da janela de spawn', () {
    // Achado da simulação (tool/simulate_economy.dart): subir o piso do spawn
    // produz exatamente as mesmas medianas, só deslocadas de um dígito. A
    // razão é que nenhuma regra do jogo olha o valor absoluto de uma peça —
    // só se dois valores são iguais, e quanto é value+1. Logo o jogo com
    // janela 1-4 é o mesmo jogo com janela 0-3 e todos os rótulos somados de 1,
    // até que alguém encoste no teto do 9.
    //
    // Consequência de design: subir o piso não dá profundidade, apenas
    // aproxima o jogador da saída (a combinação no 9, que é consumida).

    /// Todos os valores de [b] são iguais aos de [a] somados de [offset]?
    void expectShifted(Board a, Board b, int offset) {
      for (int row = 0; row < Board.boardSize; row++) {
        for (int col = 0; col < Board.boardSize; col++) {
          final position = Position(row: row, col: col);
          final left = a.getTileAt(position)?.value;
          final right = b.getTileAt(position)?.value;

          expect(
            right,
            left == null ? isNull : left + offset,
            reason: 'divergiu em $position',
          );
        }
      }
    }

    test('deslocar a janela desloca o tabuleiro inteiro', () {
      final low = MatchEngine(random: Random(9), spawnMin: 0, spawnMax: 3);
      final high = MatchEngine(random: Random(9), spawnMin: 2, spawnMax: 5);

      expectShifted(low.generateBoard(), high.generateBoard(), 2);
    });

    test('a equivalência sobrevive a um movimento resolvido', () {
      final low = MatchEngine(random: Random(4), spawnMin: 0, spawnMax: 3);
      final high = MatchEngine(random: Random(4), spawnMin: 1, spawnMax: 4);

      var boardLow = low.generateBoard();
      var boardHigh = high.generateBoard();

      final move = low
          .candidateSwaps(boardLow)
          .firstWhere((s) => low.swapCreatesMatch(boardLow, s.$1, s.$2));

      // A mesma jogada tem de ser válida nos dois tabuleiros.
      expect(high.swapCreatesMatch(boardHigh, move.$1, move.$2), isTrue);

      boardLow = low
          .resolve(low.swap(boardLow, move.$1, move.$2), anchor: move.$2)
          .board;
      boardHigh = high
          .resolve(high.swap(boardHigh, move.$1, move.$2), anchor: move.$2)
          .board;

      // Longe do teto do 9, onde a peça passa a ser consumida e a simetria
      // deixa de valer.
      expect(
        boardLow.getAllTiles().map((t) => t.value).reduce(max),
        lessThan(kMaxDigit - 1),
      );

      expectShifted(boardLow, boardHigh, 1);
    });
  });

  group('janela de spawn', () {
    test('a janela padrão tem exatamente kSpawnWidth valores', () {
      expect(engine.spawnWidth, kSpawnWidth);
    });

    test('recusa janela mais larga que kSpawnWidth', () {
      expect(() => MatchEngine(spawnMin: 0, spawnMax: 6), throwsAssertionError);
      expect(() => engine.setSpawnWindow(min: 0, max: 6), throwsAssertionError);
    });

    test('recusa janela mais estreita que kSpawnWidth', () {
      expect(() => MatchEngine(spawnMin: 0, spawnMax: 2), throwsAssertionError);
    });

    test('a janela larga só é possível com a liberação explícita', () {
      final wide = MatchEngine(
        random: Random(2),
        spawnMin: 0,
        spawnMax: 6,
        allowWideSpawn: true,
      );

      expect(wide.spawnWidth, greaterThan(kSpawnWidth));
    });

    test('a reposição nunca sorteia fora da janela, deslizando ou não', () {
      for (int min = 0; min <= kMaxDigit - kSpawnWidth; min++) {
        final max = min + kSpawnWidth - 1;
        final sliding = MatchEngine(
          random: Random(min),
          spawnMin: min,
          spawnMax: max,
        );

        for (final tile in sliding.refill(Board.empty()).getAllTiles()) {
          expect(
            tile.value,
            inInclusiveRange(min, max),
            reason: 'janela $min-$max',
          );
        }
      }
    });

    test('subir a janela no meio da partida não vaza valor antigo', () {
      final sliding = MatchEngine(random: Random(13));
      var board = sliding.generateBoard();

      sliding.setSpawnWindow(min: 3, max: 6);

      // Esvazia o topo inteiro e repõe: tudo o que nascer agora é da janela
      // nova, mesmo com o tabuleiro cheio de peças da janela antiga.
      for (int col = 0; col < Board.boardSize; col++) {
        board = board.updateTile(Position(row: 0, col: col), null);
      }
      final before = board.getAllTiles().map((t) => t.id).toSet();

      for (final tile in sliding.refill(board).getAllTiles()) {
        if (before.contains(tile.id)) continue;
        expect(tile.value, inInclusiveRange(3, 6));
      }
    });
  });

  group('cascata', () {
    /// Tabuleiro em que uma única fusão desencadeia a seguinte sem o jogador
    /// tocar em nada: os três `1` da linha 7 fundem, a coluna 3 desce, e os
    /// `2` que estavam por cima se alinham na base.
    ///
    /// A reposição do topo é aleatória, então o motor de teste usa uma janela
    /// deslocada bem acima dos valores montados à mão — assim nada que caia do
    /// topo pode formar combinação com o que foi armado, e a cascata observada
    /// é só a que o tabuleiro produz.
    test('uma jogada encadeia mais de um ciclo sem intervenção', () {
      final grid = baseGrid();

      // Linha 7 (base): trio que funde primeiro, virando um 2 em (7,2).
      grid[7][0] = 0; // impede que a base vire uma sequência de quatro
      grid[7][1] = 1;
      grid[7][2] = 1;
      grid[7][3] = 1;
      // As colunas 1 e 3 perdem uma peça e descem; a 2 fica com a peça
      // fundida. Os dois 2 da linha 6 pousam ao lado dela e fecham o trio.
      grid[6][1] = 2;
      grid[6][2] = 0;
      grid[6][3] = 2;

      final cascading = MatchEngine(
        random: Random(1),
        spawnMin: 5,
        spawnMax: 8,
      );
      final resolution = cascading.resolve(boardFromValues(grid));

      expect(
        resolution.cascades,
        greaterThanOrEqualTo(2),
        reason: 'a queda tinha de formar uma segunda combinação sozinha',
      );
      expect(resolution.steps.first.cascade, 1);
      expect(resolution.steps[1].cascade, 2);
    });

    test('o ciclo fecha: nenhuma combinação sobra no tabuleiro final', () {
      for (int seed = 0; seed < 30; seed++) {
        final e = MatchEngine(random: Random(seed));
        var board = e.generateBoard();

        for (int move = 0; move < 20; move++) {
          final hint = e.findHint(board);
          if (hint == null) break;

          final resolution = e.resolve(
            e.swap(board, hint.$1, hint.$2),
            anchor: hint.$2,
          );
          board = resolution.board;

          expect(board.isFull, isTrue, reason: 'seed $seed: sobrou vazio');
          // O orçamento de cascata (kCascadeBudgetPerTurn) pode congelar o
          // ciclo com uma combinação pendente de propósito — nesse caso
          // resolve() já gastou o teto de passos da jogada, e o match
          // restante só volta a ser resolvido na jogada seguinte.
          final pendingMatch = e.detectMatches(board).isNotEmpty;
          if (pendingMatch) {
            expect(
              resolution.steps.length,
              kCascadeBudgetPerTurn,
              reason:
                  'seed $seed: sobrou combinação sem o orçamento de cascata '
                  'ter sido totalmente consumido',
            );
          }
        }
      }
    });

    test('cada ciclo pontua e a pontuação total é a soma deles', () {
      final grid = baseGrid();
      grid[7][0] = 0;
      grid[7][1] = 1;
      grid[7][2] = 1;
      grid[7][3] = 1;
      grid[6][1] = 2;
      grid[6][2] = 0;
      grid[6][3] = 2;

      final cascading = MatchEngine(
        random: Random(1),
        spawnMin: 5,
        spawnMax: 8,
      );
      final resolution = cascading.resolve(boardFromValues(grid));

      expect(
        resolution.score,
        resolution.steps.fold<int>(0, (total, s) => total + s.score),
      );
      expect(resolution.score, greaterThan(0));
    });

    test('a reposição de toda a cascata respeita a janela', () {
      final e = MatchEngine(random: Random(21), spawnMin: 2, spawnMax: 5);
      var board = e.generateBoard();

      for (int move = 0; move < 30; move++) {
        final hint = e.findHint(board);
        if (hint == null) break;
        board = e
            .resolve(e.swap(board, hint.$1, hint.$2), anchor: hint.$2)
            .board;
      }

      // Peça abaixo do piso da janela só poderia ter vindo de sorteio inválido:
      // a fusão só cria valores acima, nunca abaixo.
      for (final tile in board.getAllTiles()) {
        expect(tile.value, greaterThanOrEqualTo(2));
        expect(tile.value, lessThanOrEqualTo(kMaxDigit));
      }
    });
  });

  group('generateBoard', () {
    test('sempre cheio, sem combinação pronta e com jogada possível', () {
      for (int seed = 0; seed < 40; seed++) {
        final board = MatchEngine(random: Random(seed)).generateBoard();

        expect(board.isFull, isTrue, reason: 'seed $seed');
        expect(engine.detectMatches(board), isEmpty, reason: 'seed $seed');
        expect(engine.hasValidMoves(board), isTrue, reason: 'seed $seed');
      }
    });

    test('não repete o mesmo padrão em todas as linhas (regressão do LCG)', () {
      final board = MatchEngine(random: Random(3)).generateBoard();
      final rows = [
        for (int row = 0; row < Board.boardSize; row++)
          board.getTilesInRow(row).map((t) => t.value).join(),
      ];

      expect(rows.toSet().length, greaterThan(1));
    });

    test('todas as peças têm id único', () {
      final board = MatchEngine(random: Random(11)).generateBoard();
      final ids = board.getAllTiles().map((t) => t.id).toSet();

      expect(ids, hasLength(Board.boardSize * Board.boardSize));
    });
  });

  group('obstáculos', () {
    /// Cobre a célula [at] sem mexer no dígito que está embaixo.
    Board cover(Board board, Position at, ObstacleType type) =>
        board.updateTile(at, board.getTileAt(at)!.withObstacle(type));

    /// Base sem combinação com uma fila de três `5` na linha 4.
    Board boardWithMatchOnRow4() {
      final values = baseGrid();
      values[4][0] = 5;
      values[4][1] = 5;
      values[4][2] = 5;
      return boardFromValues(values);
    }

    ObstacleHit? hitAt(ResolutionStep step, Position at) =>
        step.obstacleHits.where((hit) => hit.position == at).firstOrNull;

    test('a fusão numa célula vizinha derrete o gelo', () {
      // (4,3) encosta em (4,2), que a combinação consome.
      final board = cover(
        boardWithMatchOnRow4(),
        const Position(row: 4, col: 3),
        ObstacleType.ice,
      );

      final step = MatchEngine(random: Random(1)).resolve(board).steps.first;

      final hit = hitAt(step, const Position(row: 4, col: 3));
      expect(hit, isNotNull);
      expect(hit!.type, ObstacleType.ice);
      expect(hit.cleared, isTrue);
      // A liberação já vale no quadro que a UI anima.
      expect(
        step.boardAfterFusion
            .getTileAt(const Position(row: 4, col: 3))!
            .isBlocked,
        isFalse,
      );
    });

    test('o vidro sobrevive ao primeiro impacto, trincado', () {
      final board = cover(
        boardWithMatchOnRow4(),
        const Position(row: 4, col: 3),
        ObstacleType.glass,
      );

      final step = MatchEngine(random: Random(1)).resolve(board).steps.first;
      final tile = step.boardAfterFusion.getTileAt(
        const Position(row: 4, col: 3),
      )!;

      expect(hitAt(step, const Position(row: 4, col: 3))!.cleared, isFalse);
      expect(tile.obstacle, ObstacleType.glass);
      expect(tile.obstacleHp, 1);
      expect(tile.isDamaged, isTrue);
    });

    test('a pedra mal se abala com um impacto', () {
      final board = cover(
        boardWithMatchOnRow4(),
        const Position(row: 4, col: 3),
        ObstacleType.stone,
      );

      final step = MatchEngine(random: Random(1)).resolve(board).steps.first;

      expect(hitAt(step, const Position(row: 4, col: 3))!.remainingHp, 2);
      expect(
        step.boardAfterFusion
            .getTileAt(const Position(row: 4, col: 3))!
            .obstacle,
        ObstacleType.stone,
      );
    });

    test('obstáculo longe da fusão não leva dano', () {
      final board = cover(
        boardWithMatchOnRow4(),
        const Position(row: 0, col: 7),
        ObstacleType.ice,
      );

      final step = MatchEngine(random: Random(1)).resolve(board).steps.first;

      expect(hitAt(step, const Position(row: 0, col: 7)), isNull);
      expect(
        step.boardAfterFusion
            .getTileAt(const Position(row: 0, col: 7))!
            .isBlocked,
        isTrue,
      );
    });

    test('duas combinações no mesmo passo valem um impacto só', () {
      // (5,2) encosta em (4,2) e em (6,2) — uma célula de cada combinação.
      final values = baseGrid();
      values[4][0] = 5;
      values[4][1] = 5;
      values[4][2] = 5;
      values[6][2] = 7;
      values[6][3] = 7;
      values[6][4] = 7;

      final board = cover(
        boardFromValues(values),
        const Position(row: 5, col: 2),
        ObstacleType.glass,
      );

      final step = MatchEngine(random: Random(1)).resolve(board).steps.first;
      final hits = step.obstacleHits.where(
        (hit) => hit.position == const Position(row: 5, col: 2),
      );

      expect(step.fusions, hasLength(2));
      expect(hits, hasLength(1));
      expect(hits.first.remainingHp, 1);
    });

    test('peça coberta não participa de combinação', () {
      final board = cover(
        boardWithMatchOnRow4(),
        const Position(row: 4, col: 1),
        ObstacleType.stone,
      );

      expect(MatchEngine(random: Random(1)).detectMatches(board), isEmpty);
    });

    test('peça coberta não pode ser trocada', () {
      final board = cover(
        boardFromValues(baseGrid()),
        const Position(row: 4, col: 1),
        ObstacleType.ice,
      );
      final engine = MatchEngine(random: Random(1));

      expect(
        engine.tryMove(
          board,
          const Position(row: 4, col: 0),
          const Position(row: 4, col: 1),
        ),
        isA<MoveImpossible>(),
      );
      expect(
        engine.tryMove(
          board,
          const Position(row: 4, col: 1),
          const Position(row: 4, col: 2),
        ),
        isA<MoveImpossible>(),
      );
    });

    test('a busca por jogada ignora as células cobertas', () {
      final board = cover(
        boardFromValues(baseGrid()),
        const Position(row: 4, col: 1),
        ObstacleType.ice,
      );

      final swaps = MatchEngine(random: Random(1)).candidateSwaps(board);

      expect(
        swaps.any(
          (s) =>
              s.$1 == const Position(row: 4, col: 1) ||
              s.$2 == const Position(row: 4, col: 1),
        ),
        isFalse,
      );
    });

    group('onda de choque do dígito máximo', () {
      // ExplosionShape.cross varre a linha e a coluna inteiras, bem além da
      // vizinhança que `_damageObstacles` já cobriu — é o que expõe a lacuna:
      // a onda alcança uma cobertura distante da combinação, longe de qualquer
      // impacto de fusão.
      Board boardWithFarStone({required ObstacleType type}) {
        final values = baseGrid();
        values[3][2] = 8;
        values[3][3] = 8;
        values[3][4] = 8;
        var board = boardFromValues(values);
        // Fica na mesma linha da explosão (centro em (3,3)), mas fora da
        // vizinhança ortogonal que a fusão já tocou.
        board = cover(board, const Position(row: 3, col: 7), type);
        return board;
      }

      test(
        'o estouro varre uma cobertura distante e emite o impacto (era o bug)',
        () {
          final step = MatchEngine(
            random: Random(1),
            explosionShape: ExplosionShape.cross,
          ).resolve(boardWithFarStone(type: ObstacleType.stone)).steps.first;

          // A peça sumiu do tabuleiro — a onda varreu a célula inteira.
          expect(
            step.boardAfterFusion
                .getTileAt(const Position(row: 3, col: 7))
                ?.isBlocked,
            isNot(isTrue),
          );

          // E o objetivo tem de saber disso: sem o hit, "limpe toda a pedra"
          // ficaria impossível de vencer nessa jogada.
          final hit = hitAt(step, const Position(row: 3, col: 7));
          expect(hit, isNotNull);
          expect(hit!.cleared, isTrue);
        },
      );

      test('o hit do estouro traz o tipo de antes da destruição', () {
        final step = MatchEngine(
          random: Random(1),
          explosionShape: ExplosionShape.cross,
        ).resolve(boardWithFarStone(type: ObstacleType.glass)).steps.first;

        final hit = hitAt(step, const Position(row: 3, col: 7))!;
        expect(hit.type, ObstacleType.glass);
        expect(hit.remainingHp, 0);
      });

      test(
        'cobertura atingida por fusão e pelo estouro no mesmo passo recebe '
        'um impacto só',
        () {
          // (3,5) encosta na combinação (leva dano de fusão) e também está na
          // mesma linha do centro da explosão (leva a varredura). As duas
          // fontes não podem virar dois impactos.
          final board = cover(
            boardWithFarStone(type: ObstacleType.ice),
            const Position(row: 3, col: 5),
            ObstacleType.stone,
          );

          final step = MatchEngine(
            random: Random(1),
            explosionShape: ExplosionShape.cross,
          ).resolve(board).steps.first;

          final hitsAt5 = step.obstacleHits.where(
            (h) => h.position == const Position(row: 3, col: 5),
          );
          expect(hitsAt5, hasLength(1));
          // A onda destrói por inteiro: o impacto único tem de refletir isso,
          // e não a vida parcial que a fusão sozinha deixaria — senão a mesma
          // cobertura some do tabuleiro sem o objetivo contar, que é
          // exatamente o bug que esta correção fecha.
          expect(hitsAt5.first.cleared, isTrue);
        },
      );
    });
  });

  group('smash (Martelo de Fusão)', () {
    Board cover(Board board, Position at, ObstacleType type) =>
        board.updateTile(at, board.getTileAt(at)!.withObstacle(type));

    test('devolve nulo fora do tabuleiro', () {
      final board = boardFromValues(baseGrid());

      expect(engine.smash(board, const Position(row: -1, col: 0)), isNull);
      expect(engine.smash(board, const Position(row: 0, col: 8)), isNull);
    });

    test('devolve nulo na casa vazia', () {
      // Nada a obliterar: o notifier usa este nulo para recusar sem cobrar.
      final board = boardFromValues(
        baseGrid(),
      ).updateTile(const Position(row: 4, col: 4), null);

      expect(engine.smash(board, const Position(row: 4, col: 4)), isNull);
    });

    test('oblitera a peça e devolve o tabuleiro cheio', () {
      final board = boardFromValues(baseGrid());
      final victim = board.getTileAt(const Position(row: 4, col: 4))!;

      final resolution = engine.smash(board, const Position(row: 4, col: 4))!;

      expect(
        resolution.board.getAllTiles().where((t) => t.id == victim.id),
        isEmpty,
        reason: 'a peça atingida tem de sair do tabuleiro',
      );
      // A gravidade e a reposição rodam no mesmo golpe: um buraco parado seria
      // um estado que o motor não permite em nenhum outro caminho.
      expect(resolution.board.isFull, isTrue);
    });

    test('oblitera a cobertura junto com a peça', () {
      // É a razão de ser do booster: a pedra pede três impactos, e o martelo
      // não negocia — leva a célula inteira.
      final board = cover(
        boardFromValues(baseGrid()),
        const Position(row: 4, col: 4),
        ObstacleType.stone,
      );

      final resolution = engine.smash(board, const Position(row: 4, col: 4))!;

      expect(resolution.board.countObstacles(ObstacleType.stone), 0);
    });

    test('conta a cobertura destruída como limpa', () {
      // Sem isso um objetivo "limpe todo o gelo" não veria o golpe.
      final board = cover(
        boardFromValues(baseGrid()),
        const Position(row: 4, col: 4),
        ObstacleType.ice,
      );

      final resolution = engine.smash(board, const Position(row: 4, col: 4))!;

      expect(resolution.countCleared(ObstacleType.ice), 1);
    });

    test('não evolui o dígito destruído', () {
      // O martelo não é uma fusão: o 7 atingido não vira 8, nem pontua.
      final values = baseGrid();
      values[4][4] = 7;
      final board = boardFromValues(values);

      final resolution = engine.smash(board, const Position(row: 4, col: 4))!;

      expect(resolution.producedDigits, isNot(contains(8)));
      expect(resolution.countProduced(7), 0);
    });

    test('a queda que forma combinação resolve normalmente', () {
      // Três `5` na linha 5 depois de a peça de cima cair no buraco. Deixá-los
      // alinhados e inertes seria o único estado do jogo em que uma combinação
      // formada não resolve — o jogador leria isso como defeito.
      final values = baseGrid();
      values[5][1] = 5;
      values[5][2] = 5;
      values[4][3] = 5;
      final board = boardFromValues(values);

      final resolution = engine.smash(board, const Position(row: 5, col: 3))!;

      expect(resolution.steps, isNotEmpty);
      expect(resolution.producedDigits, contains(6));
    });
  });
}
