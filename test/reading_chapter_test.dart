import 'package:bible_reflection/models/reading.dart';
import 'package:bible_reflection/models/reading_chapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Reading.referenceFor', () {
    test('внутри диапазона глав показывает одну главу, а не весь диапазон', () {
      const r = Reading(
          date: '2026-07-15', bookCode: 'gen', chapterStart: 1, chapterEnd: 3);
      expect(r.reference, 'Бытие 1–3');
      expect(r.referenceFor(2), 'Бытие 2');
    });

    test('часть главы показывает диапазон стихов', () {
      const r = Reading(
        date: '2026-07-15',
        bookCode: 'ps',
        chapterStart: 118,
        chapterEnd: 118,
        verseStart: 1,
        verseEnd: 88,
      );
      expect(r.referenceFor(118), 'Псалтирь 118:1–88');
    });
  });

  group('Reading.chapterKey', () {
    test('две порции одной главы дают разные ключи', () {
      const first = Reading(
        date: '2026-07-15',
        bookCode: 'ps',
        chapterStart: 118,
        chapterEnd: 118,
        verseStart: 1,
        verseEnd: 88,
      );
      const second = Reading(
        date: '2026-07-15',
        bookCode: 'ps',
        chapterStart: 118,
        chapterEnd: 118,
        verseStart: 89,
        verseEnd: 176,
      );
      expect(first.chapterKey(118), isNot(second.chapterKey(118)),
          reason: 'иначе отметка одной порции закрыла бы вторую');
    });

    test('главы целиком различаются по книге и номеру', () {
      const gen = Reading(
          date: '2026-07-15', bookCode: 'gen', chapterStart: 1, chapterEnd: 3);
      expect(gen.chapterKey(1), 'gen-1');
      expect(gen.chapterKey(2), isNot(gen.chapterKey(1)));
    });
  });

  group('ReadingChapter.expandAll', () {
    test('разворачивает диапазоны в плоский список с сохранением порядка', () {
      const readings = [
        Reading(
            date: '2026-07-15', bookCode: 'gen', chapterStart: 1, chapterEnd: 3),
        Reading(
            date: '2026-07-15', bookCode: 'mf', chapterStart: 5, chapterEnd: 5),
      ];
      final list = ReadingChapter.expandAll(readings);
      expect(list.map((c) => c.reference).toList(),
          ['Бытие 1', 'Бытие 2', 'Бытие 3', 'От Матфея 5']);
    });

    test('ключи глав в пределах дня уникальны', () {
      const readings = [
        Reading(
            date: '2026-07-15', bookCode: 'gen', chapterStart: 1, chapterEnd: 3),
      ];
      final keys = ReadingChapter.expandAll(readings).map((c) => c.key).toSet();
      expect(keys.length, 3);
    });
  });
}
