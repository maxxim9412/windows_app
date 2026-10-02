import 'package:bible_reflection/utils/reference_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseChapterLine — книги с номером', () {
    test('4Цар — это 4-я Царств (2ki), раньше формат не распознавался', () {
      for (final line in ['4Цар.1-2', '4Цар. 3-4', '4 Цар 5', '4Цар.7']) {
        final r = parseChapterLine(line);
        expect(r.ok, isTrue, reason: line);
        expect(r.ref!.bookCode, '2ki', reason: line);
      }
    });

    test('1–3 тоже работают', () {
      expect(parseChapterLine('3Цар.15-16').ref!.bookCode, '1ki');
      expect(parseChapterLine('1Кор.13').ref!.bookCode, '1co');
    });

    test('диапазон глав разбирается целиком', () {
      final r = parseChapterLine('4Цар. 3-4').ref!;
      expect(r.chapterStart, 3);
      expect(r.chapterEnd, 4);
    });
  });

  group('parseReferenceLine — со стихами', () {
    test('4Цар 2:1-10', () {
      final r = parseReferenceLine('4Цар 2:1-10');
      expect(r.ok, isTrue);
      expect(r.ref!.bookCode, '2ki');
    });
  });
}
