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

  /// No description provided for @outcomeCampaignFinished.
  ///
  /// In en, this message translates to:
  /// **'You finished the campaign!'**
  String get outcomeCampaignFinished;

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

  /// No description provided for @playEndlessButton.
  ///
  /// In en, this message translates to:
  /// **'PLAY HIGH SCORE MODE'**
  String get playEndlessButton;

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
  /// **'Run over'**
  String get endlessOverTitle;

  /// No description provided for @endlessOverMessage.
  ///
  /// In en, this message translates to:
  /// **'There were no swaps left to make.'**
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

  /// Legenda do contador de estrelas do mapa. Existe para o número não se ler como progresso do capítulo nomeado ao lado.
  ///
  /// In en, this message translates to:
  /// **'CAMPAIGN'**
  String get starsCaption;

  /// No description provided for @starsSemantics.
  ///
  /// In en, this message translates to:
  /// **'{earned} of {total} campaign stars'**
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

  /// Rótulo sobre os nós projetados do mapa: a trilha nunca termina em corte seco.
  ///
  /// In en, this message translates to:
  /// **'Chapter {number}: Coming Soon!'**
  String chapterComingSoon(int number);

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

  /// No description provided for @bonusMoves.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{+1 Move!} other{+{count} Moves!}}'**
  String bonusMoves(int count);
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
