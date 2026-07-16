import '../utils/bible_books.dart';
import 'reading.dart';

/// Одна глава из плана на день — единица и чтения, и отметки.
///
/// План на день может состоять из нескольких записей, каждая — с диапазоном
/// глав («Быт 1–3»). Для показа списком и отметок нужен плоский перечень глав.
class ReadingChapter {
  const ReadingChapter(this.reading, this.chapter);

  final Reading reading;
  final int chapter;

  String get key => reading.chapterKey(chapter);
  String get reference => reading.referenceFor(chapter);

  /// Порядок чтения: 0 — псалмы, 1 — остальной Ветхий Завет, 2 — Новый.
  static int _group(String bookCode) {
    if (isPsalms(bookCode)) return 0;
    return isNewTestament(bookCode) ? 2 : 1;
  }

  /// Развернуть план дня в плоский список глав в порядке чтения: сначала
  /// псалмы, затем Ветхий Завет, затем Новый; внутри — канонический порядок
  /// книг, номер главы, начальный стих.
  ///
  /// Порядок намеренно не зависит от того, как админ добавлял главы в план:
  /// читающий каждый день видит одну и ту же последовательность.
  static List<ReadingChapter> expandAll(List<Reading> readings) {
    final list = <ReadingChapter>[
      for (final r in readings)
        for (final ch in r.chapters) ReadingChapter(r, ch),
    ];
    list.sort((a, b) {
      final byGroup =
          _group(a.reading.bookCode).compareTo(_group(b.reading.bookCode));
      if (byGroup != 0) return byGroup;
      final byBook =
          bookIndex(a.reading.bookCode).compareTo(bookIndex(b.reading.bookCode));
      if (byBook != 0) return byBook;
      final byChapter = a.chapter.compareTo(b.chapter);
      if (byChapter != 0) return byChapter;
      return (a.reading.verseStart ?? 0).compareTo(b.reading.verseStart ?? 0);
    });
    return list;
  }
}
