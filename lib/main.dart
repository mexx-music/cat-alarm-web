import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'app/app.dart';
import 'audio/sleep_preset_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());
  await session.setActive(true);
  await SleepPresetStore.I.load();
  runApp(const MyApp());
}
