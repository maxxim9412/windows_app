import 'package:shared_preferences/shared_preferences.dart';

/// Пользовательские настройки (время и включённость напоминаний).
class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  static const _kEnabled = 'reminders_enabled';
  static const _kHour = 'reminder_hour';
  static const _kMinute = 'reminder_minute';

  Future<bool> remindersEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabled) ?? false;
  }

  Future<int> reminderHour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kHour) ?? 8;
  }

  Future<int> reminderMinute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kMinute) ?? 0;
  }

  Future<void> save({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, enabled);
    await prefs.setInt(_kHour, hour);
    await prefs.setInt(_kMinute, minute);
  }
}
