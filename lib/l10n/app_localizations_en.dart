// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Cat Alarm';

  @override
  String get soundLabel => 'Sound';

  @override
  String get usingSoundFile => 'Using soft.m4a';

  @override
  String get audioActiveBanner => '● Audio ACTIVE – Tap STOP to stop';

  @override
  String get selectTone => 'Select alarm tone';

  @override
  String get soft => 'Soft';

  @override
  String get standard => 'Standard';

  @override
  String get power => 'Power';

  @override
  String get am => 'AM';

  @override
  String get pm => 'PM';

  @override
  String get ampmToggle => 'AM/PM';

  @override
  String get currentTimePrefix => 'Current time: ';

  @override
  String get setButton => 'Set';

  @override
  String get alarmButton => 'Alarm';

  @override
  String get stopButton => 'Stop';

  @override
  String get offButton => 'Off';

  @override
  String get testButton => 'Test';

  @override
  String get audioTestTitle => 'Audio Test';

  @override
  String get testSoundButton => 'Play test sound';

  @override
  String get statusReady => 'Ready';

  @override
  String get statusStarting => 'Starting audio player...';

  @override
  String get statusPlaying => 'Sound is playing.';

  @override
  String get statusErrorPrefix => 'Error: ';

  @override
  String get statusPlayerStatePrefix => 'PlayerState: ';

  @override
  String get statusFinished => 'Sound finished.';

  @override
  String get statusPlayerErrorPrefix => 'Player error: ';

  @override
  String get alarmArmed => 'Alarm set';

  @override
  String get wakeUpTitle => 'Wake up! 😺';

  @override
  String get homeQuestion => 'When should your cat wake you?';

  @override
  String get setAlarmButton => 'Set alarm';

  @override
  String get intensityTitle => 'Choose wake intensity';

  @override
  String get navAlarm => 'Alarm';

  @override
  String get navSounds => 'Sounds';
}
