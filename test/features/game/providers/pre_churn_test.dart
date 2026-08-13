import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_state.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';

/// Monta um tabuleiro 8x8 a partir de uma matriz de valores.
Board _boardFromValues(List<List<int>> values) {
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

/// A uma troca de fundir três peças de [value], em **L**.
Board _boardWithTrio(int value) {
  final grid = [
    for (int row = 0; row < Board.boardSize; row++)
      [for (int col = 0; col < Board.boardSize; col++) (row + col) % 3],
  ];
  grid[4][2] = value;
  grid[4][4] = value;
  grid[3][3] = value;
  return _boardFromValues(grid);
}

void _playTrio(void Function(Position, Position) swap) =>
    swap(const Position(row: 3, col: 3), const Position(row: 4, col: 3));

void main() {
  /// Uma fase que pede muito mais do que uma jogada entrega, para o objetivo
  /// nunca se cumprir sozinho no meio do teste.
  GameNotifier notifierWith({required int moveLimit, int objective = 99}) {
    final notifier = GameNotifier(
      random: Random(7),
      storage: InMemoryGameStorage(),
    );
    notifier.startLevel(
      GameLevel(
        number: 42,
        objective: Objective(digit: 6, count: objective),
        moveLimit: moveLimit,
      ),
    );
    return notifier;
  }

  group('quando o convite de movimentos aparece', () {
    test('uma fase que acabou de começar não pede socorro', () {
      expect(notifierWith(moveLimit: 20).state.shouldOfferMoves, isFalse);
    });

    test('uma fase curta não pede socorro antes da primeira jogada', () {
      // Uma fase que nasce no limiar é fase **apertada de projeto**, não um
      // jogador em apuros. Oferecer aqui venderia movimento para quem ainda não
      // gastou nenhum — e "quase lá" seria mentira na tela de abertura.
      final notifier = notifierWith(moveLimit: kPreChurnMovesLeft);

      expect(notifier.state.movesLeft, kPreChurnMovesLeft);
      expect(notifier.state.shouldOfferMoves, isFalse);
    });

    test('o convite abre no limiar de movimentos restantes', () {
      // O jogador ainda tem jogadas: é isso que faz a oferta ser sobre
      // *continuar*, e não sobre reviver. Oferecer no zero seria a tela de
      // derrota, que a regra anti-churn proíbe de monetizar.
      final notifier = notifierWith(moveLimit: kPreChurnMovesLeft + 1);
      notifier.debugSetBoard(_boardWithTrio(5));

      expect(notifier.state.shouldOfferMoves, isFalse);
      _playTrio(notifier.swapTiles);

      expect(notifier.state.movesLeft, kPreChurnMovesLeft);
      expect(notifier.state.shouldOfferMoves, isTrue);
    });

    test('não abre com o objetivo já cumprido', () {
      // A fase está ganha na prática; vender movimento aqui é vender nada.
      final notifier = notifierWith(
        moveLimit: kPreChurnMovesLeft + 1,
        objective: 1,
      );
      notifier.debugSetBoard(_boardWithTrio(5));
      _playTrio(notifier.swapTiles);

      expect(notifier.state.objectiveMet, isTrue);
      expect(notifier.state.shouldOfferMoves, isFalse);
    });

    test('não abre com a fase encerrada', () {
      final notifier = notifierWith(moveLimit: 1);
      notifier.debugSetBoard(_boardWithTrio(5));
      _playTrio(notifier.swapTiles);

      expect(notifier.state.isOver, isTrue);
      expect(notifier.state.shouldOfferMoves, isFalse);
    });

    test('não abre duas vezes na mesma fase', () {
      // Sem isto o convite voltaria a cada jogada enquanto o saldo ficasse no
      // limiar — e um anúncio que se reoferece sozinho é o churn que ele
      // deveria estar evitando.
      final notifier = notifierWith(moveLimit: kPreChurnMovesLeft + 1);
      notifier.debugSetBoard(_boardWithTrio(5));
      _playTrio(notifier.swapTiles);
      expect(notifier.state.shouldOfferMoves, isTrue);

      notifier.markMovesOfferShown();

      expect(notifier.state.shouldOfferMoves, isFalse);
    });

    test('recomeçar a fase devolve o convite', () {
      final notifier = notifierWith(moveLimit: kPreChurnMovesLeft + 1);
      notifier.markMovesOfferShown();

      notifier.restartLevel();

      expect(notifier.state.movesOfferShown, isFalse);
    });
  });

  group('o que o anúncio paga', () {
    test('o prêmio soma ao saldo sem apagar as jogadas já feitas', () {
      final notifier = notifierWith(moveLimit: kPreChurnMovesLeft + 1);
      notifier.debugSetBoard(_boardWithTrio(5));
      _playTrio(notifier.swapTiles);

      final movesBefore = notifier.state.moves;
      notifier.grantBonusMoves();

      expect(notifier.state.movesLeft, kPreChurnMovesLeft + kPreChurnReward);
      expect(
        notifier.state.moves,
        movesBefore,
        reason: 'o prêmio apagou jogadas feitas em vez de somar ao limite',
      );
    });

    test('o prêmio tira a fase do limiar e fecha o convite', () {
      final notifier = notifierWith(moveLimit: kPreChurnMovesLeft + 1);
      notifier.debugSetBoard(_boardWithTrio(5));
      _playTrio(notifier.swapTiles);

      notifier.grantBonusMoves();

      expect(notifier.state.shouldOfferMoves, isFalse);
    });

    test('a fase encerrada não aceita o prêmio', () {
      // O cartão de derrota já subiu: creditar movimentos aqui deixaria o
      // jogador com saldo numa fase que acabou.
      final notifier = notifierWith(moveLimit: 1);
      notifier.debugSetBoard(_boardWithTrio(5));
      _playTrio(notifier.swapTiles);
      final before = notifier.state.movesAvailable;

      notifier.grantBonusMoves();

      expect(notifier.state.movesAvailable, before);
    });
  });
}
