import 'package:flutter/material.dart';

import 'screens/auth_gate.dart';
import 'services/theme_service.dart';
import 'utils/app_themes.dart';

class BibleReflectionApp extends StatelessWidget {
  const BibleReflectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Оформление задаёт админ церкви, поэтому тема не константа: слушаем её и
    // пересобираем MaterialApp, когда значение меняется.
    return ValueListenableBuilder<AppTheme>(
      valueListenable: ThemeService.instance,
      builder: (context, appTheme, _) => MaterialApp(
        title: 'Размышления над Библией',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: appTheme.scheme(Brightness.light),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: appTheme.scheme(Brightness.dark),
          useMaterial3: true,
        ),
        home: const AuthGate(),
      ),
    );
  }
}
