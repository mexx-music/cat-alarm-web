import 'package:just_audio/just_audio.dart' as ja;
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class CatAlarmPlayer {
  static final CatAlarmPlayer I = CatAlarmPlayer._();
  CatAlarmPlayer._();

  // Player
  final ja.AudioPlayer ocean = ja.AudioPlayer();
  final ja.AudioPlayer rain = ja.AudioPlayer();
  final ja.AudioPlayer purr = ja.AudioPlayer();
  final ja.AudioPlayer meow = ja.AudioPlayer();
  final ja.AudioPlayer alarm =
      ja.AudioPlayer(); // <<< NEU: dedizierter Alarm-Slot

  // UI-Status
  final ValueNotifier<bool> isActive = ValueNotifier<bool>(false);

  // Interna
  Timer? _autoplayTimer;
  StreamSubscription? _positionSub;
  final List<StreamSubscription> _stateSubs = [];
  late final List<ja.AudioPlayer> _players = [
    alarm,
    ocean,
    rain,
    purr,
    meow
  ]; // <<< geändert

  // CatAlarmPlayer: zusätzliche Guards
  int _stopLatch = 0;
  int get stopLatch => _stopLatch;

  // --- NEU: Aktiv-Status automatisch aus den Player-Zuständen ableiten ---
  void _wireActivityTracking() {
    // alle alten Subs weg
    for (final s in _stateSubs) {
      s.cancel();
    }
    _stateSubs.clear();

    // Auf playingStream/processingStateStream hören
    for (final p in _players) {
      _stateSubs.add(
        p.playingStream.listen((_) => _recalcActive()),
      );
      _stateSubs.add(
        p.processingStateStream.listen((_) => _recalcActive()),
      );
    }
    // initial setzen
    _recalcActive();
  }

  void _recalcActive() {
    final anyPlaying = _players.any((p) => p.playing);
    // Optional: Wenn du „User hat gestoppt“ hart erzwingen willst:
    // final active = _armed && anyPlaying;
    final active = anyPlaying;
    if (isActive.value != active) {
      isActive.value = active;
    }
  }

  // --- Call this once in app startup (z. B. in main() oder initState deines Screens) ---
  Future<void> init() async {
    _wireActivityTracking();
  }

  // Beispiel-Start (nutze deine eigenen Startmethoden – wichtig ist nur: _armed setzen)
  Future<void> startOcean() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    await session.setActive(true);

    await ocean.setLoopMode(ja.LoopMode.one);
    await ocean.setAudioSource(ja.AudioSource.asset('assets/audio/ocean.ogg'));
    await ocean.seek(Duration.zero);
    await ocean.play();
    // isActive wird jetzt automatisch true, sobald der Player spielt
  }

  Future<void> startRain() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    await session.setActive(true);

    await rain.setLoopMode(ja.LoopMode.one);
    await rain.setAudioSource(ja.AudioSource.asset('assets/audio/rain.ogg'));
    await rain.seek(Duration.zero);
    await rain.play();
  }

  Future<void> startPurr() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    await session.setActive(true);

    await purr.setLoopMode(ja.LoopMode.one);
    await purr.setAudioSource(ja.AudioSource.asset('assets/audio/purr.ogg'));
    await purr.seek(Duration.zero);
    await purr.play();
  }

  Future<void> startMeow() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    await session.setActive(true);

    await meow.setLoopMode(ja.LoopMode.off);
    await meow.setAudioSource(ja.AudioSource.asset('assets/audio/meow.ogg'));
    await meow.seek(Duration.zero);
    await meow.play();
  }

  // universelle Startmethode NUR für den Timer/Alarm:
  Future<void> playAlarmAsset(String assetPath, {bool loop = true}) async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      await session.setActive(true);
    } catch (_) {}

    // immer den gleichen Slot verwenden -> stopAll() erwischt ihn sicher
    try {
      await alarm.stop();
    } catch (_) {}
    // note: don't set a null AudioSource (API requires non-null). Remaining cleanup will stop/seek the player.
    await alarm.setLoopMode(loop ? ja.LoopMode.one : ja.LoopMode.off);
    await alarm.setAudioSource(ja.AudioSource.asset(assetPath));
    await alarm.play();

    // Sofortiges UI-Feedback (wird später auch von Streams bestätigt)
    if (!isActive.value) isActive.value = true;
  }

  Future<void> stopAll() async {
    _stopLatch++;
    _autoplayTimer?.cancel();
    _autoplayTimer = null;
    await _positionSub?.cancel();
    _positionSub = null;

    // Debug-Ausgabe
    debugPrint('CatAlarmPlayer: stopAll() aufgerufen');

    // Alle Player wirklich stoppen und Status prüfen
    for (final p in _players) {
      try {
        await p.setLoopMode(ja.LoopMode.off);
      } catch (e) {
        debugPrint('Fehler beim Setzen des LoopMode: \x1B[31m$e\x1B[0m');
      }
      try {
        await p.stop();
      } catch (e) {
        debugPrint('Fehler beim Stoppen des Players: \x1B[31m$e\x1B[0m');
      }
      try {
        await p.seek(Duration.zero);
      } catch (e) {
        debugPrint('Fehler beim Seek: \x1B[31m$e\x1B[0m');
      }
    }

    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (e) {
      debugPrint(
          'Fehler beim Deaktivieren der AudioSession: \x1B[31m$e\x1B[0m');
    }
    _recalcActive();
    debugPrint(
        'CatAlarmPlayer: stopAll() beendet, isActive = [32m${isActive.value}[0m');
  }

  // Hilfsprüfer: wurde seit Start ein Stop gedrückt?
  bool isObsolete(int latchAtStart) => latchAtStart != _stopLatch;

  Future<void> disposeAll() async {
    await stopAll();
    for (final s in _stateSubs) {
      s.cancel();
    }
    _stateSubs.clear();
    await Future.wait(_players.map((p) => p.dispose()));
  }
}
