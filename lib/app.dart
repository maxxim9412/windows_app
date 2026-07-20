import 'package:flutter/material.dart';

import 'screens/auth_gate.dart';
import 'services/theme_service.dart';

class BibleReflectionApp extends StatelessWidget {
  const BibleReflectionApp({super.key});

  ThemeData _theme(int seed, Brightness brightness) => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(seed),
          brightness: brightness,
        ),
        useMaterial3: true,
      );

  @override
  Widget build(BuildContext context) {
    // Основной цвет задаёт админ церкви, поэтому тема не константа: слушаем
    // цвет-зерно и пересобираем MaterialApp, когда оно меняется.
    return ValueListenableBuilder<int>(
      valueListenable: ThemeService.instance,
      builder: (context, seed, _) => MaterialApp(
        title: 'Размышления над Библией',
        debugShowCheckedModeBanner: false,
        theme: _theme(seed, Brightness.light),
        darkTheme: _theme(seed, Brightness.dark),
        home: const AuthGate(),
      ),
    );
  }
}
