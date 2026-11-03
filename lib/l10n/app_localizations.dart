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

  /// No description provided for @levelStartShopHammer.
  ///
  /// In en, this message translates to:
  /// **'Hammer'**
  String get levelStartShopHammer;

  /// No description provided for @levelStartShopBomb.
  ///
  /// In en, this message translates to:
  /// **'Bomb'**
  String get levelStartShopBomb;

  /// No description provided for @levelStartShopBrush.
  ///
  /// In en, this message translates to:
  /// **'Brush'**
  String get levelStartShopBrush;

  /// No description provided for @levelStartShopBuy.
  ///
  /// In en, this message translates to:
  /// **'{price} 🪙'**
  String levelStartShopBuy(int price);

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
  /// **'The {digit} does not evolve: it stays on the board and clears blockers around it.'**
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

  /// Coins earned by the stars this run added, shown on the win card.
  ///
  /// In en, this message translates to:
  /// **'+{coins} 🪙'**
  String outcomeCoins(int coins);

  /// No description provided for @outcomeCoinsLabel.
  ///
  /// In en, this message translates to:
  /// **'COINS EARNED'**
  String get outcomeCoinsLabel;

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
  /// **'Super 9s activated'**
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

  /// No description provided for @boostersLabel.
  ///
  /// In en, this message translates to:
  /// **'Boosters'**
  String get boostersLabel;

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

  /// No description provided for @hammerOfferAdCapReached.
  ///
  /// In en, this message translates to:
  /// **'Come back tomorrow for more videos'**
  String get hammerOfferAdCapReached;

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

  /// Current coin balance shown inside the booster purchase dialog.
  ///
  /// In en, this message translates to:
  /// **'You have {coins} 🪙'**
  String hammerOfferBalance(int coins);

  /// Button that plays a rewarded ad paying coins.
  ///
  /// In en, this message translates to:
  /// **'Earn +{reward} 🪙 (Watch video)'**
  String hammerOfferEarnCoins(int reward);

  /// Confirmation shown after the coin rewarded ad completes.
  ///
  /// In en, this message translates to:
  /// **'+{reward} 🪙 added to your balance!'**
  String hammerOfferEarnedCoins(int reward);

  /// No description provided for @continueOfferTitle.
  ///
  /// In en, this message translates to:
  /// **'OUT OF MOVES'**
  String get continueOfferTitle;

  /// No description provided for @continueOfferBody.
  ///
  /// In en, this message translates to:
  /// **'Watch a short ad or spend coins to get {bonus} extra moves and keep going.'**
  String continueOfferBody(int bonus);

  /// No description provided for @continueOfferWatch.
  ///
  /// In en, this message translates to:
  /// **'WATCH AD (+{bonus})'**
  String continueOfferWatch(int bonus);

  /// No description provided for @continueOfferBuy.
  ///
  /// In en, this message translates to:
  /// **'Buy for {price} 🪙'**
  String continueOfferBuy(int price);

  /// No description provided for @continueOfferDecline.
  ///
  /// In en, this message translates to:
  /// **'GIVE UP'**
  String get continueOfferDecline;

  /// No description provided for @continueOfferFailed.
  ///
  /// In en, this message translates to:
  /// **'No ad available right now.'**
  String get continueOfferFailed;

  /// No description provided for @continueOfferNoCoins.
  ///
  /// In en, this message translates to:
  /// **'Not enough coins'**
  String get continueOfferNoCoins;

  /// No description provided for @continueOfferBalance.
  ///
  /// In en, this message translates to:
  /// **'You have {coins} 🪙'**
  String continueOfferBalance(int coins);

  /// No description provided for @bombOfferTitle.
  ///
  /// In en, this message translates to:
  /// **'Out of bombs'**
  String get bombOfferTitle;

  /// No description provided for @bombOfferBody.
  ///
  /// In en, this message translates to:
  /// **'Watch a short ad and blast the 3x3 area you picked.'**
  String get bombOfferBody;

  /// No description provided for @bombOfferWatch.
  ///
  /// In en, this message translates to:
  /// **'WATCH AD'**
  String get bombOfferWatch;

  /// No description provided for @bombOfferBuy.
  ///
  /// In en, this message translates to:
  /// **'Buy for {price} 🪙'**
  String bombOfferBuy(int price);

  /// No description provided for @bombOfferDecline.
  ///
  /// In en, this message translates to:
  /// **'NOT NOW'**
  String get bombOfferDecline;

  /// No description provided for @bombOfferFailed.
  ///
  /// In en, this message translates to:
  /// **'No ad available right now.'**
  String get bombOfferFailed;

  /// No description provided for @bombOfferNoCoins.
  ///
  /// In en, this message translates to:
  /// **'Not enough coins'**
  String get bombOfferNoCoins;

  /// No description provided for @bombOfferBalance.
  ///
  /// In en, this message translates to:
  /// **'You have {coins} 🪙'**
  String bombOfferBalance(int coins);

  /// No description provided for @brushOfferTitle.
  ///
  /// In en, this message translates to:
  /// **'Out of brushes'**
  String get brushOfferTitle;

  /// No description provided for @brushOfferBody.
  ///
  /// In en, this message translates to:
  /// **'Watch a short ad and raise the piece you picked by one.'**
  String get brushOfferBody;

  /// No description provided for @brushOfferWatch.
  ///
  /// In en, this message translates to:
  /// **'WATCH AD'**
  String get brushOfferWatch;

  /// No description provided for @brushOfferBuy.
  ///
  /// In en, this message translates to:
  /// **'Buy for {price} 🪙'**
  String brushOfferBuy(int price);

  /// No description provided for @brushOfferDecline.
  ///
  /// In en, this message translates to:
  /// **'NOT NOW'**
  String get brushOfferDecline;

  /// No description provided for @brushOfferFailed.
  ///
  /// In en, this message translates to:
  /// **'No ad available right now.'**
  String get brushOfferFailed;

  /// No description provided for @brushOfferNoCoins.
  ///
  /// In en, this message translates to:
  /// **'Not enough coins'**
  String get brushOfferNoCoins;

  /// No description provided for @brushOfferBalance.
  ///
  /// In en, this message translates to:
  /// **'You have {coins} 🪙'**
  String brushOfferBalance(int coins);

  /// No description provided for @coinStoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Your coins'**
  String get coinStoreTitle;

  /// No description provided for @coinStoreClose.
  ///
  /// In en, this message translates to:
  /// **'CLOSE'**
  String get coinStoreClose;

  /// Spoken label of the header balance pill.
  ///
  /// In en, this message translates to:
  /// **'{coins} coins'**
  String coinsBadgeSemantics(int coins);

  /// Spoken label of the hammer segment of the header pill.
  ///
  /// In en, this message translates to:
  /// **'{hammers} hammers'**
  String hammersBadgeSemantics(int hammers);

  /// No description provided for @coinSourcesTitle.
  ///
  /// In en, this message translates to:
  /// **'How to earn coins'**
  String get coinSourcesTitle;

  /// No description provided for @coinSourcesStars.
  ///
  /// In en, this message translates to:
  /// **'Beat levels with 3 stars'**
  String get coinSourcesStars;

  /// No description provided for @coinSourcesAds.
  ///
  /// In en, this message translates to:
  /// **'Watch rewarded videos'**
  String get coinSourcesAds;

  /// No description provided for @coinSourcesChests.
  ///
  /// In en, this message translates to:
  /// **'Complete the chapters on the map'**
  String get coinSourcesChests;

  /// No description provided for @coinSourceNova.
  ///
  /// In en, this message translates to:
  /// **'Trigger a Nova Fusion'**
  String get coinSourceNova;

  /// No description provided for @hammerSemantics.
  ///
  /// In en, this message translates to:
  /// **'Fusion Hammer, {count} in stock. Smashes one cell without spending a move.'**
  String hammerSemantics(int count);

  /// No description provided for @bombSemantics.
  ///
  /// In en, this message translates to:
  /// **'Bomb, {count} in stock. Blasts a 3x3 area without spending a move.'**
  String bombSemantics(int count);

  /// No description provided for @brushSemantics.
  ///
  /// In en, this message translates to:
  /// **'Brush, {count} in stock. Adds 1 to a tile\'s value without spending a move.'**
  String brushSemantics(int count);

  /// No description provided for @dailySpinTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Spin'**
  String get dailySpinTitle;

  /// No description provided for @dailySpinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'1 free spin per day'**
  String get dailySpinSubtitle;

  /// No description provided for @dailySpinSpinButton.
  ///
  /// In en, this message translates to:
  /// **'SPIN'**
  String get dailySpinSpinButton;

  /// No description provided for @dailySpinWatchAgainButton.
  ///
  /// In en, this message translates to:
  /// **'Spin Again (Watch Ad)'**
  String get dailySpinWatchAgainButton;

  /// No description provided for @dailySpinCloseButton.
  ///
  /// In en, this message translates to:
  /// **'CLOSE'**
  String get dailySpinCloseButton;

  /// No description provided for @dailySpinFreeButton.
  ///
  /// In en, this message translates to:
  /// **'FREE SPIN'**
  String get dailySpinFreeButton;

  /// No description provided for @dailySpinNextFreeIn.
  ///
  /// In en, this message translates to:
  /// **'Next free spin in'**
  String get dailySpinNextFreeIn;

  /// No description provided for @dailySpinPrizeTitle.
  ///
  /// In en, this message translates to:
  /// **'YOU WON!'**
  String get dailySpinPrizeTitle;

  /// No description provided for @dailySpinCollectButton.
  ///
  /// In en, this message translates to:
  /// **'COLLECT'**
  String get dailySpinCollectButton;

  /// No description provided for @dailySpinStockFull.
  ///
  /// In en, this message translates to:
  /// **'Stock full: +{coins} coins'**
  String dailySpinStockFull(int coins);

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

  /// No description provided for @endlessSuggestionTitle.
  ///
  /// In en, this message translates to:
  /// **'Out of energy?'**
  String get endlessSuggestionTitle;

  /// No description provided for @endlessSuggestionBody.
  ///
  /// In en, this message translates to:
  /// **'Your energy for this level ran out! How about beating your Personal Best while it recharges?'**
  String get endlessSuggestionBody;

  /// No description provided for @endlessSuggestionGo.
  ///
  /// In en, this message translates to:
  /// **'GO TO RECORD MODE'**
  String get endlessSuggestionGo;

  /// No description provided for @endlessSuggestionDecline.
  ///
  /// In en, this message translates to:
  /// **'KEEP TRYING'**
  String get endlessSuggestionDecline;

  /// No description provided for @storeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Match 3, evolve the number, reach 9'**
  String get storeSubtitle;

  /// No description provided for @storeShortDescription.
  ///
  /// In en, this message translates to:
  /// **'Number match-3: three of a kind become the next digit. Reach 9 and unleash the Super 9.'**
  String get storeShortDescription;

  /// No description provided for @storeFullDescription.
  ///
  /// In en, this message translates to:
  /// **'NineFuse is a number puzzle where matching isn\'t just clearing.\n\nLine up three identical digits and the middle one EVOLVES into the next: three 4s become a 5. Repeat the fusion, plan the chain, and climb the scale to the game\'s climax — the digit 9, which clears blockers around it, and the rare Super 9 (a 5+ match), which converts a whole value across the board in a single swap.\n\n• FUSION, NOT JUST CLEARING — match-3 mechanics with merge progression.\n• THE RITUAL OF 9 — the top digit clears blockers around it, and the Super 9 promotes the whole board.\n• ICE, GLASS AND STONE — covers that yield to 1, 2 or 3 adjacent fusions.\n• OBJECTIVE-BASED CAMPAIGN — reach a digit, break covers, clear the board.\n• ENDLESS MODE — a run with no move limit, and your high score kept.\n• FUSION HAMMER — smash one stuck cell without spending a move.\n• NO LIVES TIMER — play as much as you want, whenever you want.\n\nDark visuals, vivid per-digit colours and fluid fusion animations.'**
  String get storeFullDescription;

  /// No description provided for @storeKeywords.
  ///
  /// In en, this message translates to:
  /// **'number match 3,number puzzle,merge numbers,fusion puzzle,numeric puzzle,2048 match 3,offline puzzle,logic game'**
  String get storeKeywords;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacyTitle;

  /// No description provided for @privacyBody.
  ///
  /// In en, this message translates to:
  /// **'NineFuse keeps your progress on this device only. Ads are provided by Google AdMob.'**
  String get privacyBody;

  /// No description provided for @privacyPolicyLink.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicyLink;

  /// No description provided for @privacyAdOptions.
  ///
  /// In en, this message translates to:
  /// **'Ad privacy options'**
  String get privacyAdOptions;

  /// No description provided for @privacyClose.
  ///
  /// In en, this message translates to:
  /// **'CLOSE'**
  String get privacyClose;

  /// No description provided for @privacyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacyTooltip;

  /// No description provided for @outcomeWonHeadline.
  ///
  /// In en, this message translates to:
  /// **'COMPLETE!'**
  String get outcomeWonHeadline;

  /// No description provided for @continueOfferResume.
  ///
  /// In en, this message translates to:
  /// **'PICK UP WHERE YOU LEFT OFF'**
  String get continueOfferResume;

  /// No description provided for @continueOfferBonus.
  ///
  /// In en, this message translates to:
  /// **'{bonus, plural, =1{+1 MOVE} other{+{bonus} MOVES}}'**
  String continueOfferBonus(int bonus);

  /// No description provided for @objectiveMissingDigit.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{So close: 1 more {digit} piece.} other{So close: {count} more {digit} pieces.}}'**
  String objectiveMissingDigit(int count, int digit);

  /// No description provided for @objectiveMissingObstacle.
  ///
  /// In en, this message translates to:
  /// **'So close: {count} {obstacle} left.'**
  String objectiveMissingObstacle(int count, String obstacle);

  /// Rótulo da placa do capítulo no mapa: número do capítulo e estrelas conquistadas nele.
  ///
  /// In en, this message translates to:
  /// **'CHAPTER {number} · {earned}/{total}'**
  String mapChapterStars(int number, int earned, int total);

  /// No description provided for @mapYouAreHere.
  ///
  /// In en, this message translates to:
  /// **'YOU ARE HERE'**
  String get mapYouAreHere;

  /// No description provided for @mapLevelsCleared.
  ///
  /// In en, this message translates to:
  /// **'Levels 1–{last} cleared'**
  String mapLevelsCleared(int last);

  /// No description provided for @mapPlayLevel.
  ///
  /// In en, this message translates to:
  /// **'PLAY LEVEL {number}'**
  String mapPlayLevel(int number);

  /// Aviso do mapa quando um tipo de cobertura estreia nas próximas fases.
  ///
  /// In en, this message translates to:
  /// **'New obstacle on level {level}: {obstacle}'**
  String mapNewObstacle(int level, String obstacle);

  /// No description provided for @mapDailySpinTooltip.
  ///
  /// In en, this message translates to:
  /// **'Daily spin'**
  String get mapDailySpinTooltip;

  /// No description provided for @homeShop.
  ///
  /// In en, this message translates to:
  /// **'SHOP'**
  String get homeShop;

  /// No description provided for @homeSpin.
  ///
  /// In en, this message translates to:
  /// **'SPIN'**
  String get homeSpin;

  /// No description provided for @homeMap.
  ///
  /// In en, this message translates to:
  /// **'MAP'**
  String get homeMap;

  /// Pílula do menu inicial com o capítulo e a fase da vez.
  ///
  /// In en, this message translates to:
  /// **'CHAPTER {chapter} · LEVEL {level}'**
  String homeChapterLevel(int chapter, int level);

  /// No description provided for @homeStarsSemantics.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 star in the campaign} other{{count} stars in the campaign}}'**
  String homeStarsSemantics(int count);

  /// No description provided for @shopTitle.
  ///
  /// In en, this message translates to:
  /// **'SHOP'**
  String get shopTitle;

  /// No description provided for @shopBoosters.
  ///
  /// In en, this message translates to:
  /// **'BOOSTERS'**
  String get shopBoosters;

  /// No description provided for @shopCoins.
  ///
  /// In en, this message translates to:
  /// **'COINS'**
  String get shopCoins;

  /// No description provided for @shopStock.
  ///
  /// In en, this message translates to:
  /// **'You have {count}'**
  String shopStock(int count);

  /// No description provided for @shopVideoTitle.
  ///
  /// In en, this message translates to:
  /// **'+{coins} coins'**
  String shopVideoTitle(int coins);

  /// No description provided for @shopVideoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Watch a short video'**
  String get shopVideoSubtitle;

  /// No description provided for @shopWatch.
  ///
  /// In en, this message translates to:
  /// **'WATCH'**
  String get shopWatch;

  /// No description provided for @shopBuyFailed.
  ///
  /// In en, this message translates to:
  /// **'The purchase couldn\'t be completed. Your coins weren\'t spent.'**
  String get shopBuyFailed;

  /// No description provided for @chestReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Chapter chest!'**
  String get chestReadyTitle;

  /// No description provided for @chestCollect.
  ///
  /// In en, this message translates to:
  /// **'COLLECT'**
  String get chestCollect;

  /// No description provided for @chestLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Chest locked'**
  String get chestLockedTitle;

  /// No description provided for @chestLockedHint.
  ///
  /// In en, this message translates to:
  /// **'Beat every level of chapter {chapter} to open it.'**
  String chestLockedHint(int chapter);

  /// No description provided for @chestOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get chestOk;

  /// No description provided for @semanticsChestLocked.
  ///
  /// In en, this message translates to:
  /// **'Chapter {chapter} chest, locked.'**
  String semanticsChestLocked(int chapter);

  /// No description provided for @semanticsChestReady.
  ///
  /// In en, this message translates to:
  /// **'Chapter {chapter} chest, ready to open.'**
  String semanticsChestReady(int chapter);

  /// No description provided for @semanticsChestOpened.
  ///
  /// In en, this message translates to:
  /// **'Chapter {chapter} chest, already opened.'**
  String semanticsChestOpened(int chapter);

  /// No description provided for @settingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTooltip;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'SETTINGS'**
  String get settingsTitle;

  /// No description provided for @settingsSectionAudio.
  ///
  /// In en, this message translates to:
  /// **'SOUND & TOUCH'**
  String get settingsSectionAudio;

  /// No description provided for @settingsSound.
  ///
  /// In en, this message translates to:
  /// **'Sound effects'**
  String get settingsSound;

  /// No description provided for @settingsVolume.
  ///
  /// In en, this message translates to:
  /// **'Effects volume'**
  String get settingsVolume;

  /// No description provided for @settingsMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get settingsMusic;

  /// No description provided for @settingsVibration.
  ///
  /// In en, this message translates to:
  /// **'Vibration'**
  String get settingsVibration;

  /// No description provided for @settingsSectionLanguage.
  ///
  /// In en, this message translates to:
  /// **'LANGUAGE'**
  String get settingsSectionLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'Device default'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguagePt.
  ///
  /// In en, this message translates to:
  /// **'Português'**
  String get settingsLanguagePt;

  /// No description provided for @settingsLanguageEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEn;

  /// No description provided for @settingsSectionPrivacy.
  ///
  /// In en, this message translates to:
  /// **'PRIVACY'**
  String get settingsSectionPrivacy;

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get settingsPrivacyPolicy;

  /// No description provided for @settingsConsent.
  ///
  /// In en, this message translates to:
  /// **'Manage ad consent'**
  String get settingsConsent;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'ABOUT'**
  String get settingsSectionAbout;

  /// No description provided for @settingsCredits.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get settingsCredits;

  /// No description provided for @settingsLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open source licenses'**
  String get settingsLicenses;

  /// No description provided for @creditsTitle.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get creditsTitle;

  /// No description provided for @creditsBody.
  ///
  /// In en, this message translates to:
  /// **'Nunito, Lilita One and Baloo 2 fonts under the SIL Open Font License (OFL).\nTiles, obstacles and icons: NineFuse \"candy pop\" art pack.\nSound effects: Kenney (kenney.nl), CC0.\nMade with Flutter.'**
  String get creditsBody;

  /// No description provided for @creditsClose.
  ///
  /// In en, this message translates to:
  /// **'CLOSE'**
  String get creditsClose;

  /// No description provided for @tutorialFirstSwap.
  ///
  /// In en, this message translates to:
  /// **'Swap these two pieces to line up three of a kind.'**
  String get tutorialFirstSwap;

  /// No description provided for @tutorialFusion.
  ///
  /// In en, this message translates to:
  /// **'The piece you touched evolves: {amount} {from}s become a {to}!'**
  String tutorialFusion(String amount, int from, int to);

  /// No description provided for @tutorialAmount.
  ///
  /// In en, this message translates to:
  /// **'{size, select, three{three} four{four} five{five} other{several}}'**
  String tutorialAmount(String size);

  /// No description provided for @tutorialObjective.
  ///
  /// In en, this message translates to:
  /// **'{objective} to win.'**
  String tutorialObjective(String objective);

  /// No description provided for @tutorialMovesMedallion.
  ///
  /// In en, this message translates to:
  /// **'These are your moves. Every swap that makes a match spends one.'**
  String get tutorialMovesMedallion;

  /// No description provided for @tutorialFreeMiss.
  ///
  /// In en, this message translates to:
  /// **'A swap without a match costs no move: the pieces just slide back.'**
  String get tutorialFreeMiss;

  /// No description provided for @tutorialBoosterDock.
  ///
  /// In en, this message translates to:
  /// **'Stuck? The Hammer smashes the piece you tap, without spending a move.'**
  String get tutorialBoosterDock;

  /// No description provided for @tutorialObstacleIce.
  ///
  /// In en, this message translates to:
  /// **'Ice traps the piece. One fusion next to it breaks it.'**
  String get tutorialObstacleIce;

  /// No description provided for @tutorialObstacleGlass.
  ///
  /// In en, this message translates to:
  /// **'Glass takes two fusions next to it before it breaks.'**
  String get tutorialObstacleGlass;

  /// No description provided for @tutorialObstacleStone.
  ///
  /// In en, this message translates to:
  /// **'Stone takes three fusions next to it, or gives way at once to a 9 born beside it.'**
  String get tutorialObstacleStone;

  /// No description provided for @tutorialGotIt.
  ///
  /// In en, this message translates to:
  /// **'GOT IT'**
  String get tutorialGotIt;

  /// No description provided for @tutorialSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip tutorial'**
  String get tutorialSkip;

  /// No description provided for @settingsReplayTutorial.
  ///
  /// In en, this message translates to:
  /// **'Replay tutorial'**
  String get settingsReplayTutorial;

  /// No description provided for @settingsReplayTutorialDone.
  ///
  /// In en, this message translates to:
  /// **'The tutorial will show up again in your next levels.'**
  String get settingsReplayTutorialDone;
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
