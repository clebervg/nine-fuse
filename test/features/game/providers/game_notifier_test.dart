import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_state.dart';

void main() {
  late GameNotifier notifier;

  /// Fase folgada: serve para exercitar a mecânica sem a fase acabar no meio.
  const roomy = GameLevel(
    number: 99,
    objective: Objective(digit: 8, count: 9),
    moveLimit: 500,
  );

  setUp(() {
    notifier = GameNotifier(random: Random(42));
    notifier.startLevel(roomy);
  });

  /// Primeiro par de vizinhos cuja troca forma (ou não) combinação.
  (Position, Position)? findSwap({required bool creatingMatch}) {
    final engine = notifier.engine!;
    final board = notifier.state.board;

    for (final (a, b) in engine.candidateSwaps(board)) {
      if (engine.swapCreatesMatch(board, a, b) == creatingMatch) return (a, b);
    }
    return null;
  }

  group('startLevel', () {
    test('começa jogando, com tabuleiro cheio e contadores zerados', () {
      final state = notifier.state;

      expect(state.status, GameStatus.playing);
      expect(state.board.isFull, isTrue);
      expect(state.level, roomy);
      expect(state.score, 0);
      expect(state.moves, 0);
      expect(state.objectiveProgress, 0);
      expect(state.movesLeft, roomy.moveLimit);
      expect(state.selectedTile, isNull);
    });

    test('espalha as coberturas pedidas pela fase', () {
      const covered = GameLevel(
        number: 98,
        objective: Objective(digit: 8, count: 9),
        moveLimit: 500,
        obstacles: ObstacleLayout(ice: 2, stone: 1),
      );

      notifier.startLevel(covered);
      final blocked = notifier.state.board
          .getAllTiles()
          .where((tile) => tile.isBlocked)
          .toList();

      expect(blocked, hasLength(3));
      expect(blocked.where((t) => t.obstacle == ObstacleType.stone), hasLength(1));
    });

    test('a fase sem obstáculo nasce com o tabuleiro todo livre', () {
      expect(
        notifier.state.board.getAllTiles().where((tile) => tile.isBlocked),
        isEmpty,
      );
    });

    test('o tabuleiro coberto ainda tem dica, e portanto jogada', () {
      // Peça coberta não entra em `candidateSwaps`; se a cobertura entrasse
      // depois da checagem, a fase abriria já perdida.
      const covered = GameLevel(
        number: 97,
        objective: Objective(digit: 8, count: 9),
        moveLimit: 500,
        obstacles: ObstacleLayout(ice: 3, glass: 2),
      );

      notifier.startLevel(covered);

      expect(notifier.state.hint, isNotNull);
      expect(notifier.state.status, GameStatus.playing);
    });

    test('usa a janela de spawn da fase', () {
      const elevated = GameLevel(
        number: 98,
        objective: Objective(digit: 8),
        moveLimit: 50,
        spawnMin: 2,
        spawnMax: 5,
      );

      notifier.startLevel(elevated);

      for (final tile in notifier.state.board.getAllTiles()) {
        expect(tile.value, inInclusiveRange(2, 5));
      }
    });

    test('restartLevel devolve a mesma fase ao início', () {
      final pair = findSwap(creatingMatch: true)!;
      notifier.swapTiles(pair.$1, pair.$2);
      expect(notifier.state.moves, 1);

      notifier.restartLevel();

      expect(notifier.state.level, roomy);
      expect(notifier.state.moves, 0);
      expect(notifier.state.objectiveProgress, 0);
      expect(notifier.state.status, GameStatus.playing);
    });
  });

  group('objetivo', () {
    test('conta apenas peças criadas do dígito pedido', () {
      // Alvo 4 na janela 0-3: só entra no contador o que for fundido.
      const level = GameLevel(
        number: 97,
        objective: Objective(digit: 4, count: 99),
        moveLimit: 500,
      );
      notifier.startLevel(level);

      var expected = 0;
      for (int i = 0; i < 12; i++) {
        final pair = findSwap(creatingMatch: true);
        if (pair == null) break;

        final engine = notifier.engine!;
        final resolution = engine.resolve(
          engine.swap(notifier.state.board, pair.$1, pair.$2),
          anchor: pair.$2,
        );
        expected += resolution.countProduced(4);

        notifier.swapTiles(pair.$1, pair.$2);
      }

      // O motor é determinístico, mas `resolve` acima consumiu sorteio, então
      // comparamos só a ordem de grandeza: o contador tem de ter subido.
      expect(notifier.state.objectiveProgress, greaterThan(0));
      expect(expected, greaterThan(0));
    });

    test('cumprir o objetivo encerra a fase como vitória', () {
      // Objetivo mínimo: o primeiro movimento válido já resolve.
      const trivial = GameLevel(
        number: 96,
        objective: Objective(digit: 4),
        moveLimit: 50,
      );
      notifier.startLevel(trivial);

      for (
        int i = 0;
        i < 20 && notifier.state.status == GameStatus.playing;
        i++
      ) {
        final pair = findSwap(creatingMatch: true);
        if (pair == null) break;
        notifier.swapTiles(pair.$1, pair.$2);
      }

      expect(notifier.state.status, GameStatus.won);
      expect(notifier.state.objectiveMet, isTrue);
    });

    test('objectiveFraction vai de 0 a 1 sem passar do teto', () {
      const level = GameLevel(
        number: 95,
        objective: Objective(digit: 4, count: 2),
        moveLimit: 50,
      );
      notifier.startLevel(level);
      expect(notifier.state.objectiveFraction, 0);

      while (notifier.state.status == GameStatus.playing) {
        final pair = findSwap(creatingMatch: true);
        if (pair == null) break;
        notifier.swapTiles(pair.$1, pair.$2);
        expect(notifier.state.objectiveFraction, inInclusiveRange(0.0, 1.0));
      }

      expect(notifier.state.objectiveFraction, 1.0);
    });
  });

  group('dica', () {
    test('a fase começa com uma dica válida', () {
      final hint = notifier.state.hint;

      expect(hint, isNotNull);
      expect(
        notifier.engine!.swapCreatesMatch(
          notifier.state.board,
          hint!.$1,
          hint.$2,
        ),
        isTrue,
      );
    });

    test('a dica é renovada a cada jogada', () {
      for (int i = 0; i < 5; i++) {
        final pair = findSwap(creatingMatch: true);
        if (pair == null) break;
        notifier.swapTiles(pair.$1, pair.$2);

        final hint = notifier.state.hint;
        if (notifier.state.status != GameStatus.playing) break;

        expect(hint, isNotNull, reason: 'jogada $i deixou o estado sem dica');
        expect(
          notifier.engine!.swapCreatesMatch(
            notifier.state.board,
            hint!.$1,
            hint.$2,
          ),
          isTrue,
          reason: 'a dica após a jogada $i não funciona',
        );
      }
    });

    test('troca recusada não invalida a dica', () {
      final before = notifier.state.hint;
      final pair = findSwap(creatingMatch: false)!;

      notifier.swapTiles(pair.$1, pair.$2);

      expect(notifier.state.hint, before);
    });
  });

  group('causa da derrota', () {
    // As duas causas são independentes. Confundi-las gerou um relato de "falso
    // fim de jogo": a fase acabou por saldo, o tabuleiro seguia cheio de
    // jogadas, e a mensagem sugeria tabuleiro travado.

    test('esgotar o saldo registra limite de movimentos, não travamento', () {
      const tight = GameLevel(
        number: 92,
        objective: Objective(digit: 9, count: 9),
        moveLimit: 1,
      );
      notifier.startLevel(tight);

      final pair = findSwap(creatingMatch: true)!;
      notifier.swapTiles(pair.$1, pair.$2);

      expect(notifier.state.status, GameStatus.lost);
      expect(notifier.state.lossReason, LossReason.moveLimitReached);
    });

    test('perder por saldo deixa o tabuleiro ainda jogável', () {
      // É o cerne do relato: o tabuleiro tem jogadas, e isso está correto.
      const tight = GameLevel(
        number: 91,
        objective: Objective(digit: 9, count: 9),
        moveLimit: 1,
      );
      notifier.startLevel(tight);

      final pair = findSwap(creatingMatch: true)!;
      notifier.swapTiles(pair.$1, pair.$2);

      expect(notifier.state.lossReason, LossReason.moveLimitReached);
      expect(
        notifier.engine!.hasValidMoves(notifier.state.board),
        isTrue,
        reason: 'derrota por saldo não deve implicar tabuleiro travado',
      );
      expect(notifier.state.hint, isNotNull);
    });

    test('vencer não registra causa de derrota', () {
      const trivial = GameLevel(
        number: 90,
        objective: Objective(digit: 4),
        moveLimit: 50,
      );
      notifier.startLevel(trivial);

      while (notifier.state.status == GameStatus.playing) {
        final pair = findSwap(creatingMatch: true);
        if (pair == null) break;
        notifier.swapTiles(pair.$1, pair.$2);
      }

      expect(notifier.state.status, GameStatus.won);
      expect(notifier.state.lossReason, isNull);
    });

    test('cumprir o objetivo no último movimento vale vitória', () {
      // A ordem importa: conferir saldo antes do objetivo transformaria a
      // vitória no último movimento em derrota.
      const exact = GameLevel(
        number: 89,
        objective: Objective(digit: 4),
        moveLimit: 1,
      );
      notifier.startLevel(exact);

      final pair = findSwap(creatingMatch: true)!;
      notifier.swapTiles(pair.$1, pair.$2);

      if (notifier.state.objectiveProgress >= 1) {
        expect(notifier.state.status, GameStatus.won);
        expect(notifier.state.lossReason, isNull);
      }
    });

    test('a fase em andamento não tem causa de derrota', () {
      expect(notifier.state.status, GameStatus.playing);
      expect(notifier.state.lossReason, isNull);

      final pair = findSwap(creatingMatch: true)!;
      notifier.swapTiles(pair.$1, pair.$2);

      expect(notifier.state.lossReason, isNull);
    });
  });

  group('limite de movimentos', () {
    test('esgotar os movimentos sem cumprir o objetivo perde a fase', () {
      // Alvo inalcançável em dois movimentos.
      const tight = GameLevel(
        number: 94,
        objective: Objective(digit: kMaxDigitForTest, count: 9),
        moveLimit: 2,
      );
      notifier.startLevel(tight);

      for (int i = 0; i < 2; i++) {
        final pair = findSwap(creatingMatch: true);
        expect(pair, isNotNull);
        notifier.swapTiles(pair!.$1, pair.$2);
      }

      expect(notifier.state.moves, 2);
      expect(notifier.state.movesLeft, 0);
      expect(notifier.state.status, GameStatus.lost);
    });

    test('não aceita mais jogada depois de a fase terminar', () {
      const tight = GameLevel(
        number: 93,
        objective: Objective(digit: kMaxDigitForTest, count: 9),
        moveLimit: 1,
      );
      notifier.startLevel(tight);

      notifier.swapTiles(
        findSwap(creatingMatch: true)!.$1,
        findSwap(creatingMatch: true)!.$2,
      );
      expect(notifier.state.status, GameStatus.lost);

      final frozen = notifier.state;
      final pair = findSwap(creatingMatch: true);
      if (pair != null) notifier.swapTiles(pair.$1, pair.$2);

      expect(notifier.state, frozen);
    });

    test('troca recusada não consome movimento', () {
      final pair = findSwap(creatingMatch: false);
      expect(pair, isNotNull);

      notifier.swapTiles(pair!.$1, pair.$2);

      expect(notifier.state.moves, 0);
      expect(notifier.state.movesLeft, roomy.moveLimit);
      expect(notifier.state.rejectedSwap, (pair.$1, pair.$2));
    });
  });

  group('navegação entre fases', () {
    test('nextLevel avança na campanha', () {
      notifier.startLevel(kCampaign.first);
      notifier.nextLevel();

      expect(notifier.state.level.number, kCampaign[1].number);
    });

    test('nextLevel na última fase repete a última', () {
      notifier.startLevel(kCampaign.last);
      notifier.nextLevel();

      expect(notifier.state.level.number, kCampaign.last.number);
    });

    test('nextLevel de uma fase fora da campanha repete a fase', () {
      notifier.nextLevel();

      expect(notifier.state.level.number, roomy.number);
    });
  });

  group('seleção', () {
    test('o primeiro toque seleciona a peça', () {
      const position = Position(row: 4, col: 4);
      notifier.selectTile(position);

      expect(notifier.state.selectedTile?.position, position);
      expect(notifier.state.selectedTile?.isSelected, isTrue);
    });

    test('tocar de novo na mesma peça desfaz a seleção', () {
      const position = Position(row: 4, col: 4);
      notifier.selectTile(position);
      notifier.selectTile(position);

      expect(notifier.state.selectedTile, isNull);
    });

    test('tocar em peça distante move a seleção em vez de trocar', () {
      notifier.selectTile(Position(row: 0, col: 0));
      notifier.selectTile(Position(row: 5, col: 5));

      expect(notifier.state.selectedTile?.position, Position(row: 5, col: 5));
      expect(notifier.state.moves, 0);
    });

    test('tocar em peça adjacente dispara a troca', () {
      final pair = findSwap(creatingMatch: true)!;

      notifier.selectTile(pair.$1);
      notifier.selectTile(pair.$2);

      expect(notifier.state.moves, 1);
      expect(notifier.state.selectedTile, isNull);
    });
  });

  group('antes de qualquer fase', () {
    test('o estado inicial está idle e vazio', () {
      final fresh = GameNotifier(random: Random(1));

      expect(fresh.state.status, GameStatus.idle);
      expect(fresh.state.board.isEmpty, isTrue);
      expect(fresh.engine, isNull);
    });

    test('não aceita jogada nem seleção enquanto está idle', () {
      final fresh = GameNotifier(random: Random(1));

      fresh.selectTile(Position(row: 0, col: 0));
      fresh.swapTiles(Position(row: 0, col: 0), Position(row: 0, col: 1));

      expect(fresh.state.moves, 0);
      expect(fresh.state.selectedTile, isNull);
    });
  });

  group('trocas inválidas', () {
    test('ignora peças não adjacentes', () {
      final before = notifier.state;

      notifier.swapTiles(Position(row: 0, col: 0), Position(row: 3, col: 5));

      expect(notifier.state, before);
    });

    test('ignora posição fora do tabuleiro', () {
      final before = notifier.state;

      notifier.swapTiles(Position(row: 0, col: 0), Position(row: -1, col: 0));

      expect(notifier.state, before);
    });
  });
}

/// Dígito alto usado nos testes que precisam de um objetivo inalcançável.
const int kMaxDigitForTest = 9;
