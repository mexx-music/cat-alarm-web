import 'dart:async';
import 'package:flutter/foundation.dart';
import '../audio/cat_alarm_player.dart';

class AlarmCore {
  static final AlarmCore I = AlarmCore._();
  AlarmCore._();

  Timer? _tick;
  DateTime? _fireAt;
  bool _armed = false;
  bool _userStopped = false;

  final ValueNotifier<bool> isArmed = ValueNotifier(false);

  void arm(DateTime fireAt) {
    _userStopped = false;
    _fireAt = fireAt;
    _armed = true;
    isArmed.value = true;
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  void disarm() {
    _armed = false;
    _fireAt = null;
    isArmed.value = false;
    _tick?.cancel(); _tick = null;
  }

  void onUserStop() {              // vom STOP-Button aufrufen!
    _userStopped = true;
    disarm();
  }

  Future<void> _onTick() async {
    final now = DateTime.now();
    debugPrint('Timer: _armed=$_armed, _fireAt=$_fireAt, _now=$now');
    if (_userStopped || !_armed || _fireAt == null) return;
    if (now.isBefore(_fireAt!)) return;

    // *** nur EINMAL auslösen ***
    _armed = false;
    isArmed.value = false;
    final latched = CatAlarmPlayer.I.stopLatch;  // Generation merken
    _tick?.cancel(); _tick = null;
    final fireAt = _fireAt; _fireAt = null;

    debugPrint('ALARM ausgelöst! fireAt=$fireAt');

    // falls der User während async STOP drückt, abbrechen
    if (CatAlarmPlayer.I.isObsolete(latched)) return;

    await CatAlarmPlayer.I.startOcean();
  }
}

