import 'package:flutter/material.dart';

import 'screens/auth_gate.dart';
import 'services/theme_service.dart';
import 'utils/app_dimens.dart';

class BibleReflectionApp extends StatelessWidget {
  const BibleReflectionApp({super.key});

  // Card/кнопки — единственные компоненты, чью форму Material берёт из
  // ThemeData централизованно. Пока это не задано явно, они молча живут по
  // умолчанию Material 3 и не в курсе AppRadii — значения экрана и темы
  // расходятся, что и произошло здесь до этой правки.
  ThemeData _theme(int seed, Brightness brightness) => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(seed),
          brightness: brightness,
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
          ),
        ),
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
