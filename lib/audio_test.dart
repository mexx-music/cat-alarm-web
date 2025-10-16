import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() => runApp(AudioTestApp());

class AudioTestApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Audio Test')),
        body: Center(child: AudioTestButton()),
      ),
    );
  }
}

class AudioTestButton extends StatefulWidget {
  @override
  State<AudioTestButton> createState() => _AudioTestButtonState();
}

class _AudioTestButtonState extends State<AudioTestButton> {
  final player = AudioPlayer();
  String status = 'Bereit';

  Future<bool> _exists(String assetPath) async {
    try { await rootBundle.load(assetPath); return true; }
    catch (_) { return false; }
  }

  Future<void> playTest() async {
    setState(() { status = 'Starte Audioplayers...'; });
    print('Check assets:');
    print('soft.m4a exists? ${await _exists("assets/sounds/soft.m4a")}');
    print('Miau1a.mp3 exists? ${await _exists("assets/sounds/Miau1a.mp3")}');
    print('catalarmsoft.mp3 exists? ${await _exists("assets/sounds/catalarmsoft.mp3")}');
    try {
      await player.play(AssetSource('sounds/Miau1a.mp3'), volume: 1.0);
      setState(() { status = 'Sound wird abgespielt.'; });
    } catch (e) {
      setState(() { status = 'Fehler: ' + e.toString(); });
    }
    player.onPlayerStateChanged.listen((state) {
      setState(() { status = 'PlayerState: ' + state.toString(); });
    });
    player.onPlayerComplete.listen((event) {
      setState(() { status = 'Sound fertig.'; });
    });
    player.onPlayerError.listen((msg) {
      setState(() { status = 'Player-Fehler: ' + msg; });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: playTest,
          child: Text('Test-Sound abspielen'),
        ),
        SizedBox(height: 20),
        Text(status),
      ],
    );
  }
}
