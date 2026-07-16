/// Основной цвет оформления, который админ выбирает для церкви.
///
/// Из одного «зерна» Material 3 генерирует всю палитру — фон, карточки, кнопки,
/// светлую и тёмную схему. Поэтому храним ровно цвет-зерно, а не набор.
class ThemeColor {
  const ThemeColor({required this.name, required this.seed});
  final String name;

  /// ARGB-значение цвета-зерна (для Color(seed)).
  final int seed;
}

/// Цвет по умолчанию для новых церквей (Синий).
const int kDefaultSeed = 0xFF2D6CDF;

/// Палитра выбора. Оттенки разнесены по кругу, чтобы легко различались.
const List<ThemeColor> kThemeColors = [
  ThemeColor(name: 'Синий', seed: 0xFF2D6CDF),
  ThemeColor(name: 'Бирюзовый', seed: 0xFF00857D),
  ThemeColor(name: 'Зелёный', seed: 0xFF2E9E3A),
  ThemeColor(name: 'Лайм', seed: 0xFF7E9A1E),
  ThemeColor(name: 'Янтарь', seed: 0xFFD69A00),
  ThemeColor(name: 'Оранжевый', seed: 0xFFE0601C),
  ThemeColor(name: 'Красный', seed: 0xFFCE3A34),
  ThemeColor(name: 'Розовый', seed: 0xFFD24B86),
  ThemeColor(name: 'Фиолетовый', seed: 0xFF9B45C4),
  ThemeColor(name: 'Сине-фиолетовый', seed: 0xFF5B4BD0),
];

/// Название цвета по зерну (для подписей). Незнакомый — «Свой цвет».
String colorName(int seed) {
  for (final c in kThemeColors) {
    if (c.seed == seed) return c.name;
  }
  return 'Свой цвет';
}

/// Перенос старых id-шаблонов на ближайший цвет новой палитры. Церкви,
/// настроенные до этой палитры, хранили строковый id (classic/quiet/sage/sand).
int seedForLegacyTheme(String? id) {
  switch (id) {
    case 'sage':
      return 0xFF2E9E3A; // зелёный
    case 'sand':
      return 0xFFE0601C; // оранжевый (тёплый)
    case 'classic':
    case 'quiet':
    default:
      return kDefaultSeed;
  }
}
