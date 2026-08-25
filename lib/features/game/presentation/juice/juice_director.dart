import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/presentation/juice/juice_priority.dart';

/// Decide qual evento de apresentação uma jogada merece, sem conhecer
/// widget nem `AnimationController`. Regra de sobrescrita: supernova
/// suprime qualquer outro evento da mesma jogada — quem consome o
/// resultado (a UI) não precisa aplicar essa regra de novo, só ler o
/// valor mais alto encontrado.
class JuiceDirector {
  const JuiceDirector._();

  static JuicePriority priorityOf(Resolution resolution) {
    var best = JuicePriority.normal;

    for (final step in resolution.steps) {
      for (final fusion in step.fusions) {
        final priority = _priorityOfFusion(fusion);
        if (priority.index > best.index) best = priority;
      }
    }

    return best;
  }

  static JuicePriority _priorityOfFusion(FusionEvent fusion) {
    if (fusion.specialType != null) return JuicePriority.supernova;
    if (fusion.matchLength >= kBigMatch) {
      return fusion.value == kMaxDigit ? JuicePriority.epic : JuicePriority.great;
    }
    return JuicePriority.good;
  }

  /// A ativação do Super 9 (troca que dispara a conversão board-wide) não
  /// passa por `Resolution` — é seu próprio `MoveResult`. Sempre o topo da
  /// hierarquia.
  static JuicePriority priorityForSuperNineActivation() => JuicePriority.supernova;
}
