import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as ja;

/// SleepMixer — direkte, robuste Audio-Steuerung ohne Operation-Queue.
///
/// Design-Regeln (nach mehreren Iterationen festgezurrt):
/// - Keine globale Queue. Jede User-Aktion läuft direkt am Player. Nichts
///   kann in einer Wartereihe hängen.
/// - `_epoch` wird **ausschließlich** von `stopNow()` hochgezählt. Lange
///   Operationen (Start-Prep, Fade-In, Auto-Fade-Out) prüfen das Epoch und
///   räumen sich selbst auf, wenn dazwischen gestoppt wurde. Toggles und
///   Slider-Bewegungen ändern das Epoch nicht — sie dürfen einen laufenden
///   Start niemals abbrechen.
/// - `_isStarting` verhindert parallele Start-Aufrufe und signalisiert
///   setEnabled, dass Channels, die _während_ Start aktiviert werden, vom
///   Start-Sweep nachgeladen werden.
/// - Anti-Knack: ~200 ms Fade-In beim Hochfahren, ~150 ms Fade-Out beim
///   Toggle-Off und Music-Track-Wechsel.
/// - Volume-Slider und Toggle laufen ohne `busy`-Marker → Button bleibt frei.
class SleepMixer {
  static final SleepMixer I = SleepMixer._();
  SleepMixer._();

  // ── Player (immer derselbe Instance pro Channel) ──────────────────────────
  final Map<SleepChannel, ja.AudioPlayer> _players = {
    SleepChannel.purr: ja.AudioPlayer(),
    SleepChannel.rain: ja.AudioPlayer(),
    SleepChannel.ocean: ja.AudioPlayer(),
    SleepChannel.music: ja.AudioPlayer(),
  };

  // ── State (Single Source of Truth) ────────────────────────────────────────
  final ValueNotifier<bool> purrEnabled = ValueNotifier(false);
  final ValueNotifier<bool> rainEnabled = ValueNotifier(false);
  final ValueNotifier<bool> oceanEnabled = ValueNotifier(false);
  final ValueNotifier<bool> musicEnabled = ValueNotifier(false);

  final ValueNotifier<double> purrVolume = ValueNotifier(0.7);
  final ValueNotifier<double> rainVolume = ValueNotifier(0.55);
  final ValueNotifier<double> oceanVolume = ValueNotifier(0.6);
  final ValueNotifier<double> musicVolume = ValueNotifier(0.5);

  final ValueNotifier<MusicTrack> selectedMusic =
      ValueNotifier(MusicTrack.softAcoustic);
  final ValueNotifier<SleepTimerOption> selectedTimer =
      ValueNotifier(SleepTimerOption.min30);
  final ValueNotifier<SleepMode> selectedMode =
      ValueNotifier(SleepMode.withAlarm);

  final ValueNotifier<bool> running = ValueNotifier(false);
  final ValueNotifier<bool> busy = ValueNotifier(false);
  final ValueNotifier<Duration> remaining = ValueNotifier(Duration.zero);

  // ── Interna ───────────────────────────────────────────────────────────────
  Timer? _ticker;
  DateTime? _endsAt;
  bool _initialized = false;
  bool _sessionConfigured = false;
  bool _isStarting = false;

  /// Wird nur von `stopNow()` und `_stopAllImpl()` hochgezählt. Lange
  /// Operationen prüfen das Epoch, um stop-during-prep zu erkennen.
  int _epoch = 0;

  // ── Public API ────────────────────────────────────────────────────────────

  bool get anyChannelEnabled =>
      purrEnabled.value ||
      rainEnabled.value ||
      oceanEnabled.value ||
      musicEnabled.value;

  ja.AudioPlayer _playerFor(SleepChannel c) => _players[c]!;

