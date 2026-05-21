import 'package:flutter/material.dart';

import '../audio/sleep_mixer.dart';
import '../audio/sleep_preset_store.dart';
import '../l10n/app_localizations.dart';

/// Premium-Sleep-Screen mit Glass-Cards, warmem Amber-Akzent und sanften
/// Animationen. Stilistisch konsistent zum bestehenden Alarm-Setup-Screen:
/// dunkles Navy/Violett, warmes Gold/Amber, weiche Schatten.
class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key, this.bottomNavBuilder});

  /// Optionaler Builder für die bestehende Bottom-Nav (Klänge aktiv).
  /// So bleibt das Wecker/Klänge-Strip identisch zum Rest der App.
  final WidgetBuilder? bottomNavBuilder;

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  // Palette (1:1 zum Setup-/Armed-Screen)
  static const Color _bg = Color(0xFF0E0B22);
  static const Color _bgTop = Color(0xFF1B1638);
  static const Color _glass = Color(0xFF1F1B36);
  static const Color _amber = Color(0xFFE8A65A);

  // Notifiers we listen to so that any user-driven mix change clears the
  // currently active preset marker. Kept as a list so we can subscribe and
  // unsubscribe uniformly.
  late final List<Listenable> _mixListenables = [
    SleepMixer.I.purrEnabled,
    SleepMixer.I.rainEnabled,
    SleepMixer.I.oceanEnabled,
    SleepMixer.I.musicEnabled,
    SleepMixer.I.purrVolume,
    SleepMixer.I.rainVolume,
    SleepMixer.I.oceanVolume,
    SleepMixer.I.musicVolume,
    SleepMixer.I.selectedMusic,
    SleepMixer.I.selectedTimer,
    SleepMixer.I.selectedMode,
  ];

  @override
  void initState() {
    super.initState();
    for (final l in _mixListenables) {
      l.addListener(_onMixChanged);
    }
  }

  @override
  void dispose() {
    for (final l in _mixListenables) {
      l.removeListener(_onMixChanged);
    }
    super.dispose();
  }

  void _onMixChanged() {
    // Ignore changes that come from loading a preset — those should leave the
    // active marker intact.
    if (SleepPresetStore.I.applying) return;
    SleepPresetStore.I.clearActive();
  }

  @override
  Widget build(BuildContext context) {
    // iPhone-Landscape: kurze Höhe + Breite > Höhe. iPad bleibt mit
    // height >= 500 (auch in Landscape) unverändert.
    final mq = MediaQuery.of(context);
    final isPhoneLandscape = mq.size.height < 500 && mq.size.width > mq.size.height;
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Weicher Verlauf (Nachthimmel-Stimmung)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_bgTop, _bg],
                stops: [0.0, 0.55],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _Header(onBack: () => Navigator.of(context).maybePop()),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                        18, 4, 18, isPhoneLandscape ? 12 : 24),
                    child: isPhoneLandscape
                        ? const _CompactLandscapeBody(
                            amber: _amber, glass: _glass)
                        : const _PortraitBody(
                            amber: _amber, glass: _glass),
                  ),
                ),
                if (widget.bottomNavBuilder != null) ...[
                  SizedBox(height: isPhoneLandscape ? 2 : 8),
                  widget.bottomNavBuilder!(context),
                  SizedBox(height: isPhoneLandscape ? 4 : 10),
                ] else
                  SizedBox(height: isPhoneLandscape ? 4 : 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PortraitBody extends StatelessWidget {
  const _PortraitBody({required this.amber, required this.glass});
  final Color amber;
  final Color glass;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _IntroCard(
          title: l10n.sleepModeTitle,
          subtitle: l10n.sleepModeSubtitle,
          amber: amber,
          glass: glass,
        ),
        const SizedBox(height: 14),
        const _PresetBar(),
        const SizedBox(height: 16),
        const _SoundsGrid(),
        const SizedBox(height: 18),
        _SectionTitle(l10n.sleepTimerTitle),
        const SizedBox(height: 10),
        const _TimerChips(),
        const SizedBox(height: 18),
        _SectionTitle(l10n.sleepStartTitle),
        const SizedBox(height: 10),
        const _ModePicker(),
        const SizedBox(height: 22),
        const _StartButton(),
        const SizedBox(height: 10),
        const _RemainingLine(),
      ],
    );
  }
}

