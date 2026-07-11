import 'package:flutter/material.dart';

import '../services/auth_service.dart';

/// Раздел «Тройка»: профиль пользователя и (далее) управление тройкой.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late Future<Map<String, dynamic>?> _profile;

  @override
  void initState() {
    super.initState();
    _profile = AuthService.instance.profile();
  }

  void _reload() {
    setState(() => _profile = AuthService.instance.profile());
  }

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
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = AuthService.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Тройка')),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _profile,
        builder: (context, snapshot) {
          final name = (snapshot.data?['name'] as String?)?.trim();
          final displayName =
              (name != null && name.isNotEmpty) ? name : 'Без имени';
          final email = user?.email ?? (snapshot.data?['email'] as String?) ?? '';

          return ListView(
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
              const SizedBox(height: 16),
              Card(
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Тройки — скоро',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      SizedBox(height: 6),
                      Text(
                        'Здесь появится создание тройки, приглашение по ссылке '
                        'и обмен заметками с двумя людьми.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => AuthService.instance.signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Выйти'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
              ),
            ],
          );
        },
      ),
    );
  }
}
