import 'package:flutter/material.dart';

import 'screens/root_scaffold.dart';

class BibleReflectionApp extends StatelessWidget {
  const BibleReflectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5B6CB8),
      brightness: Brightness.light,
    );
    final darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5B6CB8),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'Размышления над Библией',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: scheme, useMaterial3: true),
      darkTheme: ThemeData(colorScheme: darkScheme, useMaterial3: true),
      home: const RootScaffold(),
    );
  }
}
