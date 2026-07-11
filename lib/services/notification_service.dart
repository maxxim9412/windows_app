import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Локальные напоминания: каждый будний день в выбранное время.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'daily_reflection';
  static const _channelName = 'Отрывок дня';

  // id уведомлений — по одному на каждый будний день (Пн..Пт).
  static const List<int> _weekdayIds = [1, 2, 3, 4, 5];

  Future<void> init() async {
    tzdata.initializeTimeZones();
    // Определяем реальный часовой пояс устройства, иначе timezone использует UTC
    // и напоминания сработают не в то время.
    try {
      final tzName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Europe/Warsaw'));
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
  }

  Future<bool> requestPermissions() async {
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final iosGranted = await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        true;

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final androidGranted =
        await android?.requestNotificationsPermission() ?? true;

    return iosGranted && androidGranted;
  }

  /// Запланировать напоминания на будни в [hour]:[minute].
  Future<void> scheduleWeekdays({required int hour, required int minute}) async {
    await cancelAll();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Ежедневное напоминание почитать отрывок и записать размышления',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    // DateTime.monday == 1 ... DateTime.friday == 5 совпадает с _weekdayIds.
    for (final weekday in _weekdayIds) {
      final scheduled = _nextInstanceOfWeekday(weekday, hour, minute);
      await _plugin.zonedSchedule(
        weekday,
        'Отрывок дня',
        'Есть минутка? Прочитайте отрывок и запишите размышления.',
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  tz.TZDateTime _nextInstanceOfWeekday(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    // Сдвигаемся к нужному дню недели и в будущее.
    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
