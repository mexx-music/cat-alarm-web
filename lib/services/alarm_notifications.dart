import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Schedules iOS local notifications so the alarm fires while the screen is
/// locked or the app is backgrounded. On Android we are a no-op; the existing
/// in-app timer/wakelock flow continues to drive the alarm there.
class AlarmNotifications {
  AlarmNotifications._();
  static final AlarmNotifications I = AlarmNotifications._();

  static const int _alarmId = 1001;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _tzReady = false;

  bool get _isIOS => !kIsWeb && Platform.isIOS;

  Future<void> init() async {
    if (!_isIOS || _initialized) return;
    try {
      const initSettings = InitializationSettings(
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(initSettings);
      _initialized = true;
    } catch (e) {
      debugPrint('AlarmNotifications: init failed: $e');
    }
  }

  Future<void> _ensureTimezone() async {
    if (_tzReady) return;
    try {
      tzdata.initializeTimeZones();
      _tzReady = true;
    } catch (e) {
      debugPrint('AlarmNotifications: tz init failed: $e');
    }
  }

  Future<bool> requestPermissions() async {
    if (!_isIOS) return true;
    await init();
    try {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    } catch (e) {
      debugPrint('AlarmNotifications: requestPermissions failed: $e');
      return false;
    }
  }

  Future<void> schedule({
    required DateTime fireAt,
    required String title,
    required String body,
  }) async {
    if (!_isIOS) return;
    await init();
    await _ensureTimezone();
    if (!_initialized || !_tzReady) return;

    try {
      await _plugin.cancel(_alarmId);
      final scheduled = tz.TZDateTime.from(fireAt, tz.local);
      const details = NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      );
      await _plugin.zonedSchedule(
        _alarmId,
        title,
        body,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('AlarmNotifications: scheduled for $scheduled');
    } catch (e) {
      debugPrint('AlarmNotifications: schedule failed: $e');
    }
  }

  Future<void> cancel() async {
    if (!_isIOS || !_initialized) return;
    try {
      await _plugin.cancel(_alarmId);
      debugPrint('AlarmNotifications: cancelled');
    } catch (e) {
      debugPrint('AlarmNotifications: cancel failed: $e');
    }
  }
}
