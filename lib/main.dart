import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'widgets/clock_view.dart';
import 'widgets/control_panel.dart';
import 'starfield.dart';
import 'audio/cat_alarm_player.dart';
import 'core/alarm_core.dart';
import 'l10n/app_localizations.dart';

// Auswahl-Enum
enum AlarmMix { soft, standard, power }

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());
  await session.setActive(true);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Title is generated from localized resources so it updates with locale.
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      // Localization wiring: delegates, supported locales and a resolution callback
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const <Locale>[
        Locale('de'),
        Locale('en'),
        Locale('es'),
        Locale('zh', 'CN'),
      ],
      localeResolutionCallback: (Locale? locale, Iterable<Locale> supportedLocales) {
        // If no locale provided, fallback to first supported
        if (locale == null) return supportedLocales.first;

        // Exact match (language + country)
        for (final supported in supportedLocales) {
          if (supported.languageCode == locale.languageCode &&
              (supported.countryCode == locale.countryCode)) {
            return supported;
          }
        }

        // Handle Chinese variants: prefer zh_CN when countryCode is CN
        if (locale.languageCode == 'zh') {
          if (locale.countryCode == 'CN') return const Locale('zh', 'CN');
          return const Locale('zh');
        }

        // Fallback to language-only match
        for (final supported in supportedLocales) {
          if (supported.languageCode == locale.languageCode) return supported;
        }

        // Final fallback
        return supportedLocales.first;
      },
      debugShowCheckedModeBanner: false,
      home: const CatAlarmScreen(),
    );
  }
}

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

  // Helfer: Pfad für aktuellen Mix (plattformabhängig)
  String _assetFor(AlarmMix m) {
    final isApple = Platform.isMacOS || Platform.isIOS;
    switch (m) {
      case AlarmMix.soft:
        return isApple ? 'assets/sounds/soft.m4a' : 'assets/sounds/catalarmsoft.mp3';
      case AlarmMix.standard:
        return isApple ? 'assets/sounds/catalarmstandard1.m4a' : 'assets/sounds/catalarmstandard.mp3';
      case AlarmMix.power:
        return isApple ? 'assets/sounds/catalarmpower1.m4a' : 'assets/sounds/catalarmpower.mp3';
      default:
        // defensive fallback in case enum is extended in the future
        return 'assets/sounds/catalarmstandard.mp3';
    }
  }

  Future<void> _showMixPicker() async {
    // Kein Dialog mehr – wir nehmen die aktuelle Auswahl _selectedMix:
    final asset = _assetFor(_selectedMix);

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
      setState(() { _now = DateTime.now(); });

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

  String _fmt2(int v) => v.toString().padLeft(2, '0');

  void _armFromHands() {
    setState(() {
      _userStopped = false;
      final now = DateTime.now();
      var fire = DateTime(now.year, now.month, now.day, _hour, _minute);
      if (!fire.isAfter(now)) {
        fire = fire.add(const Duration(days: 1)); // wenn Zeit heute schon vorbei ist → morgen
      }
      _fireAt = fire;
      _armed = true;
    });
  }

  Future<void> _triggerAlarm() async {
    final latch = CatAlarmPlayer.I.stopLatch;
    final asset = _assetFor(_selectedMix); // soft/standard/power Pfad
    if (CatAlarmPlayer.I.isObsolete(latch)) return;
    await CatAlarmPlayer.I.playAlarmAsset(asset, loop: true);
  }

  void _trigger() {
    _triggerAlarm();
  }

  void _handleStop() async {
    debugPrint('Stopp-Button wurde getappt');
    try {
      await CatAlarmPlayer.I.stopAll();       // stoppt ALLES (Meer, Alarm, Test)
    } catch (e) {
      debugPrint('Fehler beim Stoppen: $e');
    }

    try {
      AlarmCore.I.onUserStop();               // entwaffnet den Scheduler
    } catch (e) {
      debugPrint('Fehler beim Entwaffnen: $e');
    }

    try {
      await _testPlayer.stop();               // Testplayer stoppen
      await _testPlayer.setLoopMode(LoopMode.off);
    } catch (_) {}

    setState(() {
      _armed = false;
      _fireAt = null;
      _isTesting = false;
      _userStopped = true;                    // blockt weitere Timer-Aktionen
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
                const Positioned.fill(child: Starfield()),
                // Status-Banner oben im Stack
                ValueListenableBuilder<bool>(
                  valueListenable: CatAlarmPlayer.I.isActive,
                  builder: (context, playerActive, _) {
                    final active = playerActive || _isTesting; // NEU
                    if (!active) return const SizedBox.shrink();
                    final loc = AppLocalizations.of(context)!;
                    return Align(
                      alignment: Alignment.topCenter,
                      child: SafeArea(
                        child: Container(
                          margin: const EdgeInsets.all(12),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935).withAlpha((0.95 * 255).round()),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            loc.audioActiveBanner,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    );
                  },
                ),
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
                    Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
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
                                    final bool stopActive = playerActive || _isTesting || _armed;
                                    final loc = AppLocalizations.of(context)!;
                                    return ControlPanel(
                                      hourText: '${_fmt2((_hour % 12 == 0 ? 12 : _hour % 12))}:${_fmt2(_minute)}',
                                      ampmText: _hour < 12 ? 'AM' : 'PM',
                                      nowText: '${loc.currentTimePrefix}${_fmt2(_now.hour)}:${_fmt2(_now.minute)}:${_fmt2(_now.second)}',
                                      armed: stopActive,
                                      onToggleAmPm: () => setState(() {
                                        _hour = _hour < 12 ? (_hour + 12) % 24 : (_hour - 12) % 24;
                                      }),
                                      onArm: _armFromHands,
                                      onStop: _handleStop,
                                      onTest: _showMixPicker,
                                      isTesting: _isTesting,
                                      // NEU: Chips + Dateipfad IM Panel rendern
                                      topContent: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(loc.selectTone, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              ChoiceChip(
                                                label: Text(loc.soft),
                                                selected: _selectedMix == AlarmMix.soft,
                                                onSelected: (_) => setState(() => _selectedMix = AlarmMix.soft),
                                              ),
                                              const SizedBox(width: 8),
                                              ChoiceChip(
                                                label: Text(loc.standard),
                                                selected: _selectedMix == AlarmMix.standard,
                                                onSelected: (_) => setState(() => _selectedMix = AlarmMix.standard),
                                              ),
                                              const SizedBox(width: 8),
                                              ChoiceChip(
                                                label: Text(loc.power),
                                                selected: _selectedMix == AlarmMix.power,
                                                onSelected: (_) => setState(() => _selectedMix = AlarmMix.power),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          // Entfernt: Text zur aktuellen Auswahl und Datei
                                        ],
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
