import 'dart:async';
import 'dart:math';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/foundation.dart'; // Import für ValueNotifier
import 'dart:io' show Platform;

class CatAlarmPlayer {
  CatAlarmPlayer({
    String? purrAsset,
    required this.miauAssets,
    this.purrVolume = 0.28,
    this.miauMaxVolume = 1.0,
    this.fadeInDuration = const Duration(seconds: 25),
    this.minGap = const Duration(seconds: 2),
    this.maxGap = const Duration(seconds: 5),
  }) : purrAsset = purrAsset ?? (Platform.isAndroid ? 'assets/sounds/catalarmsoft.mp3' : 'assets/sounds/soft.wav');

  final String purrAsset;
  final List<String> miauAssets;
  final double purrVolume;
  final double miauMaxVolume;
  final Duration fadeInDuration;
  final Duration minGap;
  final Duration maxGap;

  final _purr = AudioPlayer();
  final _miau = AudioPlayer();
  final _rng = Random();
  Timer? _scheduler;
  bool _active = false;
  double _fade = 0.0;

  static final CatAlarmPlayer I = CatAlarmPlayer(
    miauAssets: [
      'assets/sounds/Miau1a.mp3',
      'assets/sounds/Miau2a.mp3',
      'assets/sounds/Miaub1.mp3',
      'assets/sounds/Miaub2.mp3',
      'assets/sounds/Miaub3.mp3',
      'assets/sounds/Miaub4.mp3',
      'assets/sounds/Miaub5.mp3',
      'assets/sounds/Miaub6.mp3',
    ],
  );

  int _stopLatch = 0;
  int get stopLatch => _stopLatch;
  bool isObsolete(int latchAtStart) => latchAtStart != _stopLatch;

  // ValueNotifier für den aktiven Status
  final ValueNotifier<bool> isActive = ValueNotifier(false);

  // Initialisierungsmethode (optional, für Kompatibilität)
  void init() {}

  // DisposeAll für Kompatibilität
  void disposeAll() => dispose();

  // StartOcean für Kompatibilität
  Future<void> startOcean() => start();

  Future<void> stopAll() async {
    _stopLatch++; // wichtig: STOP-Generation erhöhen
    await stop(); // Player stoppen + Session deaktivieren
    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (_) {}
    isActive.value = false;
  }

  Future<void> start() async {
    if (_active) return;
    _active = true;
    _fade = 0.0;
    final session = await AudioSession.instance;
    await session.setActive(true);
    await _purr.setAsset(purrAsset);
    _purr.setLoopMode(LoopMode.one);
    _purr.setVolume(purrVolume);
    await _purr.play();
    await _miau.setAsset(miauAssets[_rng.nextInt(miauAssets.length)]);
    _miau.setVolume(0.2);
    await _miau.play();
    _startFade();
    _scheduleNext();
    isActive.value = true;
  }

  void _startFade() {
    final tick = const Duration(milliseconds: 200);
    final steps = (fadeInDuration.inMilliseconds / tick.inMilliseconds).clamp(1, 9999).round();
    int n = 0;
    Timer.periodic(tick, (t) {
      if (!_active) { t.cancel(); return; }
      _fade = (++n / steps).clamp(0.0, 1.0);
      if (_fade >= 1.0) t.cancel();
    });
  }

  void _scheduleNext() {
    if (!_active) return;
    final gapMs = _rng.nextInt(maxGap.inMilliseconds - minGap.inMilliseconds + 1) + minGap.inMilliseconds;
    _scheduler?.cancel();
    _scheduler = Timer(Duration(milliseconds: gapMs), () async {
      if (!_active) return;
      final file = miauAssets[_rng.nextInt(miauAssets.length)];
      await _miau.setAsset(file);
      final vol = (0.15 + 0.85 * _fade).clamp(0.0, 1.0) * miauMaxVolume;
      _miau.setVolume(vol);
      await _miau.play();
      _scheduleNext();
    });
  }

  Future<void> stop() async {
    _active = false;
    _scheduler?.cancel();
    await _miau.stop();
    await _purr.stop();
    isActive.value = false;
  }

  void dispose() {
    _scheduler?.cancel();
    _miau.dispose();
    _purr.dispose();
  }
}
