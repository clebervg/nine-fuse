import 'package:nine_fuse/features/game/domain/campaign_chapter.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Traduz o dado estruturado que vem do `domain`.
///
/// Mora aqui, e num lugar só, porque as mesmas três conversões são pedidas por
/// telas diferentes: o objetivo aparece no cartão de início, no HUD e no
/// rótulo semântico do pin do mapa. Duplicar o `switch` faria o cartão prometer
/// uma coisa e o HUD outra ao primeiro ajuste de texto.
///
/// É extensão de [AppLocalizations] de propósito: quem já tem o `l10n` em mãos
/// não precisa importar mais nada nem receber um parâmetro novo.
extension DomainLabels on AppLocalizations {
  /// "Crie um 5" / "Crie 3 peças 5" / "Quebre 5 pedras".
  ///
  /// O plural fica em ICU no ARB, e não num `if` aqui: as regras de plural
  /// mudam por idioma, e um `count == 1` em Dart fixaria a regra do português.
  ///
  /// [target] existe para o [ObjectiveType.clearAllObstacles], em que o número
  /// não vem do objetivo e sim do tabuleiro sorteado. Quem já tem o `GameState`
  /// passa `state.objectiveTarget`; quem só tem a fase (o mapa da saga, o cartão
  /// de início) deixa em branco e o rótulo cai no pedido da fase.
  String objectiveLabel(Objective objective, {int? target}) =>
      switch (objective.type) {
        ObjectiveType.reachDigit =>
          objective.count == 1
              ? objectiveCreateOne(objective.digit!)
              : objectiveCreateMany(objective.count, objective.digit!),
        ObjectiveType.clearObstacles => objectiveClearObstacles(
          objective.count,
          obstacleName(objective.obstacle, objective.count),
        ),
        ObjectiveType.clearAllObstacles => () {
          final count = target ?? objective.count;
          return objectiveClearAllObstacles(
            count,
            obstacleName(objective.obstacle, count),
          );
        }(),
      };

  /// "Faltou pouco: 1 pedra." — o que separava o jogador da vitória.
  ///
  /// [remaining] vem de `objectiveTarget - objectiveProgress`, a mesma conta
  /// que o prêmio de movimentos usa: a tela de derrota e o crédito falam do
  /// mesmo número.
  String objectiveMissing(Objective objective, int remaining) =>
      objective.isObstacleGoal
      ? objectiveMissingObstacle(
          remaining,
          obstacleName(objective.obstacle, remaining),
        )
      : objectiveMissingDigit(remaining, objective.digit!);

  /// "pedra" / "pedras", já flexionado para [count].
  ///
  /// Vem flexionado do ARB, e não concatenado com um "s" aqui: em inglês o
  /// plural de "glass pane" não é o de "stone", e em português "gelo" e "pedra"
  /// nem sequer têm o mesmo gênero.
  String obstacleName(ObstacleType type, int count) => switch (type) {
    ObstacleType.none => '',
    ObstacleType.ice => obstacleIceCount(count),
    ObstacleType.glass => obstacleGlassCount(count),
    ObstacleType.stone => obstacleStoneCount(count),
  };

  /// A dica de uma fase, ou nulo quando a fase não ensina nada novo.
  String? levelTip(LevelTip? tip) => switch (tip) {
    null => null,
    LevelTip.alignThree => tipAlignThree,
    LevelTip.repeatFusion => tipRepeatFusion,
    LevelTip.chainFusion => tipChainFusion,
    LevelTip.biggerMatches => tipBiggerMatches,
    LevelTip.longLevel => tipLongLevel,
    LevelTip.zeroStopped => tipZeroStopped,
    LevelTip.obstacleBlocks => tipObstacleBlocks,
    // O dígito entra como parâmetro para a frase acompanhar [kMaxDigit] em
    // vez de repetir "9" à mão em dois idiomas.
    LevelTip.apexExplodes => tipApexExplodes(kMaxDigit),
  };

  /// "Capítulo 1: Fusões Primárias".
  String chapterTitle(CampaignChapter chapter) =>
      chapterLabel(chapter.number, chapterName(chapter));

  /// Só o nome do capítulo, sem o número — a placa do mapa mostra o número
  /// no rótulo de cima, junto das estrelas, e o nome sozinho como título.
  String chapterName(CampaignChapter chapter) => switch (chapter.name) {
    ChapterName.primaryFusions => chapterPrimaryFusions,
    ChapterName.towardNine => chapterTowardNine,
  };
}
