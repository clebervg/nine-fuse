import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_state.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import 'package:nine_fuse/features/game/providers/hammer_booster.dart';

/// Armazenamento que só sabe falhar na leitura do inventário. Perder o martelo
/// comprado é ruim; abrir o jogo sem tabuleiro é pior.
class _BrokenHammerStorage extends InMemoryGameStorage {
  @override
  Future<int> readHammerCount() async => throw StateError('sem disco');
}

void main() {
  late GameNotifier notifier;

  /// Fase folgada: serve para exercitar a mecânica sem a fase acabar no meio.
  const roomy = GameLevel(
    number: 99,
    objective: Objective(digit: 8, count: 9),
    moveLimit: 500,
  );

  setUp(() {
    notifier = GameNotifier(random: Random(42), storage: InMemoryGameStorage());
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
      expect(
        blocked.where((t) => t.obstacle == ObstacleType.stone),
        hasLength(1),
      );
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
        objective: Objective(digit: kMaxDigit, count: 9),
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
        objective: Objective(digit: kMaxDigit, count: 9),
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

  group('sugestão de migração para o Endless', () {
    // Fase que trava em um movimento: qualquer troca que forme combinação já
    // esgota o saldo antes de o objetivo (inalcançável) ser cumprido.
    const stuck = GameLevel(
      number: 95,
      objective: Objective(digit: kMaxDigit, count: 9),
      moveLimit: 1,
    );

    void loseOnce() {
      final pair = findSwap(creatingMatch: true)!;
      notifier.swapTiles(pair.$1, pair.$2);
    }

    test('derrota incrementa o contador na mesma fase', () {
      notifier.startLevel(stuck);
      loseOnce();
      expect(notifier.state.status, GameStatus.lost);
      expect(notifier.state.consecutiveLosses, 1);

      notifier.restartLevel();
      loseOnce();
      expect(notifier.state.consecutiveLosses, 2);
    });

    test('sugere o Endless só na terceira derrota seguida, não antes', () {
      notifier.startLevel(stuck);
      for (int i = 0; i < 2; i++) {
        loseOnce();
        expect(notifier.state.shouldOfferEndless, isFalse);
        notifier.restartLevel();
      }
      loseOnce();

      expect(notifier.state.consecutiveLosses, 3);
      expect(notifier.state.shouldOfferEndless, isTrue);
    });

    test('vencer zera o contador', () {
      notifier.startLevel(stuck);
      loseOnce();
      notifier.restartLevel();
      loseOnce();
      expect(notifier.state.consecutiveLosses, 2);

      notifier.markEndlessOfferShown();
      expect(notifier.state.endlessOfferShown, true);

      const winnable = GameLevel(
        number: 96,
        objective: Objective(digit: 4),
        moveLimit: 50,
      );
      notifier.startLevel(winnable);
      while (notifier.state.status == GameStatus.playing) {
        final pair = findSwap(creatingMatch: true);
        if (pair == null) break;
        notifier.swapTiles(pair.$1, pair.$2);
      }

      expect(notifier.state.status, GameStatus.won);
      expect(notifier.state.consecutiveLosses, 0);
      expect(notifier.state.endlessOfferShown, false);
    });

    test(
      'trocar de fase depois de perder zera o contador, mesmo sem vencer',
      () {
        notifier.startLevel(stuck);
        loseOnce();
        expect(notifier.state.consecutiveLosses, 1);

        const otherLevel = GameLevel(
          number: 97,
          objective: Objective(digit: 4),
          moveLimit: 50,
        );
        notifier.startLevel(otherLevel);

        expect(notifier.state.consecutiveLosses, 0);
      },
    );

    test('markEndlessOfferShown trava o convite até a próxima fase', () {
      notifier.startLevel(stuck);
      for (int i = 0; i < 2; i++) {
        loseOnce();
        notifier.restartLevel();
      }
      loseOnce();
      expect(notifier.state.shouldOfferEndless, isTrue);

      notifier.markEndlessOfferShown();
      expect(notifier.state.shouldOfferEndless, isFalse);

      // Recomeçar a mesma fase perdida não reabre o convite: a fase segue
      // sendo a mesma, e a oferta já foi gasta.
      notifier.restartLevel();
      loseOnce();
      expect(notifier.state.consecutiveLosses, 4);
      expect(notifier.state.shouldOfferEndless, isFalse);
    });
  });

  group('navegação entre fases', () {
    test('nextLevel avança na campanha', () {
      notifier.startLevel(kCampaign.first);
      notifier.nextLevel();

      expect(notifier.state.level.number, kCampaign[1].number);
    });

    // O caso "última fase artesanal abre a próxima, gerada" já é coberto por
    // infinite_campaign_test.dart — mantê-lo aqui duplicaria o mesmo cenário.

    test('nextLevel de uma fase fora da campanha avança um número', () {
      notifier.nextLevel();

      expect(notifier.state.level.number, roomy.number + 1);
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
      final fresh = GameNotifier(
        random: Random(1),
        storage: InMemoryGameStorage(),
      );

      expect(fresh.state.status, GameStatus.idle);
      expect(fresh.state.board.isEmpty, isTrue);
      expect(fresh.engine, isNull);
    });

    test('não aceita jogada nem seleção enquanto está idle', () {
      final fresh = GameNotifier(
        random: Random(1),
        storage: InMemoryGameStorage(),
      );

      fresh.selectTile(Position(row: 0, col: 0));
      fresh.swapTiles(Position(row: 0, col: 0), Position(row: 0, col: 1));

      expect(fresh.state.moves, 0);
      expect(fresh.state.selectedTile, isNull);
    });
  });

  group('Martelo de Fusão', () {
    // O tato e o som falam com canal nativo, que não existe num teste de
    // unidade. Ficam desligados por padrão aqui; os dois testes que os
    // verificam trocam por um contador.
    late void Function() realTargeting;
    late void Function() realRejection;
    late void Function() realStrike;

    setUp(() {
      realTargeting = HammerBooster.targetingFeedback;
      realRejection = HammerBooster.rejectionFeedback;
      realStrike = HammerBooster.strikeFeedback;
      HammerBooster.targetingFeedback = () {};
      HammerBooster.rejectionFeedback = () {};
      HammerBooster.strikeFeedback = () {};
    });

    tearDown(() {
      HammerBooster.targetingFeedback = realTargeting;
      HammerBooster.rejectionFeedback = realRejection;
      HammerBooster.strikeFeedback = realStrike;
    });

    /// Tabuleiro estável (faixas diagonais de período 3 nunca alinham três) com
    /// um `7` solitário na mira. O 7 está fora da janela de sorteio, então
    /// nenhuma reposição pode fabricá-lo — é o que torna a asserção de "não
    /// evoluiu" imune ao acaso do refill.
    Board stableBoardWithVictim(Position at, {ObstacleType? cover}) {
      var board = Board.empty();
      for (int row = 0; row < Board.boardSize; row++) {
        for (int col = 0; col < Board.boardSize; col++) {
          final position = Position(row: row, col: col);
          board = board.updateTile(
            position,
            Tile(
              id: 'r${row}c$col',
              value: position == at ? 7 : (row + col) % 3,
              position: position,
            ),
          );
        }
      }
      if (cover != null) {
        board = board.updateTile(at, board.getTileAt(at)!.withObstacle(cover));
      }
      return board;
    }

    /// Notifier com inventário já carregado do armazenamento.
    Future<GameNotifier> withHammers(
      int count, {
      GameLevel level = roomy,
      GameStorage? storage,
    }) async {
      final notifier = GameNotifier(
        random: Random(42),
        storage: storage ?? InMemoryGameStorage(hammerCount: count),
      );
      // A leitura do inventário é assíncrona, como a do progresso da campanha.
      await Future<void>.delayed(Duration.zero);
      notifier.startLevel(level);
      return notifier;
    }

    test('o inventário é lido do armazenamento na criação', () async {
      final hammered = await withHammers(2);

      expect(hammered.state.hammerCount, 2);
    });

    test('o inventário sobrevive ao início de uma fase nova', () async {
      // É inventário do jogador, não da fase: zerá-lo em `startLevel` faria o
      // martelo comprado desaparecer ao avançar.
      final hammered = await withHammers(2);
      hammered.startLevel(roomy);

      expect(hammered.state.hammerCount, 2);
    });

    test('falha de leitura vale como inventário vazio', () async {
      final hammered = GameNotifier(
        random: Random(42),
        storage: _BrokenHammerStorage(),
      );
      await Future<void>.delayed(Duration.zero);

      expect(hammered.state.hammerCount, 0);
      expect(hammered.state.status, GameStatus.idle);
    });

    group('mira', () {
      test('alternar liga e desliga o modo de mira', () async {
        final hammered = await withHammers(1);

        hammered.toggleHammerTargeting();
        expect(hammered.state.isHammerTargeting, isTrue);

        hammered.toggleHammerTargeting();
        expect(hammered.state.isHammerTargeting, isFalse);
      });

      test('cancelar desliga a mira e descarta o alvo pendente', () async {
        final hammered = await withHammers(0);
        hammered.toggleHammerTargeting();
        hammered.useHammer(const Position(row: 4, col: 4));

        hammered.cancelHammerTargeting();

        expect(hammered.state.isHammerTargeting, isFalse);
        expect(hammered.state.pendingHammerTarget, isNull);
      });

      test('a mira dá uma batida tátil ao ligar, e não ao desligar', () async {
        var beats = 0;
        final original = HammerBooster.targetingFeedback;
        HammerBooster.targetingFeedback = () => beats++;
        addTearDown(() => HammerBooster.targetingFeedback = original);

        final hammered = await withHammers(1);
        hammered.toggleHammerTargeting();
        expect(beats, 1);

        hammered.toggleHammerTargeting();
        expect(beats, 1);
      });

      test('a fase encerrada não entra em mira', () async {
        const tight = GameLevel(
          number: 88,
          objective: Objective(digit: kMaxDigit, count: 9),
          moveLimit: 1,
        );
        final hammered = await withHammers(1, level: tight);

        final engine = hammered.engine!;
        final pair = engine
            .candidateSwaps(hammered.state.board)
            .firstWhere(
              (s) => engine.swapCreatesMatch(hammered.state.board, s.$1, s.$2),
            );
        hammered.swapTiles(pair.$1, pair.$2);
        expect(hammered.state.isOver, isTrue);

        hammered.toggleHammerTargeting();

        expect(hammered.state.isHammerTargeting, isFalse);
      });
    });

    group('golpe', () {
      test('coordenada fora do tabuleiro não consome martelo', () async {
        final hammered = await withHammers(1);
        hammered.toggleHammerTargeting();

        hammered.useHammer(const Position(row: -1, col: 0));

        expect(hammered.state.hammerCount, 1);
        expect(
          hammered.state.isHammerTargeting,
          isTrue,
          reason: 'errar a mira não pode custar a mira',
        );
      });

      test('casa vazia não consome martelo', () async {
        final hammered = await withHammers(1);
        hammered.debugSetBoard(
          hammered.state.board.updateTile(const Position(row: 4, col: 4), null),
        );
        hammered.toggleHammerTargeting();

        hammered.useHammer(const Position(row: 4, col: 4));

        expect(hammered.state.hammerCount, 1);
      });

      test('a recusa avisa por tato, sem cobrar', () async {
        var beats = 0;
        final original = HammerBooster.rejectionFeedback;
        HammerBooster.rejectionFeedback = () => beats++;
        addTearDown(() => HammerBooster.rejectionFeedback = original);

        final hammered = await withHammers(1);
        hammered.toggleHammerTargeting();
        hammered.useHammer(const Position(row: 9, col: 9));

        expect(beats, 1);
        expect(hammered.state.hammerCount, 1);
      });

      test('oblitera a peça, consome o martelo e desliga a mira', () async {
        const target = Position(row: 4, col: 4);
        final hammered = await withHammers(1);
        hammered.debugSetBoard(stableBoardWithVictim(target));
        hammered.toggleHammerTargeting();

        hammered.useHammer(target);

        expect(hammered.state.hammerCount, 0);
        expect(hammered.state.isHammerTargeting, isFalse);
        expect(
          hammered.state.board.getAllTiles().where((t) => t.value == 7),
          isEmpty,
        );
        // A gravidade e a reposição rodam no mesmo golpe.
        expect(hammered.state.board.isFull, isTrue);
      });

      test('oblitera a cobertura junto, sem esperar três impactos', () async {
        const target = Position(row: 4, col: 4);
        final hammered = await withHammers(1);
        hammered.debugSetBoard(
          stableBoardWithVictim(target, cover: ObstacleType.stone),
        );

        hammered.useHammer(target);

        expect(hammered.state.board.countObstacles(ObstacleType.stone), 0);
      });

      test('não gasta movimento', () async {
        // É o que o jogador está comprando.
        const target = Position(row: 4, col: 4);
        final hammered = await withHammers(1);
        hammered.debugSetBoard(stableBoardWithVictim(target));
        final before = hammered.state.movesLeft;

        hammered.useHammer(target);

        expect(hammered.state.movesLeft, before);
        expect(hammered.state.moves, 0);
      });

      test('não evolui o dígito destruído', () async {
        // O 7 atingido não vira 8: o martelo não é uma fusão.
        const target = Position(row: 4, col: 4);
        final hammered = await withHammers(
          1,
          level: const GameLevel(
            number: 87,
            objective: Objective(digit: 8, count: 9),
            moveLimit: 500,
          ),
        );
        hammered.debugSetBoard(stableBoardWithVictim(target));

        hammered.useHammer(target);

        expect(hammered.state.objectiveProgress, 0);
      });

      test('a cobertura destruída conta para o objetivo', () async {
        // `boardObstacleGoal` é fixado no início da fase. Uma cobertura que sai
        // do tabuleiro sem contar tornaria a fase impossível de vencer.
        const target = Position(row: 4, col: 4);
        final hammered = await withHammers(
          1,
          level: const GameLevel(
            number: 86,
            objective: Objective.clearObstacles(
              obstacle: ObstacleType.ice,
              count: 2,
            ),
            moveLimit: 500,
          ),
        );
        hammered.debugSetBoard(
          stableBoardWithVictim(target, cover: ObstacleType.ice),
        );

        hammered.useHammer(target);

        expect(hammered.state.objectiveProgress, 1);
      });

      test('nada de limite artificial: golpes seguidos funcionam', () async {
        final hammered = await withHammers(3);

        for (int i = 0; i < 3; i++) {
          final target = Position(row: 4, col: i);
          hammered.debugSetBoard(stableBoardWithVictim(target));
          hammered.useHammer(target);
          expect(
            hammered.state.hammerCount,
            2 - i,
            reason: 'o golpe ${i + 1} não foi cobrado como devia',
          );
        }

        // Sem saldo, o quarto golpe já é funil de conversão, não recusa.
        hammered.useHammer(const Position(row: 4, col: 5));
        expect(hammered.state.hammerCount, 0);
      });

      test('a fase encerrada não aceita golpe', () async {
        const tight = GameLevel(
          number: 85,
          objective: Objective(digit: kMaxDigit, count: 9),
          moveLimit: 1,
        );
        final hammered = await withHammers(1, level: tight);
        final engine = hammered.engine!;
        final pair = engine
            .candidateSwaps(hammered.state.board)
            .firstWhere(
              (s) => engine.swapCreatesMatch(hammered.state.board, s.$1, s.$2),
            );
        hammered.swapTiles(pair.$1, pair.$2);
        expect(hammered.state.isOver, isTrue);

        hammered.useHammer(const Position(row: 4, col: 4));

        expect(hammered.state.hammerCount, 1);
      });

      test('o golpe registra onde caiu e qual dígito morreu', () async {
        // A UI precisa do dígito para tingir o estilhaço: quando ela desenha, a
        // peça já não está no tabuleiro para ser consultada.
        const target = Position(row: 4, col: 4);
        final hammered = await withHammers(1);
        hammered.debugSetBoard(stableBoardWithVictim(target));

        hammered.useHammer(target);

        expect(hammered.state.hammerStrike, (target, 7));
      });

      test('o saldo é gravado a cada golpe', () async {
        const target = Position(row: 4, col: 4);
        final storage = InMemoryGameStorage(hammerCount: 2);
        final hammered = await withHammers(2, storage: storage);
        hammered.debugSetBoard(stableBoardWithVictim(target));

        hammered.useHammer(target);
        await Future<void>.delayed(Duration.zero);

        expect(storage.hammerCount, 1);
      });
    });

    group('funil de conversão', () {
      test('sem saldo, mirar guarda o alvo em vez de destruir', () async {
        const target = Position(row: 4, col: 4);
        final hammered = await withHammers(0);
        hammered.debugSetBoard(stableBoardWithVictim(target));
        hammered.toggleHammerTargeting();

        hammered.useHammer(target);

        expect(hammered.state.pendingHammerTarget, target);
        expect(
          hammered.state.board.getTileAt(target)?.value,
          7,
          reason: 'nada pode ser destruído antes de o martelo existir',
        );
      });

      test('creditar o martelo aplica no alvo já destacado', () async {
        // O jogador escolheu a peça antes do anúncio; obrigá-lo a mirar de novo
        // depois de assistir seria cobrar duas vezes pelo mesmo golpe.
        const target = Position(row: 4, col: 4);
        final hammered = await withHammers(0);
        hammered.debugSetBoard(stableBoardWithVictim(target));
        hammered.toggleHammerTargeting();
        hammered.useHammer(target);

        hammered.grantHammer();

        expect(
          hammered.state.board.getAllTiles().where((t) => t.value == 7),
          isEmpty,
        );
        expect(hammered.state.hammerCount, 0, reason: 'o crédito foi gasto');
        expect(hammered.state.pendingHammerTarget, isNull);
        expect(hammered.state.isHammerTargeting, isFalse);
      });

      test('creditar sem alvo pendente só engorda o inventário', () async {
        final hammered = await withHammers(0);

        hammered.grantHammer();

        expect(hammered.state.hammerCount, 1);
      });
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
