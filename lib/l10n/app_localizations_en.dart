// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'NineFuse';

  @override
  String levelTitle(int number) {
    return 'Level $number';
  }

  @override
  String objectiveCreateOne(int digit) {
    return 'Create a $digit';
  }

  @override
  String objectiveCreateMany(int count, int digit) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Create $count $digit tiles',
      one: 'Create one $digit tile',
    );
    return '$_temp0';
  }

  @override
  String get hudObjective => 'GOAL';

  @override
  String get hudScore => 'POINTS';

  @override
  String get hudMoves => 'MOVES';

  @override
  String hudScoreValue(int score) {
    return '$score pts';
  }

  @override
  String objectiveProgress(int progress, int count) {
    return '$progress of $count';
  }

  @override
  String moveBudget(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Moves',
      one: '1 Move',
    );
    return '$_temp0';
  }

  @override
  String get playButton => 'PLAY';

  @override
  String get tipAlignThree =>
      'Line up three equal tiles: the one you touched evolves.';

  @override
  String get tipRepeatFusion =>
      'Fuse again. Swaps that form no trio cost no move.';

  @override
  String get tipChainFusion => 'Three 4s become a 5. Plan the chain fusion.';

  @override
  String get tipBiggerMatches =>
      'Matches of 4 or 5 tiles pay more than two of 3.';

  @override
  String get tipLongLevel => 'Long level: mind the space on the board.';

  @override
  String get tipZeroStopped =>
      'The 0 stopped falling. Bigger tiles arrive from the top.';

  @override
  String tipApexExplodes(int digit) {
    return 'The $digit does not evolve: it explodes and clears the area around it.';
  }

  @override
  String get outcomeWonTitle => 'LEVEL COMPLETED!';

  @override
  String get outcomeMovesTitle => 'OUT OF MOVES';

  @override
  String get outcomeStuckTitle => 'BOARD STUCK';

  @override
  String get outcomeGenericTitle => 'NOT THIS TIME';

  @override
  String get outcomeCampaignFinished => 'You finished the campaign!';

  @override
  String outcomeWonMessage(int moves) {
    String _temp0 = intl.Intl.pluralLogic(
      moves,
      locale: localeName,
      other: 'Goal reached in $moves moves.',
      one: 'Goal reached in 1 move.',
    );
    return '$_temp0';
  }

  @override
  String get outcomeMovesMessage => 'So close to the goal!';

  @override
  String get outcomeStuckMessage => 'No valid swaps left!';

  @override
  String get outcomeGenericMessage => 'The level is over.';

  @override
  String outcomeMovesDetail(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'The level\'s $count moves ran out — the board still had plays.',
      one: 'The level\'s single move ran out — the board still had plays.',
    );
    return '$_temp0';
  }

  @override
  String outcomeScore(int score) {
    return 'Points: $score';
  }

  @override
  String get nextLevelButton => 'NEXT LEVEL';

  @override
  String get playEndlessButton => 'PLAY HIGH SCORE MODE';

  @override
  String get playAgainButton => 'PLAY AGAIN';

  @override
  String get tryAgainButton => 'TRY AGAIN';

  @override
  String get backToLevels => 'Back to levels';

  @override
  String get endlessTitle => 'High Score Mode';

  @override
  String get endlessHighlightTitle => 'High Score Mode 🏆';

  @override
  String get endlessPoints => 'Points';

  @override
  String get endlessRecord => 'Best';

  @override
  String get endlessBiggestTile => 'Best Tile';

  @override
  String get endlessNone => '—';

  @override
  String get endlessBandTop => 'Top band reached';

  @override
  String get endlessNextBand => 'Next band: create a';

  @override
  String get endlessRecordTitle => 'New record!';

  @override
  String get endlessOverTitle => 'Run over';

  @override
  String get endlessOverMessage => 'There were no swaps left to make.';

  @override
  String get endlessMoves => 'Moves';

  @override
  String get endlessHighestDigit => 'Highest tile';

  @override
  String get endlessExplosions => 'Explosions';

  @override
  String get endlessRestart => 'New run';

  @override
  String get endlessBackToMenu => 'Back to menu';

  @override
  String endlessBestScore(int score) {
    return 'Your best score: $score pts';
  }

  @override
  String endlessLockedHint(int level) {
    return 'Clear level $level to unlock';
  }

  @override
  String get endlessCta => 'Beat Record';

  @override
  String get starsCaption => 'CAMPAIGN';

  @override
  String starsSemantics(int earned, int total) {
    return '$earned of $total campaign stars';
  }

  @override
  String chapterLabel(int number, String name) {
    return 'Chapter $number: $name';
  }

  @override
  String get chapterPrimaryFusions => 'Primary Fusions';

  @override
  String get chapterTowardNine => 'Toward the Nine';

  @override
  String chapterComingSoon(int number) {
    return 'Chapter $number: Coming Soon!';
  }

  @override
  String semanticsLevelCleared(
    int number,
    int stars,
    int total,
    String objective,
  ) {
    return 'Level $number, completed with $stars of $total stars. $objective.';
  }

  @override
  String semanticsLevelCurrent(int number, String objective) {
    return 'Level $number, unlocked. $objective.';
  }

  @override
  String semanticsLevelLocked(int number) {
    return 'Level $number, locked.';
  }

  @override
  String get comboSuperFusion => 'SUPER FUSION!';

  @override
  String get comboTwo => 'COMBO x2!';

  @override
  String comboMany(int count) {
    return 'AMAZING x$count!';
  }

  @override
  String get apexCelebration => 'MAXIMUM FUSION! 🎉';

  @override
  String chapterStarsSemantics(int stars, int total, String chapter) {
    return '$stars of $total stars in $chapter.';
  }

  @override
  String bonusMoves(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count Moves!',
      one: '+1 Move!',
    );
    return '$_temp0';
  }
}
