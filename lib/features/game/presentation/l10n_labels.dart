import 'package:nine_fuse/features/game/domain/campaign_chapter.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
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
  /// "Crie um 5" / "Crie 3 peças 5".
  ///
  /// O plural fica em ICU no ARB, e não num `if` aqui: as regras de plural
  /// mudam por idioma, e um `count == 1` em Dart fixaria a regra do português.
  String objectiveLabel(Objective objective) => objective.count == 1
      ? objectiveCreateOne(objective.digit)
      : objectiveCreateMany(objective.count, objective.digit);

  /// A dica de uma fase, ou nulo quando a fase não ensina nada novo.
  String? levelTip(LevelTip? tip) => switch (tip) {
    null => null,
    LevelTip.alignThree => tipAlignThree,
    LevelTip.repeatFusion => tipRepeatFusion,
    LevelTip.chainFusion => tipChainFusion,
    LevelTip.biggerMatches => tipBiggerMatches,
    LevelTip.longLevel => tipLongLevel,
    LevelTip.zeroStopped => tipZeroStopped,
    // O dígito entra como parâmetro para a frase acompanhar [kMaxDigit] em
    // vez de repetir "9" à mão em dois idiomas.
    LevelTip.apexExplodes => tipApexExplodes(kMaxDigit),
  };

  /// "Capítulo 1: Fusões Primárias".
  String chapterTitle(CampaignChapter chapter) =>
      chapterLabel(chapter.number, switch (chapter.name) {
        ChapterName.primaryFusions => chapterPrimaryFusions,
        ChapterName.towardNine => chapterTowardNine,
      });
}
