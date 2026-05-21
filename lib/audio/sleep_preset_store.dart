import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sleep_mixer.dart';

/// Persisted snapshot of a sleep-mode mix. Owns nothing about playback —
/// it's purely a value object that can be applied to [SleepMixer].
@immutable
class SleepPreset {
  const SleepPreset({
    required this.id,
    required this.name,
    required this.enabledChannels,
    required this.volumes,
    required this.selectedMusic,
    required this.selectedTimer,
    required this.mode,
  });

  final String id;
  final String name;
  final Set<SleepChannel> enabledChannels;
  final Map<SleepChannel, double> volumes;
  final MusicTrack selectedMusic;
  final SleepTimerOption selectedTimer;
  final SleepMode mode;

  SleepPreset copyWith({
    String? name,
    Set<SleepChannel>? enabledChannels,
    Map<SleepChannel, double>? volumes,
    MusicTrack? selectedMusic,
    SleepTimerOption? selectedTimer,
    SleepMode? mode,
  }) {
    return SleepPreset(
      id: id,
      name: name ?? this.name,
      enabledChannels: enabledChannels ?? this.enabledChannels,
      volumes: volumes ?? this.volumes,
      selectedMusic: selectedMusic ?? this.selectedMusic,
      selectedTimer: selectedTimer ?? this.selectedTimer,
      mode: mode ?? this.mode,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'enabled': enabledChannels.map((c) => c.name).toList(),
        'volumes': {
          for (final c in SleepChannel.values) c.name: volumes[c] ?? 0.0,
        },
        'music': selectedMusic.name,
        'timer': selectedTimer.name,
        'mode': mode.name,
      };

  static SleepPreset fromJson(Map<String, dynamic> json) {
    final enabled = <SleepChannel>{};
    for (final v in (json['enabled'] as List<dynamic>? ?? const [])) {
      final c = _channelByName(v as String);
      if (c != null) enabled.add(c);
    }
    final volumes = <SleepChannel, double>{};
    final rawVols = (json['volumes'] as Map?)?.cast<String, dynamic>() ?? {};
    for (final c in SleepChannel.values) {
      final raw = rawVols[c.name];
      if (raw is num) volumes[c] = raw.toDouble().clamp(0.0, 1.0).toDouble();
    }
    return SleepPreset(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      enabledChannels: enabled,
      volumes: volumes,
      selectedMusic:
          _musicByName(json['music'] as String?) ?? MusicTrack.softAcoustic,
      selectedTimer:
          _timerByName(json['timer'] as String?) ?? SleepTimerOption.min30,
      mode: _modeByName(json['mode'] as String?) ?? SleepMode.withAlarm,
    );
  }
}

/// SharedPreferences-backed store for [SleepPreset]s. Singleton because the
/// preset bar in the sleep screen and any future entry points should see the
/// same list and the same active selection.
class SleepPresetStore {
  SleepPresetStore._();
  static final SleepPresetStore I = SleepPresetStore._();

  static const String _prefsKey = 'sleep_presets_v1';
  static const String _activeKey = 'sleep_presets_active_v1';

  /// All known presets, in display order. The first three are the default
  /// `set1`/`set2`/`set3` slots that are always present.
  final ValueNotifier<List<SleepPreset>> presets =
      ValueNotifier<List<SleepPreset>>(const []);

  /// Id of the currently loaded preset, or null if the user changed the mix
  /// since the last load/save.
  final ValueNotifier<String?> activeId = ValueNotifier<String?>(null);

  bool _loaded = false;
  bool _applying = false;

  /// True while [apply] is mutating the SleepMixer state. Listeners that
  /// would otherwise clear [activeId] in response to user edits use this to
  /// distinguish "I set this" from "the user changed it".
  bool get applying => _applying;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    List<SleepPreset> list;
    if (raw == null || raw.isEmpty) {
      list = _defaults();
      await _persist(list);
    } else {
      try {
        final decoded = (jsonDecode(raw) as List<dynamic>)
            .map((e) => SleepPreset.fromJson(e as Map<String, dynamic>))
            .toList();
        list = _ensureDefaults(decoded);
      } catch (e) {
        debugPrint('SleepPresetStore.load: decode failed, resetting ($e)');
        list = _defaults();
        await _persist(list);
      }
    }
    presets.value = list;
    activeId.value = prefs.getString(_activeKey);
  }

