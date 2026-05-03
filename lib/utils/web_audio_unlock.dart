import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

bool _unlocked = false;

// Web-only: activates the Web Audio API context on the first user gesture.
// Subsequent calls are no-ops. Must be called from a button press (user gesture).
// Volume is forced to 0 before AND after play() to ensure nothing is audible
// on iOS Safari where setVolume timing can be unreliable.
Future<void> unlockAudio() async {
  if (!kIsWeb || _unlocked) return;
  _unlocked = true;
  try {
    final p = AudioPlayer();
    await p.setVolume(0.0);       // stumm VOR setAsset
    await p.setAsset('assets/sounds/catalarmstandard.mp3');
    await p.setVolume(0.0);       // nochmals stumm VOR play (iOS Safari Timing-Fix)
    await p.play();               // notwendig, um WebAudio-Context zu entsperren
    await p.stop();               // sofort stoppen (nicht nur pause)
    await p.dispose();
  } catch (_) {}
}


