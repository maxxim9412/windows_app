import 'package:flutter/foundation.dart';

import '../data/church_repository.dart';
import '../utils/app_themes.dart';
import 'auth_service.dart';

/// Основной цвет-зерно текущего пользователя — его задаёт админ его церкви.
///
/// Приложение слушает это значение и перекрашивается на лету, поэтому админ
/// видит результат сразу, не перезапуская.
class ThemeService extends ValueNotifier<int> {
  ThemeService._() : super(kDefaultSeed);
  static final ThemeService instance = ThemeService._();

  /// Подтянуть цвет церкви пользователя. Вызывается после входа и после смены
  /// церкви. Ошибку глотаем: остаться на цвете по умолчанию не страшно, а
  /// ронять запуск из-за оформления — глупо.
  Future<void> loadForCurrentUser() async {
    try {
      final churchId = await AuthService.instance.currentChurchId();
      if (churchId == null) {
        value = kDefaultSeed;
        return;
      }
      final church = await ChurchRepository.instance.byId(churchId);
      value = church?.themeSeed ?? kDefaultSeed;
    } catch (_) {
      value = kDefaultSeed;
    }
  }

  /// Применить локально — чтобы админ увидел выбор мгновенно.
  void apply(int seed) => value = seed;

  /// Вернуть цвет по умолчанию (при выходе из аккаунта).
  void reset() => value = kDefaultSeed;
}
