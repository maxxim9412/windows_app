import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
    if (kIsWeb) return; // в вебе локальных уведомлений нет
    tzdata.initializeTimeZones();
    // Определяем часовой пояс устройства без нативных плагинов: подбираем
    // локацию из базы timezone, чьё текущее смещение совпадает со смещением
    // устройства. Иначе timezone использует UTC и напоминания сработают не в то время.
    tz.setLocalLocation(_localLocation());

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    // DarwinInitializationSettings общий для iOS и macOS. Без macOS: здесь
    // плагин бросает необработанное исключение прямо в main() — на macOS
    // это гасило весь Dart-изолят ещё до первого кадра (чёрное окно).
    const darwinInit = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(
          android: androidInit, iOS: darwinInit, macOS: darwinInit),
    );
  }

  /// Ищет tz-локацию с тем же смещением, что и у устройства сейчас.
  tz.Location _localLocation() {
    final offset = DateTime.now().timeZoneOffset;
    final now = DateTime.now();
    for (final loc in tz.timeZoneDatabase.locations.values) {
      if (tz.TZDateTime.from(now, loc).timeZoneOffset == offset) {
        return loc;
      }
    }
    return tz.getLocation('UTC');
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final iosGranted = await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        true;

    final macos = _plugin.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>();
    final macosGranted = await macos?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        true;

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final androidGranted =
        await android?.requestNotificationsPermission() ?? true;

    return iosGranted && macosGranted && androidGranted;
  }

  /// Запланировать напоминания на будни в [hour]:[minute].
  Future<void> scheduleWeekdays({required int hour, required int minute}) async {
    if (kIsWeb) return;
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
      macOS: DarwinNotificationDetails(),
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
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  Future<void> cancelAll() => kIsWeb ? Future.value() : _plugin.cancelAll();

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
