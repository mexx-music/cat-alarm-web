import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_zh.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('zh'),
    Locale('zh', 'CN')
  ];

  /// App title shown in the app bar
  ///
  /// In en, this message translates to:
  /// **'Cat Alarm'**
  String get appTitle;

  /// Label for sound selection UI
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get soundLabel;

  /// Short note indicating the active sound file
  ///
  /// In en, this message translates to:
  /// **'Using soft.m4a'**
  String get usingSoundFile;

  /// No description provided for @audioActiveBanner.
  ///
  /// In en, this message translates to:
  /// **'● Audio ACTIVE – Tap STOP to stop'**
  String get audioActiveBanner;

  /// No description provided for @selectTone.
  ///
  /// In en, this message translates to:
  /// **'Select alarm tone'**
  String get selectTone;

  /// No description provided for @soft.
  ///
  /// In en, this message translates to:
  /// **'Soft'**
  String get soft;

  /// No description provided for @standard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get standard;

  /// No description provided for @power.
  ///
  /// In en, this message translates to:
  /// **'Power'**
  String get power;

  /// No description provided for @am.
  ///
  /// In en, this message translates to:
  /// **'AM'**
  String get am;

  /// No description provided for @pm.
  ///
  /// In en, this message translates to:
  /// **'PM'**
  String get pm;

  /// No description provided for @ampmToggle.
  ///
  /// In en, this message translates to:
  /// **'AM/PM'**
  String get ampmToggle;

  /// No description provided for @currentTimePrefix.
  ///
  /// In en, this message translates to:
  /// **'Current time: '**
  String get currentTimePrefix;

  /// No description provided for @setButton.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get setButton;

  /// No description provided for @alarmButton.
  ///
  /// In en, this message translates to:
  /// **'Alarm'**
  String get alarmButton;

  /// No description provided for @stopButton.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopButton;

  /// No description provided for @offButton.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get offButton;

  /// No description provided for @testButton.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get testButton;

  /// No description provided for @audioTestTitle.
  ///
  /// In en, this message translates to:
  /// **'Audio Test'**
  String get audioTestTitle;

  /// No description provided for @testSoundButton.
  ///
  /// In en, this message translates to:
  /// **'Play test sound'**
  String get testSoundButton;

  /// No description provided for @statusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get statusReady;

  /// No description provided for @statusStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting audio player...'**
  String get statusStarting;

  /// No description provided for @statusPlaying.
  ///
  /// In en, this message translates to:
  /// **'Sound is playing.'**
  String get statusPlaying;

  /// No description provided for @statusErrorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error: '**
  String get statusErrorPrefix;

  /// No description provided for @statusPlayerStatePrefix.
  ///
  /// In en, this message translates to:
  /// **'PlayerState: '**
  String get statusPlayerStatePrefix;

  /// No description provided for @statusFinished.
  ///
  /// In en, this message translates to:
  /// **'Sound finished.'**
  String get statusFinished;

  /// No description provided for @statusPlayerErrorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Player error: '**
  String get statusPlayerErrorPrefix;

  /// No description provided for @alarmArmed.
  ///
  /// In en, this message translates to:
  /// **'Alarm set'**
  String get alarmArmed;

  /// No description provided for @wakeUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Wake up! 😺'**
  String get wakeUpTitle;

  /// No description provided for @homeQuestion.
  ///
  /// In en, this message translates to:
  /// **'When should your cat wake you?'**
  String get homeQuestion;

  /// No description provided for @setAlarmButton.
  ///
  /// In en, this message translates to:
  /// **'Set alarm'**
  String get setAlarmButton;

  /// No description provided for @intensityTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose wake intensity'**
  String get intensityTitle;

  /// No description provided for @navAlarm.
  ///
  /// In en, this message translates to:
  /// **'Alarm'**
  String get navAlarm;

  /// No description provided for @navSounds.
  ///
  /// In en, this message translates to:
  /// **'Sounds'**
  String get navSounds;

  /// No description provided for @armedGreeting.
  ///
  /// In en, this message translates to:
  /// **'Good night ❤'**
  String get armedGreeting;

  /// No description provided for @armedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your cat will wake you gently'**
  String get armedSubtitle;

  /// No description provided for @nowLabel.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get nowLabel;

  /// No description provided for @alarmAt.
  ///
  /// In en, this message translates to:
  /// **'Alarm at'**
  String get alarmAt;

  /// No description provided for @wakesInLabel.
  ///
  /// In en, this message translates to:
  /// **'Your cat will wake you in'**
  String get wakesInLabel;

  /// No description provided for @wakesInSoon.
  ///
  /// In en, this message translates to:
  /// **'soon'**
  String get wakesInSoon;

  /// No description provided for @wakesInSoonFull.
  ///
  /// In en, this message translates to:
  /// **'Your cat will wake you soon'**
  String get wakesInSoonFull;

  /// No description provided for @nightTapToWake.
  ///
  /// In en, this message translates to:
  /// **'Tap to wake'**
  String get nightTapToWake;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get goodMorning;

  /// No description provided for @wokeYou.
  ///
  /// In en, this message translates to:
  /// **'Your cat woke you up'**
  String get wokeYou;

  /// No description provided for @timeToWake.
  ///
  /// In en, this message translates to:
  /// **'Time to get up!'**
  String get timeToWake;

  /// No description provided for @iAmAwake.
  ///
  /// In en, this message translates to:
  /// **'I\'m awake'**
  String get iAmAwake;

  /// No description provided for @snooze5.
  ///
  /// In en, this message translates to:
  /// **'5 more minutes'**
  String get snooze5;

  /// No description provided for @morningTagline.
  ///
  /// In en, this message translates to:
  /// **'Every morning is brighter with your cat.'**
  String get morningTagline;

  /// No description provided for @sleepModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Sleep mode'**
  String get sleepModeTitle;

  /// No description provided for @sleepModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Mix sounds and set a timer'**
  String get sleepModeSubtitle;

  /// No description provided for @sleepSoundPurr.
  ///
  /// In en, this message translates to:
  /// **'Purring'**
  String get sleepSoundPurr;

  /// No description provided for @sleepSoundRain.
  ///
  /// In en, this message translates to:
  /// **'Rain'**
  String get sleepSoundRain;

  /// No description provided for @sleepSoundOcean.
  ///
  /// In en, this message translates to:
  /// **'Ocean'**
  String get sleepSoundOcean;

  /// No description provided for @sleepSoundMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get sleepSoundMusic;

  /// No description provided for @sleepMusicTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose music'**
  String get sleepMusicTitle;

  /// No description provided for @sleepMusicSoftAcoustic.
  ///
  /// In en, this message translates to:
  /// **'Soft Acoustic Guitar'**
  String get sleepMusicSoftAcoustic;

  /// No description provided for @sleepMusicVerySlow.
  ///
  /// In en, this message translates to:
  /// **'Very Slow Acoustic'**
  String get sleepMusicVerySlow;

  /// No description provided for @sleepMusicRelaxing.
  ///
  /// In en, this message translates to:
  /// **'Relaxing Acoustic'**
  String get sleepMusicRelaxing;

  /// No description provided for @sleepMusicWarmSauna.
  ///
  /// In en, this message translates to:
  /// **'Warm Sauna Ambience'**
  String get sleepMusicWarmSauna;

  /// No description provided for @sleepTimerTitle.
  ///
  /// In en, this message translates to:
  /// **'Select timer'**
  String get sleepTimerTitle;

  /// No description provided for @sleepTimer15.
  ///
  /// In en, this message translates to:
  /// **'15 min'**
  String get sleepTimer15;

  /// No description provided for @sleepTimer30.
  ///
  /// In en, this message translates to:
  /// **'30 min'**
  String get sleepTimer30;

  /// No description provided for @sleepTimer60.
  ///
  /// In en, this message translates to:
  /// **'60 min'**
  String get sleepTimer60;

  /// No description provided for @sleepTimerUntilStop.
  ///
  /// In en, this message translates to:
  /// **'Until I stop'**
  String get sleepTimerUntilStop;

  /// No description provided for @sleepStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Start sleep mode'**
  String get sleepStartTitle;

  /// No description provided for @sleepWithAlarm.
  ///
  /// In en, this message translates to:
  /// **'With alarm'**
  String get sleepWithAlarm;

  /// No description provided for @sleepWithAlarmHint.
  ///
  /// In en, this message translates to:
  /// **'Alarm stays active'**
  String get sleepWithAlarmHint;

  /// No description provided for @sleepWithoutAlarm.
  ///
  /// In en, this message translates to:
  /// **'No alarm'**
  String get sleepWithoutAlarm;

  /// No description provided for @sleepWithoutAlarmHint.
  ///
  /// In en, this message translates to:
  /// **'Sounds stop with timer'**
  String get sleepWithoutAlarmHint;

  /// No description provided for @sleepStartButton.
  ///
  /// In en, this message translates to:
  /// **'Start sleep mode'**
  String get sleepStartButton;

  /// No description provided for @sleepStopButton.
  ///
  /// In en, this message translates to:
  /// **'Stop sleep mode'**
  String get sleepStopButton;

  /// No description provided for @sleepRemainingPrefix.
  ///
  /// In en, this message translates to:
  /// **'remaining '**
  String get sleepRemainingPrefix;

  /// No description provided for @sleepUnlimited.
  ///
  /// In en, this message translates to:
  /// **'runs until stop'**
  String get sleepUnlimited;

  /// No description provided for @sleepActive.
  ///
  /// In en, this message translates to:
  /// **'● Sleep running'**
  String get sleepActive;

  /// No description provided for @sleepNoChannelHint.
  ///
  /// In en, this message translates to:
  /// **'Please enable at least one sound'**
  String get sleepNoChannelHint;

  /// No description provided for @sleepPresetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get sleepPresetsTitle;

  /// No description provided for @sleepPresetSave.
  ///
  /// In en, this message translates to:
  /// **'Save current set'**
  String get sleepPresetSave;

  /// No description provided for @sleepPresetSaved.
  ///
  /// In en, this message translates to:
  /// **'Set saved'**
  String get sleepPresetSaved;

  /// No description provided for @sleepPresetAdd.
  ///
  /// In en, this message translates to:
  /// **'Add set'**
  String get sleepPresetAdd;

  /// No description provided for @sleepPresetSaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Save set?'**
  String get sleepPresetSaveTitle;

  /// No description provided for @sleepPresetSaveBody.
  ///
  /// In en, this message translates to:
  /// **'Overwrite \"{name}\" with the current mix?'**
  String sleepPresetSaveBody(String name);

  /// No description provided for @sleepPresetSaveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get sleepPresetSaveConfirm;

  /// No description provided for @sleepPresetSaveCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get sleepPresetSaveCancel;

  /// No description provided for @sleepPresetDefault.
  ///
  /// In en, this message translates to:
  /// **'Set {n}'**
  String sleepPresetDefault(int n);
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
      <String>['de', 'en', 'es', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'CN':
            return AppLocalizationsZhCn();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
