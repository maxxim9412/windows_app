import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/local_migration.dart';
import 'auth_screen.dart';
import 'root_scaffold.dart';

/// Показывает вход, если пользователь не авторизован, иначе — приложение.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user != null) {
          // Ключ по uid: при смене аккаунта перенос проверяется заново.
          return _MigrationGate(key: ValueKey(user.uid));
        }
        return const AuthScreen();
      },
    );
  }
}

/// Пропускает в приложение только после разового переноса локальных данных в
/// облако. Иначе экраны успели бы прочитать Firestore до заливки и показали бы
/// пустые дни, будто прогресс потерян.
class _MigrationGate extends StatefulWidget {
  const _MigrationGate({super.key});

  @override
  State<_MigrationGate> createState() => _MigrationGateState();
}

class _MigrationGateState extends State<_MigrationGate> {
  // Не в build: иначе перенос перезапускался бы на каждой перерисовке.
  final Future<void> _migration = LocalMigration.instance.runIfNeeded();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _migration,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Синхронизируем ваши записи…'),
                ],
              ),
            ),
          );
        }
        return const RootScaffold();
      },
    );
  }
}
