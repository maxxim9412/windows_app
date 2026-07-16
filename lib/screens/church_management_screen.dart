import 'package:flutter/material.dart';

import '../data/church_repository.dart';
import '../models/church.dart';
import '../utils/app_themes.dart';
import 'church_report_screen.dart';
import 'church_theme_screen.dart';
import 'monthly_schedule_screen.dart';

/// Супер-админ: добавление/удаление церквей, их администраторов и оформления.
class ChurchManagementScreen extends StatefulWidget {
  const ChurchManagementScreen({super.key});

  @override
  State<ChurchManagementScreen> createState() => _ChurchManagementScreenState();
}

class _ChurchManagementScreenState extends State<ChurchManagementScreen> {
  final _newChurchCtrl = TextEditingController();

  // Один раз, не в build: иначе перерисовка (например, при смене оформления)
  // подсунула бы StreamBuilder новый поток и список церквей мигал бы спиннером.
  late final Stream<List<Church>> _churches =
      ChurchRepository.instance.streamChurches();

  @override
  void dispose() {
    _newChurchCtrl.dispose();
    super.dispose();
  }

  Future<void> _addChurch() async {
    final name = _newChurchCtrl.text.trim();
    if (name.isEmpty) return;
    await ChurchRepository.instance.create(name);
    _newChurchCtrl.clear();
  }

  Future<void> _deleteChurch(Church c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Удалить «${c.name}»?'),
        content: const Text('График этой церкви останется в базе, но церковь '
            'исчезнет из списка. Действие необратимо.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Удалить')),
        ],
      ),
    );
    if (ok == true) await ChurchRepository.instance.delete(c.id);
  }

  Future<void> _addAdmin(Church c) async {
    final ctrl = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Админ церкви «${c.name}»'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(
            hintText: 'Почта пользователя',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Добавить')),
        ],
      ),
    );
    if (email == null || email.isEmpty) return;
    final user = await ChurchRepository.instance.userByEmail(email);
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Пользователь с почтой $email не найден. '
                'Он должен сначала зарегистрироваться.')));
      }
      return;
    }
    await ChurchRepository.instance.addAdmin(c.id, user.uid);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.name} назначен админом «${c.name}»')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Церкви')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newChurchCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Новая церковь',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addChurch(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                    onPressed: _addChurch, child: const Text('Добавить')),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<Church>>(
              stream: _churches,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final churches = snap.data!;
                if (churches.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('Пока нет церквей. Добавьте первую выше.',
                          textAlign: TextAlign.center),
                    ),
                  );
                }
                return ListView(
                  children: churches.map(_churchTile).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _churchTile(Church c) {
    return ExpansionTile(
      title: Text(c.name),
      subtitle: Text(
          'Админов: ${c.adminUids.length} · ${colorName(c.themeSeed)}'),
      trailing: IconButton(
        tooltip: 'Удалить церковь',
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _deleteChurch(c),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.insights_outlined),
          title: const Text('Отчёт'),
          subtitle: const Text('Люди и тройки этой церкви'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChurchReportScreen(
                churchId: c.id,
                churchName: c.name,
              ),
            ),
          ),
        ),
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.edit_calendar_outlined),
          title: const Text('График на месяц'),
          subtitle: const Text('Отрывки QT и план чтения этой церкви'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MonthlyScheduleScreen(
                churchId: c.id,
                churchName: c.name,
              ),
            ),
          ),
        ),
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.palette_outlined),
          title: const Text('Оформление'),
          subtitle: Text(colorName(c.themeSeed)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChurchThemeScreen(
                churchId: c.id,
                churchName: c.name,
                currentSeed: c.themeSeed,
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        const SizedBox(height: 8),
        FutureBuilder<Map<String, String>>(
          future: ChurchRepository.instance.namesFor(c.adminUids),
          builder: (context, snap) {
            final names = snap.data ?? {};
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (c.adminUids.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('Админов пока нет.'),
                  )
                else
                  ...c.adminUids.map((uid) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person_outline),
                        title: Text(names[uid] ?? uid),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => ChurchRepository.instance
                              .removeAdmin(c.id, uid),
                        ),
                      )),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: () => _addAdmin(c),
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('Добавить админа'),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