  /// Persist the current SleepMixer state into the slot with [id]. If the
  /// slot doesn't exist, it's created.
  Future<void> saveCurrent(String id, {String? name}) async {
    final mixer = SleepMixer.I;
    final enabled = <SleepChannel>{
      for (final c in SleepChannel.values)
        if (mixer.enabledNotifier(c).value) c,
    };
    final volumes = <SleepChannel, double>{
      for (final c in SleepChannel.values) c: mixer.volumeNotifier(c).value,
    };
    final list = [...presets.value];
    final idx = list.indexWhere((p) => p.id == id);
    if (idx >= 0) {
      list[idx] = list[idx].copyWith(
        name: name,
        enabledChannels: enabled,
        volumes: volumes,
        selectedMusic: mixer.selectedMusic.value,
        selectedTimer: mixer.selectedTimer.value,
        mode: mixer.selectedMode.value,
      );
    } else {
      list.add(SleepPreset(
        id: id,
        name: name ?? id,
        enabledChannels: enabled,
        volumes: volumes,
        selectedMusic: mixer.selectedMusic.value,
        selectedTimer: mixer.selectedTimer.value,
        mode: mixer.selectedMode.value,
      ));
    }
    presets.value = list;
    activeId.value = id;
    await _persist(list);
    await _persistActive(id);
  }

  /// Append a new empty slot named [name] and return its id.
  Future<String> addSlot({required String name}) async {
    final id = 'set_${DateTime.now().millisecondsSinceEpoch}';
    final mixer = SleepMixer.I;
    final preset = SleepPreset(
      id: id,
      name: name,
      enabledChannels: const <SleepChannel>{},
      volumes: {
        for (final c in SleepChannel.values) c: mixer.volumeNotifier(c).value,
      },
      selectedMusic: mixer.selectedMusic.value,
      selectedTimer: mixer.selectedTimer.value,
      mode: mixer.selectedMode.value,
    );
    final list = [...presets.value, preset];
    presets.value = list;
    await _persist(list);
    return id;
  }

  /// Load [preset] into the [SleepMixer]. If the mixer is currently playing,
  /// it is stopped first (per the preset spec — loading must not auto-start).
  Future<void> apply(SleepPreset preset) async {
    final mixer = SleepMixer.I;
    if (mixer.running.value) {
      await mixer.stopNow();
    }
    _applying = true;
    try {
      for (final c in SleepChannel.values) {
        mixer.enabledNotifier(c).value = preset.enabledChannels.contains(c);
        final v = preset.volumes[c];
        if (v != null) mixer.volumeNotifier(c).value = v;
      }
      mixer.selectedMusic.value = preset.selectedMusic;
      mixer.selectedTimer.value = preset.selectedTimer;
      mixer.selectedMode.value = preset.mode;
    } finally {
      _applying = false;
    }
    activeId.value = preset.id;
    await _persistActive(preset.id);
  }

  /// Mark the active selection as cleared. Called from the UI when the user
  /// edits the mix after loading a preset.
  Future<void> clearActive() async {
    if (activeId.value == null) return;
    activeId.value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeKey);
  }

  Future<void> _persist(List<SleepPreset> list) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(list.map((p) => p.toJson()).toList());
    await prefs.setString(_prefsKey, encoded);
  }

  Future<void> _persistActive(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeKey, id);
  }

  List<SleepPreset> _ensureDefaults(List<SleepPreset> existing) {
    final byId = {for (final p in existing) p.id: p};
    final defaults = _defaults();
    final merged = <SleepPreset>[];
    for (final d in defaults) {
      merged.add(byId[d.id] ?? d);
      byId.remove(d.id);
    }
    // Preserve any user-added slots after the defaults, in their original order.
    for (final p in existing) {
      if (byId.containsKey(p.id)) merged.add(p);
    }
    return merged;
  }

  List<SleepPreset> _defaults() {
    SleepPreset blank(String id, String name) => SleepPreset(
          id: id,
          name: name,
          enabledChannels: const <SleepChannel>{},
          volumes: const {
            SleepChannel.purr: 0.7,
            SleepChannel.rain: 0.55,
            SleepChannel.ocean: 0.6,
            SleepChannel.music: 0.5,
          },
          selectedMusic: MusicTrack.softAcoustic,
          selectedTimer: SleepTimerOption.min30,
          mode: SleepMode.withAlarm,
        );
    return [
      blank('set1', 'Set 1'),
      blank('set2', 'Set 2'),
      blank('set3', 'Set 3'),
    ];
  }
}

SleepChannel? _channelByName(String name) {
  for (final c in SleepChannel.values) {
    if (c.name == name) return c;
  }
  return null;
}

MusicTrack? _musicByName(String? name) {
  if (name == null) return null;
  for (final m in MusicTrack.values) {
    if (m.name == name) return m;
  }
  return null;
}

SleepTimerOption? _timerByName(String? name) {
  if (name == null) return null;
  for (final t in SleepTimerOption.values) {
    if (t.name == name) return t;
  }
  return null;
}

SleepMode? _modeByName(String? name) {
  if (name == null) return null;
  for (final m in SleepMode.values) {
    if (m.name == name) return m;
  }
  return null;
}
