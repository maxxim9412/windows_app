import 'package:bible_reflection/utils/app_themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('палитра', () {
    test('десять цветов, все зёрна уникальны', () {
      expect(kThemeColors.length, 10);
      expect(kThemeColors.map((c) => c.seed).toSet().length, 10);
    });

    test('цвет по умолчанию — из палитры (Синий)', () {
      expect(kThemeColors.any((c) => c.seed == kDefaultSeed), isTrue);
      expect(colorName(kDefaultSeed), 'Синий');
    });

    test('незнакомое зерно подписывается как «Свой цвет»', () {
      expect(colorName(0xFF123456), 'Свой цвет');
    });

    test('каждое зерно даёт светлую и тёмную схему', () {
      for (final c in kThemeColors) {
        expect(
            ColorScheme.fromSeed(
                    seedColor: Color(c.seed), brightness: Brightness.light)
                .brightness,
            Brightness.light);
        expect(
            ColorScheme.fromSeed(
                    seedColor: Color(c.seed), brightness: Brightness.dark)
                .brightness,
            Brightness.dark);
      }
    });
  });

  group('перенос старых шаблонов', () {
    test('sage → зелёный, sand → оранжевый', () {
      expect(seedForLegacyTheme('sage'), 0xFF2E9E3A);
      expect(seedForLegacyTheme('sand'), 0xFFE0601C);
    });

    test('classic/quiet/неизвестное/null → цвет по умолчанию', () {
      for (final id in ['classic', 'quiet', 'что-то', null]) {
        expect(seedForLegacyTheme(id), kDefaultSeed);
      }
    });
  });
}
