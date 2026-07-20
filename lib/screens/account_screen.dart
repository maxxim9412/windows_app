import 'package:flutter/material.dart';

import '../data/church_repository.dart';
import '../models/church.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../services/triad_service.dart';
import '../utils/app_themes.dart';
import 'church_management_screen.dart';
import 'church_report_screen.dart';
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

  Future<void> _editProfile(String currentName, String currentPhone) async {
    final nameCtrl = TextEditingController(text: currentName);
    final phoneCtrl = TextEditingController(text: currentPhone);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ваши данные'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Имя',
                hintText: 'Как вас видят в тройке',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Телефон',
                helperText: 'Виден только вашей тройке и администраторам',
                helperMaxLines: 2,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final name = nameCtrl.text.trim();
    await AuthService.instance.updateProfile(
      name: name.isEmpty ? null : name,
      phone: phoneCtrl.text.trim(),
    );
    // Тройка хранит копию имени и телефона — обновляем и её, иначе участники
    // продолжат видеть старые данные.
    await TriadService.instance.syncMyProfileToTriad();
    _load();
  }

  Future<void> _changeChurch() async {
    var selected = _churchId;
    final result = await showDialog<String?>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setInner) => AlertDialog(
          title: const Text('Ваша церковь'),
          // Варианта «не выбрана» тут нет: без церкви нет ни графика, ни тройки,
          // а при регистрации церковь обязательна — не давать же обходить это
          // через смену.
          content: DropdownButtonFormField<String>(
            initialValue: selected,
            isExpanded: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: [
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
    if (result == _churchId) return;

    // Тройка читает график своей церкви, поэтому смешанной по церквям она быть
    // не может: уходя в другую церковь, человек выходит из ВСЕХ своих троек
    // (их может быть несколько).
    final triadIds = await TriadService.instance.myTriadIds();
    if (triadIds.isNotEmpty) {
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Смена церкви'),
          content: Text(
              'Участники тройки читают один и тот же график, поэтому тройка '
              'может быть только из одной церкви.\n\n'
              'Если сменить церковь, вы выйдете из ${triadIds.length == 1 ? 'своей тройки' : 'всех своих троек'}. Продолжить?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Сменить и выйти')),
          ],
        ),
      );
      if (ok != true) return;
      for (final id in triadIds) {
        await TriadService.instance.leave(id);
      }
    }

    await AuthService.instance.setChurch(result);
    // У новой церкви может быть своё оформление.
    await ThemeService.instance.loadForCurrentUser();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(triadIds.isNotEmpty
              ? 'Церковь изменена, из троек вы вышли.'
              : 'Церковь изменена.')));
    }
    _load();
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
    final phone = ((_profile?['phone'] as String?) ?? '').trim();

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
              subtitle: Text(phone.isEmpty ? email : '$email\n$phone'),
              isThreeLine: phone.isNotEmpty,
              trailing: IconButton(
                tooltip: 'Изменить имя и телефон',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editProfile(name ?? '', phone),
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
                leading: const Icon(Icons.insights_outlined),
                title: const Text('Отчёт по церкви'),
                subtitle: const Text('Тройки и кому нужен участник'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChurchReportScreen(
                      churchId: _myChurch!.id,
                      churchName: _myChurch!.name,
                    ),
                  ),
                ),
              ),
            ),
          if (_myChurch != null && _isChurchAdmin)
            Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Оформление церкви'),
                subtitle: Text(colorName(_myChurch!.themeSeed)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChurchThemeScreen(
                        churchId: _myChurch!.id,
                        churchName: _myChurch!.name,
                        currentSeed: _myChurch!.themeSeed,
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
