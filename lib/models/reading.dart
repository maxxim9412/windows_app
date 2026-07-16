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

  /// Ссылка на одну главу внутри записи: «Бытие 1» (а не «Бытие 1–3») или
  /// «Псалтирь 118:1–88», если читается часть главы.
  String referenceFor(int chapter) {
    if (hasVerses) {
      final vs =
          verseStart == verseEnd ? '$verseStart' : '$verseStart–$verseEnd';
      return '${bookName(bookCode)} $chapter:$vs';
    }
    return '${bookName(bookCode)} $chapter';
  }

  /// Ключ отметки о прочтении главы. Диапазон стихов входит в ключ: на один
  /// день можно назначить и «Пс 118:1–88», и «Пс 118:89–176» — это одна глава,
  /// но разные порции, и путать их отметки нельзя.
  String chapterKey(int chapter) {
    final base = '$bookCode-$chapter';
    return hasVerses ? '$base:$verseStart-$verseEnd' : base;
  }
}
