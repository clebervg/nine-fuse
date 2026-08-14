import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pt'),
  ];

  /// Nome do app, na barra de tarefas do sistema.
  ///
  /// In en, this message translates to:
  /// **'NineFuse'**
  String get appTitle;

  /// No description provided for @levelTitle.
  ///
  /// In en, this message translates to:
  /// **'Level {number}'**
  String levelTitle(int number);

  /// No description provided for @objectiveCreateOne.
  ///
  /// In en, this message translates to:
  /// **'Create a {digit}'**
  String objectiveCreateOne(int digit);

  /// Objetivo de mais de uma peça. O plural fica em ICU porque concatenar 'peças' quebraria em inglês.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Create one {digit} tile} other{Create {count} {digit} tiles}}'**
  String objectiveCreateMany(int count, int digit);

  /// Nome do gelo com a quantidade implícita. O plural fica em ICU porque cada idioma pluraliza a sua palavra.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{ice block} other{ice blocks}}'**
  String obstacleIceCount(int count);

  /// No description provided for @obstacleGlassCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{glass pane} other{glass panes}}'**
  String obstacleGlassCount(int count);

  /// No description provided for @obstacleStoneCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{stone} other{stones}}'**
  String obstacleStoneCount(int count);

  /// Objetivo de quebrar N coberturas. O nome já vem flexionado pelo ICU de obstacle*Count.
  ///
  /// In en, this message translates to:
  /// **'Break {count} {obstacle}'**
  String objectiveClearObstacles(int count, String obstacle);

  /// Objetivo de limpar tudo. Diz o número porque 'todas' sem quantidade não deixa o jogador planejar as jogadas.
  ///
  /// In en, this message translates to:
  /// **'Clear the board: {count} {obstacle}'**
  String objectiveClearAllObstacles(int count, String obstacle);

  /// No description provided for @hudObjective.
  ///
  /// In en, this message translates to:
  /// **'GOAL'**
  String get hudObjective;

  /// No description provided for @hudScore.
  ///
  /// In en, this message translates to:
  /// **'POINTS'**
  String get hudScore;

  /// No description provided for @hudMoves.
  ///
  /// In en, this message translates to:
  /// **'MOVES'**
  String get hudMoves;

  /// No description provided for @hudScoreValue.
  ///
  /// In en, this message translates to:
  /// **'{score} pts'**
  String hudScoreValue(int score);

  /// No description provided for @objectiveProgress.
  ///
  /// In en, this message translates to:
  /// **'{progress} of {count}'**
  String objectiveProgress(int progress, int count);

  /// No description provided for @moveBudget.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Move} other{{count} Moves}}'**
  String moveBudget(int count);

  /// No description provided for @playButton.
  ///
  /// In en, this message translates to:
  /// **'PLAY'**
  String get playButton;

  /// No description provided for @tipAlignThree.
  ///
  /// In en, this message translates to:
  /// **'Line up three equal tiles: the one you touched evolves.'**
  String get tipAlignThree;

  /// No description provided for @tipRepeatFusion.
  ///
  /// In en, this message translates to:
  /// **'Fuse again. Swaps that form no trio cost no move.'**
  String get tipRepeatFusion;

  /// No description provided for @tipChainFusion.
  ///
  /// In en, this message translates to:
  /// **'Three 4s become a 5. Plan the chain fusion.'**
  String get tipChainFusion;

  /// No description provided for @tipBiggerMatches.
  ///
  /// In en, this message translates to:
  /// **'Matches of 4 or 5 tiles pay more than two of 3.'**
  String get tipBiggerMatches;

  /// No description provided for @tipLongLevel.
  ///
  /// In en, this message translates to:
  /// **'Long level: mind the space on the board.'**
  String get tipLongLevel;

  /// No description provided for @tipZeroStopped.
  ///
  /// In en, this message translates to:
  /// **'The 0 stopped falling. Bigger tiles arrive from the top.'**
  String get tipZeroStopped;

  /// No description provided for @tipObstacleBlocks.
  ///
  /// In en, this message translates to:
  /// **'Covered tiles are stuck: fuse right next to them to break the cover.'**
  String get tipObstacleBlocks;

  /// No description provided for @tipApexExplodes.
  ///
  /// In en, this message translates to:
  /// **'The {digit} does not evolve: it explodes and clears the area around it.'**
  String tipApexExplodes(int digit);

  /// No description provided for @outcomeWonTitle.
  ///
  /// In en, this message translates to:
  /// **'LEVEL COMPLETED!'**
  String get outcomeWonTitle;

  /// No description provided for @outcomeMovesTitle.
  ///
  /// In en, this message translates to:
  /// **'OUT OF MOVES'**
  String get outcomeMovesTitle;

  /// No description provided for @outcomeStuckTitle.
  ///
  /// In en, this message translates to:
  /// **'BOARD STUCK'**
  String get outcomeStuckTitle;

  /// No description provided for @outcomeGenericTitle.
  ///
  /// In en, this message translates to:
  /// **'NOT THIS TIME'**
  String get outcomeGenericTitle;

  /// No description provided for @outcomeWonMessage.
  ///
  /// In en, this message translates to:
  /// **'{moves, plural, =1{Goal reached in 1 move.} other{Goal reached in {moves} moves.}}'**
  String outcomeWonMessage(int moves);

  /// No description provided for @outcomeMovesMessage.
  ///
  /// In en, this message translates to:
  /// **'So close to the goal!'**
  String get outcomeMovesMessage;

  /// No description provided for @outcomeStuckMessage.
  ///
  /// In en, this message translates to:
  /// **'No valid swaps left!'**
  String get outcomeStuckMessage;

  /// No description provided for @outcomeGenericMessage.
  ///
  /// In en, this message translates to:
  /// **'The level is over.'**
  String get outcomeGenericMessage;

  /// Separa derrota por saldo de derrota por travamento: sem dizer que ainda havia jogadas, 'movimentos esgotados' segue sendo lido como 'o tabuleiro morreu'.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{The level\'s single move ran out — the board still had plays.} other{The level\'s {count} moves ran out — the board still had plays.}}'**
  String outcomeMovesDetail(int count);

  /// No description provided for @outcomeScore.
  ///
  /// In en, this message translates to:
  /// **'Points: {score}'**
  String outcomeScore(int score);

  /// No description provided for @nextLevelButton.
  ///
  /// In en, this message translates to:
  /// **'NEXT LEVEL'**
  String get nextLevelButton;

  /// No description provided for @playAgainButton.
  ///
  /// In en, this message translates to:
  /// **'PLAY AGAIN'**
  String get playAgainButton;

  /// No description provided for @tryAgainButton.
  ///
  /// In en, this message translates to:
  /// **'TRY AGAIN'**
  String get tryAgainButton;

  /// No description provided for @backToLevels.
  ///
  /// In en, this message translates to:
  /// **'Back to levels'**
  String get backToLevels;

  /// No description provided for @endlessTitle.
  ///
  /// In en, this message translates to:
  /// **'High Score Mode'**
  String get endlessTitle;

  /// No description provided for @endlessHighlightTitle.
  ///
  /// In en, this message translates to:
  /// **'High Score Mode 🏆'**
  String get endlessHighlightTitle;

  /// No description provided for @endlessPoints.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get endlessPoints;

  /// No description provided for @endlessRecord.
  ///
  /// In en, this message translates to:
  /// **'Best'**
  String get endlessRecord;

  /// No description provided for @endlessBiggestTile.
  ///
  /// In en, this message translates to:
  /// **'Best Tile'**
  String get endlessBiggestTile;

  /// No description provided for @endlessNone.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get endlessNone;

  /// No description provided for @endlessBandTop.
  ///
  /// In en, this message translates to:
  /// **'Top band reached'**
  String get endlessBandTop;

  /// No description provided for @endlessNextBand.
  ///
  /// In en, this message translates to:
  /// **'Next band: create a'**
  String get endlessNextBand;

  /// No description provided for @endlessRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'New record!'**
  String get endlessRecordTitle;

  /// No description provided for @endlessOverTitle.
  ///
  /// In en, this message translates to:
  /// **'Out of Moves!'**
  String get endlessOverTitle;

  /// No description provided for @endlessOverMessage.
  ///
  /// In en, this message translates to:
  /// **'You\'ve run out of moves. Keep going?'**
  String get endlessOverMessage;

  /// No description provided for @endlessMoves.
  ///
  /// In en, this message translates to:
  /// **'Moves'**
  String get endlessMoves;

  /// No description provided for @endlessHighestDigit.
  ///
  /// In en, this message translates to:
  /// **'Highest tile'**
  String get endlessHighestDigit;

  /// No description provided for @endlessExplosions.
  ///
  /// In en, this message translates to:
  /// **'Explosions'**
  String get endlessExplosions;

  /// No description provided for @endlessRestart.
  ///
  /// In en, this message translates to:
  /// **'New run'**
  String get endlessRestart;

  /// No description provided for @endlessBackToMenu.
  ///
  /// In en, this message translates to:
  /// **'Back to menu'**
  String get endlessBackToMenu;

  /// No description provided for @endlessBestScore.
  ///
  /// In en, this message translates to:
  /// **'Your best score: {score} pts'**
  String endlessBestScore(int score);

  /// No description provided for @endlessLockedHint.
  ///
  /// In en, this message translates to:
  /// **'Clear level {level} to unlock'**
  String endlessLockedHint(int level);

  /// No description provided for @endlessCta.
  ///
  /// In en, this message translates to:
  /// **'Beat Record'**
  String get endlessCta;

  /// Legenda do contador de estrelas do mapa. Existe para o número não se ler como progresso da campanha inteira: numa campanha infinita não há total de campanha, então o contador é sempre do capítulo atual.
  ///
  /// In en, this message translates to:
  /// **'CHAPTER'**
  String get starsCaption;

  /// No description provided for @starsSemantics.
  ///
  /// In en, this message translates to:
  /// **'{earned} of {total} chapter stars'**
  String starsSemantics(int earned, int total);

  /// No description provided for @chapterLabel.
  ///
  /// In en, this message translates to:
  /// **'Chapter {number}: {name}'**
  String chapterLabel(int number, String name);

  /// No description provided for @chapterPrimaryFusions.
  ///
  /// In en, this message translates to:
  /// **'Primary Fusions'**
  String get chapterPrimaryFusions;

  /// No description provided for @chapterTowardNine.
  ///
  /// In en, this message translates to:
  /// **'Toward the Nine'**
  String get chapterTowardNine;

  /// No description provided for @semanticsLevelCleared.
  ///
  /// In en, this message translates to:
  /// **'Level {number}, completed with {stars} of {total} stars. {objective}.'**
  String semanticsLevelCleared(
    int number,
    int stars,
    int total,
    String objective,
  );

  /// No description provided for @semanticsLevelCurrent.
  ///
  /// In en, this message translates to:
  /// **'Level {number}, unlocked. {objective}.'**
  String semanticsLevelCurrent(int number, String objective);

  /// No description provided for @semanticsLevelLocked.
  ///
  /// In en, this message translates to:
  /// **'Level {number}, locked.'**
  String semanticsLevelLocked(int number);

  /// No description provided for @comboSuperFusion.
  ///
  /// In en, this message translates to:
  /// **'SUPER FUSION!'**
  String get comboSuperFusion;

  /// No description provided for @comboTwo.
  ///
  /// In en, this message translates to:
  /// **'COMBO x2!'**
  String get comboTwo;

  /// No description provided for @comboMany.
  ///
  /// In en, this message translates to:
  /// **'AMAZING x{count}!'**
  String comboMany(int count);

  /// No description provided for @apexCelebration.
  ///
  /// In en, this message translates to:
  /// **'MAXIMUM FUSION! 🎉'**
  String get apexCelebration;

  /// No description provided for @chapterStarsSemantics.
  ///
  /// In en, this message translates to:
  /// **'{stars} of {total} stars in {chapter}.'**
  String chapterStarsSemantics(int stars, int total, String chapter);

  /// No description provided for @bonusMoves.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{+1 Move!} other{+{count} Moves!}}'**
  String bonusMoves(int count);

  /// Booster button in the HUD, with the remaining stock.
  ///
  /// In en, this message translates to:
  /// **'HAMMER ({count})'**
  String hammerButton(int count);

  /// No description provided for @hammerCancel.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get hammerCancel;

  /// No description provided for @hammerAimHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a cell to smash it'**
  String get hammerAimHint;

  /// No description provided for @hammerOfferTitle.
  ///
  /// In en, this message translates to:
  /// **'Out of hammers'**
  String get hammerOfferTitle;

  /// No description provided for @hammerOfferBody.
  ///
  /// In en, this message translates to:
  /// **'Watch a short ad and smash the cell you picked.'**
  String get hammerOfferBody;

  /// No description provided for @hammerOfferWatch.
  ///
  /// In en, this message translates to:
  /// **'WATCH AD'**
  String get hammerOfferWatch;

  /// No description provided for @hammerOfferDecline.
  ///
  /// In en, this message translates to:
  /// **'NOT NOW'**
  String get hammerOfferDecline;

  /// No description provided for @hammerOfferFailed.
  ///
  /// In en, this message translates to:
  /// **'No ad available right now.'**
  String get hammerOfferFailed;

  /// Button that trades coins for a Fusion Hammer.
  ///
  /// In en, this message translates to:
  /// **'Buy for {price} 🪙'**
  String hammerOfferBuy(int price);

  /// Explains why the buy button is disabled.
  ///
  /// In en, this message translates to:
  /// **'Not enough coins'**
  String get hammerOfferNoCoins;

  /// No description provided for @hammerSemantics.
  ///
  /// In en, this message translates to:
  /// **'Fusion Hammer, {count} in stock. Smashes one cell without spending a move.'**
  String hammerSemantics(int count);

  /// No description provided for @movesOfferTitle.
  ///
  /// In en, this message translates to:
  /// **'Almost there!'**
  String get movesOfferTitle;

  /// No description provided for @movesOfferBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 move left} other{{count} moves left}}. Watch a short ad and get {reward} more.'**
  String movesOfferBody(int count, int reward);

  /// No description provided for @movesOfferWatch.
  ///
  /// In en, this message translates to:
  /// **'GET +{reward} MOVES'**
  String movesOfferWatch(int reward);

  /// No description provided for @movesOfferDecline.
  ///
  /// In en, this message translates to:
  /// **'KEEP PLAYING'**
  String get movesOfferDecline;

  /// No description provided for @movesOfferFailed.
  ///
  /// In en, this message translates to:
  /// **'No ad available right now.'**
  String get movesOfferFailed;

  /// No description provided for @storeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Match 3, evolve the number, reach 9'**
  String get storeSubtitle;

  /// No description provided for @storeShortDescription.
  ///
  /// In en, this message translates to:
  /// **'Number match-3: three of a kind become the next digit. Reach 9 and blow up the board.'**
  String get storeShortDescription;

  /// No description provided for @storeFullDescription.
  ///
  /// In en, this message translates to:
  /// **'NineFuse is a number puzzle where matching isn\'t just clearing.\n\nLine up three identical digits and the middle one EVOLVES into the next: three 4s become a 5. Repeat the fusion, plan the chain, and climb the scale to the game\'s climax — the digit 9, which detonates in a shockwave, clears the neighbourhood and pays back moves.\n\n• FUSION, NOT JUST CLEARING — match-3 mechanics with merge progression.\n• THE RITUAL OF 9 — the top digit explodes, breaks stone and grants bonus moves.\n• ICE, GLASS AND STONE — covers that yield to 1, 2 or 3 adjacent fusions.\n• OBJECTIVE-BASED CAMPAIGN — reach a digit, break covers, clear the board.\n• ENDLESS MODE — a run with no move limit, and your high score kept.\n• FUSION HAMMER — smash one stuck cell without spending a move.\n• NO LIVES TIMER — play as much as you want, whenever you want.\n\nDark visuals, vivid per-digit colours and fluid fusion animations.'**
  String get storeFullDescription;

  /// No description provided for @storeKeywords.
  ///
  /// In en, this message translates to:
  /// **'number match 3,number puzzle,merge numbers,fusion puzzle,numeric puzzle,2048 match 3,offline puzzle,logic game'**
  String get storeKeywords;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