/// iPhone-Landscape: zwei Spalten nebeneinander.
/// Links: Intro (kompakt), Preset-Bar, Sounds-Grid.
/// Rechts: Timer, Modus, Start-Button.
class _CompactLandscapeBody extends StatelessWidget {
  const _CompactLandscapeBody({required this.amber, required this.glass});
  final Color amber;
  final Color glass;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _IntroCard(
                title: l10n.sleepModeTitle,
                subtitle: l10n.sleepModeSubtitle,
                amber: amber,
                glass: glass,
                compact: true,
              ),
              const SizedBox(height: 8),
              const _PresetBar(),
              const SizedBox(height: 10),
              const _SoundsGrid(),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionTitle(l10n.sleepTimerTitle),
              const SizedBox(height: 8),
              const _TimerChips(),
              const SizedBox(height: 12),
              _SectionTitle(l10n.sleepStartTitle),
              const SizedBox(height: 8),
              const _ModePicker(),
              const SizedBox(height: 12),
              const _StartButton(),
              const SizedBox(height: 4),
              const _RemainingLine(),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded,
                color: Colors.white, size: 28),
            onPressed: onBack,
            tooltip: l10n.navAlarm,
          ),
          const Spacer(),
          // „Sleep läuft"-Pille mit eingebautem Stop-Knopf — sichtbar nur
          // während Wiedergabe. Tap auf den Stop-Bereich beendet sofort.
          ValueListenableBuilder<bool>(
            valueListenable: SleepMixer.I.running,
            builder: (_, running, __) {
              if (!running) return const SizedBox.shrink();
              return Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => SleepMixer.I.stopNow(),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F1B36).withAlpha(200),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFFE8A65A).withAlpha(170),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.sleepActive,
                          style: const TextStyle(
                            color: Color(0xFFE8C28A),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Color(0xFFD94A2C),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.stop_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
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

class _IntroCard extends StatelessWidget {
  const _IntroCard({
    required this.title,
    required this.subtitle,
    required this.amber,
    required this.glass,
    this.compact = false,
  });
  final String title;
  final String subtitle;
  final Color amber;
  final Color glass;

  /// Im iPhone-Landscape rendert die Karte in einer Zeile (kein Subtitle,
  /// kleineres Icon, geringere Polsterung), um vertikalen Platz zu sparen.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 32.0 : 44.0;
    return Container(
      padding: compact
          ? const EdgeInsets.fromLTRB(12, 8, 12, 8)
          : const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: glass.withAlpha(190),
        borderRadius: BorderRadius.circular(compact ? 18 : 26),
        border: Border.all(color: Colors.white.withAlpha(18)),
        boxShadow: [
          BoxShadow(
            color: amber.withAlpha(40),
            blurRadius: 30,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [amber.withAlpha(220), const Color(0xFFE8C28A)],
              ),
              borderRadius: BorderRadius.circular(compact ? 10 : 14),
              boxShadow: [
                BoxShadow(
                  color: amber.withAlpha(120),
                  blurRadius: 18,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Icon(Icons.nightlight_round,
                color: const Color(0xFF3B2412), size: compact ? 18 : 24),
          ),
          SizedBox(width: compact ? 10 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 14 : 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!compact) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withAlpha(170),
                      fontSize: 12.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withAlpha(220),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ── Sounds Grid ──────────────────────────────────────────────────────────────

class _SoundsGrid extends StatelessWidget {
  const _SoundsGrid();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(builder: (context, constraints) {
      // 2-Spalten-Grid; auf sehr schmalen Layouts trotzdem 2 Spalten.
      const gap = 12.0;
      final cellWidth = (constraints.maxWidth - gap) / 2;
      Widget cell(Widget child) =>
          SizedBox(width: cellWidth, child: child);
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          cell(_SoundCard(
            channel: SleepChannel.purr,
            label: l10n.sleepSoundPurr,
            icon: Icons.pets_rounded,
          )),
          cell(_SoundCard(
            channel: SleepChannel.rain,
            label: l10n.sleepSoundRain,
            icon: Icons.water_drop_rounded,
          )),
          cell(_SoundCard(
            channel: SleepChannel.ocean,
            label: l10n.sleepSoundOcean,
            icon: Icons.waves_rounded,
          )),
          cell(_MusicCard(label: l10n.sleepSoundMusic)),
        ],
      );
    });
  }
}

class _SoundCard extends StatelessWidget {
  const _SoundCard({
    required this.channel,
    required this.label,
    required this.icon,
  });

  final SleepChannel channel;
  final String label;
  final IconData icon;

  static const Color _amber = Color(0xFFE8A65A);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SleepMixer.I.enabledNotifier(channel),
      builder: (_, enabled, __) {
        return _SoundCardShell(
          enabled: enabled,
          icon: icon,
          label: label,
          onIconTap: () => SleepMixer.I.setEnabled(channel, !enabled),
          trailing: _ToggleSwitch(
            value: enabled,
            onChanged: (v) => SleepMixer.I.setEnabled(channel, v),
          ),
          slider: ValueListenableBuilder<double>(
            valueListenable: SleepMixer.I.volumeNotifier(channel),
            builder: (_, vol, __) {
              return _VolumeRow(
                value: vol,
                onChanged: enabled
                    ? (v) => SleepMixer.I.setVolume(channel, v)
                    : null,
                color: enabled ? _amber : Colors.white.withAlpha(60),
              );
            },
          ),
        );
      },
    );
  }
}

