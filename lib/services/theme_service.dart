import 'package:flutter/foundation.dart';

import '../data/church_repository.dart';
import '../utils/app_themes.dart';
import 'auth_service.dart';

/// Оформление текущего пользователя — его задаёт админ его церкви.
///
/// Приложение слушает это значение и перекрашивается на лету, поэтому админ
/// видит результат сразу, не перезапуская.
class ThemeService extends ValueNotifier<AppTheme> {
  ThemeService._() : super(themeById(null));
  static final ThemeService instance = ThemeService._();

  /// Подтянуть оформление церкви пользователя. Вызывается после входа и после
  /// смены церкви. Ошибку глотаем: остаться на классической теме не страшно,
  /// а ронять запуск из-за цвета — глупо.
  Future<void> loadForCurrentUser() async {
    try {
      final churchId = await AuthService.instance.currentChurchId();
      if (churchId == null) {
        value = themeById(null);
        return;
      }
      final church = await ChurchRepository.instance.byId(churchId);
      value = themeById(church?.themeId);
    } catch (_) {
      value = themeById(null);
    }
  }

  /// Применить локально — чтобы админ увидел выбор мгновенно.
  void apply(String id) => value = themeById(id);

  /// Вернуть тему по умолчанию (при выходе из аккаунта).
  void reset() => value = themeById(null);
}
