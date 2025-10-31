import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart' as ja;

class CatAlarmPlayer {
  static final CatAlarmPlayer I = CatAlarmPlayer._();
  CatAlarmPlayer._();

  // Player
  final ja.AudioPlayer ocean = ja.AudioPlayer();
  final ja.AudioPlayer rain  = ja.AudioPlayer();
  final ja.AudioPlayer purr  = ja.AudioPlayer();
  final ja.AudioPlayer meow  = ja.AudioPlayer();
  final ja.AudioPlayer alarm = ja.AudioPlayer(); // <<< NEU: dedizierter Alarm-Slot

  /// UI-Status (für Banner/Buttons)
  final ValueNotifier<bool> isActive = ValueNotifier<bool>(false);

  int _stopLatch = 0;
  int get stopLatch => _stopLatch;
  bool isObsolete(int latchAtStart) => latchAtStart != _stopLatch;

  StreamSubscription<bool>? _playingSub;
  StreamSubscription<ja.ProcessingState>? _stateSub;

  bool _armed = false;

  Future<void> init() async {
    await _playingSub?.cancel();
    await _stateSub?.cancel();
    _playingSub = alarm.playingStream.listen((_) => _recalcActive());
    _stateSub   = alarm.processingStateStream.listen((_) => _recalcActive());
    _recalcActive();
  }

  void _recalcActive() {
    final active = alarm.playing;
    if (isActive.value != active) isActive.value = active;
  }

  /// Startet den gewählten CatAlarm-Asset (Timer benutzt nur diese Methode!)
  Future<void> playAlarmAsset(String assetPath, {bool loop = true, double volume = 1.0}) async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      await session.setActive(true);
    } catch (e) {
      debugPrint('AudioSession activate error: $e');
    }

    try { await alarm.setLoopMode(loop ? ja.LoopMode.one : ja.LoopMode.off); } catch (_) {}
    try { await alarm.stop(); } catch (_) {}
    try { await alarm.seek(Duration.zero); } catch (_) {}
    await alarm.setAsset(assetPath);
    await alarm.setVolume(volume);
    await alarm.play();

    if (!isActive.value) isActive.value = true;
    debugPrint('CatAlarmPlayer: Alarm gestartet -> $assetPath');
  }

  /// Stoppt wirklich den Timer-Sound
  Future<void> stopAll() async {
    _stopLatch++;

    try { await alarm.setLoopMode(ja.LoopMode.off); } catch (_) {}
    try { await alarm.stop(); } catch (_) {}
    try { await alarm.seek(Duration.zero); } catch (_) {}

    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (e) {
      debugPrint('AudioSession deactivate error: $e');
    }

    _recalcActive();
    debugPrint('CatAlarmPlayer: stopAll() -> isActive=[32m${isActive.value}[0m');
  }

  Future<void> disposeAll() async {
    await stopAll();
    await _playingSub?.cancel();
    await _stateSub?.cancel();
    await alarm.dispose();
  }

  Future<void> startOcean() async {
    _armed = true;
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    await session.setActive(true);

    await ocean.setLoopMode(ja.LoopMode.one);
    await ocean.setAudioSource(ja.AudioSource.asset('assets/audio/ocean.ogg'));
    await ocean.seek(Duration.zero);
    await ocean.play();
    // isActive wird jetzt automatisch true, sobald der Player spielt
  }
}
