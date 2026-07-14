import '../utils/bible_books.dart';

/// Запись плана чтения: диапазон глав книги на день. Опционально — диапазон
/// стихов внутри одной главы (напр. длинный псалом по частям: Пс 118:1–88).
class Reading {
  final int? id;
  final String date; // yyyy-MM-dd
  final String bookCode;
  final int chapterStart;
  final int chapterEnd;
  final int? verseStart; // если задан — читаем не всю главу, а стихи
  final int? verseEnd;
  final int orderIndex;

  const Reading({
    this.id,
    required this.date,
    required this.bookCode,
    required this.chapterStart,
    required this.chapterEnd,
    this.verseStart,
    this.verseEnd,
    this.orderIndex = 0,
  });

  bool get hasVerses => verseStart != null && verseEnd != null;

  /// Напр. «Бытие 1–3», «От Матфея 5» или «Псалтирь 118:1–88».
  String get reference {
    if (hasVerses) {
      final vs =
          verseStart == verseEnd ? '$verseStart' : '$verseStart–$verseEnd';
      return '${bookName(bookCode)} $chapterStart:$vs';
    }
    final ch = chapterStart == chapterEnd
        ? '$chapterStart'
        : '$chapterStart–$chapterEnd';
    return '${bookName(bookCode)} $ch';
  }

  Iterable<int> get chapters =>
      List.generate(chapterEnd - chapterStart + 1, (i) => chapterStart + i);
}
