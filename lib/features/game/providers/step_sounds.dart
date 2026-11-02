import 'package:nine_fuse/core/audio/sound_event.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/special_tile.dart';

/// O efeito sonoro do quadro de fusão de um passo da cascata.
///
/// **Um som por passo, o mais forte vence.** Um passo pode ter três fusões e
/// um 9 nascendo junto: tocar todos empilharia quatro sons no mesmo quadro, e
/// o clímax se perderia no meio da fusão comum. Quem decide a hierarquia é
/// esta função pura — campanha e Recorde a compartilham, para o mesmo passo
/// não soar de dois jeitos.
///
/// Devolve nulo quando o passo não tem fusão (o passo 0 do Martelo, cujo som
/// é o do golpe) ou quando é uma Nova: a Nova soa no fim do hitstop, junto do
/// payoff, e não no instante em que os 9s se alinham.
SoundEvent? stepSound(ResolutionStep step) {
  if (step.novaEvents.isNotEmpty || step.fusions.isEmpty) return null;
  if (step.fusions.any((f) => f.specialType == SpecialTileType.superNine)) {
    return SoundEvent.superNine;
  }
  if (step.fusions.any((f) => f.value == kMaxDigit)) return SoundEvent.nineBorn;
  return step.cascade > 1 ? SoundEvent.combo : SoundEvent.fusion;
}

/// Se o passo quebrou alguma cobertura. Trincar não conta — o mesmo critério
/// do objetivo (`Resolution.countCleared`): o som acompanha o que o olho vê
/// sumir.
bool stepBreaksObstacle(ResolutionStep step) =>
    step.obstacleHits.any((hit) => hit.cleared);
