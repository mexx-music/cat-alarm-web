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
import '../l10n/app_localizations.dart';

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
      body: Stack(
        fit: StackFit.expand,
        children: [
          WakelockManager(active: _armed || _isTesting),
          const Positioned.fill(child: Starfield()),
          const PwaInstallButton(),
          ValueListenableBuilder<bool>(
            valueListenable: CatAlarmPlayer.I.isActive,
            builder: (context, playerActive, _) {
              if (playerActive && !_armed) {
                return _AlarmRingingScreen(onStop: _handleStop, hour: _hour, minute: _minute);
              }
              if (_armed) {
                return _ArmedScreen(
                  hour: _hour,
                  minute: _minute,
                  now: _now,
                  onStop: _handleStop,
                );
              }
              // Normaler Einstell-Screen
              return Column(
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
                            onTimeChanged: (h, m) =>
                                setState(() { _hour = h; _minute = m; }),
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
                          child: ControlPanel(
                            hourText: formatHour12(_hour, _minute),
                            ampmText: amPm(_hour),
                            armed: playerActive || _isTesting || _armed,
                            onToggleAmPm: () => setState(() {
                              _hour = _hour < 12
                                  ? (_hour + 12) % 24
                                  : (_hour - 12) % 24;
                            }),
                            onArm: _armFromHands,
                            onStop: _handleStop,
                            onTest: _showMixPicker,
                            isTesting: _isTesting,
                            topContent: MixSelector(
                              selected: _selectedMix,
                              onChanged: (mix) =>
                                  setState(() => _selectedMix = mix),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Alarm-klingelt-Screen ──────────────────────────────────────────────────
class _AlarmRingingScreen extends StatefulWidget {
  const _AlarmRingingScreen({required this.onStop, required this.hour, required this.minute});
  final VoidCallback onStop;
  final int hour;
  final int minute;

  @override
  State<_AlarmRingingScreen> createState() => _AlarmRingingScreenState();
}

class _AlarmRingingScreenState extends State<_AlarmRingingScreen> {
  bool _showFirst = true;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (mounted) setState(() => _showFirst = !_showFirst);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String get _alarmTime =>
      '${widget.hour.toString().padLeft(2, '0')}:${widget.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 260,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Image.asset(
                    _showFirst
                        ? 'assets/images/wakeupcat1.png'
                        : 'assets/images/wakeupcat2.png',
                    key: ValueKey(_showFirst),
                    height: 260,
                    fit: BoxFit.contain,
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: Text(
                    _alarmTime,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFF4500),
                      letterSpacing: 4,
                      shadows: [
                        Shadow(color: Color(0xFFFF4500), blurRadius: 16),
                        Shadow(color: Color(0xFFFF8C00), blurRadius: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            l10n.wakeUpTitle,
            style: const TextStyle(
              fontSize: 26,
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: 220,
            height: 56,
            child: ElevatedButton(
              onPressed: widget.onStop,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: Text(
                l10n.stopButton,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Armed-Screen (Fullscreen) ──────────────────────────────────────────────
class _ArmedScreen extends StatelessWidget {
  const _ArmedScreen({
    required this.hour,
    required this.minute,
    required this.now,
    required this.onStop,
  });

  final int hour;
  final int minute;
  final DateTime now;
  final VoidCallback onStop;

  String get _time24h =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  String get _currentTime =>
      '${now.hour.toString().padLeft(2, '0')}'
      ':${now.minute.toString().padLeft(2, '0')}'
      ':${now.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final imgHeight = (screenH * 0.32).clamp(220.0, 300.0);
    return SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Dezente aktuelle Uhrzeit oben
          Text(
            _currentTime,
            style: const TextStyle(
              fontSize: 15,
              color: Color.fromRGBO(255, 255, 255, 0.65),
              fontWeight: FontWeight.w400,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          // Sleepcat-Bild (ersetzt ClockView im Armed-Zustand)
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/images/sleepcat.png',
              height: imgHeight,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 28),
          const Icon(Icons.nightlight_round,
              size: 48, color: Color(0xFFB0C4DE)),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.alarmArmed,
            style: const TextStyle(
              fontSize: 20,
              color: Colors.white70,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _time24h,
            style: const TextStyle(
              fontSize: 64,
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: 220,
            height: 56,
            child: ElevatedButton(
              onPressed: onStop,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: Text(
                AppLocalizations.of(context)!.stopButton,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