class _MusicCard extends StatelessWidget {
  const _MusicCard({required this.label});
  final String label;
  static const Color _amber = Color(0xFFE8A65A);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SleepMixer.I.musicEnabled,
      builder: (_, enabled, __) {
        return _SoundCardShell(
          enabled: enabled,
          icon: Icons.music_note_rounded,
          label: label,
          onIconTap: () => _openPicker(context),
          trailing: _ToggleSwitch(
            value: enabled,
            onChanged: (v) =>
                SleepMixer.I.setEnabled(SleepChannel.music, v),
          ),
          slider: ValueListenableBuilder<double>(
            valueListenable: SleepMixer.I.musicVolume,
            builder: (_, vol, __) {
              return _VolumeRow(
                value: vol,
                onChanged: enabled
                    ? (v) => SleepMixer.I.setVolume(SleepChannel.music, v)
                    : null,
                color: enabled ? _amber : Colors.white.withAlpha(60),
              );
            },
          ),
          extra: ValueListenableBuilder<MusicTrack>(
            valueListenable: SleepMixer.I.selectedMusic,
            builder: (_, track, __) {
              return _MusicChip(
                label: _trackLabel(context, track),
                onTap: () => _openPicker(context),
              );
            },
          ),
        );
      },
    );
  }

  void _openPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF14102B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => const _MusicPickerSheet(),
    );
  }

  static String _trackLabel(BuildContext context, MusicTrack t) {
    final l = AppLocalizations.of(context)!;
    switch (t) {
      case MusicTrack.softAcoustic:
        return l.sleepMusicSoftAcoustic;
      case MusicTrack.verySlow:
        return l.sleepMusicVerySlow;
      case MusicTrack.relaxing:
        return l.sleepMusicRelaxing;
      case MusicTrack.warmSauna:
        return l.sleepMusicWarmSauna;
    }
  }
}

class _SoundCardShell extends StatelessWidget {
  const _SoundCardShell({
    required this.enabled,
    required this.icon,
    required this.label,
    required this.onIconTap,
    required this.trailing,
    required this.slider,
    this.extra,
  });

  final bool enabled;
  final IconData icon;
  final String label;
  final VoidCallback onIconTap;
  final Widget trailing;
  final Widget slider;
  final Widget? extra;

  static const Color _glass = Color(0xFF1F1B36);
  static const Color _glassSel = Color(0xFF2A2347);
  static const Color _amber = Color(0xFFE8A65A);

  @override
  Widget build(BuildContext context) {
    final bg = enabled ? _glassSel.withAlpha(230) : _glass.withAlpha(190);
    final border =
        enabled ? _amber.withAlpha(180) : Colors.white.withAlpha(18);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border, width: 1.2),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: _amber.withAlpha(50),
                  blurRadius: 22,
                  spreadRadius: -4,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onIconTap,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: enabled
                        ? _amber.withAlpha(45)
                        : Colors.white.withAlpha(14),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon,
                      color: enabled
                          ? _amber
                          : Colors.white.withAlpha(170),
                      size: 18),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              trailing,
            ],
          ),
          const SizedBox(height: 8),
          slider,
          if (extra != null) ...[
            const SizedBox(height: 8),
            extra!,
          ],
        ],
      ),
    );
  }
}

