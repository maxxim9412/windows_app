import 'package:bible_reflection/utils/app_themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('themeById', () {
    test('незнакомый id из базы не роняет приложение, а даёт тему по умолчанию',
        () {
      expect(themeById('несуществующая').id, kAppThemes.first.id);
    });

    test('оформление не выбрано — тема по умолчанию', () {
      expect(themeById(null).id, kAppThemes.first.id);
    });

    test('каждый id находится', () {
      for (final t in kAppThemes) {
        expect(themeById(t.id).id, t.id);
      }
    });
  });

  test('id уникальны — иначе выбор в базе стал бы неоднозначным', () {
    expect(kAppThemes.map((t) => t.id).toSet().length, kAppThemes.length);
  });

  group('схемы', () {
    test('каждая тема даёт светлую и тёмную схему', () {
      for (final t in kAppThemes) {
        expect(t.scheme(Brightness.light).brightness, Brightness.light);
        expect(t.scheme(Brightness.dark).brightness, Brightness.dark);
      }
    });

    test('темы различимы: у приглушённой другой primary, чем у классической',
        () {
      final classic = themeById('classic').scheme(Brightness.light);
      final quiet = themeById('quiet').scheme(Brightness.light);
      expect(classic.primary, isNot(quiet.primary),
          reason: 'одно зерно, но разный вариант раскладки — цвета должны разойтись');
    });
  });
}
