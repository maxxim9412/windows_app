import 'package:flutter/material.dart';

import '../data/church_repository.dart';
import '../models/church.dart';
import '../services/auth_service.dart';
import '../services/triad_service.dart';
import '../utils/app_themes.dart';
import 'church_management_screen.dart';
import 'church_theme_screen.dart';
import 'triad_view.dart';

/// Раздел «Тройка»: профиль, церковь и управление тройкой.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  Map<String, dynamic>? _profile;
  List<Church> _churches = const [];
  String? _churchId;
  bool _isSuperAdmin = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    Map<String, dynamic>? profile;
    var churches = const <Church>[];
    var isSuper = false;
    try {
      profile = await AuthService.instance.profile();
      churches = await ChurchRepository.instance.allChurches();
      isSuper = await AuthService.instance.isAdmin();
    } catch (_) {
      // Ошибка сети/правил — не «вешаем» страницу, покажем что есть.
    }
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _churches = churches;
      _churchId = profile?['churchId'] as String?;
      _isSuperAdmin = isSuper;
      _loading = false;
    });
  }

  Church? get _myChurch {
    if (_churchId == null) return null;
    final match = _churches.where((c) => c.id == _churchId);
    return match.isEmpty ? null : match.first;
  }

  String get _churchName => _myChurch?.name ?? (_churchId == null ? 'Не выбрана' : '—');

  /// Админ своей церкви — он и настраивает её оформление.
  bool get _isChurchAdmin =>
      _myChurch?.adminUids.contains(AuthService.instance.uid) ?? false;

  Future<void> _editName(String current) async {
    final ctrl = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ваше имя'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Как вас видят в тройке',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await AuthService.instance.updateName(name);
      _load();
    }
  }

  Future<void> _changeChurch() async {
    var selected = _churchId;
    final result = await showDialog<String?>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setInner) => AlertDialog(
          title: const Text('Ваша церковь'),
          content: DropdownButtonFormField<String>(
            initialValue: selected,
            isExpanded: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: null, child: Text('Не выбрана')),
              for (final c in _churches)
                DropdownMenuItem(value: c.id, child: Text(c.name)),
            ],
            onChanged: (v) => setInner(() => selected = v),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена')),
            FilledButton(
                onPressed: () => Navigator.pop(context, selected),
                child: const Text('Сохранить')),
          ],
        ),
      ),
    );
    // null-результат допустим (пользователь мог выбрать «Не выбрана»),
    // поэтому отличаем отмену по флагу.
    if (result != _churchId) {
      await AuthService.instance.setChurch(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Церковь изменена. Перезапустите приложение, чтобы обновить график.')));
      }
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = AuthService.instance.currentUser;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Тройка')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final name = (_profile?['name'] as String?)?.trim();
    final displayName = (name != null && name.isNotEmpty) ? name : 'Без имени';
    final email = user?.email ?? (_profile?['email'] as String?) ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Тройка')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primary,
                child: Text(
                  displayName != 'Без имени'
                      ? displayName.characters.first.toUpperCase()
                      : '?',
                  style: TextStyle(color: theme.colorScheme.onPrimary),
                ),
              ),
              title: Text(displayName),
              subtitle: Text(email),
              trailing: IconButton(
                tooltip: 'Изменить имя',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editName(name ?? ''),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.church_outlined),
              title: const Text('Церковь'),
              subtitle: Text(_churchName),
              trailing: TextButton(
                  onPressed: _changeChurch, child: const Text('Изменить')),
            ),
          ),
          if (_myChurch != null && _isChurchAdmin)
            Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Оформление церкви'),
                subtitle: Text(themeById(_myChurch!.themeId).name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChurchThemeScreen(
                        churchId: _myChurch!.id,
                        churchName: _myChurch!.name,
                        currentThemeId: _myChurch!.themeId,
                      ),
                    ),
                  );
                  _load();
                },
              ),
            ),
          if (_isSuperAdmin)
            Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('Управление церквями'),
                subtitle: const Text('Добавить/удалить церкви и их админов'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ChurchManagementScreen()));
                  _load();
                },
              ),
            ),
          const SizedBox(height: 16),
          const TriadView(),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              TriadService.instance.reset();
              AuthService.instance.signOut();
            },
            icon: const Icon(Icons.logout),
            label: const Text('Выйти из аккаунта'),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52)),
          ),
        ],
      ),
    );
  }
}
