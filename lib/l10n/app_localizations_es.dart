// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Cat Alarm';

  @override
  String get soundLabel => 'Sonido';

  @override
  String get usingSoundFile => 'Usando soft.m4a';

  @override
  String get audioActiveBanner => '● Audio ACTIVO – Toca STOP para detener';

  @override
  String get selectTone => 'Selecciona tono de alarma';

  @override
  String get soft => 'Suave';

  @override
  String get standard => 'Estándar';

  @override
  String get power => 'Potente';

  @override
  String get am => 'AM';

  @override
  String get pm => 'PM';

  @override
  String get ampmToggle => 'AM/PM';

  @override
  String get currentTimePrefix => 'Hora actual: ';

  @override
  String get setButton => 'Ajustar';

  @override
  String get alarmButton => 'Alarma';

  @override
  String get stopButton => 'Parar';

  @override
  String get offButton => 'Apagado';

  @override
  String get testButton => 'Prueba';

  @override
  String get audioTestTitle => 'Prueba de Audio';

  @override
  String get testSoundButton => 'Reproducir sonido de prueba';

  @override
  String get statusReady => 'Listo';

  @override
  String get statusStarting => 'Iniciando reproductor de audio...';

  @override
  String get statusPlaying => 'El sonido se está reproduciendo.';

  @override
  String get statusErrorPrefix => 'Error: ';

  @override
  String get statusPlayerStatePrefix => 'Estado del reproductor: ';

  @override
  String get statusFinished => 'Sonido finalizado.';

  @override
  String get statusPlayerErrorPrefix => 'Error del reproductor: ';

  @override
  String get alarmArmed => 'Alarma establecida';

  @override
  String get wakeUpTitle => '¡Despierta! 😺';

  @override
  String get homeQuestion => '¿Cuándo debería despertarte tu gato?';

  @override
  String get setAlarmButton => 'Programar alarma';

  @override
  String get intensityTitle => 'Elige la intensidad';

  @override
  String get navAlarm => 'Alarma';

  @override
  String get navSounds => 'Sonidos';
}
