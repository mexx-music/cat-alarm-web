import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:screen_brightness/screen_brightness.dart';

/// WakelockManager: aktiviert WakelockPlus während [active] true ist.
/// Zusätzlich dimmt es optional das Display auf [dimLevel] (Default 0.1)
/// nach [autoDimAfter] (Default 2 Minuten). Bei Alarm-Start wird zusätzlich
/// ein kurzer Boost auf 100% gesetzt (log: 'Brightness: alarm boost').
class WakelockManager extends StatefulWidget {
  final bool active;

  /// Ziel-Dimm-Level (0.0 .. 1.0). Default: 0.1 (10%).
  final double dimLevel;

  /// Wartezeit bis automatisch gedimmt wird. Wenn null -> sofort dimmen.
  final Duration? autoDimAfter;

  const WakelockManager({
    Key? key,
    required this.active,
    this.dimLevel = 0.1,
    this.autoDimAfter = const Duration(minutes: 2),
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
      await ScreenBrightness().setScreenBrightness(level);
      debugPrint('Brightness: dimmed (level=$level)');
    } catch (e) {
      debugPrint('WakelockManager: failed to set dim level $level: $e');
    }
  }

  Future<void> _applyBoost() async {
    if (!_brightnessSupported) return;
    try {
      // ensure we saved previous
      _previousBrightness ??= await ScreenBrightness().current;
      if (!mounted) return;
      await ScreenBrightness().setScreenBrightness(1.0);
      debugPrint('Brightness: alarm boost');
    } catch (e) {
      debugPrint('WakelockManager: failed to apply alarm boost: $e');
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
      // Cancel any pending auto-dim timer when toggling
      _autoDimTimer?.cancel();
      _autoDimTimer = null;

      if (enable && !_isEnabled) {
        await WakelockPlus.enable();
        _isEnabled = true;
        debugPrint('WakelockManager: enabled');

        // Alarm boost immediately
        await _applyBoost();

        // Schedule dimming after autoDimAfter (or immediately if null)
        final autoAfter = widget.autoDimAfter ?? const Duration(minutes: 2);
        if (widget.autoDimAfter == null) {
          // user requested immediate dim
          await _applyDim(widget.dimLevel);
        } else {
          // schedule timer to dim after autoAfter
          _autoDimTimer = Timer(autoAfter, () async {
            // Before dimming, ensure widget still mounted and enabled
            if (!mounted || !_isEnabled) return;
            await _applyDim(widget.dimLevel);
          });
          debugPrint(
              'WakelockManager: auto-dim scheduled in ${autoAfter.inSeconds}s');
        }
      } else if (!enable && _isEnabled) {
        // disable wakelock
        await WakelockPlus.disable();
        _isEnabled = false;
        debugPrint('WakelockManager: disabled');

        // Cancel timer
        _autoDimTimer?.cancel();
        _autoDimTimer = null;

        // Restore brightness if we modified it
        await _restoreBrightness(reason: 'from alarm');
      } else if (enable && _isEnabled) {
        // already enabled, but dim level or timer may have changed
        _autoDimTimer?.cancel();
        _autoDimTimer = null;
        final autoAfter = widget.autoDimAfter ?? const Duration(minutes: 2);
        if (widget.autoDimAfter == null) {
          await _applyDim(widget.dimLevel);
        } else {
          _autoDimTimer = Timer(autoAfter, () async {
            if (!mounted || !_isEnabled) return;
            await _applyDim(widget.dimLevel);
          });
          debugPrint(
              'WakelockManager: auto-dim rescheduled in ${autoAfter.inSeconds}s');
        }
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
