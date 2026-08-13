import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/level_generator.dart';

export 'package:nine_fuse/features/game/domain/game_level.dart';

/// A fase de número [number] — a **única** porta de acesso a fases.
///
/// Existe porque uma campanha infinita não pode ser uma lista: não há `length`
/// para indexar nem para comparar. Quem chama não sabe, e não precisa saber, se
/// a fase que recebeu foi escrita à mão ou calculada — as duas são `GameLevel`,
/// e é isso que mantém motor, HUD, mapa e cartões alheios à mudança.
GameLevel levelAt(int number) {
  assert(number >= 1, 'a campanha começa na fase 1');

  return number <= kHandcraftedLevels
      ? kCampaign[number - 1]
      : generateLevel(number);
}
