import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../utils/app_dimens.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _enabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = SettingsService.instance;
    final enabled = await s.remindersEnabled();
    final hour = await s.reminderHour();
    final minute = await s.reminderMinute();
    setState(() {
      _enabled = enabled;
      _time = TimeOfDay(hour: hour, minute: minute);
      _loading = false;
    });
  }

  Future<void> _apply() async {
    await SettingsService.instance.save(
      enabled: _enabled,
      hour: _time.hour,
      minute: _time.minute,
    );

    if (_enabled) {
      final granted = await NotificationService.instance.requestPermissions();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Нет разрешения на уведомления. '
                    'Разрешите их в настройках устройства.')),
          );
        }
        return;
      }
      await NotificationService.instance
          .scheduleWeekdays(hour: _time.hour, minute: _time.minute);
    } else {
      await NotificationService.instance.cancelAll();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_enabled
              ? 'Напоминания включены: будни в '
                  '${_time.format(context)}'
              : 'Напоминания выключены'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Напоминания')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SwitchListTile(
                  title: const Text('Напоминать по будням'),
                  subtitle: const Text('Понедельник–пятница'),
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                ),
                ListTile(
                  enabled: _enabled,
                  leading: const Icon(Icons.access_time),
                  title: const Text('Время напоминания'),
                  trailing: Text(_time.format(context),
                      style: Theme.of(context).textTheme.titleMedium),
                  onTap: _enabled
                      ? () async {
                          final picked = await showTimePicker(
                              context: context, initialTime: _time);
                          if (picked != null) setState(() => _time = picked);
                        }
                      : null,
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: FilledButton(
                    onPressed: _apply,
                    child: const Text('Применить'),
                  ),
                ),
              ],
            ),
    );
  }
}
