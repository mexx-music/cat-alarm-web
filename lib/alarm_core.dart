import 'dart:async';
import 'package:flutter/foundation.dart';
import 'cat_alarm_player.dart';

class AlarmCore {
  static final AlarmCore I = AlarmCore._();
  AlarmCore._();

  Timer? _tick;
  DateTime? _fireAt; // wann auslösen
  bool _armed = false; // „scharf“ ja/nein
  bool _userStopped = false; // Latch gegen Re-Arm

  // für UI (optional)
  final ValueNotifier<bool> isArmed = ValueNotifier(false);

  void arm(DateTime fireAt) {
    _userStopped = false; // User erlaubt wieder
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
    _tick?.cancel();
    _tick = null;
  }

  Future<void> _onTick() async {
    final now = DateTime.now();
    debugPrint('Timer: _armed=$_armed, _fireAt=$_fireAt, _now=$now');

    if (_userStopped) return; // <- **NEU**: nach STOP nie wieder etwas tun
    if (!_armed || _fireAt == null) return;
    if (now.isBefore(_fireAt!)) return;

    // *** NUR EINMAL AUSLÖSEN ***
    _armed = false;
    isArmed.value = false;
    final latched = CatAlarmPlayer.I.stopLatch; // Latch capturen
    // sofort „unscharf“ machen, bevor Audio startet:
    _fireAt = null;
    _tick?.cancel();
    _tick = null;

    debugPrint('ALARM ausgelöst!');

    // Wenn User während async was gestoppt hat -> abbrechen
    if (CatAlarmPlayer.I.isObsolete(latched)) return;

    // Hier deinen Alarm starten (Meer, Regen, etc.)
    await CatAlarmPlayer.I.startOcean();
  }

  // vom STOP-Button setzen:
  void onUserStop() {
    _userStopped = true; // <- **entscheidend**: blockt JEDES Re-Armen
    disarm();
  }
}
