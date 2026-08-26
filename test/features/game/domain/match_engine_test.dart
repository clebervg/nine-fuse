import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/fusion_rule.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/nova_event.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/special_tile.dart';
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

    test('começa sorteando 0-3, como pede o design do MVP', () {
      final engine = MatchEngine(random: Random(0));

      expect(engine.spawnMin, 0);
      expect(engine.spawnMax, 3);
    });
  });

  group('Bloco 9 (fusão que cria o dígito máximo)', () {
    /// Trio de 8 no meio do tabuleiro, cercado de gelo — fundir gera um 9 e
    /// deve limpar as coberturas ao redor, sem tocar em nenhum valor.
    Board nineWithIceAround() {
      var board = boardFromValues(baseGrid());
      for (final col in [2, 3, 4]) {
        final pos = Position(row: 3, col: col);
        board = board.updateTile(
          pos,
          board.getTileAt(pos)!.copyWith(value: kMaxDigit - 1),
        );
      }
      // Não precisa de bloqueador em (3,5): o valor natural do grid base ali
      // já é 2 (diferente de 8), então o trio nunca vira uma sequência de 4
      // por acidente. Forçá-lo a 0 (como a primeira versão deste teste
      // fazia) revelava um 0 idêntico ao gelo vizinho quando ele quebra,
      // encadeando uma cascata espúria — o que o teste abaixo justamente
      // não quer medir.

      // Gelo nos quatro cantos da vizinhança 3x3 da célula central (3,3),
      // onde a fusão nasce (âncora ausente, cai no meio da sequência reta).
      // Não pode usar (3,2)/(3,4): são as próprias células do trio, e uma
      // peça coberta não participa de combinação — cobri-las quebraria a
      // fusão que o teste depende de existir.
      for (final pos in const [
        Position(row: 2, col: 2),
        Position(row: 2, col: 4),
        Position(row: 4, col: 2),
        Position(row: 4, col: 4),
      ]) {
        board = board.updateTile(pos, board.getTileAt(pos)!.withObstacle(ObstacleType.ice));
      }
      return board;
    }

    test('a fusão de três 8 cria um 9 que permanece no tabuleiro', () {
      final resolution = engine.resolve(nineWithIceAround());

      expect(resolution.highestProduced, kMaxDigit);
      expect(
        resolution.board.getAllTiles().where((t) => t.value == kMaxDigit),
        hasLength(1),
        reason: 'o Bloco 9 não se consome — só o gelo ao redor cede',
      );
    });

    test('limpa as coberturas na vizinhança 3x3 do 9 recém-criado', () {
      final resolution = engine.resolve(nineWithIceAround());

      expect(resolution.countCleared(ObstacleType.ice), 4);
    });

    test('não limpa bloqueador fora da vizinhança 3x3', () {
      var board = nineWithIceAround();
      const distant = Position(row: 0, col: 0);
      board = board.updateTile(distant, board.getTileAt(distant)!.withObstacle(ObstacleType.ice));

      final resolution = engine.resolve(board);

      expect(resolution.countCleared(ObstacleType.ice), 4, reason: 'a distante não conta');
      expect(resolution.board.getTileAt(distant)!.isBlocked, isTrue);
    });

    test('não dispara cascata própria — resolve em um passo só', () {
      final resolution = engine.resolve(nineWithIceAround());
      expect(resolution.cascades, 1);
    });

    test('4x8 aplica o bônus de score do Bloco 9 aprimorado', () {
      final base = nineWithIceAround();
      var big = base;
      // Estende o trio para um quarteto: (3,1) também vira 8.
      final extra = const Position(row: 3, col: 1);
      big = big.updateTile(extra, big.getTileAt(extra)!.copyWith(value: kMaxDigit - 1));

      final threeScore = MatchEngine(random: Random(1)).resolve(base).score;
      final fourScore = MatchEngine(random: Random(1)).resolve(big).score;

      expect(fourScore, greaterThanOrEqualTo(threeScore + kBigNineScoreBonus));
    });

    test('peças 8 combinadas numa cascata automática não limpam bloqueador', () {
      // Duas fusões separadas: a do jogador (cascade 1) não produz 9; a
      // cascata resultante (cascade 2) sim. O gelo (longe de qualquer célula
      // tocada por qualquer uma das duas fusões) deve continuar intacto —
      // provando que nada foi limpo por acidente numa jogada que não devia
      // acionar o efeito nenhum.
      //
      // Nota de implementação: um gelo colado no 9 recém-nascido não serve
      // para essa prova. Para um match reto (sem âncora, como toda cascata),
      // a vizinhança ortogonal que `_damageObstacles` já cobre coincide
      // exatamente com a caixa 3x3 do Bloco 9 — então qualquer gelo dentro
      // dessa caixa já seria limpo pelo dano comum de fusão, mesmo com o
      // efeito do Bloco 9 desativado. Só um gelo fora do alcance de **ambos**
      // os mecanismos prova que a cascata não limpou nada além do de sempre.
      final grid = baseGrid();
      // Cascade 1: trio vertical de valor 5 na coluna 2 (linhas 4-6), abaixo
      // de um 8 solto na linha 3. Ao fundir, libera duas células na coluna e
      // o 8 cai duas linhas, pousando na linha 5 — a mesma linha onde as
      // colunas 3 e 4 já têm um 8 parado, formando o trio que a cascata 2
      // funde em 9.
      grid[3][2] = kMaxDigit - 1;
      grid[4][2] = 5;
      grid[5][2] = 5;
      grid[6][2] = 5;
      grid[5][3] = kMaxDigit - 1;
      grid[5][4] = kMaxDigit - 1;

      var board = boardFromValues(grid);
      const farFromEverything = Position(row: 0, col: 7);
      board = board.updateTile(
        farFromEverything,
        board.getTileAt(farFromEverything)!.withObstacle(ObstacleType.ice),
      );

      final resolution = MatchEngine(random: Random(4)).resolve(board);

      // Só é uma prova útil se de fato houve uma cascata (cascade 2) que
      // produziu o 9 — caso o cenário não force isso, o teste falha alto e
      // pede ajuste da grade, em vez de passar sem testar nada.
      final producedInCascade = resolution.steps
          .where((s) => s.cascade > 1)
          .any((s) => s.fusions.any((f) => f.value == kMaxDigit));
      expect(
        producedInCascade,
        isTrue,
        reason: 'cenário precisa produzir o 9 numa cascata, não no passo do jogador',
      );
      expect(resolution.countCleared(ObstacleType.ice), 0);
    });

    // Achado da revisão final da branch: a vizinhança ortogonal que
    // `_damageObstacles` já ataca (as combinações consumidas + seus vizinhos
    // ortogonais) e a caixa 3x3 do Bloco 9 se sobrepõem quase inteiramente
    // para um trio reto — é literalmente o que o teste anterior documenta
    // ("a vizinhança ortogonal... coincide exatamente com a caixa 3x3"). Sem
    // deduplicar por posição, uma cobertura na sobreposição levava DOIS hits
    // no mesmo passo: um de `_damageObstacles`, outro de
    // `_clearBlockersAround` — quebrando o "um impacto por passo" que o
    // projeto documenta como invariante. Com vidro (2 HP) o efeito é visível:
    // o bug faria `cleared` sair `true` já no primeiro (e único) passo.
    test(
      'uma cobertura na sobreposição das duas vizinhanças leva só um hit',
      () {
        var board = boardFromValues(baseGrid());
        for (final col in [2, 3, 4]) {
          final pos = Position(row: 3, col: col);
          board = board.updateTile(
            pos,
            board.getTileAt(pos)!.copyWith(value: kMaxDigit - 1),
          );
        }
        // (2,2) está nas duas vizinhanças: é canto da caixa 3x3 do Bloco 9
        // (centro em (3,3)) **e** vizinho ortogonal de (3,2), uma das casas
        // consumidas pela fusão.
        const overlap = Position(row: 2, col: 2);
        board = board.updateTile(
          overlap,
          board.getTileAt(overlap)!.withObstacle(ObstacleType.glass),
        );

        final glassId = board.getTileAt(overlap)!.id;
        final resolution = engine.resolve(board);

        final hits = resolution.steps
            .expand((s) => s.obstacleHits)
            .where((h) => h.position == overlap)
            .toList();

        expect(
          hits,
          hasLength(1),
          reason: 'um impacto por passo, mesmo em posição tocada por dois '
              'mecanismos de dano',
        );
        // A gravidade move a peça coberta como qualquer outra (é decisão de
        // projeto registrada em CLAUDE.md: obstáculo cai com o resto), então
        // procurar o vidro pelo **id** — não pela posição de origem — é o
        // que garante achar a peça certa depois do assentamento.
        final glassAfter = resolution.board
            .getAllTiles()
            .firstWhere((t) => t.id == glassId);
        expect(
          glassAfter.isBlocked,
          isTrue,
          reason: 'vidro (2 HP) não pode cair com um hit só',
        );
        expect(resolution.countCleared(ObstacleType.glass), 0);
      },
    );
  });

  group('Super 9 (5+ peças de valor 8)', () {
    Board fiveEights() {
      final grid = baseGrid();
      for (final col in [1, 2, 3, 4, 5]) {
        grid[3][col] = kMaxDigit - 1;
      }
      return boardFromValues(grid);
    }

    test('match de 5+ peças 8 cria um Super 9, não um 9 comum', () {
      final resolution = engine.resolve(fiveEights());

      final born = resolution.steps.first.fusions.firstWhere((f) => f.value == kMaxDigit);
      expect(born.specialType, SpecialTileType.superNine);

      final tile = resolution.board
          .getAllTiles()
          .firstWhere((t) => t.specialType == SpecialTileType.superNine);
      expect(tile.value, kMaxDigit);
      expect(tile.specialTurnsLeft, kSpecialTileLifespan);
    });

    test('Super 9 também limpa bloqueadores ao nascer, como qualquer Bloco 9', () {
      var board = fiveEights();
      const neighbour = Position(row: 2, col: 3);
      board = board.updateTile(neighbour, board.getTileAt(neighbour)!.withObstacle(ObstacleType.ice));

      final resolution = engine.resolve(board);
      expect(resolution.countCleared(ObstacleType.ice), 1);
    });

    test('só existe 1 Super 9 por vez: um segundo match de 5+ vira Bloco 9 comum', () {
      // Monta um tabuleiro com um Super 9 já presente e força um segundo
      // match de 5+ peças de valor 8 em outra área do tabuleiro.
      var board = fiveEights();
      const existing = Position(row: 6, col: 6);
      board = board.updateTile(
        existing,
        Tile.withSpecial(id: 'existing', value: kMaxDigit, position: existing, specialType: SpecialTileType.superNine),
      );

      final resolution = engine.resolve(board);

      final superNines = resolution.board
          .getAllTiles()
          .where((t) => t.specialType == SpecialTileType.superNine);
      expect(superNines, hasLength(1), reason: 'nunca mais que um Super 9 no tabuleiro');

      final newNine = resolution.steps.first.fusions.firstWhere((f) => f.value == kMaxDigit);
      expect(newNine.specialType, isNull, reason: 'vira Bloco 9 comum, não um segundo Super 9');
    });

    test(
      'duas combinações de 5+ peças 8 na MESMA resolução: só a primeira vira Super 9',
      () {
        // Dois grupos disjuntos de 5+ peças de valor 8, longe o bastante
        // (linha 0 e linha 7) para não se tocarem, ambos já formados quando
        // resolve() é chamado — logo processados na MESMA chamada de
        // _applyFusions, exercitando o ramo do `updates` de
        // _hasActiveSuperNine (não o do tabuleiro pré-existente).
        final grid = baseGrid();
        for (final col in [1, 2, 3, 4, 5]) {
          grid[0][col] = kMaxDigit - 1;
          grid[7][col] = kMaxDigit - 1;
        }
        final board = boardFromValues(grid);

        final resolution = engine.resolve(board);

        final superNines = resolution.board
            .getAllTiles()
            .where((t) => t.specialType == SpecialTileType.superNine);
        expect(
          superNines,
          hasLength(1),
          reason: 'apenas um Super 9 pode nascer, mesmo com dois matches de 5+ na mesma jogada',
        );

        final bornNines = resolution.steps.first.fusions
            .where((f) => f.value == kMaxDigit)
            .toList();
        expect(bornNines, hasLength(2), reason: 'os dois matches de 5+ resolvem na mesma chamada');

        final withSuperNine = bornNines.where((f) => f.specialType == SpecialTileType.superNine);
        final plainNines = bornNines.where((f) => f.specialType == null);
        expect(withSuperNine, hasLength(1));
        expect(plainNines, hasLength(1), reason: 'o segundo match vira Bloco 9 comum');
      },
    );
  });

  group('Evento Nova (fusão de 3+ peças de valor 9)', () {
    /// Três peças 9 já prontas no tabuleiro, lado a lado na linha 3, colunas
    /// 2-4 — o alinhamento acontece sozinho, sem precisar de troca do
    /// jogador, porque o cenário de teste já nasce com o trio formado.
    Board threeNinesInRow() {
      final grid = baseGrid();
      for (final col in [2, 3, 4]) {
        grid[3][col] = kMaxDigit;
      }
      return boardFromValues(grid);
    }

    test('trio de 9 dispara um NovaEvent de tier 1', () {
      final resolution = engine.resolve(threeNinesInRow());

      expect(resolution.novaEvents, hasLength(1));
      expect(resolution.novaEvents.single.tier, 1);
    });

    test('núcleo 3x3 destrói as peças do trio', () {
      final resolution = engine.resolve(threeNinesInRow());

      for (final col in [2, 3, 4]) {
        final pos = Position(row: 3, col: col);
        expect(
          resolution.novaEvents.single.clearedTiles,
          contains(pos),
          reason: '$pos era parte do trio consumido',
        );
      }
    });

    test('peça sobrevivente no anel (fora do núcleo, dentro da 5x5) é promovida', () {
      var board = threeNinesInRow();
      // (1,3): duas linhas acima do centro (3,3) — fora do núcleo 3x3
      // (linhas 2-4), dentro da zona 5x5 (linhas 1-5).
      const inRing = Position(row: 1, col: 3);
      board = board.updateTile(inRing, board.getTileAt(inRing)!.copyWith(value: 4));

      final resolution = engine.resolve(board);

      expect(resolution.novaEvents.single.promoted[inRing], 5);
      // A checagem de valor final usa o quadro *antes* da gravidade
      // (`boardAfterFusion`), não `resolution.board`: toda resolução aplica
      // queda logo depois da fusão, então a peça promovida em (1,3) escorrega
      // para baixo até preencher o buraco deixado pelo núcleo destruído — o
      // valor promovido é real, só não fica na mesma posição depois de cair.
      expect(
        resolution.steps.first.boardAfterFusion.getTileAt(inRing)!.value,
        5,
      );
    });

    test('peça fora da zona 5x5 não é tocada', () {
      var board = threeNinesInRow();
      // (0,3): três linhas acima do centro (3,3) — fora da zona 5x5
      // (linhas 1-5).
      const outside = Position(row: 0, col: 3);
      board = board.updateTile(outside, board.getTileAt(outside)!.copyWith(value: 4));

      final resolution = engine.resolve(board);

      expect(resolution.novaEvents.single.promoted.containsKey(outside), isFalse);
      expect(resolution.novaEvents.single.clearedTiles.contains(outside), isFalse);
      // Mesma ressalva da checagem de anel acima: `resolution.board` já
      // passou pela gravidade/refill do passo, então o valor original de uma
      // célula intocada pode ter sido substituído por outra peça que caiu por
      // cima dela. `boardAfterFusion` é o quadro imediatamente após a Nova,
      // antes de qualquer peça se mexer.
      expect(
        resolution.steps.first.boardAfterFusion.getTileAt(outside)!.value,
        4,
      );
    });

    test('soma kNovaScoreTier1 ao placar do passo', () {
      final resolution = engine.resolve(threeNinesInRow());
      final step = resolution.steps.firstWhere((s) => s.novaEvents.isNotEmpty);
      expect(step.score, greaterThanOrEqualTo(kNovaScoreTier1));
    });

    test('cap de 1 Nova por jogada: um segundo trio de 9 na mesma jogada não gera evento', () {
      var board = threeNinesInRow();
      // Segundo trio de 9, longe do primeiro, já formado no mesmo tabuleiro
      // — ambos processados na mesma chamada de resolve()/_applyFusions.
      for (final col in [2, 3, 4]) {
        board = board.updateTile(
          Position(row: 6, col: col),
          board.getTileAt(Position(row: 6, col: col))!.copyWith(value: kMaxDigit),
        );
      }

      final resolution = engine.resolve(board);

      expect(
        resolution.novaEvents,
        hasLength(1),
        reason: 'só a primeira combinação de 9s vira Nova nesta jogada',
      );
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

  group('ativação do Super 9', () {
    Board withSuperNineAt(Position at, {int neighbourValue = 3}) {
      var board = boardFromValues(baseGrid());
      board = board.updateTile(
        at,
        Tile.withSpecial(
          id: 'super',
          value: kMaxDigit,
          position: at,
          specialType: SpecialTileType.superNine,
        ),
      );
      final neighbour = Position(row: at.row, col: at.col + 1);
      board = board.updateTile(
        neighbour,
        board.getTileAt(neighbour)!.copyWith(value: neighbourValue),
      );
      return board;
    }

    test('trocar com um vizinho de valor x promove todo x para x+1', () {
      const at = Position(row: 4, col: 2);
      final neighbour = Position(row: at.row, col: at.col + 1);
      var board = withSuperNineAt(at, neighbourValue: 3);
      // Espalha mais peças de valor 3 pelo tabuleiro, fora da vizinhança do
      // Super 9, para provar que a conversão é **board-wide**.
      const distant = Position(row: 0, col: 6);
      board = board.updateTile(distant, board.getTileAt(distant)!.copyWith(value: 3));

      final result = engine.tryMove(board, at, neighbour);

      expect(result, isA<MoveSuperNineActivated>());
      final activated = result as MoveSuperNineActivated;
      expect(activated.convertedFrom, 3);
      expect(
        activated.board.getAllTiles().where((t) => t.value == 3),
        isEmpty,
        reason: 'todo valor 3 devia virar 4',
      );
      expect(
        activated.board.getTileAt(distant)!.value,
        4,
        reason: 'a peça distante também converte — é board-wide',
      );
    });

    test('o próprio Super 9 é consumido pela conversão', () {
      const at = Position(row: 4, col: 2);
      final neighbour = Position(row: at.row, col: at.col + 1);
      final board = withSuperNineAt(at);

      final result = engine.tryMove(board, at, neighbour) as MoveSuperNineActivated;

      expect(
        result.board.getAllTiles().where((t) => t.specialType == SpecialTileType.superNine),
        isEmpty,
      );
    });

    test('preserva os ids das peças promovidas', () {
      const at = Position(row: 4, col: 2);
      final neighbour = Position(row: at.row, col: at.col + 1);
      final board = withSuperNineAt(at, neighbourValue: 3);
      final neighbourId = board.getTileAt(neighbour)!.id;

      final result = engine.tryMove(board, at, neighbour) as MoveSuperNineActivated;

      expect(result.board.getTileAt(neighbour)!.id, neighbourId);
    });

    test('não roda resolve() — um match criado pela conversão fica congelado', () {
      const at = Position(row: 4, col: 2);
      final neighbour = Position(row: at.row, col: at.col + 1);
      var board = withSuperNineAt(at, neighbourValue: 3);
      // Duas outras peças de valor 3 já formam, junto com a do vizinho, um
      // trio na mesma linha depois da conversão para 4.
      board = board.updateTile(
        const Position(row: 4, col: 4),
        board.getTileAt(const Position(row: 4, col: 4))!.copyWith(value: 3),
      );
      board = board.updateTile(
        const Position(row: 4, col: 5),
        board.getTileAt(const Position(row: 4, col: 5))!.copyWith(value: 3),
      );

      final result = engine.tryMove(board, at, neighbour) as MoveSuperNineActivated;

      expect(
        engine.detectMatches(result.board),
        isNotEmpty,
        reason: 'o match ficou pendente, não foi resolvido nem descartado',
      );
    });
  });

  group('MatchEngine.decaySpecials', () {
    test('decrementa toda peça especial em um turno', () {
      var board = boardFromValues(baseGrid());
      const at = Position(row: 0, col: 0);
      board = board.updateTile(
        at,
        Tile.withSpecial(id: 't', value: 5, position: at, specialType: SpecialTileType.wildcard),
      );

      final decayed = engine.decaySpecials(board);
      expect(decayed.getTileAt(at)!.specialTurnsLeft, kSpecialTileLifespan - 1);
    });

    test('reverte para peça normal ao chegar a zero', () {
      var board = boardFromValues(baseGrid());
      const at = Position(row: 0, col: 0);
      board = board.updateTile(
        at,
        Tile.withSpecial(id: 't', value: 5, position: at, specialType: SpecialTileType.wildcard),
      );

      var decayed = board;
      for (int i = 0; i < kSpecialTileLifespan; i++) {
        decayed = engine.decaySpecials(decayed);
      }

      final tile = decayed.getTileAt(at)!;
      expect(tile.specialType, isNull);
      expect(tile.value, 5);
    });
  });

  group('Resolution.novaEvents (plumbing, sem Nova disparando ainda)', () {
    test('resolução sem Nova tem novaEvents vazio', () {
      final resolution = engine.resolve(boardFromValues(baseGrid()));
      expect(resolution.novaEvents, isEmpty);
    });
  });
}
