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

  /// Развернуть план дня в плоский список глав, сохраняя порядок.
  static List<ReadingChapter> expandAll(List<Reading> readings) => [
        for (final r in readings)
          for (final ch in r.chapters) ReadingChapter(r, ch),
      ];
}
