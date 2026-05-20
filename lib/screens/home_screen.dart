import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../utils/asset_resolver.dart';
import '../utils/layout.dart';
import '../utils/time_formatters.dart';
import '../utils/web_audio_unlock.dart';
import '../widgets/pwa_install_button.dart';
import '../widgets/clock_view.dart';
import '../widgets/mix_selector.dart';
import '../widgets/wakelock_manager.dart';
import '../starfield.dart';
import '../audio/cat_alarm_player.dart';
import '../audio/sleep_mixer.dart';
import '../core/alarm_core.dart';
import '../services/alarm_notifications.dart';
import '../l10n/app_localizations.dart';
import 'sleep_screen.dart';

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

  // Night-mode (Battery-Saver) während Armed:
  // wird nach [_nightModeDelay] ab _armedSince automatisch true,
  // beim Stop/Snooze/Trigger zurückgesetzt.
  static const Duration _nightModeDelay = Duration(minutes: 10);
  DateTime? _armedSince;
  bool _nightMode = false;

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
    // Sleep-Mixer-Player einmal vorbereiten (LoopMode etc.). Idempotent.
    SleepMixer.I.init();
    // iOS-only: prepare local-notification scheduler so the alarm can fire
    // while the screen is locked or the app is in the background.
    AlarmNotifications.I.init();
    // Testplayer-Status tracken
    _testPlayer.playerStateStream.listen((s) {
      final playing = s.playing;
      if (mounted && _isTesting != playing) {
        setState(() => _isTesting = playing);
      }
    });
    // Uhrzeit regelmäßig aktualisieren — Sekunden-genau für Trigger-Präzision,
    // aber UI-Rebuilds nur dann, wenn die Anzeige sie braucht (Battery-Saver
    // im Night-Mode: rebuild nur bei Minutenwechsel).
    Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) t.cancel();
      final now = DateTime.now();

      // Hinweis: kein Early-Return auf _userStopped — sonst friert die
      // Setup-Uhrzeit nach Stop ein. Auto-Trigger und Night-Mode sind
      // bereits durch _armed=false (in _handleStop) blockiert.

      // Automatischer Alarm-Check
      if (_armed && _fireAt != null && !_userStopped && now.compareTo(_fireAt!) >= 0) {
        final fireAt = _fireAt;
        setState(() {
          _armed = false;
          _fireAt = null;
          _now = now;
          _nightMode = false;
          _armedSince = null;
        });
        print('ALARM ausgelöst! fireAt=$fireAt');
        _trigger(); // async, nutzt Latch im Player
        return;
      }

      // 10-Minuten-Schwelle → Night-Mode aktivieren
      if (_armed &&
          _armedSince != null &&
          !_nightMode &&
          now.difference(_armedSince!) >= _nightModeDelay) {
        setState(() {
          _now = now;
          _nightMode = true;
        });
        return;
      }

      // Regulärer Tick: rebuild abhängig vom Mode
      if (_nightMode) {
        // Night-Mode: nur bei Minutenwechsel rebuilden (Battery)
        if (now.minute != _now.minute) {
          setState(() => _now = now);
        } else {
          _now = now; // intern weiterführen, kein Rebuild
        }
      } else {
        // Normal: jede Sekunde rebuilden (Setup-Mini-Uhr braucht das)
        setState(() => _now = now);
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
    final now = DateTime.now();
    var fire = DateTime(now.year, now.month, now.day, _hour, _minute);
    if (!fire.isAfter(now)) {
      fire = fire
          .add(const Duration(days: 1)); // wenn Zeit heute schon vorbei ist → morgen
    }
    setState(() {
      _userStopped = false;
      _fireAt = fire;
      _armed = true;
      _armedSince = now;
      _nightMode = false;
    });
    _scheduleIosAlarmNotification(fire);
  }

  // Vom Night-Mode-Screen aufgerufen: User tippt → zurück zum Armed-View.
  // Die 10-Minuten-Countdown läuft ab jetzt neu.
  void _exitNightMode() {
    if (!_nightMode) return;
    setState(() {
      _nightMode = false;
      _armedSince = DateTime.now();
    });
  }

  Future<void> _scheduleIosAlarmNotification(DateTime fireAt) async {
    try {
      await AlarmNotifications.I.requestPermissions();
      final l10n = AppLocalizations.of(context);
      final title = l10n?.appTitle ?? 'Cat Alarm';
      final body = l10n?.wakeUpTitle ?? 'Wake up!';
      await AlarmNotifications.I
          .schedule(fireAt: fireAt, title: title, body: body);
    } catch (e) {
      debugPrint('iOS alarm notification scheduling failed: $e');
    }
  }

  Future<void> _triggerAlarm() async {
    final latch = CatAlarmPlayer.I.stopLatch;
    final asset = assetForAlarmMix(_selectedMix); // soft/standard/power Pfad
    if (CatAlarmPlayer.I.isObsolete(latch)) return;
    // Falls der Einschlafmodus läuft, sanft ausblenden, damit der Wecker
    // klar hörbar ist. Bestehender Alarm-Pfad bleibt unverändert.
    SleepMixer.I.stopForAlarm();
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
    // Sleep-Mixer ebenfalls beenden — verhindert, dass Klänge nach dem
    // bewussten Stop weiterspielen. Manueller Stop = sofort, kein Fade.
    try {
      await SleepMixer.I.stopNow();
    } catch (_) {}

    try {
      AlarmCore.I.onUserStop(); // entwaffnet den Scheduler
    } catch (e) {
      debugPrint('Fehler beim Entwaffnen: $e');
    }

    // iOS-only: cancel any pending local notification so it cannot fire later.
    AlarmNotifications.I.cancel();

    try {
      await _testPlayer.stop(); // Testplayer stoppen
      await _testPlayer.setLoopMode(LoopMode.off);
    } catch (_) {}

    setState(() {
      _armed = false;
      _fireAt = null;
      _isTesting = false;
      _userStopped = true; // blockt weitere Timer-Aktionen
      _nightMode = false;
      _armedSince = null;
    });

    print('Alle Player gestoppt & entwaffnet');
  }

  // Snooze: stoppt nur den aktuellen Klingelton und legt einen neuen
  // Weckzeitpunkt in 5 Minuten an. Nutzt ausschließlich bestehende
  // Primitives (stopAll, _scheduleIosAlarmNotification, der vorhandene
  // 1-Sekunden-Timer im initState löst dann erneut aus).
  void _handleSnooze() async {
    debugPrint('Snooze getappt');
    try {
      await CatAlarmPlayer.I.stopAll();
    } catch (e) {
      debugPrint('Snooze stop error: $e');
    }
    try {
      await _testPlayer.stop();
      await _testPlayer.setLoopMode(LoopMode.off);
    } catch (_) {}
    // iOS: alte Notification löschen, neue wird gleich darunter geplant.
    await AlarmNotifications.I.cancel();

    final fire = DateTime.now().add(const Duration(minutes: 5));
    setState(() {
      _userStopped = false;
      _fireAt = fire;
      _armed = true;
      _isTesting = false;
      _armedSince = DateTime.now();
      _nightMode = false;
    });
    _scheduleIosAlarmNotification(fire);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Wakelock muss auch während des Klingelns aktiv bleiben,
          // sonst schläft das Display und Android suspendiert das Audio.
          ValueListenableBuilder<bool>(
            valueListenable: CatAlarmPlayer.I.isActive,
            builder: (context, ringing, _) {
              final tablet = isTablet(context);

              // iPhone-Pfad bleibt unverändert: sofort auf Nacht-Helligkeit.
              // iPad-Pfad: erst nach einigen Minuten dimmen und insgesamt
              // weniger stark abdunkeln, damit der Armed-Screen tagsüber
              // gut lesbar bleibt. Während des Klingelns wird der Screen
              // bewusst hell gehalten.
              double dim;
              Duration? autoDimAfter;
              if (ringing) {
                dim = tablet ? 0.85 : 0.06;
                autoDimAfter = null;
              } else if (_nightMode) {
                dim = tablet ? 0.04 : 0.02;
                autoDimAfter = null;
              } else if (tablet) {
                dim = 0.35;
                autoDimAfter = const Duration(minutes: 4);
              } else {
                dim = 0.06;
                autoDimAfter = null;
              }

              return WakelockManager(
                active: _armed || _isTesting || ringing,
                dimLevel: dim,
                autoDimAfter: autoDimAfter,
              );
            },
          ),
          // Starfield (Animation) im Night-Mode deaktivieren → Battery-Saver
          if (!_nightMode) const Positioned.fill(child: Starfield()),
          const PwaInstallButton(),
          ValueListenableBuilder<bool>(
            valueListenable: CatAlarmPlayer.I.isActive,
            builder: (context, playerActive, _) {
              if (playerActive && !_armed) {
                return _AlarmRingingScreen(
                  onStop: _handleStop,
                  onSnooze: _handleSnooze,
                  hour: _hour,
                  minute: _minute,
                  now: _now,
                );
              }
              if (_armed) {
                if (_nightMode) {
                  return _NightModeScreen(
                    hour: _hour,
                    minute: _minute,
                    now: _now,
                    onTap: _exitNightMode,
                  );
                }
                return _ArmedScreen(
                  hour: _hour,
                  minute: _minute,
                  now: _now,
                  fireAt: _fireAt,
                  onStop: _handleStop,
                );
              }
              // Normaler Einstell-Screen — cozy night style
              final showStop = playerActive || _isTesting;
              return _HomeSetupView(
                hour: _hour,
                minute: _minute,
                now: _now,
                selectedMix: _selectedMix,
                onTimeChanged: (h, m) =>
                    setState(() { _hour = h; _minute = m; }),
                onToggleAmPm: () => setState(() {
                  _hour = _hour < 12
                      ? (_hour + 12) % 24
                      : (_hour - 12) % 24;
                }),
                onMixChanged: (mix) => setState(() => _selectedMix = mix),
                onArm: _armFromHands,
                onStop: _handleStop,
                onPreview: _showMixPicker,
                isTesting: _isTesting,
                showStop: showStop,
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Alarm-klingelt-Screen (cozy sunrise layout) ────────────────────────────
class _AlarmRingingScreen extends StatelessWidget {
  const _AlarmRingingScreen({
    required this.onStop,
    required this.onSnooze,
    required this.hour,
    required this.minute,
    required this.now,
  });

  final VoidCallback onStop;
  final VoidCallback onSnooze;
  final int hour;
  final int minute;
  final DateTime now;

  static const Color _warmGold = Color(0xFFE8C28A);
  static const Color _warmAmber = Color(0xFFE8A65A);

  String get _alarmTime =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    // Phone-Querformat: eigene Zwei-Zonen-Komposition.
    if (isPhoneLandscape(context)) {
      return _PhoneLandscapeRingingLayout(
        onStop: onStop,
        onSnooze: onSnooze,
        hour: hour,
        minute: minute,
        now: now,
      );
    }
    // iPad-Querformat: großzügige Smart-Display-Komposition.
    if (isTabletLandscape(context)) {
      return _TabletLandscapeRingingLayout(
        onStop: onStop,
        onSnooze: onSnooze,
        hour: hour,
        minute: minute,
        now: now,
      );
    }
    // iPad-Hochformat: eigene cinematische Komposition. iPhone-Pfad unverändert.
    if (isTabletPortrait(context)) {
      return _TabletPortraitRingingLayout(
        onStop: onStop,
        onSnooze: onSnooze,
        hour: hour,
        minute: minute,
        now: now,
      );
    }
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1) Sunrise photo, anchored bottom, top-fading to transparent
        Positioned.fill(
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (Rect bounds) {
              return const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0x00FFFFFF),
                  Color(0x66FFFFFF),
                  Color(0xFFFFFFFF),
                  Color(0xFFFFFFFF),
                ],
                stops: <double>[0.0, 0.18, 0.36, 1.0],
              ).createShader(bounds);
            },
            child: Image.asset(
              'assets/images/goodmorningcat.png',
              fit: BoxFit.cover,
              alignment: Alignment.bottomCenter,
            ),
          ),
        ),
        // 2) Warm sunrise glow wash at top for headline legibility
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF1B1638).withAlpha(150),
                    const Color(0xFF1B1638).withAlpha(0),
                  ],
                  stops: const [0.0, 0.45],
                ),
              ),
            ),
          ),
        ),
        // 3) Content
        SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _CurrentClockReadout(now: now),
                ),
              ),
              const SizedBox(height: 2),
              MaxContentBox(
                child: _RingingHeader(
                  greeting: l10n.goodMorning,
                  subtitle: l10n.wokeYou,
                  alarmTime: _alarmTime,
                  timeToWake: l10n.timeToWake,
                ),
              ),
              const Spacer(),
              MaxContentBox(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: _IAmAwakeButton(
                    label: l10n.iAmAwake,
                    onTap: onStop,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              MaxContentBox(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: _SnoozeButton(
                    label: l10n.snooze5,
                    onTap: onSnooze,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              MaxContentBox(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    '❤  ${l10n.morningTagline}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withAlpha(150),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ],
    );
  }
}

class _RingingHeader extends StatelessWidget {
  const _RingingHeader({
    required this.greeting,
    required this.subtitle,
    required this.alarmTime,
    required this.timeToWake,
    this.timeFontSize = 64,
    this.textScale = 1.0,
  });

  final String greeting;
  final String subtitle;
  final String alarmTime;
  final String timeToWake;

  /// Größe der großen Weckzeit. Default = iPhone (64).
  final double timeFontSize;

  /// Skaliert die Begleit-Schriften und Icon/Vertical-Spacings. Default 1.0
  /// → iPhone unverändert. iPad-Pfad ruft mit höherem Wert auf.
  final double textScale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
      child: Column(
        children: [
          Icon(Icons.wb_sunny_rounded,
              color: _AlarmRingingScreen._warmGold.withAlpha(220),
              size: 22 * textScale),
          SizedBox(height: 6 * textScale),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: greeting),
              const TextSpan(text: '  ☀️'),
            ]),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22 * textScale,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              height: 1.1,
            ),
          ),
          SizedBox(height: 4 * textScale),
          Text(
            '$subtitle 🐾',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withAlpha(205),
              fontSize: 13 * textScale,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.2,
              height: 1.3,
            ),
          ),
          SizedBox(height: 12 * textScale),
          Text(
            alarmTime,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: timeFontSize,
              fontWeight: FontWeight.w300,
              letterSpacing: 4,
              height: 1.0,
              shadows: [
                Shadow(
                  color: _AlarmRingingScreen._warmAmber.withAlpha(170),
                  blurRadius: 26,
                ),
                Shadow(
                  color: _AlarmRingingScreen._warmAmber.withAlpha(90),
                  blurRadius: 44,
                ),
              ],
            ),
          ),
          SizedBox(height: 6 * textScale),
          Text(
            '$timeToWake ❤',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withAlpha(195),
              fontSize: 13 * textScale,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _IAmAwakeButton extends StatelessWidget {
  const _IAmAwakeButton({
    required this.label,
    required this.onTap,
    this.height = 60,
    this.glowBlur = 32,
    this.glowAlpha = 150,
    this.iconSize = 22,
    this.labelFontSize = 17,
  });
  final String label;
  final VoidCallback onTap;
  final double height;
  final double glowBlur;
  final int glowAlpha;
  final double iconSize;
  final double labelFontSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(
            colors: [Color(0xFFFCE0AC), Color(0xFFE9B270)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE9B270).withAlpha(glowAlpha),
              blurRadius: glowBlur,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(32),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pets_rounded,
                      color: const Color(0xFF3B2412), size: iconSize),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: TextStyle(
                      color: const Color(0xFF3B2412),
                      fontWeight: FontWeight.w800,
                      fontSize: labelFontSize,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SnoozeButton extends StatelessWidget {
  const _SnoozeButton({
    required this.label,
    required this.onTap,
    this.height = 50,
    this.iconSize = 18,
    this.labelFontSize = 14,
  });
  final String label;
  final VoidCallback onTap;
  final double height;
  final double iconSize;
  final double labelFontSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Material(
        color: const Color(0xFF1F1B36).withAlpha(180),
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                  color: Colors.white.withAlpha(30), width: 1),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.nightlight_round,
                      color: _AlarmRingingScreen._warmGold.withAlpha(210),
                      size: iconSize),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withAlpha(220),
                      fontWeight: FontWeight.w600,
                      fontSize: labelFontSize,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Armed-Screen (cozy night layout) ───────────────────────────────────────
class _ArmedScreen extends StatelessWidget {
  const _ArmedScreen({
    required this.hour,
    required this.minute,
    required this.now,
    required this.fireAt,
    required this.onStop,
  });

  final int hour;
  final int minute;
  final DateTime now;
  final DateTime? fireAt;
  final VoidCallback onStop;

  static const Color _warmGold = Color(0xFFE8C28A);
  static const Color _warmAmber = Color(0xFFE8A65A);

  String get _alarmTimeText =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  String get _nowTimeText =>
      '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}:'
      '${now.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    // Phone-Querformat: eigene Sleep-Ambient-Komposition.
    if (isPhoneLandscape(context)) {
      return _PhoneLandscapeArmedLayout(
        hour: hour,
        minute: minute,
        now: now,
        fireAt: fireAt,
        onStop: onStop,
      );
    }
    // iPad-Hochformat: eigene cinematische Komposition. iPhone-Pfad unverändert.
    if (isTabletPortrait(context)) {
      return _TabletPortraitArmedLayout(
        hour: hour,
        minute: minute,
        now: now,
        fireAt: fireAt,
        onStop: onStop,
      );
    }
    // iPad-Querformat: cinematic Two-Zone Smart-Display (Premium-Stil
    // analog zum Wake-Screen). iPhone-Landscape-Pfad bleibt unverändert.
    if (isTabletLandscape(context)) {
      return _TabletLandscapeArmedLayout(
        hour: hour,
        minute: minute,
        now: now,
        fireAt: fireAt,
        onStop: onStop,
      );
    }
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1) Immersive cat photo, anchored to bottom, top-fading to transparent
        Positioned.fill(
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (Rect bounds) {
              return const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0x00FFFFFF),
                  Color(0x66FFFFFF),
                  Color(0xFFFFFFFF),
                  Color(0xFFFFFFFF),
                ],
                stops: <double>[0.0, 0.22, 0.42, 1.0],
              ).createShader(bounds);
            },
            child: Image.asset(
              armedBackgroundAsset(context),
              fit: BoxFit.cover,
              alignment: Alignment.bottomCenter,
            ),
          ),
        ),
        // 2) Soft dark wash on top for legibility of the headline
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0E0B22).withAlpha(180),
                    const Color(0xFF0E0B22).withAlpha(0),
                  ],
                  stops: const [0.0, 0.45],
                ),
              ),
            ),
          ),
        ),
        // 3) Content
        SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 8),
              MaxContentBox(
                child: _ArmedHeader(
                  greeting: l10n.armedGreeting,
                  subtitle: l10n.armedSubtitle,
                  nowLabel: l10n.nowLabel,
                  nowTimeText: _nowTimeText,
                  alarmLabel: l10n.alarmAt,
                  alarmTimeText: _alarmTimeText,
                  remainingText: _buildRemainingText(l10n),
                ),
              ),
              const Spacer(),
              MaxContentBox(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: _CozyStopButton(
                    label: l10n.stopButton,
                    onTap: onStop,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const _BottomNavStrip(),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ],
    );
  }

  String? _buildRemainingText(AppLocalizations l10n) {
    final fire = fireAt;
    if (fire == null) return null;
    final diff = fire.difference(now);
    if (diff.isNegative) return null;
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    if (h <= 0 && m <= 0) {
      return l10n.wakesInSoonFull;
    }
    final duration = h <= 0 ? '${m}m' : '${h}h ${m}m';
    return '${l10n.wakesInLabel} $duration';
  }
}

