import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  // Water reminder IDs: 0–59. Supplement IDs: 100+
  static const _maxWaterSlots = 60;

  Future<void> init() async {
    tz.initializeTimeZones();
    final tzName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzName));

    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(iOS: ios);
    await _plugin.initialize(settings);
  }

  /// intervalMinutes: 5〜120 minutes. Schedules daily recurring notifications
  /// from 8:00 to 22:00. Capped at 60 slots due to iOS limit.
  Future<void> scheduleWaterReminders({int intervalMinutes = 10}) async {
    for (int i = 0; i < _maxWaterSlots; i++) {
      await _plugin.cancel(i);
    }

    // Generate (hour, minute) pairs from 8:00 to 22:00
    final times = <({int hour, int minute})>[];
    for (int m = 8 * 60; m <= 22 * 60; m += intervalMinutes) {
      times.add((hour: m ~/ 60, minute: m % 60));
    }

    final toSchedule = times.take(_maxWaterSlots).toList();
    for (int i = 0; i < toSchedule.length; i++) {
      final t = toSchedule[i];
      await _plugin.zonedSchedule(
        i,
        '水分補給の時間です 💧',
        '今日の目標水分量を達成しましょう',
        _nextInstanceOfHourMinute(t.hour, t.minute),
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBanner: true,
            presentList: true,
            presentBadge: false,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> scheduleSupplementReminder({
    required int slot,
    required String name,
    required int hour,
    required int minute,
  }) async {
    final id = 100 + slot;
    await _plugin.zonedSchedule(
      id,
      'サプリの時間です 💊',
      '$name を忘れずに！',
      _nextInstanceOfHourMinute(hour, minute),
      const NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentBadge: false,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelSupplementReminder(int slot) async {
    await _plugin.cancel(100 + slot);
  }

  Future<void> cancelWaterReminders() async {
    for (int i = 0; i < _maxWaterSlots; i++) {
      await _plugin.cancel(i);
    }
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  tz.TZDateTime _nextInstanceOfHourMinute(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var t =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (t.isBefore(now)) t = t.add(const Duration(days: 1));
    return t;
  }
}
