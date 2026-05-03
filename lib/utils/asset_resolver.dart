import 'package:flutter/foundation.dart';
import '../widgets/mix_selector.dart';

String assetForAlarmMix(AlarmMix mix) {
  // dart:io Platform is unavailable on web — use kIsWeb + defaultTargetPlatform
  final isApple = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.iOS);
  switch (mix) {
    case AlarmMix.soft:
      return isApple
          ? 'assets/sounds/soft.m4a'
          : 'assets/sounds/catalarmsoft.mp3';
    case AlarmMix.standard:
      return isApple
          ? 'assets/sounds/catalarmstandard1.m4a'
          : 'assets/sounds/catalarmstandard.mp3';
    case AlarmMix.power:
      return isApple
          ? 'assets/sounds/catalarmpower1.m4a'
          : 'assets/sounds/catalarmpower.mp3';
    default:
      // defensive fallback in case enum is extended in the future
      return 'assets/sounds/catalarmstandard.mp3';
  }
}