  ValueNotifier<bool> enabledNotifier(SleepChannel c) {
    switch (c) {
      case SleepChannel.purr:
        return purrEnabled;
      case SleepChannel.rain:
        return rainEnabled;
      case SleepChannel.ocean:
        return oceanEnabled;
      case SleepChannel.music:
        return musicEnabled;
    }
  }

  ValueNotifier<double> volumeNotifier(SleepChannel c) {
    switch (c) {
      case SleepChannel.purr:
        return purrVolume;
      case SleepChannel.rain:
        return rainVolume;
      case SleepChannel.ocean:
        return oceanVolume;
      case SleepChannel.music:
        return musicVolume;
    }
  }

  /// Wird einmal beim App-Start gerufen. Beeinflusst `busy` nicht.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    debugPrint('SleepMixer.init: setting LoopMode.one on all players');
    for (final p in _players.values) {
      try {
        await p.setLoopMode(ja.LoopMode.one);
      } catch (_) {}
    }
    debugPrint('SleepMixer.init: done');
  }

  /// Startet den Mixer. Bereitet die initial aktivierten Channels parallel
  /// vor; macht danach einen Sweep, um Channels nachzuladen, die _während_
  /// Start aktiviert wurden. `running` flippt erst, wenn alle Channels
  /// fertig sind.
  Future<void> start() async {
    debugPrint(
        'SleepMixer.start: requested running=${running.value} starting=$_isStarting '
        'any=$anyChannelEnabled '
        'purr=${purrEnabled.value} rain=${rainEnabled.value} '
        'ocean=${oceanEnabled.value} music=${musicEnabled.value}');

    if (running.value || _isStarting) {
      debugPrint('SleepMixer.start: skip (already running/starting)');
      return;
    }
    if (!anyChannelEnabled) {
      debugPrint('SleepMixer.start: skip (no channel enabled)');
      return;
    }

    _isStarting = true;
    busy.value = true;
    final myEpoch = _epoch;

    try {
      await _ensureSession(activate: true);
      if (_epoch != myEpoch) return;

      // 1) Initial-Set parallel vorbereiten
      List<SleepChannel> snapshot() => [
            for (final c in SleepChannel.values)
              if (enabledNotifier(c).value) c
          ];
      final planned = snapshot();
      debugPrint('SleepMixer.start: preparing batch $planned');
      await Future.wait(<Future<void>>[
        for (final c in planned)
          _prepareAndPlayChannel(c, myEpoch, fadeIn: true)
      ]);
      if (_epoch != myEpoch) return;

      // 2) Sweep — falls der User während Start weitere Channels aktiviert
      //    hat, holen wir die jetzt nach. Max. 2 Sweeps reichen praktisch.
      for (int sweep = 0; sweep < 2; sweep++) {
        final current = snapshot();
        final missing =
            current.where((c) => !_players[c]!.playing).toList();
        if (missing.isEmpty) break;
        debugPrint('SleepMixer.start: sweep $sweep, catching $missing');
        await Future.wait(<Future<void>>[
          for (final c in missing)
            _prepareAndPlayChannel(c, myEpoch, fadeIn: true)
        ]);
        if (_epoch != myEpoch) return;
      }

      // 3) Timer
      _ticker?.cancel();
      _endsAt = null;
      remaining.value = Duration.zero;
      final dur = selectedTimer.value.duration;
      if (dur != null) {
        _endsAt = DateTime.now().add(dur);
        remaining.value = dur;
      }
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());

      running.value = true;
      debugPrint('SleepMixer.start: running=true');
    } catch (e, st) {
      debugPrint('SleepMixer.start: error $e\n$st');
    } finally {
      _isStarting = false;
      busy.value = false;
    }
  }

  /// Sofortiger harter Stop. Bewusst direkt, ohne jede Queue.
  Future<void> stopNow() async {
    debugPrint('SleepMixer.stopNow: called');
    _epoch++;
    _ticker?.cancel();
    _ticker = null;
    _endsAt = null;
    running.value = false;
    remaining.value = Duration.zero;
    _isStarting = false; // Sweeps brechen via Epoch-Check ab
    busy.value = true;

    try {
      debugPrint('SleepMixer.stopNow: stopping purr/rain/ocean/music');
      await Future.wait(<Future<void>>[
        for (final c in SleepChannel.values) _hardStopDirect(c),
      ]);
      try {
        final session = await AudioSession.instance;
        await session.setActive(false);
      } catch (e) {
        debugPrint('SleepMixer.stopNow: session deactivate error: $e');
      }
      debugPrint('SleepMixer.stopNow: done');
    } finally {
      busy.value = false;
    }
  }

  /// Toggle für einen Channel. **Kein Epoch-Bump** — toggles dürfen einen
  /// laufenden Start niemals abbrechen.
  Future<void> setEnabled(SleepChannel c, bool enabled) async {
    debugPrint(
        'SleepMixer.setEnabled($c, $enabled) running=${running.value} starting=$_isStarting');
    enabledNotifier(c).value = enabled;

    // Mixer aus → reine State-Vorwahl, sonst nichts.
    if (!running.value && !_isStarting) return;

    if (enabled) {
      if (_isStarting) {
        // Start läuft gerade — der Sweep am Ende von start() holt den
        // Channel auf. Nichts hier tun, damit wir nicht doppelt starten.
        debugPrint(
            'SleepMixer.setEnabled: deferred to start sweep ($c)');
        return;
      }
      await _ensureSession(activate: true);
      final myEpoch = _epoch;
      await _prepareAndPlayChannel(c, myEpoch, fadeIn: true);
      return;
    }

    // Disable: kurzes Fade-Out, dann hart stoppen.
    final myEpoch = _epoch;
    await _fadeChannelTo(c, 0.0, const Duration(milliseconds: 150), myEpoch);
    await _hardStopDirect(c);
    // Volume wieder auf den User-Wert für den nächsten Re-Enable.
    try {
      await _playerFor(c).setVolume(volumeNotifier(c).value);
    } catch (_) {}

    // Wenn der Mixer wirklich läuft (nicht nur Start in Progress) und nichts
    // mehr aktiv ist → kompletter Stop.
    if (running.value && !anyChannelEnabled) {
      debugPrint('SleepMixer.setEnabled: last channel off → stopNow');
      await stopNow();
    }
  }

  /// Lautstärke — sofort.
  Future<void> setVolume(SleepChannel c, double volume) async {
    final v = volume.clamp(0.0, 1.0).toDouble();
    volumeNotifier(c).value = v;
    if (!running.value && !_isStarting) return;
    if (!enabledNotifier(c).value) return;
    try {
      await _playerFor(c).setVolume(v);
    } catch (e) {
      debugPrint('SleepMixer.setVolume($c=$v) error: $e');
    }
  }

  /// Music-Track wechseln.
  Future<void> selectMusic(MusicTrack t) async {
    if (selectedMusic.value == t) return;
    selectedMusic.value = t;
    if (!running.value) return;
    if (!musicEnabled.value) return;
    final myEpoch = _epoch;
    await _fadeChannelTo(
        SleepChannel.music, 0.0, const Duration(milliseconds: 150), myEpoch);
    await _hardStopDirect(SleepChannel.music);
    if (_epoch != myEpoch) return;
    await _prepareAndPlayChannel(SleepChannel.music, myEpoch, fadeIn: true);
  }

  void selectTimer(SleepTimerOption opt) {
    selectedTimer.value = opt;
    if (!running.value) return;
    final dur = opt.duration;
    if (dur != null) {
      _endsAt = DateTime.now().add(dur);
      remaining.value = dur;
    } else {
      _endsAt = null;
      remaining.value = Duration.zero;
    }
  }

  void selectMode(SleepMode m) {
    selectedMode.value = m;
  }

  /// Wird vom Alarm-Trigger gerufen. Kurzer Fade (3 s) → harter Stop.
  Future<void> stopForAlarm() async {
    if (!running.value) return;
    await _fadeOutAndStop(const Duration(seconds: 3));
  }

  // ── Privates ──────────────────────────────────────────────────────────────

  Future<void> _ensureSession({required bool activate}) async {
    try {
      final session = await AudioSession.instance;
      if (!_sessionConfigured) {
        await session.configure(const AudioSessionConfiguration.music());
        _sessionConfigured = true;
      }
      await session.setActive(activate);
    } catch (e) {
      debugPrint(
          'SleepMixer: AudioSession ${activate ? "activate" : "deactivate"} error: $e');
    }
  }

  String _assetFor(SleepChannel c) {
    switch (c) {
      case SleepChannel.purr:
        return 'assets/sounds/sleep_purr.mp3';
      case SleepChannel.rain:
        return 'assets/sounds/sleep_rain.m4a';
      case SleepChannel.ocean:
        return 'assets/sounds/sleep_ocean.m4a';
      case SleepChannel.music:
        return _assetForMusic(selectedMusic.value);
    }
  }

  String _assetForMusic(MusicTrack t) {
    switch (t) {
      case MusicTrack.softAcoustic:
        return 'assets/sounds/music_soft_acoustic.mp3';
      case MusicTrack.verySlow:
        return 'assets/sounds/music_very_slow.mp3';
      case MusicTrack.relaxing:
        return 'assets/sounds/music_relaxing.mp3';
      case MusicTrack.warmSauna:
        return 'assets/sounds/music_warm_sauna.mp3';
    }
  }

  /// Bereitet einen Channel vor und startet ihn. Volume wird direkt auf den
  /// Ziel-Wert gesetzt — kein Fade-In. (Der 200 ms Fade-In hat sich als
  /// fragil erwiesen: setVolume-Calls während setAudioSource-Loading wurden
  /// auf manchen Plattformen verschluckt; Folge: Channel spielte stumm.)
  ///
  /// Volume wird **zweimal** gesetzt — vor und nach setAudioSource — falls
  /// just_audio die Lautstärke beim Quellen-Wechsel verwirft.
  Future<void> _prepareAndPlayChannel(
      SleepChannel c, int myEpoch, {bool fadeIn = false}) async {
    // ignore: avoid_unused_constructor_parameters
    final _ = fadeIn; // beibehalten für Aufrufkompatibilität, aktuell ignoriert
    final p = _playerFor(c);
    final asset = _assetFor(c);
    final target = volumeNotifier(c).value;
    debugPrint(
        'SleepMixer._prepare($c): asset=$asset targetVolume=$target');

    try {
      await p.setLoopMode(ja.LoopMode.off);
    } catch (_) {}
    if (_epoch != myEpoch) return;
    try {
      await p.stop();
    } catch (_) {}
    if (_epoch != myEpoch) return;
    try {
      await p.seek(Duration.zero);
    } catch (_) {}
    if (_epoch != myEpoch) return;

    try {
      await p.setVolume(target);
    } catch (_) {}
    if (_epoch != myEpoch) return;

    try {
      await p.setAudioSource(ja.AudioSource.asset(asset));
    } catch (e) {
      debugPrint('SleepMixer._prepare($c): setAudioSource error $e');
      return;
    }
    if (_epoch != myEpoch) {
      await _hardStopDirect(c);
      return;
    }

    // Volume nach setAudioSource erneut setzen — manche Backends resetten
    // beim Quellen-Wechsel.
    try {
      await p.setVolume(target);
    } catch (_) {}

    try {
      await p.setLoopMode(ja.LoopMode.one);
    } catch (_) {}
    if (_epoch != myEpoch) {
      await _hardStopDirect(c);
      return;
    }

    try {
      // Bewusst NICHT awaiten: just_audio's play() Future resolved erst,
      // wenn die Wiedergabe endet (bei LoopMode.one nie). Wir wollen nur
      // die Wiedergabe starten und sofort weitermachen.
      unawaited(p.play());
    } catch (e) {
      debugPrint('SleepMixer._prepare($c): play error $e');
      return;
    }

    // Volume noch einmal nach play() — manchmal landet das Set-Vor-Play
    // im Limbo, bis der Player tatsächlich aktiv ist.
    try {
      await p.setVolume(target);
    } catch (_) {}

    debugPrint('SleepMixer._prepare($c): playing at $target');
  }

  Future<void> _fadeChannelTo(
      SleepChannel c, double target, Duration over, int myEpoch) async {
    final p = _playerFor(c);
    final startVol = volumeNotifier(c).value;
    const steps = 8;
    final stepMs = (over.inMilliseconds / steps).round().clamp(10, 200);
    for (int i = 1; i <= steps; i++) {
      if (_epoch != myEpoch) return;
      final v = startVol + (target - startVol) * (i / steps);
      try {
        await p.setVolume(v);
      } catch (_) {}
      await Future<void>.delayed(Duration(milliseconds: stepMs));
    }
  }

  Future<void> _hardStopDirect(SleepChannel c) async {
    debugPrint('SleepMixer.hardStop: ${c.name}');
    final p = _playerFor(c);
    try {
      await p.setLoopMode(ja.LoopMode.off);
    } catch (_) {}
    try {
      await p.pause();
    } catch (_) {}
    try {
      await p.stop();
    } catch (_) {}
    try {
      await p.seek(Duration.zero);
    } catch (_) {}
    try {
      await p.setVolume(0);
    } catch (_) {}
  }

  /// Auto-Fade-Out (Timer-Ende, Alarm). Bricht via Epoch ab, wenn manuell
  /// gestoppt wird.
  Future<void> _fadeOutAndStop(Duration over) async {
    final myEpoch = _epoch;
    const steps = 24;
    final stepMs = (over.inMilliseconds / steps).round().clamp(20, 500);
    final startVols = <SleepChannel, double>{
      for (final c in SleepChannel.values) c: volumeNotifier(c).value,
    };
    for (int i = 1; i <= steps; i++) {
      if (_epoch != myEpoch) break;
      final t = 1.0 - i / steps;
      for (final c in SleepChannel.values) {
        if (!enabledNotifier(c).value) continue;
        try {
          await _playerFor(c).setVolume(startVols[c]! * t);
        } catch (_) {}
      }
      await Future<void>.delayed(Duration(milliseconds: stepMs));
    }
    if (_epoch == myEpoch) {
      await stopNow();
    }
  }

  void _onTick() {
    if (_endsAt == null) return;
    final left = _endsAt!.difference(DateTime.now());
    if (left <= Duration.zero) {
      remaining.value = Duration.zero;
      _endsAt = null;
      _fadeOutAndStop(const Duration(seconds: 6));
    } else {
      remaining.value = left;
    }
  }

  Future<void> dispose() async {
    _ticker?.cancel();
    for (final p in _players.values) {
      try {
        await p.dispose();
      } catch (_) {}
    }
  }
}

enum SleepChannel { purr, rain, ocean, music }

enum MusicTrack { softAcoustic, verySlow, relaxing, warmSauna }

enum SleepMode { withAlarm, withoutAlarm }

enum SleepTimerOption { min15, min30, min60, untilStop }

extension SleepTimerOptionX on SleepTimerOption {
  /// null = unbegrenzt („Bis ich stoppe").
  Duration? get duration {
    switch (this) {
      case SleepTimerOption.min15:
        return const Duration(minutes: 15);
      case SleepTimerOption.min30:
        return const Duration(minutes: 30);
      case SleepTimerOption.min60:
        return const Duration(minutes: 60);
      case SleepTimerOption.untilStop:
        return null;
    }
  }
}
