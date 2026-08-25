import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/special_tile.dart';
import 'package:nine_fuse/features/game/presentation/juice/juice_director.dart';
import 'package:nine_fuse/features/game/presentation/juice/juice_priority.dart';

FusionEvent _fusion({int matchLength = 3, int value = 4, SpecialTileType? specialType}) {
  return FusionEvent(
    consumed: const [Position(row: 0, col: 0)],
    at: const Position(row: 0, col: 0),
    tileId: 't',
    value: value,
    matchLength: matchLength,
    score: 0,
    specialType: specialType,
  );
}

void main() {
  group('JuicePriority', () {
    test('ordem é normal < good < great < epic < legendary < supernova', () {
      expect(JuicePriority.normal.index, lessThan(JuicePriority.good.index));
      expect(JuicePriority.good.index, lessThan(JuicePriority.great.index));
      expect(JuicePriority.great.index, lessThan(JuicePriority.epic.index));
      expect(JuicePriority.epic.index, lessThan(JuicePriority.legendary.index));
      expect(JuicePriority.legendary.index, lessThan(JuicePriority.supernova.index));
    });
  });

  group('JuiceDirector.priorityOf', () {
    test('match-3 comum é good', () {
      final resolution = Resolution(
        board: Board.empty(),
        steps: [
          ResolutionStep(
            cascade: 1,
            fusions: [_fusion(matchLength: 3, value: 4)],
            boardAfterFusion: Board.empty(),
            boardAfterSettle: Board.empty(),
            score: 0,
          ),
        ],
      );
      expect(JuiceDirector.priorityOf(resolution), JuicePriority.good);
    });

    test('match-4 comum é great', () {
      final resolution = Resolution(
        board: Board.empty(),
        steps: [
          ResolutionStep(
            cascade: 1,
            // Nota: usa value: 5 (não kMaxDigit) para não colidir com o
            // teste "epic" abaixo — a regra real é "match-4 com valor
            // kMaxDigit" -> epic, "match-4 com outro valor" -> great.
            fusions: [_fusion(matchLength: 4, value: 5)],
            boardAfterFusion: Board.empty(),
            boardAfterSettle: Board.empty(),
            score: 0,
          ),
        ],
      );
      expect(JuiceDirector.priorityOf(resolution), JuicePriority.great);
    });

    test('Bloco 9 (4x com valor kMaxDigit) é epic', () {
      final resolution = Resolution(
        board: Board.empty(),
        steps: [
          ResolutionStep(
            cascade: 1,
            fusions: [_fusion(matchLength: 4, value: kMaxDigit)],
            boardAfterFusion: Board.empty(),
            boardAfterSettle: Board.empty(),
            score: 0,
          ),
        ],
      );
      expect(JuiceDirector.priorityOf(resolution), JuicePriority.epic);
    });

    test('criação de Super 9 é supernova e suprime os demais', () {
      final resolution = Resolution(
        board: Board.empty(),
        steps: [
          ResolutionStep(
            cascade: 1,
            fusions: [
              _fusion(matchLength: 3, value: 2),
              _fusion(matchLength: 5, value: kMaxDigit, specialType: SpecialTileType.superNine),
            ],
            boardAfterFusion: Board.empty(),
            boardAfterSettle: Board.empty(),
            score: 0,
          ),
        ],
      );
      expect(JuiceDirector.priorityOf(resolution), JuicePriority.supernova);
    });
  });

  group('JuiceDirector.priorityForSuperNineActivation', () {
    test('ativação (troca com o Super 9) é sempre supernova', () {
      expect(JuiceDirector.priorityForSuperNineActivation(), JuicePriority.supernova);
    });
  });
}
