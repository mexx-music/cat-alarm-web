import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../utils/asset_resolver.dart';
import '../utils/time_formatters.dart';
import '../utils/web_audio_unlock.dart';
import '../widgets/pwa_install_button.dart';
import '../widgets/clock_view.dart';
import '../widgets/control_panel.dart';
import '../widgets/mix_selector.dart';
import '../widgets/wakelock_manager.dart';
import '../starfield.dart';
import '../audio/cat_alarm_player.dart';
import '../core/alarm_core.dart';

class CatAlarmScreen extends StatefulWidget {
  const CatAlarmScreen({super.key});

  @override
  State<CatAlarmScreen> createState() => _CatAlarmScreenState();
}

class _CatAlarmScreenState extends State<CatAlarmScreen> {
  final AudioPlayer _testPlayer = AudioPlayer(); // Testplayer für Mix-Popup
  bool _isTesting = false;
  int _hour = 0;
  int _minute = 0;
  DateTime _now = DateTime.now();
  bool _armed = false;
  DateTime? _fireAt;

  // NEU: verhindert Re-Arm/Trigger nach STOP
  bool _userStopped = false;

  // State
  AlarmMix _selectedMix = AlarmMix.standard;

  Future<void> _showMixPicker() async {
    await unlockAudio(); // web: aktiviert AudioContext beim ersten Klick
    // Kein Dialog mehr – wir nehmen die aktuelle Auswahl _selectedMix:
    final asset = assetForAlarmMix(_selectedMix);

    await _testPlayer.stop();
    await CatAlarmPlayer.I.stopAll(); // stoppt alle Alarm-Sounds
    await _testPlayer.setAsset(asset);
    await _testPlayer.setLoopMode(LoopMode.one);
    await _testPlayer.seek(Duration.zero);
    await _testPlayer.play();
    setState(() => _isTesting = true);
  }

  @override
  void initState() {
    super.initState();
    // CatAlarmPlayer Aktivitäts-Tracking initialisieren
    CatAlarmPlayer.I.init();
    // Testplayer-Status tracken
    _testPlayer.playerStateStream.listen((s) {
      final playing = s.playing;
      if (mounted && _isTesting != playing) {
        setState(() => _isTesting = playing);
      }
    });
    // Uhrzeit regelmäßig aktualisieren
    Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) t.cancel();
      setState(() {
        _now = DateTime.now();
      });

      // Wenn Nutzer gestoppt hat, nie wieder automatisch starten
      if (_userStopped) {
        print('Timer: userStopped=true -> keine Aktionen');
        return;
      }

      // Automatischer Alarm-Check
      print('Timer: _armed=$_armed, _fireAt=$_fireAt, _now=$_now');
      if (_armed && _fireAt != null && _now.compareTo(_fireAt!) >= 0) {
        // *** WICHTIG: erst entwaffnen, dann triggern ***
        final fireAt = _fireAt;
        setState(() {
          _armed = false;
          _fireAt = null;
        });
        print('ALARM ausgelöst! fireAt=$fireAt');
        _trigger(); // async, nutzt Latch im Player
      }
    });
  }

  @override
  void dispose() {
    CatAlarmPlayer.I.disposeAll(); // gibt Ressourcen frei
    _testPlayer.dispose();
    super.dispose();
  }

  void _armFromHands() {
    unlockAudio(); // web: aktiviert AudioContext beim ersten Klick (fire-and-forget)
    setState(() {
      _userStopped = false;
      final now = DateTime.now();
      var fire = DateTime(now.year, now.month, now.day, _hour, _minute);
      if (!fire.isAfter(now)) {
        fire = fire.add(const Duration(
            days: 1)); // wenn Zeit heute schon vorbei ist → morgen
      }
      _fireAt = fire;
      _armed = true;
    });
  }

  Future<void> _triggerAlarm() async {
    final latch = CatAlarmPlayer.I.stopLatch;
    final asset = assetForAlarmMix(_selectedMix); // soft/standard/power Pfad
    if (CatAlarmPlayer.I.isObsolete(latch)) return;
    await CatAlarmPlayer.I.playAlarmAsset(asset, loop: true);
  }

  void _trigger() {
    _triggerAlarm();
  }

  void _handleStop() async {
    debugPrint('Stopp-Button wurde getappt');
    try {
      await CatAlarmPlayer.I.stopAll(); // stoppt ALLES (Meer, Alarm, Test)
    } catch (e) {
      debugPrint('Fehler beim Stoppen: $e');
    }

    try {
      AlarmCore.I.onUserStop(); // entwaffnet den Scheduler
    } catch (e) {
      debugPrint('Fehler beim Entwaffnen: $e');
    }

    try {
      await _testPlayer.stop(); // Testplayer stoppen
      await _testPlayer.setLoopMode(LoopMode.off);
    } catch (_) {}

    setState(() {
      _armed = false;
      _fireAt = null;
      _isTesting = false;
      _userStopped = true; // blockt weitere Timer-Aktionen
    });

    print('Alle Player gestoppt & entwaffnet');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, c) {
          return SizedBox.expand(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Wakelock-Manager: hält Bildschirm an während Alarm/Test/Armed
                WakelockManager(active: _armed || _isTesting),
                const Positioned.fill(child: Starfield()),
                const PwaInstallButton(),
                Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: ClockView(
                              hour: _hour,
                              minute: _minute,
                              now: _now,
                              onTimeChanged: (h, m) {
                                setState(() {
                                  _hour = h;
                                  _minute = m;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                      padding: const EdgeInsets.only(
                          left: 16, right: 16, bottom: 24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: SizedBox(
                          height: 300,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: ValueListenableBuilder<bool>(
                                  valueListenable: CatAlarmPlayer.I.isActive,
                                  builder: (context, playerActive, _) {
                                    final bool stopActive =
                                        playerActive || _isTesting || _armed;
                                    return ControlPanel(
                                      hourText: formatHour12(_hour, _minute),
                                      ampmText: amPm(_hour),
                                      armed: stopActive,
                                      onToggleAmPm: () => setState(() {
                                        _hour = _hour < 12
                                            ? (_hour + 12) % 24
                                            : (_hour - 12) % 24;
                                      }),
                                      onArm: _armFromHands,
                                      onStop: _handleStop,
                                      onTest: _showMixPicker,
                                      isTesting: _isTesting,
                                      // NEU: Chips + Dateipfad IM Panel rendern
                                      topContent: MixSelector(
                                        selected: _selectedMix,
                                        onChanged: (mix) =>
                                            setState(() => _selectedMix = mix),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
