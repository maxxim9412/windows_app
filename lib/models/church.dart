import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/app_themes.dart';

/// Церковь: своё название, свой график и свои админы.
class Church {
  final String id;
  final String name;
  final List<String> adminUids;

  /// Цвет-зерно оформления (ARGB). null — не задан цветом; см. [themeSeed].
  final int? themeColor;

  /// Старый строковый id шаблона (classic/sage/…). Оставлен для миграции: если
  /// цвет ещё не выбран новой палитрой, берём его из этого id.
  final String? themeId;

  const Church({
    required this.id,
    required this.name,
    required this.adminUids,
    this.themeColor,
    this.themeId,
  });

  /// Итоговый цвет-зерно: выбранный цвет, иначе перенос со старого шаблона,
  /// иначе цвет по умолчанию.
  int get themeSeed => themeColor ?? seedForLegacyTheme(themeId);

  factory Church.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return Church(
      id: doc.id,
      name: (m['name'] as String?) ?? '',
      adminUids: List<String>.from(m['adminUids'] as List? ?? const []),
      themeColor: (m['themeColor'] as num?)?.toInt(),
      themeId: m['theme'] as String?,
    );
  }
}
