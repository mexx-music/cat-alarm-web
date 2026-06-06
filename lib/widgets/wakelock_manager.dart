import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:screen_brightness/screen_brightness.dart';

/// WakelockManager: aktiviert WakelockPlus während [active] true ist.
/// Beim Aktivieren wird nach [autoDimAfter] auf [dimLevel] gedimmt
/// (null = sofort). Der Timer läuft einmal und wird nicht durch Rebuilds
/// zurückgesetzt. Beim Deaktivieren wird die ursprüngliche Helligkeit
/// wiederhergestellt.
class WakelockManager extends StatefulWidget {
  final bool active;

  /// Ziel-Dimm-Level (0.0 .. 1.0). Default: 0.06 (nachttauglich).
  final double dimLevel;

  /// Wartezeit bis automatisch gedimmt wird. Wenn null -> sofort dimmen.
  final Duration? autoDimAfter;

  /// Wenn false (Default), darf [dimLevel] die Helligkeit NIE über die
  /// ursprüngliche Gerätehelligkeit hinaus anheben (Armed-/Night-Dim dimmt
  /// nur nach unten). Nur wenn true (z. B. Alarm klingelt) darf aktiv
  /// aufgehellt werden.
  final bool allowBrighten;

  const WakelockManager({
    Key? key,
    required this.active,
    this.dimLevel = 0.06,
    this.autoDimAfter,
    this.allowBrighten = false,
  }) : super(key: key);

  @override
  State<WakelockManager> createState() => _WakelockManagerState();
}

class _WakelockManagerState extends State<WakelockManager> {
  bool _isEnabled = false;
  double? _previousBrightness;
  bool _brightnessSupported = true; // optimistisch
  Timer? _autoDimTimer;

  @override
  void initState() {
    super.initState();
    _initBrightnessSupport();
    _update(widget.active);
  }

  Future<void> _initBrightnessSupport() async {
    try {
      final brightness = await ScreenBrightness().current;
      if (!mounted) return;
      _previousBrightness = brightness;
      debugPrint('WakelockManager: current brightness=$brightness');
      _brightnessSupported = true;
    } catch (e) {
      _brightnessSupported = false;
      debugPrint('WakelockManager: brightness not supported: $e');
    }
  }

  @override
  void didUpdateWidget(covariant WakelockManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active ||
        oldWidget.dimLevel != widget.dimLevel ||
        oldWidget.autoDimAfter != widget.autoDimAfter) {
      _update(widget.active);
    }
  }

  Future<void> _applyDim(double level) async {
    if (!_brightnessSupported) return;
    try {
      if (!mounted) return;
      var target = level;
      // Dimmen darf nie aufhellen: Ziel auf Originalhelligkeit begrenzen,
      // außer der Aufruf erlaubt aktives Aufhellen (Alarm).
      if (!widget.allowBrighten) {
        await _ensurePreviousBrightness();
        final original = _previousBrightness;
        if (original != null && target > original) {
          target = original;
        }
      }
      await ScreenBrightness().setScreenBrightness(target);
      debugPrint(
          'Brightness: dimmed (requested=$level, applied=$target, allowBrighten=${widget.allowBrighten})');
    } catch (e) {
      debugPrint('WakelockManager: failed to set dim level $level: $e');
    }
  }

  Future<void> _ensurePreviousBrightness() async {
    if (!_brightnessSupported) return;
    if (_previousBrightness != null) return;
    try {
      _previousBrightness = await ScreenBrightness().current;
    } catch (e) {
      debugPrint('WakelockManager: failed to read current brightness: $e');
    }
  }

  Future<void> _restoreBrightness({String reason = 'from alarm'}) async {
    if (!_brightnessSupported || _previousBrightness == null) return;
    try {
      if (!mounted) return;
      await ScreenBrightness().setScreenBrightness(_previousBrightness!);
      debugPrint('Brightness: restored ($reason)');
    } catch (e) {
      debugPrint('WakelockManager: failed to restore brightness: $e');
    }
  }

  Future<void> _update(bool enable) async {
    try {
      if (enable && !_isEnabled) {
        // Transition inactive → active: start fresh.
        _autoDimTimer?.cancel();
        _autoDimTimer = null;

        await WakelockPlus.enable();
        _isEnabled = true;
        debugPrint('WakelockManager: enabled');

        await _ensurePreviousBrightness();

        if (widget.autoDimAfter == null) {
          await _applyDim(widget.dimLevel);
        } else {
          _autoDimTimer = Timer(widget.autoDimAfter!, () async {
            if (!mounted || !_isEnabled) return;
            await _applyDim(widget.dimLevel);
          });
          debugPrint(
              'WakelockManager: auto-dim scheduled in ${widget.autoDimAfter!.inSeconds}s');
        }
      } else if (!enable && _isEnabled) {
        // Transition active → inactive.
        _autoDimTimer?.cancel();
        _autoDimTimer = null;

        await WakelockPlus.disable();
        _isEnabled = false;
        debugPrint('WakelockManager: disabled');

        await _restoreBrightness(reason: 'from alarm');
      } else if (enable && _isEnabled) {
        // Already active, dim params changed (e.g. night-mode kick-in).
        // autoDimAfter == null → apply dim immediately (night-mode / ringing).
        // autoDimAfter != null → a delay timer is already running; leave it alone.
        if (widget.autoDimAfter == null) {
          _autoDimTimer?.cancel();
          _autoDimTimer = null;
          await _applyDim(widget.dimLevel);
          debugPrint(
              'WakelockManager: immediate dim applied (level=${widget.dimLevel})');
        }
        // else: running timer continues undisturbed.
      }
    } catch (e) {
      debugPrint(
          'WakelockManager: error while changing wakelock/brightness state: $e');
    }
  }

  @override
  void dispose() {
    // ensure timer cancelled
    _autoDimTimer?.cancel();
    _autoDimTimer = null;

    if (_isEnabled) {
      // ensure disabled on dispose
      WakelockPlus.disable().then((_) {
        debugPrint('WakelockManager: disabled in dispose');
      }).catchError((e) {
        debugPrint('WakelockManager: disable error in dispose: $e');
      });
    }

    // restore brightness on dispose if supported
    if (_brightnessSupported && _previousBrightness != null) {
      ScreenBrightness().setScreenBrightness(_previousBrightness!).then((_) {
        debugPrint('Brightness: restored (dispose)');
      }).catchError((e) {
        debugPrint('WakelockManager: failed restore in dispose: $e');
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
