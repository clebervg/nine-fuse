import 'package:nine_fuse/features/game/domain/level_catalog.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';

/// Quantas fases à frente da fase da vez o mapa avisa uma estreia.
///
/// Curto de propósito: o aviso é "prepare-se", não um calendário. Avisar com
/// dez fases de antecedência seria uma promessa que o jogador esquece antes de
/// chegar lá, e ocuparia o topo do mapa por todo esse tempo.
const int kObstacleDebutLookahead = 3;

/// Até onde a busca pela estreia de um tipo vai antes de desistir.
///
/// As três coberturas estreiam na campanha artesanal (fases 8-10); o teto só
/// existe para um tipo que um dia deixe de aparecer não virar varredura sem fim
/// do gerador.
const int kObstacleDebutSearchLimit = 200;

/// A primeira aparição de um tipo de cobertura na campanha.
typedef ObstacleDebut = ({int level, ObstacleType type});

/// Fase em que cada tipo de cobertura aparece pela primeira vez, na ordem.
///
/// Deriva do catálogo ([levelOf], por padrão [levelAt]) e não de uma tabela
/// à parte: a estreia é consequência do desenho das fases, e uma lista mantida
/// à mão divergiria dele no primeiro ajuste de campanha.
List<ObstacleDebut> obstacleDebuts({
  GameLevel Function(int number) levelOf = levelAt,
  int searchLimit = kObstacleDebutSearchLimit,
}) {
  if (identical(levelOf, levelAt) && searchLimit == kObstacleDebutSearchLimit) {
    // A campanha real não muda em tempo de execução: calcula uma vez só, já
    // que o mapa pergunta a cada reconstrução.
    return _campaignDebuts ??= _scan(levelOf, searchLimit);
  }
  return _scan(levelOf, searchLimit);
}

List<ObstacleDebut>? _campaignDebuts;

List<ObstacleDebut> _scan(GameLevel Function(int) levelOf, int searchLimit) {
  final pending = {
    ObstacleType.ice,
    ObstacleType.glass,
    ObstacleType.stone,
    ObstacleType.chain,
  };
  final debuts = <ObstacleDebut>[];

  for (int n = 1; n <= searchLimit && pending.isNotEmpty; n++) {
    final layout = levelOf(n).obstacles;
    // A varredura é crescente, então a lista sai ordenada por fase — é o
    // que deixa [upcomingObstacleDebut] devolver a mais próxima.
    for (final type in pending.toList()) {
      if (layout.countOf(type) > 0) {
        debuts.add((level: n, type: type));
        pending.remove(type);
      }
    }
  }

  return debuts;
}

/// A estreia de cobertura mais próxima entre a fase [nextLevel] (a da vez) e
/// as [lookahead] seguintes, ou nulo se nenhuma está tão perto.
///
/// Inclui a própria fase da vez: "novo obstáculo na fase 8" enquanto o botão
/// diz "jogar fase 8" é exatamente o aviso que o jogador precisa antes de
/// entrar.
ObstacleDebut? upcomingObstacleDebut(
  int nextLevel, {
  int lookahead = kObstacleDebutLookahead,
  GameLevel Function(int number) levelOf = levelAt,
}) {
  for (final debut in obstacleDebuts(levelOf: levelOf)) {
    if (debut.level >= nextLevel && debut.level <= nextLevel + lookahead) {
      return debut;
    }
  }
  return null;
}