class _ArmedHeader extends StatelessWidget {
  const _ArmedHeader({
    required this.greeting,
    required this.subtitle,
    required this.nowLabel,
    required this.nowTimeText,
    required this.alarmLabel,
    required this.alarmTimeText,
    required this.remainingText,
    this.timeFontSize = 60,
    this.textScale = 1.0,
  });

  final String greeting;
  final String subtitle;
  final String nowLabel;
  final String nowTimeText;
  final String alarmLabel;
  final String alarmTimeText;
  final String? remainingText;
  final double timeFontSize;

  /// Skaliert alle Begleit-Schriften (Greeting, Subtitle, Now, "Wecker um",
  /// Restzeit). Default 1.0 → iPhone-Größen unverändert. iPad-Pfad ruft
  /// mit höherem Wert auf, damit der Zeit-Block bewusst Premium wirkt.
  final double textScale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
      child: Column(
        children: [
          Icon(Icons.nightlight_round,
              color: _ArmedScreen._warmGold, size: 22 * textScale),
          SizedBox(height: 6 * textScale),
          Text(
            greeting,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _ArmedScreen._warmGold,
              fontSize: 15 * textScale,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: 4 * textScale),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withAlpha(170),
              fontSize: 13 * textScale,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.2,
              height: 1.3,
            ),
          ),
          SizedBox(height: 12 * textScale),
          // "Jetzt 23:14" – aktuelle Uhrzeit, subtil
          Text(
            '$nowLabel $nowTimeText',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _ArmedScreen._warmGold.withAlpha(160),
              fontSize: 12 * textScale,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.0,
            ),
          ),
          SizedBox(height: 14 * textScale),
          // Kleines Label über der großen Weckzeit
          Text(
            alarmLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withAlpha(170),
              fontSize: 11 * textScale,
              fontWeight: FontWeight.w500,
              letterSpacing: 2.0,
            ),
          ),
          SizedBox(height: 4 * textScale),
          // Große Weckzeit mit warmem Glow
          Text(
            alarmTimeText,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: timeFontSize,
              fontWeight: FontWeight.w300,
              letterSpacing: 4,
              height: 1.0,
              shadows: [
                Shadow(
                  color: _ArmedScreen._warmAmber.withAlpha(140),
                  blurRadius: 24,
                ),
                Shadow(
                  color: _ArmedScreen._warmAmber.withAlpha(70),
                  blurRadius: 40,
                ),
              ],
            ),
          ),
          if (remainingText != null) ...[
            SizedBox(height: 10 * textScale),
            Text(
              remainingText!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withAlpha(195),
                fontSize: 13 * textScale,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.3,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CozyStopButton extends StatelessWidget {
  const _CozyStopButton({
    required this.label,
    required this.onTap,
    this.height = 58,
    this.glowBlur = 26,
    this.glowAlpha = 120,
  });
  final String label;
  final VoidCallback onTap;
  final double height;
  final double glowBlur;
  final int glowAlpha;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            colors: [Color(0xFFF4D8B0), Color(0xFFE6B47A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE6B47A).withAlpha(glowAlpha),
              blurRadius: glowBlur,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(30),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stop_circle_outlined,
                      color: Color(0xFF3B2412), size: 22),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF3B2412),
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Setup-View (cozy night layout) ─────────────────────────────────────────
class _HomeSetupView extends StatelessWidget {
  const _HomeSetupView({
    required this.hour,
    required this.minute,
    required this.now,
    required this.selectedMix,
    required this.onTimeChanged,
    required this.onToggleAmPm,
    required this.onMixChanged,
    required this.onArm,
    required this.onStop,
    required this.onPreview,
    required this.isTesting,
    required this.showStop,
  });

  final int hour;
  final int minute;
  final DateTime now;
  final AlarmMix selectedMix;
  final void Function(int hour, int minute) onTimeChanged;
  final VoidCallback onToggleAmPm;
  final ValueChanged<AlarmMix> onMixChanged;
  final VoidCallback onArm;
  final VoidCallback onStop;
  final VoidCallback onPreview;
  final bool isTesting;
  final bool showStop;

  static const Color _warmAmber = Color(0xFFE8A65A);
  static const Color _warmGold = Color(0xFFE8C28A);

  @override
  Widget build(BuildContext context) {
    // Phone-Querformat: eigenes kompaktes Zwei-Spalten-Layout.
    if (isPhoneLandscape(context)) {
      return _PhoneLandscapeSetupLayout(
        hour: hour,
        minute: minute,
        now: now,
        selectedMix: selectedMix,
        onTimeChanged: onTimeChanged,
        onToggleAmPm: onToggleAmPm,
        onMixChanged: onMixChanged,
        onArm: onArm,
        onStop: onStop,
        onPreview: onPreview,
        isTesting: isTesting,
        showStop: showStop,
      );
    }
    // iPad-Querformat: cinematic Two-Zone Smart-Display.
    if (isTabletLandscape(context)) {
      return _TabletLandscapeSetupLayout(
        hour: hour,
        minute: minute,
        now: now,
        selectedMix: selectedMix,
        onTimeChanged: onTimeChanged,
        onToggleAmPm: onToggleAmPm,
        onMixChanged: onMixChanged,
        onArm: onArm,
        onStop: onStop,
        onPreview: onPreview,
        isTesting: isTesting,
        showStop: showStop,
      );
    }
    // iPad-Hochformat: eigenes Layout. iPhone-Pfad darunter bleibt unverändert.
    if (isTabletPortrait(context)) {
      return _TabletPortraitSetupLayout(
        hour: hour,
        minute: minute,
        now: now,
        selectedMix: selectedMix,
        onTimeChanged: onTimeChanged,
        onToggleAmPm: onToggleAmPm,
        onMixChanged: onMixChanged,
        onArm: onArm,
        onStop: onStop,
        onPreview: onPreview,
        isTesting: isTesting,
        showStop: showStop,
      );
    }
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 20),
            child: Align(
              alignment: Alignment.centerRight,
              child: _CurrentClockReadout(now: now),
            ),
          ),
          _Header(question: l10n.homeQuestion),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: ClockView(
                    hour: hour,
                    minute: minute,
                    now: now,
                    onTimeChanged: onTimeChanged,
                  ),
                ),
              ),
            ),
          ),
          MaxContentBox(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TimeReadout(text: formatHour12(hour, minute)),
                  const SizedBox(width: 10),
                  _AmPmPill(
                      label: hour < 12 ? l10n.am : l10n.pm,
                      onTap: onToggleAmPm),
                  const SizedBox(width: 10),
                  _IconChip(
                    icon: isTesting
                        ? Icons.stop_rounded
                        : Icons.play_arrow_rounded,
                    onTap: onPreview,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          MaxContentBox(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                l10n.intensityTitle,
                style: TextStyle(
                  color: Colors.white.withAlpha(200),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          MaxContentBox(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: MixSelector(
                selected: selectedMix,
                onChanged: onMixChanged,
              ),
            ),
          ),
          const SizedBox(height: 18),
          MaxContentBox(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: showStop
                  ? _StopButton(onTap: onStop)
                  : _PrimaryCta(
                      label: l10n.setAlarmButton,
                      onTap: onArm,
                    ),
            ),
          ),
          const SizedBox(height: 14),
          const _BottomNavStrip(),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.question});
  final String question;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              question,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                height: 1.25,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeReadout extends StatelessWidget {
  const _TimeReadout({
    required this.text,
    this.fontSize = 22,
    this.glow = false,
  });
  final String text;

  /// Optionale Größe (Default 22 = Phone-Hochformat).
  final double fontSize;

  /// Warmer Amber-Glow hinter dem Text (Default false = kein Glow).
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: _HomeSetupView._warmGold,
        fontSize: fontSize,
        fontWeight: FontWeight.w400,
        letterSpacing: 2.5,
        height: 1.0,
        shadows: glow
            ? [
                Shadow(
                  color: const Color(0xFFE8A65A).withAlpha(120),
                  blurRadius: 18,
                ),
              ]
            : null,
      ),
    );
  }
}

