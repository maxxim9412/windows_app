import 'package:flutter/material.dart';

import 'screens/auth_gate.dart';
import 'services/theme_service.dart';

/// Радиусы скруглений — «редакционный» стиль (почти острые углы), а не
/// стоковый Material с его крупными скруглениями. Три размера вместо одного
/// на все компоненты: мелкие элементы (кнопки, поля) чуть острее крупных
/// поверхностей (карточки, диалоги, шторки) — так острота не бьёт по глазам.
class _Radii {
  static const sm = 4.0; // кнопки, поля ввода, пункты списков
  static const lg = 10.0; // карточки, диалоги, нижние шторки
}

class BibleReflectionApp extends StatelessWidget {
  const BibleReflectionApp({super.key});

  ThemeData _theme(int seed, Brightness brightness) {
    final scheme =
        ColorScheme.fromSeed(seedColor: Color(seed), brightness: brightness);
    final smShape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(_Radii.sm));
    final lgShape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(_Radii.lg));

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      // Единственная точка, откуда шрифт расходится по всему приложению —
      // Material сам прокидывает fontFamily во весь TextTheme и большинство
      // текстов внутри компонентов (кнопки, поля, диалоги).
      fontFamily: 'Source Serif 4',
      appBarTheme: const AppBarTheme(elevation: 0, scrolledUnderElevation: 0),
      cardTheme: CardThemeData(elevation: 0, shape: lgShape),
      dialogTheme: DialogThemeData(shape: lgShape),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(_Radii.lg)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(shape: smShape),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(shape: smShape),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: smShape),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(_Radii.sm)),
      ),
      chipTheme: ChipThemeData(shape: smShape),
      navigationBarTheme: NavigationBarThemeData(
        indicatorShape: smShape,
      ),
    );
  }

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
