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
  String obstacleIceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ice blocks',
      one: 'ice block',
    );
    return '$_temp0';
  }

  @override
  String obstacleGlassCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'glass panes',
      one: 'glass pane',
    );
    return '$_temp0';
  }

  @override
  String obstacleStoneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'stones',
      one: 'stone',
    );
    return '$_temp0';
  }

  @override
  String objectiveClearObstacles(int count, String obstacle) {
    return 'Break $count $obstacle';
  }

  @override
  String objectiveClearAllObstacles(int count, String obstacle) {
    return 'Clear the board: $count $obstacle';
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
  String get tipObstacleBlocks =>
      'Covered tiles are stuck: fuse right next to them to break the cover.';

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
  String outcomeCoins(int coins) {
    return '+$coins 🪙';
  }

  @override
  String get outcomeCoinsLabel => 'COINS EARNED';

  @override
  String get nextLevelButton => 'NEXT LEVEL';

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
  String get endlessOverTitle => 'Out of Moves!';

  @override
  String get endlessOverMessage => 'You\'ve run out of moves. Keep going?';

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
  String get starsCaption => 'CHAPTER';

  @override
  String starsSemantics(int earned, int total) {
    return '$earned of $total chapter stars';
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

  @override
  String hammerButton(int count) {
    return 'HAMMER ($count)';
  }

  @override
  String get hammerCancel => 'CANCEL';

  @override
  String get boostersLabel => 'Boosters';

  @override
  String get hammerAimHint => 'Tap a cell to smash it';

  @override
  String get hammerOfferTitle => 'Out of hammers';

  @override
  String get hammerOfferBody =>
      'Watch a short ad and smash the cell you picked.';

  @override
  String get hammerOfferWatch => 'WATCH AD';

  @override
  String get hammerOfferDecline => 'NOT NOW';

  @override
  String get hammerOfferFailed => 'No ad available right now.';

  @override
  String hammerOfferBuy(int price) {
    return 'Buy for $price 🪙';
  }

  @override
  String get hammerOfferNoCoins => 'Not enough coins';

  @override
  String hammerOfferBalance(int coins) {
    return 'You have $coins 🪙';
  }

  @override
  String hammerOfferEarnCoins(int reward) {
    return 'Earn +$reward 🪙 (Watch video)';
  }

  @override
  String hammerOfferEarnedCoins(int reward) {
    return '+$reward 🪙 added to your balance!';
  }

  @override
  String get coinStoreTitle => 'Your coins';

  @override
  String get coinStoreClose => 'CLOSE';

  @override
  String coinsBadgeSemantics(int coins) {
    return '$coins coins';
  }

  @override
  String hammersBadgeSemantics(int hammers) {
    return '$hammers hammers';
  }

  @override
  String get coinSourcesTitle => 'How to earn coins';

  @override
  String get coinSourcesStars => 'Beat levels with 3 stars';

  @override
  String get coinSourcesAds => 'Watch rewarded videos';

  @override
  String get coinSourcesChests => 'Complete the chapters on the map';

  @override
  String hammerSemantics(int count) {
    return 'Fusion Hammer, $count in stock. Smashes one cell without spending a move.';
  }

  @override
  String get movesOfferTitle => 'Almost there!';

  @override
  String movesOfferBody(int count, int reward) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count moves left',
      one: '1 move left',
    );
    return '$_temp0. Watch a short ad and get $reward more.';
  }

  @override
  String movesOfferWatch(int reward) {
    return 'GET +$reward MOVES';
  }

  @override
  String get movesOfferDecline => 'KEEP PLAYING';

  @override
  String get movesOfferFailed => 'No ad available right now.';

  @override
  String get endlessSuggestionTitle => 'Out of energy?';

  @override
  String get endlessSuggestionBody =>
      'Your energy for this level ran out! How about beating your Personal Best while it recharges?';

  @override
  String get endlessSuggestionGo => 'GO TO RECORD MODE';

  @override
  String get endlessSuggestionDecline => 'KEEP TRYING';

  @override
  String get storeSubtitle => 'Match 3, evolve the number, reach 9';

  @override
  String get storeShortDescription =>
      'Number match-3: three of a kind become the next digit. Reach 9 and blow up the board.';

  @override
  String get storeFullDescription =>
      'NineFuse is a number puzzle where matching isn\'t just clearing.\n\nLine up three identical digits and the middle one EVOLVES into the next: three 4s become a 5. Repeat the fusion, plan the chain, and climb the scale to the game\'s climax — the digit 9, which detonates in a shockwave, clears the neighbourhood and pays back moves.\n\n• FUSION, NOT JUST CLEARING — match-3 mechanics with merge progression.\n• THE RITUAL OF 9 — the top digit explodes, breaks stone and grants bonus moves.\n• ICE, GLASS AND STONE — covers that yield to 1, 2 or 3 adjacent fusions.\n• OBJECTIVE-BASED CAMPAIGN — reach a digit, break covers, clear the board.\n• ENDLESS MODE — a run with no move limit, and your high score kept.\n• FUSION HAMMER — smash one stuck cell without spending a move.\n• NO LIVES TIMER — play as much as you want, whenever you want.\n\nDark visuals, vivid per-digit colours and fluid fusion animations.';

  @override
  String get storeKeywords =>
      'number match 3,number puzzle,merge numbers,fusion puzzle,numeric puzzle,2048 match 3,offline puzzle,logic game';
}
