import 'package:flutter/material.dart';

/// Оформление, которое админ церкви выбирает для своих прихожан.
///
/// Палитра не задаётся руками по цветам: Material 3 генерирует её целиком —
/// фон, карточки, кнопки, обе схемы (светлую и тёмную) — из одного зерна. За
/// счёт этого экраны, которые везде берут цвета из темы, перекрашиваются
/// согласованно.
class AppTheme {
  const AppTheme({
    required this.id,
    required this.name,
    required this.description,
    required this.seed,
    this.variant = DynamicSchemeVariant.tonalSpot,
  });

  /// Хранится в Firestore (`churches/{id}.theme`) — не переименовывать.
  final String id;
  final String name;
  final String description;
  final int seed;

  /// Способ разложить зерно в палитру. `neutral` заметно гасит насыщенность.
  final DynamicSchemeVariant variant;

  ColorScheme scheme(Brightness brightness) => ColorScheme.fromSeed(
        seedColor: Color(seed),
        brightness: brightness,
        dynamicSchemeVariant: variant,
      );
}

const List<AppTheme> kAppThemes = [
  AppTheme(
    id: 'classic',
    name: 'Классический синий',
    description: 'Как было с самого начала.',
    seed: 0xFF5B6CB8,
  ),
  AppTheme(
    id: 'quiet',
    name: 'Приглушённый синий',
    description: 'Тот же цвет, но тише: из фона уходит синева.',
    seed: 0xFF5B6CB8,
    variant: DynamicSchemeVariant.neutral,
  ),
  AppTheme(
    id: 'sage',
    name: 'Шалфей',
    description: 'Спокойный зелёный, глаз отдыхает на длинных текстах.',
    seed: 0xFF5F7A6B,
  ),
  AppTheme(
    id: 'sand',
    name: 'Тёплый песок',
    description: 'Бумажная гамма вместо холодной.',
    seed: 0xFF8A7060,
  ),
];

/// Первая тема — запасной вариант: церковь не выбрана, оформление не задано
/// или в базе оказался незнакомый id.
AppTheme themeById(String? id) =>
    kAppThemes.firstWhere((t) => t.id == id, orElse: () => kAppThemes.first);
