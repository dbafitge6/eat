import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(iOS: ios);
    await _plugin.initialize(settings);
  }

  Future<void> scheduleWaterReminders(List<int> hours) async {
    await _plugin.cancelAll();
    for (int i = 0; i < hours.length; i++) {
      await _plugin.periodicallyShow(
        i,
        '水分補給の時間です',
        '今日の目標水分量を達成しましょう',
        RepeatInterval.hourly,
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: false,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
