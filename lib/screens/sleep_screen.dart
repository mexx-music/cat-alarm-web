import 'package:flutter/material.dart';

import '../audio/sleep_mixer.dart';
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _IntroCard(
                          title: l10n.sleepModeTitle,
                          subtitle: l10n.sleepModeSubtitle,
                          amber: _amber,
                          glass: _glass,
                        ),
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
                    ),
                  ),
                ),
                if (widget.bottomNavBuilder != null) ...[
                  const SizedBox(height: 8),
                  widget.bottomNavBuilder!(context),
                  const SizedBox(height: 10),
                ] else
                  const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
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
  });
  final String title;
  final String subtitle;
  final Color amber;
  final Color glass;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: glass.withAlpha(190),
        borderRadius: BorderRadius.circular(26),
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [amber.withAlpha(220), const Color(0xFFE8C28A)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: amber.withAlpha(120),
                  blurRadius: 18,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: const Icon(Icons.nightlight_round,
                color: Color(0xFF3B2412), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
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
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                    borderRadius: BorderRadius.circular(22),
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
                          size: running ? 28 : 26,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          label,
                          style: TextStyle(
                            color: fg,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
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
