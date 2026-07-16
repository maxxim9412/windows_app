import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/local_migration.dart';
import '../services/theme_service.dart';
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
          // Ключ по uid: при смене аккаунта всё готовится заново.
          return _StartupGate(key: ValueKey(user.uid));
        }
        return const AuthScreen();
      },
    );
  }
}

/// Готовит аккаунт к работе, прежде чем пустить в приложение:
/// 1. Разовый перенос локальных данных в облако — иначе экраны прочитали бы
///    Firestore до заливки и показали пустые дни, будто прогресс потерян.
/// 2. Оформление церкви — иначе приложение мигнуло бы чужой темой.
class _StartupGate extends StatefulWidget {
  const _StartupGate({super.key});

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  // Не в build: иначе подготовка перезапускалась бы на каждой перерисовке.
  late final Future<void> _startup = _prepare();

  Future<void> _prepare() async {
    await LocalMigration.instance.runIfNeeded();
    await ThemeService.instance.loadForCurrentUser();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _startup,
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
