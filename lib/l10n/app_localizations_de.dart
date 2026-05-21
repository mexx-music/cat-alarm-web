// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Cat Alarm';

  @override
  String get soundLabel => 'Ton';

  @override
  String get usingSoundFile => 'Verwendet: soft.m4a';

  @override
  String get audioActiveBanner => '● Audio AKTIV – Tippe STOP zum Beenden';

  @override
  String get selectTone => 'Weckton auswählen';

  @override
  String get soft => 'Sanft';

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
  String get currentTimePrefix => 'Aktuelle Uhrzeit: ';

  @override
  String get setButton => 'Stellen';

  @override
  String get alarmButton => 'Alarm';

  @override
  String get stopButton => 'Stopp';

  @override
  String get offButton => 'Aus';

  @override
  String get testButton => 'Test';

  @override
  String get audioTestTitle => 'Audio Test';

  @override
  String get testSoundButton => 'Test-Sound abspielen';

  @override
  String get statusReady => 'Bereit';

  @override
  String get statusStarting => 'Starte Audioplayer...';

  @override
  String get statusPlaying => 'Sound wird abgespielt.';

  @override
  String get statusErrorPrefix => 'Fehler: ';

  @override
  String get statusPlayerStatePrefix => 'PlayerState: ';

  @override
  String get statusFinished => 'Sound fertig.';

  @override
  String get statusPlayerErrorPrefix => 'Player-Fehler: ';

  @override
  String get alarmArmed => 'Wecker gestellt';

  @override
  String get wakeUpTitle => 'Aufwachen! 😺';

  @override
  String get homeQuestion => 'Wann soll deine Katze dich wecken?';

  @override
  String get setAlarmButton => 'Wecker stellen';

  @override
  String get intensityTitle => 'Weckintensität wählen';

  @override
  String get navAlarm => 'Wecker';

  @override
  String get navSounds => 'Klänge';

  @override
  String get armedGreeting => 'Gute Nacht ❤';

  @override
  String get armedSubtitle => 'Deine Katze wacht für dich auf';

  @override
  String get nowLabel => 'Jetzt';

  @override
  String get alarmAt => 'Wecker um';

  @override
  String get wakesInLabel => 'Deine Katze weckt dich in';

  @override
  String get wakesInSoon => 'gleich';

  @override
  String get wakesInSoonFull => 'Deine Katze weckt dich gleich';

  @override
  String get nightTapToWake => 'Tippen zum Aufwecken';

  @override
  String get goodMorning => 'Guten Morgen';

  @override
  String get wokeYou => 'Deine Katze hat dich geweckt';

  @override
  String get timeToWake => 'Zeit aufzustehen!';

  @override
  String get iAmAwake => 'Ich bin wach';

  @override
  String get snooze5 => 'Noch 5 Minuten';

  @override
  String get morningTagline => 'Jeder Morgen ist schöner mit deiner Katze.';

  @override
  String get sleepModeTitle => 'Einschlafmodus';

  @override
  String get sleepModeSubtitle => 'Kombiniere Klänge und stelle einen Timer';

  @override
  String get sleepSoundPurr => 'Schnurren';

  @override
  String get sleepSoundRain => 'Regen';

  @override
  String get sleepSoundOcean => 'Meer';

  @override
  String get sleepSoundMusic => 'Musik';

  @override
  String get sleepMusicTitle => 'Musik auswählen';

  @override
  String get sleepMusicSoftAcoustic => 'Soft Acoustic Guitar';

  @override
  String get sleepMusicVerySlow => 'Very Slow Acoustic';

  @override
  String get sleepMusicRelaxing => 'Relaxing Acoustic';

  @override
  String get sleepMusicWarmSauna => 'Warm Sauna Ambience';

  @override
  String get sleepTimerTitle => 'Timer wählen';

  @override
  String get sleepTimer15 => '15 min';

  @override
  String get sleepTimer30 => '30 min';

  @override
  String get sleepTimer60 => '60 min';

  @override
  String get sleepTimerUntilStop => 'Bis ich stoppe';

  @override
  String get sleepStartTitle => 'Einschlafmodus starten';

  @override
  String get sleepWithAlarm => 'Mit Wecker';

  @override
  String get sleepWithAlarmHint => 'Wecker bleibt aktiv';

  @override
  String get sleepWithoutAlarm => 'Ohne Wecker';

  @override
  String get sleepWithoutAlarmHint => 'Sounds stoppen mit Timer';

  @override
  String get sleepStartButton => 'Einschlafmodus starten';

  @override
  String get sleepStopButton => 'Einschlafmodus stoppen';

  @override
  String get sleepRemainingPrefix => 'noch ';

  @override
  String get sleepUnlimited => 'läuft bis Stopp';

  @override
  String get sleepActive => '● Sleep läuft';

  @override
  String get sleepNoChannelHint => 'Bitte mindestens einen Klang aktivieren';

  @override
  String get sleepPresetsTitle => 'Vorlagen';

  @override
  String get sleepPresetSave => 'Aktuelles Set speichern';

  @override
  String get sleepPresetSaved => 'Set gespeichert';

  @override
  String get sleepPresetAdd => 'Set hinzufügen';

  @override
  String get sleepPresetSaveTitle => 'Set speichern?';

  @override
  String sleepPresetSaveBody(String name) {
    return '„$name“ mit der aktuellen Mischung überschreiben?';
  }

  @override
  String get sleepPresetSaveConfirm => 'Speichern';

  @override
  String get sleepPresetSaveCancel => 'Abbrechen';

  @override
  String sleepPresetDefault(int n) {
    return 'Set $n';
  }
}
