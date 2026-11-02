import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/audio/sound_event.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/nova_event.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/special_tile.dart';
import 'package:nine_fuse/features/game/providers/step_sounds.dart';

const _origin = Position(row: 0, col: 0);

FusionEvent _fusion({int value = 4, SpecialTileType? specialType}) =>
    FusionEvent(
      consumed: const [_origin],
      at: _origin,
      tileId: 't',
      value: value,
      matchLength: 3,
      score: 0,
      specialType: specialType,
    );

ResolutionStep _step({
  int cascade = 1,
  List<FusionEvent>? fusions,
  List<ObstacleHit> obstacleHits = const [],
  List<NovaEvent> novaEvents = const [],
}) => ResolutionStep(
  cascade: cascade,
  fusions: fusions ?? [_fusion()],
  boardAfterFusion: Board.empty(),
  boardAfterSettle: Board.empty(),
  score: 0,
  obstacleHits: obstacleHits,
  novaEvents: novaEvents,
);

void main() {
  test('fusão comum na jogada do jogador', () {
    expect(stepSound(_step()), SoundEvent.fusion);
  });

  test('cascata 2+ é combo', () {
    expect(stepSound(_step(cascade: 2)), SoundEvent.combo);
  });

  test('o 9 nascendo vence a fusão comum do mesmo passo', () {
    final step = _step(
      cascade: 3,
      fusions: [
        _fusion(),
        _fusion(value: kMaxDigit),
      ],
    );
    expect(stepSound(step), SoundEvent.nineBorn);
  });

  test('o Super 9 vence o 9 comum', () {
    final step = _step(
      fusions: [
        _fusion(value: kMaxDigit),
        _fusion(value: kMaxDigit, specialType: SpecialTileType.superNine),
      ],
    );
    expect(stepSound(step), SoundEvent.superNine);
  });

  test('passo sem fusão (golpe do Martelo) não tem som de fusão', () {
    expect(stepSound(_step(cascade: 0, fusions: const [])), isNull);
  });

  test('a Nova soa no fim do hitstop, não no quadro da fusão', () {
    final step = _step(
      fusions: [_fusion(value: kMaxDigit)],
      novaEvents: const [
        NovaEvent(
          at: _origin,
          tier: 1,
          obstacleHits: [],
          clearedTiles: {},
          promoted: {},
        ),
      ],
    );
    expect(stepSound(step), isNull);
  });

  test('só a cobertura quebrada soa; trincar não', () {
    const cracked = ObstacleHit(
      position: _origin,
      type: ObstacleType.glass,
      remainingHp: 1,
    );
    const broken = ObstacleHit(
      position: _origin,
      type: ObstacleType.ice,
      remainingHp: 0,
    );

    expect(stepBreaksObstacle(_step(obstacleHits: const [cracked])), isFalse);
    expect(
      stepBreaksObstacle(_step(obstacleHits: const [cracked, broken])),
      isTrue,
    );
  });
}