// Kleine, dezente HH:mm:ss-Anzeige der aktuellen Systemzeit.
// Wird auf allen relevanten Screens verwendet. Updated automatisch jede
// Sekunde, weil `now` von `_CatAlarmScreenState._now` (1-Sek-Timer)
// durchgereicht wird – keine eigenen Timer pro Widget.
class _CurrentClockReadout extends StatelessWidget {
  const _CurrentClockReadout({
    required this.now,
    this.fontSize = 12,
  });
  final DateTime now;
  final double fontSize;

  String get _formatted =>
      '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}:'
      '${now.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatted,
      style: TextStyle(
        color: _HomeSetupView._warmGold.withAlpha(160),
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.2,
        height: 1.0,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

class _AmPmPill extends StatelessWidget {
  const _AmPmPill({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Material(
        color: const Color(0xFF1F1B36).withAlpha(180),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: _HomeSetupView._warmGold.withAlpha(70), width: 1),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: _HomeSetupView._warmGold,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: Material(
        color: const Color(0xFF1F1B36).withAlpha(180),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: _HomeSetupView._warmGold.withAlpha(70), width: 1),
            ),
            child: Center(
              child: Icon(icon,
                  color: _HomeSetupView._warmGold, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryCta extends StatelessWidget {
  const _PrimaryCta({
    required this.label,
    required this.onTap,
    this.height = 58,
    this.glowBlur = 24,
    this.glowAlpha = 110,
  });
  final String label;
  final VoidCallback onTap;
  final double height;
  final double glowBlur;
  final int glowAlpha;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            colors: [Color(0xFFF2B872), Color(0xFFE08A3C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE08A3C).withAlpha(glowAlpha),
              blurRadius: glowBlur,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(30),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.pets_rounded,
                      color: Color(0xFF3B2412), size: 22),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF3B2412),
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StopButton extends StatelessWidget {
  const _StopButton({required this.onTap, this.height = 58});
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Text(
          AppLocalizations.of(context)!.stopButton,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _BottomNavStrip extends StatelessWidget {
  const _BottomNavStrip({this.compact = false, this.activeIndex = 0});

  /// Flacher Modus für sehr enge Layouts (Phone-Landscape). Default false →
  /// Phone-Hochformat / iPad-Hochformat sind pixel-identisch zu vorher.
  final bool compact;

  /// 0 = Wecker, 1 = Klänge.
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: compact ? 80 : 60),
      padding: EdgeInsets.symmetric(vertical: compact ? 4 : 10),
      decoration: BoxDecoration(
        color: const Color(0xFF14102B).withAlpha(160),
        borderRadius: BorderRadius.circular(compact ? 16 : 22),
        border: Border.all(color: Colors.white.withAlpha(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _NavItem(
            icon: Icons.alarm_rounded,
            label: l10n.navAlarm,
            active: activeIndex == 0,
            compact: compact,
            onTap: () {
              if (activeIndex != 0) Navigator.of(context).maybePop();
            },
          ),
          _NavItem(
            icon: Icons.music_note_rounded,
            label: l10n.navSounds,
            active: activeIndex == 1,
            compact: compact,
            onTap: () {
              if (activeIndex == 1) return;
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SleepScreen(
                    bottomNavBuilder: (ctx) =>
                        const _BottomNavStrip(activeIndex: 1),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    this.compact = false,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final bool active;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? _HomeSetupView._warmAmber
        : Colors.white.withAlpha(110);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 16,
          vertical: compact ? 4 : 6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: color,
                size: compact ? 16 : 22,
                shadows: active
                    ? [
                        Shadow(
                          color: _HomeSetupView._warmAmber.withAlpha(140),
                          blurRadius: compact ? 6 : 10,
                        ),
                      ]
                    : null),
            SizedBox(height: compact ? 1 : 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: compact ? 9 : 11,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Night-Mode-Screen (ultra-dark, minimal, no animations) ─────────────────
// Wird nach 10 Minuten Armed-Zustand automatisch aktiv. Komplett statisch:
// kein Bild, kein Gradient, kein ShaderMask, kein InkWell, keine Animation.
// Tap-anywhere reaktiviert den normalen Armed-View und startet den
// 10-Minuten-Countdown neu.
class _NightModeScreen extends StatelessWidget {
  const _NightModeScreen({
    required this.hour,
    required this.minute,
    required this.now,
    required this.onTap,
  });

  final int hour;
  final int minute;
  final DateTime now;
  final VoidCallback onTap;

  static const Color _nightBg = Color(0xFF050308);
  static const Color _nightInk = Color(0xFFE8C28A);

  String get _alarmTime =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  String get _nowTime =>
      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ColoredBox(
        color: _nightBg,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _nowTime,
                  style: TextStyle(
                    color: _nightInk.withAlpha(70),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 2.0,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _alarmTime,
                  style: TextStyle(
                    color: _nightInk.withAlpha(140),
                    fontSize: 44,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 4,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.nightTapToWake,
                  style: TextStyle(
                    color: _nightInk.withAlpha(45),
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── iPad-Hochformat-Setup-Layout ───────────────────────────────────────────
// Separate Komposition NUR für isTabletPortrait. Wiederverwendet bestehende
// Sub-Widgets (_Header, _AmPmPill, _IconChip, MixSelector, _PrimaryCta,
// _StopButton, _BottomNavStrip, ClockView). Keine funktionalen Änderungen.
class _TabletPortraitSetupLayout extends StatelessWidget {
  const _TabletPortraitSetupLayout({
    required this.hour,
    required this.minute,
    required this.now,
    required this.selectedMix,
    required this.onTimeChanged,
    required this.onToggleAmPm,
    required this.onMixChanged,
    required this.onArm,
    required this.onStop,
    required this.onPreview,
    required this.isTesting,
    required this.showStop,
  });

  final int hour;
  final int minute;
  final DateTime now;
  final AlarmMix selectedMix;
  final void Function(int hour, int minute) onTimeChanged;
  final VoidCallback onToggleAmPm;
  final ValueChanged<AlarmMix> onMixChanged;
  final VoidCallback onArm;
  final VoidCallback onStop;
  final VoidCallback onPreview;
  final bool isTesting;
  final bool showStop;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1) Hero cat photo – full-screen, anchored slightly left/down
        Positioned.fill(
          child: Image.asset(
            'assets/images/catipad.png',
            fit: BoxFit.cover,
            alignment: const Alignment(-0.25, 0.15),
          ),
        ),
        // 2) Vertical cinematic fade: dark top + clear middle + dark bottom
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0E0B22).withAlpha(220),
                    const Color(0xFF0E0B22).withAlpha(0),
                    const Color(0xFF0E0B22).withAlpha(0),
                    const Color(0xFF0E0B22).withAlpha(235),
                  ],
                  stops: const [0.0, 0.14, 0.45, 1.0],
                ),
              ),
            ),
          ),
        ),
        // 3) Soft right-side wash so the floating clock has contrast
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    const Color(0xFF0E0B22).withAlpha(150),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
        ),
        // 4) Content
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: _CurrentClockReadout(now: now, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: _Header(question: l10n.homeQuestion),
                  ),
                ),
                // Floating clock dial – weiter rechts, leicht höher
                Expanded(
                  child: Row(
                    children: [
                      const Spacer(flex: 7),
                      Expanded(
                        flex: 5,
                        child: Align(
                          alignment: const Alignment(0, -0.25),
                          child: _FloatingClock(
                            hour: hour,
                            minute: minute,
                            now: now,
                            onTimeChanged: onTimeChanged,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
                // Bottom controls – centered, max-width contained
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _AmPmPill(
                                label: hour < 12 ? l10n.am : l10n.pm,
                                onTap: onToggleAmPm),
                            const SizedBox(width: 12),
                            _IconChip(
                              icon: isTesting
                                  ? Icons.stop_rounded
                                  : Icons.play_arrow_rounded,
                              onTap: onPreview,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          l10n.intensityTitle,
                          style: TextStyle(
                            color: Colors.white.withAlpha(200),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        MixSelector(
                          selected: selectedMix,
                          onChanged: onMixChanged,
                        ),
                        const SizedBox(height: 16),
                        showStop
                            ? _StopButton(onTap: onStop, height: 76)
                            : _PrimaryCta(
                                label: l10n.setAlarmButton,
                                onTap: onArm,
                                height: 76,
                                glowBlur: 40,
                                glowAlpha: 180,
                              ),
                        const SizedBox(height: 20),
                        const _BottomNavStrip(),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Magisches Premium-Overlay: digitales Readout + transparente analoge
// Uhr (ohne Zifferblatt-Katze, mit kleinerer Mini-Uhr, leichter
// Opacity-Schleier). Drag-Logik unverändert in ClockView.
class _FloatingClock extends StatelessWidget {
  const _FloatingClock({
    required this.hour,
    required this.minute,
    required this.now,
    required this.onTimeChanged,
  });

  final int hour;
  final int minute;
  final DateTime now;
  final void Function(int hour, int minute) onTimeChanged;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.82,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            formatHour12(hour, minute),
            style: TextStyle(
              color: Colors.white.withAlpha(235),
              fontSize: 42,
              fontWeight: FontWeight.w300,
              letterSpacing: 4,
              height: 1.0,
              shadows: [
                Shadow(
                  color: const Color(0xFFE8A65A).withAlpha(130),
                  blurRadius: 26,
                ),
                Shadow(
                  color: const Color(0xFFE8A65A).withAlpha(70),
                  blurRadius: 46,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AspectRatio(
            aspectRatio: 1,
            child: ClockView(
              hour: hour,
              minute: minute,
              now: now,
              onTimeChanged: onTimeChanged,
              showCatImage: false,
              miniClockScale: 0.55,
            ),
          ),
        ],
      ),
    );
  }
}

// ── iPad-Hochformat-Armed-Layout (cinematic sleeping cat) ──────────────────
// Wiederverwendet _ArmedHeader, _CozyStopButton und _BottomNavStrip,
// aber mit einer eigenen Hero-Background-Komposition: catwait.png als
// fullscreen Background mit weichem Top-Fade, zentrierter Premium-Header,
// größerer warmer Stop-CTA. Keine funktionalen Änderungen.
class _TabletPortraitArmedLayout extends StatelessWidget {
  const _TabletPortraitArmedLayout({
    required this.hour,
    required this.minute,
    required this.now,
    required this.fireAt,
    required this.onStop,
  });

  final int hour;
  final int minute;
  final DateTime now;
  final DateTime? fireAt;
  final VoidCallback onStop;

  String get _alarmTimeText =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  String get _nowTimeText =>
      '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}:'
      '${now.second.toString().padLeft(2, '0')}';

  String? _buildRemainingText(AppLocalizations l10n) {
    final fire = fireAt;
    if (fire == null) return null;
    final diff = fire.difference(now);
    if (diff.isNegative) return null;
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    if (h <= 0 && m <= 0) {
      return l10n.wakesInSoonFull;
    }
    final duration = h <= 0 ? '${m}m' : '${h}h ${m}m';
    return '${l10n.wakesInLabel} $duration';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1) Hero sleeping cat photo. Auf iPad-Hochformat sitzt das Bild
        // nicht mehr bottom-anchored (zeigte sonst nur Decke), sondern leicht
        // nach oben gezogen → Katze und Kissen werden zum Hauptmotiv.
        Positioned.fill(
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (Rect bounds) {
              return const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0x00FFFFFF),
                  Color(0x66FFFFFF),
                  Color(0xFFFFFFFF),
                  Color(0xFFFFFFFF),
                ],
                stops: <double>[0.0, 0.16, 0.38, 1.0],
              ).createShader(bounds);
            },
            child: Image.asset(
              armedBackgroundAsset(context),
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.25),
            ),
          ),
        ),
        // 2) Dezenter dunkler Wash oben – sanfter als auf dem iPhone, damit
        // die Katze nicht zu sehr verschwindet.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0E0B22).withAlpha(140),
                    const Color(0xFF0E0B22).withAlpha(0),
                  ],
                  stops: const [0.0, 0.42],
                ),
              ),
            ),
          ),
        ),
        // 3) Content
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const SizedBox(height: 56),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: _ArmedHeader(
                      greeting: l10n.armedGreeting,
                      subtitle: l10n.armedSubtitle,
                      nowLabel: l10n.nowLabel,
                      nowTimeText: _nowTimeText,
                      alarmLabel: l10n.alarmAt,
                      alarmTimeText: _alarmTimeText,
                      remainingText: _buildRemainingText(l10n),
                      timeFontSize: 84,
                      textScale: 1.45,
                    ),
                  ),
                ),
                const Spacer(),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CozyStopButton(
                          label: l10n.stopButton,
                          onTap: onStop,
                          height: 80,
                          glowBlur: 40,
                          glowAlpha: 170,
                        ),
                        const SizedBox(height: 22),
                        const _BottomNavStrip(),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── iPad-Hochformat-Ringing-Layout (cinematic sunrise) ─────────────────────
// Eigene Komposition für isTabletPortrait. Wiederverwendet _RingingHeader,
// _IAmAwakeButton, _SnoozeButton mit größeren Schrift-/Button-Werten.
// Keine funktionalen Änderungen (onStop, onSnooze sind identisch).
class _TabletPortraitRingingLayout extends StatelessWidget {
  const _TabletPortraitRingingLayout({
    required this.onStop,
    required this.onSnooze,
    required this.hour,
    required this.minute,
    required this.now,
  });

  final VoidCallback onStop;
  final VoidCallback onSnooze;
  final int hour;
  final int minute;
  final DateTime now;

  String get _alarmTime =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1) Hero sunrise cat photo, leicht über die Mitte gezogen – Gesicht
        // bleibt sichtbar, riesige Deckenfläche unten reduziert.
        Positioned.fill(
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (Rect bounds) {
              return const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0x00FFFFFF),
                  Color(0x55FFFFFF),
                  Color(0xFFFFFFFF),
                  Color(0xFFFFFFFF),
                ],
                stops: <double>[0.0, 0.14, 0.34, 1.0],
              ).createShader(bounds);
            },
            child: Image.asset(
              'assets/images/goodmorningcat.png',
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.15),
            ),
          ),
        ),
        // 2) Etwas stärkerer Top-Wash als auf dem iPhone für klare Lesbarkeit
        // unterhalb der iPad-StatusBar – aber bewusst noch transparent.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF1B1638).withAlpha(190),
                    const Color(0xFF1B1638).withAlpha(0),
                  ],
                  stops: const [0.0, 0.4],
                ),
              ),
            ),
          ),
        ),
        // 3) Content
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: _CurrentClockReadout(now: now, fontSize: 13),
                ),
                // Header bewusst weit unten unter der StatusBar – kollidiert
                // damit nicht mehr mit iOS-Notification-Bannern.
                const SizedBox(height: 32),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: _RingingHeader(
                      greeting: l10n.goodMorning,
                      subtitle: l10n.wokeYou,
                      alarmTime: _alarmTime,
                      timeToWake: l10n.timeToWake,
                      timeFontSize: 92,
                      textScale: 1.45,
                    ),
                  ),
                ),
                const Spacer(),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _IAmAwakeButton(
                          label: l10n.iAmAwake,
                          onTap: onStop,
                          height: 82,
                          glowBlur: 42,
                          glowAlpha: 180,
                          iconSize: 26,
                          labelFontSize: 20,
                        ),
                        const SizedBox(height: 14),
                        _SnoozeButton(
                          label: l10n.snooze5,
                          onTap: onSnooze,
                          height: 64,
                          iconSize: 22,
                          labelFontSize: 16,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '❤  ${l10n.morningTagline}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withAlpha(170),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Phone-Querformat-Setup-Layout ──────────────────────────────────────────
// Eigene kompakte Zwei-Spalten-Komposition NUR für isPhoneLandscape.
// Links: catipad als Hero-Bild. Rechts: Titel, kleine Uhr, AM/PM-Reihe,
// kompakte Intensitätskarten, flacher CTA, flacher Bottom-Nav-Strip.
// Wiederverwendet bestehende Widgets mit kompakteren Parametern. Keine
// funktionalen Änderungen.
class _PhoneLandscapeSetupLayout extends StatelessWidget {
  const _PhoneLandscapeSetupLayout({
    required this.hour,
    required this.minute,
    required this.now,
    required this.selectedMix,
    required this.onTimeChanged,
    required this.onToggleAmPm,
    required this.onMixChanged,
    required this.onArm,
    required this.onStop,
    required this.onPreview,
    required this.isTesting,
    required this.showStop,
  });

  final int hour;
  final int minute;
  final DateTime now;
  final AlarmMix selectedMix;
  final void Function(int hour, int minute) onTimeChanged;
  final VoidCallback onToggleAmPm;
  final ValueChanged<AlarmMix> onMixChanged;
  final VoidCallback onArm;
  final VoidCallback onStop;
  final VoidCallback onPreview;
  final bool isTesting;
  final bool showStop;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1) Cinematic fullscreen background. Bild deckt die ganze Szene
        // (Katze + Wecker + Sonnenuntergang) — kein zusätzliches Cat-Bild
        // links nötig.
        Positioned.fill(
          child: Image.asset(
            'assets/images/querformatscreen.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
        // 2) Sanfter dunkler Wash am unteren Bildrand für die Lesbarkeit
        // der Controls. Oben bleibt der Sonnenuntergang klar.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    const Color(0xFF0E0B22).withAlpha(180),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
        ),
        // 3) Content
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: _CurrentClockReadout(now: now),
                ),
                // Top section: Uhr nach rechts angeordnet, AM/PM +
                // Preview-Chip darunter. Links bleibt offen, damit die
                // Katze aus dem Background sichtbar bleibt.
                Expanded(
                  child: Row(
                    children: [
                      const Spacer(flex: 2),
                      Expanded(
                        flex: 4,
                        child: Column(
                          children: [
                            Expanded(
                              child: Center(
                                child: AspectRatio(
                                  aspectRatio: 1,
                                  child: ClockView(
                                    hour: hour,
                                    minute: minute,
                                    now: now,
                                    onTimeChanged: onTimeChanged,
                                    showCatImage: false,
                                    miniClockScale: 0.55,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _TimeReadout(
                                  text: formatHour12(hour, minute),
                                  fontSize: 26,
                                  glow: true,
                                ),
                                const SizedBox(width: 10),
                                _AmPmPill(
                                    label: hour < 12 ? l10n.am : l10n.pm,
                                    onTap: onToggleAmPm),
                                const SizedBox(width: 10),
                                _IconChip(
                                  icon: isTesting
                                      ? Icons.stop_rounded
                                      : Icons.play_arrow_rounded,
                                  onTap: onPreview,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // Bottom-Controls – kompakt mittig, max-width für edle Optik
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MixSelector(
                          selected: selectedMix,
                          onChanged: onMixChanged,
                          compact: true,
                        ),
                        const SizedBox(height: 6),
                        showStop
                            ? _StopButton(onTap: onStop, height: 44)
                            : _PrimaryCta(
                                label: l10n.setAlarmButton,
                                onTap: onArm,
                                height: 44,
                                glowBlur: 22,
                                glowAlpha: 130,
                              ),
                        const SizedBox(height: 4),
                        const _BottomNavStrip(compact: true),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Phone-Querformat-Armed-Layout (Sleep Ambient Display) ──────────────────
// Eigene Komposition für isPhoneLandscape. Wiederverwendet _ArmedHeader,
// _CozyStopButton und _BottomNavStrip mit landscape-passenden Werten.
// Keine funktionalen Änderungen.
class _PhoneLandscapeArmedLayout extends StatelessWidget {
  const _PhoneLandscapeArmedLayout({
    required this.hour,
    required this.minute,
    required this.now,
    required this.fireAt,
    required this.onStop,
  });

  final int hour;
  final int minute;
  final DateTime now;
  final DateTime? fireAt;
  final VoidCallback onStop;

  String get _alarmTimeText =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  String get _nowTimeText =>
      '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}:'
      '${now.second.toString().padLeft(2, '0')}';

  String? _buildRemainingText(AppLocalizations l10n) {
    final fire = fireAt;
    if (fire == null) return null;
    final diff = fire.difference(now);
    if (diff.isNegative) return null;
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    if (h <= 0 && m <= 0) {
      return l10n.wakesInSoonFull;
    }
    final duration = h <= 0 ? '${m}m' : '${h}h ${m}m';
    return '${l10n.wakesInLabel} $duration';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1) Cinematic fullscreen Landscape-Background. Das Bild trägt die
        // ganze Szene: Katze links, Sternenhimmel mit Mond rechts – exakt
        // die Zwei-Zonen-Komposition, ohne harte Card-Grenze.
        Positioned.fill(
          child: Image.asset(
            'assets/images/querformatarmedscreen.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
        // 2) Sanfter Right-Wash: linke Hälfte transparent (Katze klar),
        // rechte Hälfte dezent dunkler für die Lesbarkeit des Text-Blocks.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    const Color(0xFF0E0B22).withAlpha(155),
                  ],
                  stops: const [0.0, 0.42, 1.0],
                ),
              ),
            ),
          ),
        ),
        // 3) Dezenter Bottom-Wash für den flachen Bottom-Nav-Strip.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    const Color(0xFF0E0B22).withAlpha(110),
                  ],
                  stops: const [0.0, 0.65, 1.0],
                ),
              ),
            ),
          ),
        ),
        // 4) Content – Row mit linker Cat-Zone (leer) und rechter UI-Zone.
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 22, 6),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      // LINKS: Cat-Zone bleibt frei → Katze aus dem Bild bleibt
                      // ungestört sichtbar.
                      const Spacer(flex: 5),
                      // RECHTS: ruhiger UI-Block, vertikal zentriert.
                      Expanded(
                        flex: 5,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _ArmedHeader(
                                  greeting: l10n.armedGreeting,
                                  subtitle: l10n.armedSubtitle,
                                  nowLabel: l10n.nowLabel,
                                  nowTimeText: _nowTimeText,
                                  alarmLabel: l10n.alarmAt,
                                  alarmTimeText: _alarmTimeText,
                                  remainingText: _buildRemainingText(l10n),
                                  timeFontSize: 62,
                                  textScale: 0.9,
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: 260,
                                  child: _CozyStopButton(
                                    label: l10n.stopButton,
                                    onTap: onStop,
                                    height: 46,
                                    glowBlur: 22,
                                    glowAlpha: 120,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const _BottomNavStrip(compact: true),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── iPad-Querformat-Armed-Layout (cinematic two-zone smart display) ───────
// Eigene Premium-Komposition NUR für isTabletLandscape. Wiederverwendet
// _ArmedHeader, _CozyStopButton und _BottomNavStrip mit landscape-passenden
// Parametern; keine Alarm-/Timer-/Audio-/Notification-Logik geändert.
class _TabletLandscapeArmedLayout extends StatelessWidget {
  const _TabletLandscapeArmedLayout({
    required this.hour,
    required this.minute,
    required this.now,
    required this.fireAt,
    required this.onStop,
  });

  final int hour;
  final int minute;
  final DateTime now;
  final DateTime? fireAt;
  final VoidCallback onStop;

  String get _alarmTimeText =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  String get _nowTimeText =>
      '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}:'
      '${now.second.toString().padLeft(2, '0')}';

  String? _buildRemainingText(AppLocalizations l10n) {
    final fire = fireAt;
    if (fire == null) return null;
    final diff = fire.difference(now);
    if (diff.isNegative) return null;
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    if (h <= 0 && m <= 0) {
      return l10n.wakesInSoonFull;
    }
    final duration = h <= 0 ? '${m}m' : '${h}h ${m}m';
    return '${l10n.wakesInLabel} $duration';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1) Cinematic fullscreen Landscape-Background. Das Bild trägt die
        // ganze Szene: Katze links, Mond/Sternenhimmel rechts.
        Positioned.fill(
          child: Image.asset(
            'assets/images/querformatarmedscreen.png',
            fit: BoxFit.cover,
            alignment: const Alignment(-0.4, 0),
          ),
        ),
        // 2) Sanfter Right-Wash: linke Hälfte frei für die Katze,
        // rechte Hälfte dezent dunkler für die Lesbarkeit.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF0E0B22).withAlpha(40),
                    const Color(0xFF0E0B22).withAlpha(185),
                  ],
                  stops: const [0.0, 0.34, 1.0],
                ),
              ),
            ),
          ),
        ),
        // 3) Dezenter Bottom-Wash für den flachen Bottom-Nav-Strip.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    const Color(0xFF0E0B22).withAlpha(120),
                  ],
                  stops: const [0.0, 0.72, 1.0],
                ),
              ),
            ),
          ),
        ),
        // 4) Content – Row mit freier Cat-Zone links (~55%) und kompaktem
        // UI-Block rechts (~45%). Premium-Skalierung analog Wake-Screen.
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 40, 20),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Spacer(flex: 6),
                      Expanded(
                        flex: 5,
                        child: Align(
                          alignment: const Alignment(0, -0.05),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 540),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _ArmedHeader(
                                  greeting: l10n.armedGreeting,
                                  subtitle: l10n.armedSubtitle,
                                  nowLabel: l10n.nowLabel,
                                  nowTimeText: _nowTimeText,
                                  alarmLabel: l10n.alarmAt,
                                  alarmTimeText: _alarmTimeText,
                                  remainingText: _buildRemainingText(l10n),
                                  timeFontSize: 96,
                                  textScale: 1.25,
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: 360,
                                  child: _CozyStopButton(
                                    label: l10n.stopButton,
                                    onTap: onStop,
                                    height: 60,
                                    glowBlur: 32,
                                    glowAlpha: 150,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const _BottomNavStrip(compact: true),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Phone-Querformat-Ringing-Layout (cinematic sunrise two-zone) ───────────
// Eigene Komposition für isPhoneLandscape. Linke Bildhälfte zeigt die
// erwachende Katze (aus dem Background), rechte Hälfte ist UI-Zone mit
// Greeting + Time + Buttons. Keine funktionalen Änderungen.
class _PhoneLandscapeRingingLayout extends StatelessWidget {
  const _PhoneLandscapeRingingLayout({
    required this.onStop,
    required this.onSnooze,
    required this.hour,
    required this.minute,
    required this.now,
  });

  final VoidCallback onStop;
  final VoidCallback onSnooze;
  final int hour;
  final int minute;
  final DateTime now;

  String get _alarmTime =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1) Cinematic Landscape Wakeup-Background (wakeupquer.png).
        // Katze + Pfote + Sonnenuntergang links, dunkler Bereich rechts.
        Positioned.fill(
          child: Image.asset(
            'assets/images/wakeupquer.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
        // 2) Right-Wash: linke Hälfte transparent (Katze klar), rechte
        // Hälfte sanft dunkler für die Lesbarkeit des Text-Blocks.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    const Color(0xFF1B1638).withAlpha(170),
                  ],
                  stops: const [0.0, 0.42, 1.0],
                ),
              ),
            ),
          ),
        ),
        // 3) Dezenter Bottom-Wash für die Tagline / den Bottom-Bereich.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    const Color(0xFF1B1638).withAlpha(110),
                  ],
                  stops: const [0.0, 0.65, 1.0],
                ),
              ),
            ),
          ),
        ),
        // 4) Content – Row mit linker Cat-Zone (frei) und rechter UI-Zone.
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 22, 8),
            child: Row(
              children: [
                const Spacer(flex: 5),
                Expanded(
                  flex: 5,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _CurrentClockReadout(now: now),
                          const SizedBox(height: 4),
                          _RingingHeader(
                            greeting: l10n.goodMorning,
                            subtitle: l10n.wokeYou,
                            alarmTime: _alarmTime,
                            timeToWake: l10n.timeToWake,
                            timeFontSize: 78,
                            textScale: 0.92,
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: 280,
                            child: _IAmAwakeButton(
                              label: l10n.iAmAwake,
                              onTap: onStop,
                              height: 48,
                              glowBlur: 24,
                              glowAlpha: 140,
                              iconSize: 20,
                              labelFontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 280,
                            child: _SnoozeButton(
                              label: l10n.snooze5,
                              onTap: onSnooze,
                              height: 42,
                              iconSize: 16,
                              labelFontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '❤  ${l10n.morningTagline}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withAlpha(170),
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── iPad-Querformat-Ringing-Layout (Smart Display Two-Zone) ────────────────
// Eigene großzügige Komposition für isTabletLandscape. Selbe Architektur wie
// _PhoneLandscapeRingingLayout (Cat-Zone links, UI-Zone rechts), aber mit
// iPad-Typografie/-Buttons + mehr negative space. Keine funktionalen
// Änderungen.
class _TabletLandscapeRingingLayout extends StatelessWidget {
  const _TabletLandscapeRingingLayout({
    required this.onStop,
    required this.onSnooze,
    required this.hour,
    required this.minute,
    required this.now,
  });

  final VoidCallback onStop;
  final VoidCallback onSnooze;
  final int hour;
  final int minute;
  final DateTime now;

  String get _alarmTime =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1) Cinematic Landscape Wakeup-Background (wakeupquer.png).
        // Katze + Pfote + Sonnenuntergang links, dunkler Bereich rechts –
        // fullscreen, keine Card-Optik.
        Positioned.fill(
          child: Image.asset(
            'assets/images/wakeupquer.png',
            fit: BoxFit.cover,
            alignment: const Alignment(-0.6, 0),
          ),
        ),
        // 2) Right-Wash: weicher Übergang über fast die ganze rechte Hälfte.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF1B1638).withAlpha(40),
                    const Color(0xFF1B1638).withAlpha(185),
                  ],
                  stops: const [0.0, 0.32, 1.0],
                ),
              ),
            ),
          ),
        ),
        // 3) Sehr dezenter Bottom-Wash für die Tagline-Zone unten.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    const Color(0xFF1B1638).withAlpha(110),
                  ],
                  stops: const [0.0, 0.72, 1.0],
                ),
              ),
            ),
          ),
        ),
        // 4) Content – Row mit linker freier Cat-Zone (~55%) und rechter
        // UI-Zone (~45%). Mehr breathing room als auf dem iPhone.
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 40, 20),
            child: Row(
              children: [
                const Spacer(flex: 6),
                Expanded(
                  flex: 5,
                  child: Align(
                    alignment: const Alignment(0, -0.22),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 540),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _CurrentClockReadout(now: now, fontSize: 14),
                          const SizedBox(height: 6),
                          _RingingHeader(
                            greeting: l10n.goodMorning,
                            subtitle: l10n.wokeYou,
                            alarmTime: _alarmTime,
                            timeToWake: l10n.timeToWake,
                            timeFontSize: 108,
                            textScale: 1.35,
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: 420,
                            child: _IAmAwakeButton(
                              label: l10n.iAmAwake,
                              onTap: onStop,
                              height: 68,
                              glowBlur: 38,
                              glowAlpha: 175,
                              iconSize: 26,
                              labelFontSize: 19,
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: 380,
                            child: Opacity(
                              opacity: 0.78,
                              child: _SnoozeButton(
                                label: l10n.snooze5,
                                onTap: onSnooze,
                                height: 56,
                                iconSize: 22,
                                labelFontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            '❤  ${l10n.morningTagline}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withAlpha(170),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── iPad-Querformat-Setup-Layout (Smart Display Two-Zone) ──────────────────
// Eigene cinematische Zwei-Zonen-Komposition für isTabletLandscape.
// Links bleibt frei für die Katze im Background, rechts liegt die
// kompakte UI-Zone. Wiederverwendet bestehende Sub-Widgets mit
// landscape-passenden Parametern. Keine funktionalen Änderungen.
class _TabletLandscapeSetupLayout extends StatelessWidget {
  const _TabletLandscapeSetupLayout({
    required this.hour,
    required this.minute,
    required this.now,
    required this.selectedMix,
    required this.onTimeChanged,
    required this.onToggleAmPm,
    required this.onMixChanged,
    required this.onArm,
    required this.onStop,
    required this.onPreview,
    required this.isTesting,
    required this.showStop,
  });

  final int hour;
  final int minute;
  final DateTime now;
  final AlarmMix selectedMix;
  final void Function(int hour, int minute) onTimeChanged;
  final VoidCallback onToggleAmPm;
  final ValueChanged<AlarmMix> onMixChanged;
  final VoidCallback onArm;
  final VoidCallback onStop;
  final VoidCallback onPreview;
  final bool isTesting;
  final bool showStop;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1) Cinematic Landscape Background.
        Positioned.fill(
          child: Image.asset(
            'assets/images/querformatscreen.png',
            fit: BoxFit.cover,
            alignment: const Alignment(-0.4, 0),
          ),
        ),
        // 2) Right-Wash: weicher Übergang in die UI-Zone rechts.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF0E0B22).withAlpha(45),
                    const Color(0xFF0E0B22).withAlpha(190),
                  ],
                  stops: const [0.0, 0.34, 1.0],
                ),
              ),
            ),
          ),
        ),
        // 3) Dezenter Bottom-Wash für die Bottom-Nav-Zone.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    const Color(0xFF0E0B22).withAlpha(120),
                  ],
                  stops: const [0.0, 0.72, 1.0],
                ),
              ),
            ),
          ),
        ),
        // 4) Content – Row mit Cat-Zone links und kompaktem UI-Block rechts.
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 18, 36, 18),
            child: Row(
              children: [
                const Spacer(flex: 6),
                Expanded(
                  flex: 5,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _CurrentClockReadout(now: now, fontSize: 13),
                          const SizedBox(height: 6),
                          // Kompakter Titel
                          Text(
                            l10n.homeQuestion,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 18),
                          // Elegante schwebende Uhr – nicht dominant
                          SizedBox(
                            height: 325,
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: ClockView(
                                hour: hour,
                                minute: minute,
                                now: now,
                                onTimeChanged: onTimeChanged,
                                showCatImage: false,
                                miniClockScale: 0.55,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Digital + AM/PM + Preview kompakt gruppiert
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _TimeReadout(
                                text: formatHour12(hour, minute),
                                fontSize: 28,
                                glow: true,
                              ),
                              const SizedBox(width: 12),
                              _AmPmPill(
                                  label: hour < 12 ? l10n.am : l10n.pm,
                                  onTap: onToggleAmPm),
                              const SizedBox(width: 12),
                              _IconChip(
                                icon: isTesting
                                    ? Icons.stop_rounded
                                    : Icons.play_arrow_rounded,
                                onTap: onPreview,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            l10n.intensityTitle,
                            style: TextStyle(
                              color: Colors.white.withAlpha(195),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          MixSelector(
                            selected: selectedMix,
                            onChanged: onMixChanged,
                            compact: true,
                          ),
                          const SizedBox(height: 18),
                          // Premium CTA – schmaler als die volle Spalte
                          SizedBox(
                            width: 420,
                            child: showStop
                                ? _StopButton(onTap: onStop, height: 56)
                                : _PrimaryCta(
                                    label: l10n.setAlarmButton,
                                    onTap: onArm,
                                    height: 56,
                                    glowBlur: 32,
                                    glowAlpha: 160,
                                  ),
                          ),
                          const SizedBox(height: 16),
                          const _BottomNavStrip(compact: true),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
