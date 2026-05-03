import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

bool _unlocked = false;

// Web-only: activates the Web Audio API context on the first user gesture.
// Subsequent calls are no-ops. Must be called from a button press (user gesture).
Future<void> unlockAudio() async {
  if (!kIsWeb || _unlocked) return;
  _unlocked = true;
  try {
    final p = AudioPlayer();
    await p.setVolume(0.0);
    await p.setAsset('assets/sounds/catalarmstandard.mp3');
    await p.play();
    await p.pause();
    await p.dispose();
  } catch (_) {}
}
