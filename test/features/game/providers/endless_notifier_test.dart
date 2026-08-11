import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/endless_progression.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/providers/endless_notifier.dart';
import 'package:nine_fuse/features/game/providers/endless_state.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';

void main() {
  late InMemoryGameStorage storage;
  late EndlessNotifier notifier;

  setUp(() {
    storage = InMemoryGameStorage();
    notifier = EndlessNotifier(random: Random(7), storage: storage);
  });

  (Position, Position)? findSwap({required bool creatingMatch}) {
    final engine = notifier.engine!;
    final board = notifier.state.board;

    for (final (a, b) in engine.candidateSwaps(board)) {
      if (engine.swapCreatesMatch(board, a, b) == creatingMatch) return (a, b);
    }
    return null;
  }

  /// Joga até travar ou até [cap] movimentos.
  int playUntilStuck({int cap = 600}) {
    var played = 0;
    while (played < cap && notifier.state.status == EndlessStatus.playing) {
      final pair = findSwap(creatingMatch: true);
      if (pair == null) break;
      notifier.swapTiles(pair.$1, pair.$2);
      played++;
    }
    return played;
  }

  group('start', () {
    test('começa jogando, sem objetivo e no primeiro degrau', () async {
      await notifier.start();
      final state = notifier.state;

      expect(state.status, EndlessStatus.playing);
      expect(state.board.isFull, isTrue);
      expect(state.step, EndlessProgression.firstStep);
      expect(state.score, 0);
      expect(state.moves, 0);
      expect(state.isRecord, isFalse);
    });

    test('a janela inicial é a do primeiro degrau', () async {
      await notifier.start();

      expect(notifier.engine!.spawnMin, 0);
      expect(notifier.engine!.spawnMax, 3);
      for (final tile in notifier.state.board.getAllTiles()) {
        expect(tile.value, inInclusiveRange(0, 3));
      }
    });

    test('carrega o recorde salvo', () async {
      storage = InMemoryGameStorage(highScore: 12345);
      notifier = EndlessNotifier(random: Random(7), storage: storage);

      await notifier.start();

      expect(notifier.highScore, 12345);
    });
  });

  group('progressão da janela', () {
    test('a janela sobe ao longo da partida', () async {
      await notifier.start();
      playUntilStuck();

      expect(
        notifier.state.step,
        greaterThan(EndlessProgression.firstStep),
        reason: 'a janela deveria ter subido em uma partida inteira',
      );
      // A janela do motor tem de acompanhar o degrau do estado.
      expect(
        notifier.engine!.spawnMin,
        const EndlessProgression().spawnMinFor(notifier.state.step),
      );
    });

    test('o primeiro degrau abre o tabuleiro sem cobertura', () async {
      await notifier.start();

      expect(
        notifier.state.board.getAllTiles().where((tile) => tile.isBlocked),
        isEmpty,
      );
    });

    test('subir de degrau acrescenta cobertura ao tabuleiro', () async {
      await notifier.start();
      playUntilStuck();

      expect(
        notifier.state.step,
        greaterThan(EndlessProgression.firstStep),
        reason: 'sem promoção este teste não prova nada',
      );
      expect(
        notifier.state.board.getAllTiles().where((tile) => tile.isBlocked),
        isNotEmpty,
      );
    });

    test('a cobertura acrescentada nunca encosta em outra', () async {
      await notifier.start();
      playUntilStuck();

      final board = notifier.state.board;
      for (final tile in board.getAllTiles().where((t) => t.isBlocked)) {
        for (final neighbour in tile.position.orthogonalNeighbours) {
          expect(
            board.getTileAt(neighbour)?.isBlocked ?? false,
            isFalse,
            reason: '${tile.position} encosta em $neighbour',
          );
        }
      }
    });

    test('a partida nunca trava por causa da cobertura recém-posta', () async {
      // Travar é fim de corrida legítimo — mas por assoreamento do tabuleiro,
      // nunca por o próprio jogo ter coberto a última jogada disponível.
      await notifier.start();
      playUntilStuck();

      if (notifier.state.status == EndlessStatus.stuck) {
        expect(notifier.engine!.findHint(notifier.state.board), isNull);
      }
    });

    test('a janela nunca passa do último degrau', () async {
      await notifier.start();
      playUntilStuck();

      expect(
        notifier.state.step,
        lessThanOrEqualTo(EndlessProgression.lastStep),
      );
      expect(notifier.engine!.spawnMax, lessThan(9));
    });
  });

  group('fim da corrida', () {
    test('travar encerra a partida sem ser derrota', () async {
      await notifier.start();
      final played = playUntilStuck();

      // Com a janela progressiva a partida é longa; se travou, o estado tem de
      // refletir isso, e não ficar aceitando jogadas.
      if (notifier.state.status == EndlessStatus.stuck) {
        expect(notifier.state.isOver, isTrue);
        expect(
          findSwap(creatingMatch: true),
          isNull,
          reason: 'travou mas ainda havia jogada disponível',
        );
      } else {
        expect(played, greaterThan(0));
      }
    });

    test('não aceita jogada depois de travar', () async {
      await notifier.start();
      playUntilStuck();

      if (notifier.state.status != EndlessStatus.stuck) return;

      final frozen = notifier.state;
      notifier.swapTiles(Position(row: 0, col: 0), Position(row: 0, col: 1));

      expect(notifier.state, frozen);
    });
  });

  group('recorde', () {
    test('grava o recorde ao terminar acima do anterior', () async {
      await notifier.start();
      playUntilStuck();
      if (notifier.state.status != EndlessStatus.stuck) return;

      expect(notifier.state.score, greaterThan(0));
      expect(await storage.readHighScore(), notifier.state.score);
      expect(notifier.state.isRecord, isTrue);
    });

    test('não regrava quando a corrida fica abaixo do recorde', () async {
      storage = InMemoryGameStorage(highScore: 9999999);
      notifier = EndlessNotifier(random: Random(7), storage: storage);

      await notifier.start();
      playUntilStuck();

      expect(await storage.readHighScore(), 9999999);
      expect(notifier.state.isRecord, isFalse);
    });
  });

  group('dica', () {
    test('a corrida começa com uma dica válida', () async {
      await notifier.start();
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

    test('travar zera a dica', () async {
      await notifier.start();
      playUntilStuck();

      if (notifier.state.status != EndlessStatus.stuck) return;

      // Sem jogada não há o que sugerir: dica nula e fim da corrida são a
      // mesma condição.
      expect(notifier.state.hint, isNull);
    });
  });

  group('mecânica', () {
    test('troca recusada não conta movimento nem pontos', () async {
      await notifier.start();
      final pair = findSwap(creatingMatch: false);
      expect(pair, isNotNull);

      notifier.swapTiles(pair!.$1, pair.$2);

      expect(notifier.state.moves, 0);
      expect(notifier.state.score, 0);
      expect(notifier.state.rejectedSwap, (pair.$1, pair.$2));
    });

    test('jogada válida pontua e mantém o tabuleiro cheio', () async {
      await notifier.start();
      notifier.swapTiles(
        findSwap(creatingMatch: true)!.$1,
        findSwap(creatingMatch: true)!.$2,
      );

      expect(notifier.state.moves, 1);
      expect(notifier.state.score, greaterThan(0));
      expect(notifier.state.board.isFull, isTrue);
    });

    test('registra o maior dígito criado', () async {
      await notifier.start();
      playUntilStuck(cap: 200);

      expect(
        notifier.state.highestDigit,
        greaterThan(3),
        reason: 'em 200 movimentos deveria ter passado da janela inicial',
      );
    });

    test('não aceita jogada antes de start', () {
      notifier.swapTiles(Position(row: 0, col: 0), Position(row: 0, col: 1));

      expect(notifier.state.status, EndlessStatus.idle);
      expect(notifier.state.moves, 0);
    });

    test('seleção segue a mesma regra da campanha', () async {
      await notifier.start();
      const position = Position(row: 4, col: 4);

      notifier.selectTile(position);
      expect(notifier.state.selectedTile?.position, position);

      notifier.selectTile(position);
      expect(notifier.state.selectedTile, isNull);
    });
  });
}
