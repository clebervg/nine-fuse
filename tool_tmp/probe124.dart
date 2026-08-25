import 'package:nine_fuse/features/game/domain/level_generator.dart';

void main() {
  for (var n = 118; n <= 126; n++) {
    final lvl = generateLevel(n);
    print('fase $n: ${lvl.objective.type} digit=${lvl.objective.digit} count=${lvl.objective.count} obstacle=${lvl.objective.obstacle} moves=${lvl.moveLimit} spawn=${lvl.spawnMin}-${lvl.spawnMax} obstacles=${lvl.obstacles}');
  }
}
