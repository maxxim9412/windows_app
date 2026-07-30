/// Общая шкала отступов и скруглений. Экраны раньше писали эти числа
/// россыпью, каждый своими literal-значениями — поменять «просторнее
/// стало» или «углы круглее» значило вручную обойти каждый файл (так и
/// было при откате прошлого дизайна). Теперь это один источник: поменял
/// здесь — сдвинулись все экраны разом.
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20; // было 16 — пробуем «просторнее»
  static const double xl = 24;
  static const double xxl = 32;
}

class AppRadii {
  static const double sm = 10; // было 8
  static const double md = 16; // было 12
  static const double lg = 22; // было 18
}
