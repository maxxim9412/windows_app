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
    test('разворачивает диапазоны в плоский список', () {
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

    test('порядок: псалмы → Ветхий Завет → Новый, как бы ни добавляли', () {
      // Админ забил вперемешку: НЗ, ВЗ, псалом.
      const readings = [
        Reading(
            date: '2026-07-15', bookCode: 'jn', chapterStart: 3, chapterEnd: 3),
        Reading(
            date: '2026-07-15', bookCode: 'gen', chapterStart: 1, chapterEnd: 1),
        Reading(
            date: '2026-07-15', bookCode: 'ps', chapterStart: 23, chapterEnd: 23),
      ];
      final list = ReadingChapter.expandAll(readings);
      expect(list.map((c) => c.reference).toList(),
          ['Псалтирь 23', 'Бытие 1', 'От Иоанна 3']);
    });

    test('обратный порядок добавления даёт тот же результат', () {
      const a = Reading(
          date: '2026-07-15', bookCode: 'ps', chapterStart: 23, chapterEnd: 23);
      const b = Reading(
          date: '2026-07-15', bookCode: 'gen', chapterStart: 1, chapterEnd: 1);
      const c = Reading(
          date: '2026-07-15', bookCode: 'jn', chapterStart: 3, chapterEnd: 3);
      expect(
        ReadingChapter.expandAll([a, b, c]).map((x) => x.reference).toList(),
        ReadingChapter.expandAll([c, b, a]).map((x) => x.reference).toList(),
      );
    });

    test('псалмы идут первыми, хотя в каноне стоят в середине Ветхого', () {
      const readings = [
        Reading(
            date: '2026-07-15', bookCode: 'gen', chapterStart: 1, chapterEnd: 1),
        Reading(
            date: '2026-07-15', bookCode: 'ps', chapterStart: 1, chapterEnd: 1),
      ];
      final list = ReadingChapter.expandAll(readings);
      expect(list.first.reference, 'Псалтирь 1',
          reason: 'Бытие каноничнее, но псалом читаем первым');
    });

    test('внутри Ветхого — канонический порядок книг', () {
      const readings = [
        Reading(
            date: '2026-07-15', bookCode: 'isa', chapterStart: 6, chapterEnd: 6),
        Reading(
            date: '2026-07-15', bookCode: 'exo', chapterStart: 2, chapterEnd: 2),
      ];
      expect(ReadingChapter.expandAll(readings).map((c) => c.reference).toList(),
          ['Исход 2', 'Исаия 6']);
    });

    test('две порции одной главы идут по возрастанию стихов', () {
      const second = Reading(
        date: '2026-07-15',
        bookCode: 'ps',
        chapterStart: 118,
        chapterEnd: 118,
        verseStart: 89,
        verseEnd: 176,
      );
      const first = Reading(
        date: '2026-07-15',
        bookCode: 'ps',
        chapterStart: 118,
        chapterEnd: 118,
        verseStart: 1,
        verseEnd: 88,
      );
      expect(
          ReadingChapter.expandAll([second, first])
              .map((c) => c.reference)
              .toList(),
          ['Псалтирь 118:1–88', 'Псалтирь 118:89–176']);
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