class _ToggleSwitch extends StatelessWidget {
  const _ToggleSwitch({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;
  static const Color _amber = Color(0xFFE8A65A);

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 0.85,
      child: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF3B2412),
        activeTrackColor: _amber,
        inactiveTrackColor: const Color(0xFF14102B),
        inactiveThumbColor: Colors.white.withAlpha(120),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({
    required this.value,
    required this.onChanged,
    required this.color,
  });
  final double value;
  final ValueChanged<double>? onChanged;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: color,
              inactiveTrackColor: Colors.white.withAlpha(28),
              thumbColor: color,
              overlayColor: color.withAlpha(50),
            ),
            child: Slider(
              value: value.clamp(0.0, 1.0),
              onChanged: onChanged,
              min: 0,
              max: 1,
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 36,
          child: Text(
            '${(value * 100).round()} %',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Colors.white.withAlpha(190),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _MusicChip extends StatelessWidget {
  const _MusicChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF14102B).withAlpha(180),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white.withAlpha(220),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more_rounded,
                color: Colors.white.withAlpha(150), size: 16),
          ],
        ),
      ),
    );
  }
}

class _MusicPickerSheet extends StatelessWidget {
  const _MusicPickerSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(40),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Center(
              child: Text(
                l10n.sleepMusicTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 14),
            ValueListenableBuilder<MusicTrack>(
              valueListenable: SleepMixer.I.selectedMusic,
              builder: (_, sel, __) {
                return Column(
                  children: [
                    _MusicTile(
                      label: l10n.sleepMusicSoftAcoustic,
                      selected: sel == MusicTrack.softAcoustic,
                      onTap: () => _select(context, MusicTrack.softAcoustic),
                    ),
                    _MusicTile(
                      label: l10n.sleepMusicVerySlow,
                      selected: sel == MusicTrack.verySlow,
                      onTap: () => _select(context, MusicTrack.verySlow),
                    ),
                    _MusicTile(
                      label: l10n.sleepMusicRelaxing,
                      selected: sel == MusicTrack.relaxing,
                      onTap: () => _select(context, MusicTrack.relaxing),
                    ),
                    _MusicTile(
                      label: l10n.sleepMusicWarmSauna,
                      selected: sel == MusicTrack.warmSauna,
                      onTap: () => _select(context, MusicTrack.warmSauna),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _select(BuildContext context, MusicTrack t) {
    SleepMixer.I.selectMusic(t);
    Navigator.of(context).pop();
  }
}

class _MusicTile extends StatelessWidget {
  const _MusicTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  static const Color _amber = Color(0xFFE8A65A);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: selected
            ? const Color(0xFF2A2347).withAlpha(230)
            : const Color(0xFF1F1B36).withAlpha(180),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? _amber.withAlpha(180) : Colors.white.withAlpha(18),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.music_note_rounded,
                    color: selected ? _amber : Colors.white.withAlpha(180),
                    size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_rounded,
                      color: _amber, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Timer ────────────────────────────────────────────────────────────────────

class _TimerChips extends StatelessWidget {
  const _TimerChips();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<SleepTimerOption>(
      valueListenable: SleepMixer.I.selectedTimer,
      builder: (_, sel, __) {
        return Row(
          children: [
            Expanded(
              child: _TimerChip(
                label: l10n.sleepTimer15,
                selected: sel == SleepTimerOption.min15,
                onTap: () =>
                    SleepMixer.I.selectTimer(SleepTimerOption.min15),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TimerChip(
                label: l10n.sleepTimer30,
                selected: sel == SleepTimerOption.min30,
                onTap: () =>
                    SleepMixer.I.selectTimer(SleepTimerOption.min30),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TimerChip(
                label: l10n.sleepTimer60,
                selected: sel == SleepTimerOption.min60,
                onTap: () =>
                    SleepMixer.I.selectTimer(SleepTimerOption.min60),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _TimerChip(
                label: l10n.sleepTimerUntilStop,
                selected: sel == SleepTimerOption.untilStop,
                onTap: () =>
                    SleepMixer.I.selectTimer(SleepTimerOption.untilStop),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TimerChip extends StatelessWidget {
  const _TimerChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  static const Color _amber = Color(0xFFE8A65A);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFF2A2347).withAlpha(230)
            : const Color(0xFF1F1B36).withAlpha(180),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? _amber.withAlpha(200) : Colors.white.withAlpha(18),
          width: 1.2,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: _amber.withAlpha(60),
                  blurRadius: 14,
                  spreadRadius: -3,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white.withAlpha(190),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Modus (Mit/Ohne Wecker) ──────────────────────────────────────────────────

class _ModePicker extends StatelessWidget {
  const _ModePicker();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<SleepMode>(
      valueListenable: SleepMixer.I.selectedMode,
      builder: (_, mode, __) {
        return Row(
          children: [
            Expanded(
              child: _ModeCard(
                icon: Icons.alarm_rounded,
                title: l10n.sleepWithAlarm,
                hint: l10n.sleepWithAlarmHint,
                selected: mode == SleepMode.withAlarm,
                onTap: () => SleepMixer.I.selectMode(SleepMode.withAlarm),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ModeCard(
                icon: Icons.do_not_disturb_on_rounded,
                title: l10n.sleepWithoutAlarm,
                hint: l10n.sleepWithoutAlarmHint,
                selected: mode == SleepMode.withoutAlarm,
                onTap: () =>
                    SleepMixer.I.selectMode(SleepMode.withoutAlarm),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.hint,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String hint;
  final bool selected;
  final VoidCallback onTap;
  static const Color _amber = Color(0xFFE8A65A);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFF2A2347).withAlpha(230)
            : const Color(0xFF1F1B36).withAlpha(180),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? _amber.withAlpha(200) : Colors.white.withAlpha(18),
          width: 1.3,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: _amber.withAlpha(70),
                  blurRadius: 18,
                  spreadRadius: -3,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    color: selected ? _amber : Colors.white.withAlpha(180),
                    size: 22),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withAlpha(165),
                    fontSize: 10.5,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Start/Stop ───────────────────────────────────────────────────────────────

class _StartButton extends StatelessWidget {
  const _StartButton();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mq = MediaQuery.of(context);
    final compact = mq.size.height < 500 && mq.size.width > mq.size.height;
    return ValueListenableBuilder<bool>(
      valueListenable: SleepMixer.I.running,
      builder: (_, running, __) {
        return ValueListenableBuilder<bool>(
          valueListenable: SleepMixer.I.busy,
          builder: (_, busy, __) {
            final label =
                running ? l10n.sleepStopButton : l10n.sleepStartButton;
            // Running-State: klar erkennbarer STOP-Button in warmem Rot,
            // damit er nicht mit dem Start-Button verwechselt wird.
            final gradient = running
                ? const [Color(0xFFE25A47), Color(0xFFB23A2B)]
                : const [Color(0xFFF2B872), Color(0xFFE08A3C)];
            final fg = running
                ? Colors.white
                : const Color(0xFF3B2412);
            final glow = running
                ? const Color(0xFFB23A2B).withAlpha(170)
                : const Color(0xFFE08A3C).withAlpha(160);

            // Während eine Audio-Operation läuft: Button visuell etwas
            // gedämpft + Taps ignorieren. Verhindert doppelte Trigger.
            final disabled = busy;

            return Opacity(
              opacity: disabled ? 0.65 : 1.0,
              child: GestureDetector(
                onTap: disabled
                    ? null
                    : () async {
                        debugPrint(
                            'SleepScreen: Start tapped — busy=$busy running=$running '
                            'anyChannelEnabled=${SleepMixer.I.anyChannelEnabled} '
                            'purr=${SleepMixer.I.purrEnabled.value} '
                            'rain=${SleepMixer.I.rainEnabled.value} '
                            'ocean=${SleepMixer.I.oceanEnabled.value} '
                            'music=${SleepMixer.I.musicEnabled.value} '
                            'timer=${SleepMixer.I.selectedTimer.value}');
                        if (running) {
                          // Manueller Stop = sofort, kein Fade.
                          debugPrint('SleepScreen: → stopNow');
                          await SleepMixer.I.stopNow();
                          return;
                        }
                        if (!SleepMixer.I.anyChannelEnabled) {
                          debugPrint(
                              'SleepScreen: → no channel, showing snackbar');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.sleepNoChannelHint),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: const Color(0xFF1F1B36),
                            ),
                          );
                          return;
                        }
                        debugPrint('SleepScreen: → start()');
                        await SleepMixer.I.start();
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: compact ? 52 : 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                    borderRadius: BorderRadius.circular(compact ? 18 : 22),
                    border: running
                        ? Border.all(
                            color: Colors.white.withAlpha(60),
                            width: 1.4,
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: glow,
                        blurRadius: 24,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          running
                              ? Icons.stop_circle_rounded
                              : Icons.play_arrow_rounded,
                          color: fg,
                          size: compact ? 22 : (running ? 28 : 26),
                        ),
                        SizedBox(width: compact ? 8 : 10),
                        Text(
                          label,
                          style: TextStyle(
                            color: fg,
                            fontSize: compact ? 13.5 : 15.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _RemainingLine extends StatelessWidget {
  const _RemainingLine();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<bool>(
      valueListenable: SleepMixer.I.running,
      builder: (_, running, __) {
        if (!running) return const SizedBox(height: 14);
        return ValueListenableBuilder<Duration>(
          valueListenable: SleepMixer.I.remaining,
          builder: (_, left, __) {
            final unlimited = left == Duration.zero &&
                SleepMixer.I.selectedTimer.value ==
                    SleepTimerOption.untilStop;
            final text = unlimited
                ? l10n.sleepUnlimited
                : '${l10n.sleepRemainingPrefix}${_fmt(left)}';
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: Text(
                  text,
                  style: TextStyle(
                    color: Colors.white.withAlpha(190),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

// ── Presets ──────────────────────────────────────────────────────────────────

/// Horizontal bar of saved sleep-mode mixes. Tap loads, long-press saves,
/// "+" adds a new slot. The currently active set is highlighted in amber.
class _PresetBar extends StatelessWidget {
  const _PresetBar();

  static const Color _glass = Color(0xFF1F1B36);

  String _displayName(BuildContext context, SleepPreset p, int index) {
    final defaults = {'set1': 1, 'set2': 2, 'set3': 3};
    final n = defaults[p.id];
    if (n != null) {
      return AppLocalizations.of(context)!.sleepPresetDefault(n);
    }
    return p.name.isEmpty ? '#${index + 1}' : p.name;
  }

  Future<void> _confirmAndSave(
      BuildContext context, String id, String displayName) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F1B36),
        title: Text(
          l10n.sleepPresetSaveTitle,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          l10n.sleepPresetSaveBody(displayName),
          style: TextStyle(color: Colors.white.withAlpha(220)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              l10n.sleepPresetSaveCancel,
              style: TextStyle(color: Colors.white.withAlpha(180)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l10n.sleepPresetSaveConfirm,
              style: const TextStyle(
                color: Color(0xFFE8A65A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await SleepPresetStore.I.saveCurrent(id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.sleepPresetSaved),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: _glass,
      ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final count = SleepPresetStore.I.presets.value.length + 1;
    final name = l10n.sleepPresetDefault(count);
    final id = await SleepPresetStore.I.addSlot(name: name);
    await SleepPresetStore.I.saveCurrent(id, name: name);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.sleepPresetSaved),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: _glass,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<List<SleepPreset>>(
      valueListenable: SleepPresetStore.I.presets,
      builder: (_, list, __) {
        return ValueListenableBuilder<String?>(
          valueListenable: SleepPresetStore.I.activeId,
          builder: (_, activeId, __) {
            return SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                itemCount: list.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  if (i == list.length) {
                    return _PresetAddChip(
                      tooltip: l10n.sleepPresetAdd,
                      onTap: () => _add(ctx),
                    );
                  }
                  final preset = list[i];
                  final name = _displayName(ctx, preset, i);
                  return _PresetChip(
                    label: name,
                    active: preset.id == activeId,
                    onTap: () => SleepPresetStore.I.apply(preset),
                    onLongPress: () =>
                        _confirmAndSave(ctx, preset.id, name),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.active,
    required this.onTap,
    required this.onLongPress,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  static const Color _amber = Color(0xFFE8A65A);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF2A2347).withAlpha(230)
            : const Color(0xFF1F1B36).withAlpha(180),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? _amber.withAlpha(220) : Colors.white.withAlpha(18),
          width: 1.2,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: _amber.withAlpha(70),
                  blurRadius: 14,
                  spreadRadius: -3,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : Colors.white.withAlpha(220),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PresetAddChip extends StatelessWidget {
  const _PresetAddChip({required this.tooltip, required this.onTap});
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xFF1F1B36).withAlpha(180),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            width: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withAlpha(18), width: 1.2),
            ),
            child: Icon(
              Icons.add_rounded,
              color: Colors.white.withAlpha(200),
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}
