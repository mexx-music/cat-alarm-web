import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'l10n/app_localizations.dart';

void main() => runApp(const AudioTestApp());

class AudioTestApp extends StatelessWidget {
  const AudioTestApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        appBar: AppBar(
            title: Builder(
                builder: (c) => Text(
                    AppLocalizations.of(c)?.audioTestTitle ?? 'Audio Test'))),
        body: const Center(child: AudioTestButton()),
      ),
    );
  }
}

class AudioTestButton extends StatefulWidget {
  const AudioTestButton({Key? key}) : super(key: key);

  @override
  State<AudioTestButton> createState() => _AudioTestButtonState();
}

class _AudioTestButtonState extends State<AudioTestButton> {
  final player = AudioPlayer();
  String status = 'Bereit';

  Future<bool> _exists(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> playTest() async {
    setState(() {
      status = AppLocalizations.of(context)?.statusStarting ??
          'Starting audio player...';
    });
    print('Check assets:');
    print('soft.m4a exists? ${await _exists("assets/sounds/soft.m4a")}');
    print('Miau1a.mp3 exists? ${await _exists("assets/sounds/Miau1a.mp3")}');
    print(
        'catalarmsoft.mp3 exists? ${await _exists("assets/sounds/catalarmsoft.mp3")}');
    try {
      await player.play(AssetSource('sounds/Miau1a.mp3'), volume: 1.0);
      setState(() {
        status =
            AppLocalizations.of(context)?.statusPlaying ?? 'Sound is playing.';
      });
    } catch (e) {
      setState(() {
        status =
            (AppLocalizations.of(context)?.statusErrorPrefix ?? 'Error: ') +
                e.toString();
      });
    }
    player.onPlayerStateChanged.listen((state) {
      setState(() {
        status = (AppLocalizations.of(context)?.statusPlayerStatePrefix ??
                'PlayerState: ') +
            state.toString();
      });
    });
    player.onPlayerComplete.listen((event) {
      setState(() {
        status =
            AppLocalizations.of(context)?.statusFinished ?? 'Sound finished.';
      });
    });
    // audioplayers v6: onPlayerError stream is not available on all platforms/versions.
    // Keep error handling inside catch blocks and state-change listeners.
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: playTest,
          child: Builder(
              builder: (c) => Text(AppLocalizations.of(c)?.testSoundButton ??
                  'Play test sound')),
        ),
        const SizedBox(height: 20),
        Text(status),
      ],
    );
  }
}
