import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

class AudioSmoke {
  static Future<void> run() async {
    // 1) AudioSession aktivieren (macOS/iOS wichtig)
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    await session.setActive(true);

    // 2) Existenzchecks (verhindert „silent fail“)
    Future<bool> exists(String p) async {
      try { await rootBundle.load(p); return true; } catch (_) { return false; }
    }
    final miau = 'assets/sounds/Miau1a.mp3';
    final purr = Platform.isAndroid ? 'assets/sounds/catalarmsoft.mp3' : 'assets/sounds/soft.wav';

    print('SMOKE: exists($miau) = ${await exists(miau)}');
    print('SMOKE: exists($purr) = ${await exists(purr)}');

    // 3) Ein Player – EIN File abspielen (deutlich hörbar)
    final p = AudioPlayer();
    p.playbackEventStream.listen(
      (e) => print('SMOKE: state=${e.processingState} pos=${e.updatePosition}'),
      onError: (e) => print('SMOKE onError: $e'),
    );

    try {
      await p.setAsset(miau);
      await p.setVolume(1.0);
      await p.play();
      print('SMOKE: playing $miau (sollte hörbar sein)');
    } catch (e) {
      print('SMOKE: load/play failed: $e');
    }

    // 4) Nach 2s zusätzlich Schnurren im Loop dazumischen
    Future.delayed(const Duration(seconds: 2), () async {
      final p2 = AudioPlayer();
      await p2.setAsset(purr);
      await p2.setLoopMode(LoopMode.one);
      await p2.setVolume(0.3);
      await p2.play();
      print('SMOKE: purr loop gestartet');
    });
  }
}
