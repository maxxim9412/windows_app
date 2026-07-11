import '../utils/bible_books.dart';

/// Запись плана чтения: диапазон глав книги на конкретный день.
class Reading {
  final int? id;
  final String date; // yyyy-MM-dd
  final String bookCode;
  final int chapterStart;
  final int chapterEnd;
  final int orderIndex;

  const Reading({
    this.id,
    required this.date,
    required this.bookCode,
    required this.chapterStart,
    required this.chapterEnd,
    this.orderIndex = 0,
  });

  /// Напр. «Бытие 1–3» или «От Матфея 5».
  String get reference {
    final ch = chapterStart == chapterEnd
        ? '$chapterStart'
        : '$chapterStart–$chapterEnd';
    return '${bookName(bookCode)} $ch';
  }

  Iterable<int> get chapters =>
      List.generate(chapterEnd - chapterStart + 1, (i) => chapterStart + i);

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'date': date,
        'book_code': bookCode,
        'chapter_start': chapterStart,
        'chapter_end': chapterEnd,
        'order_index': orderIndex,
      };

  factory Reading.fromMap(Map<String, Object?> m) => Reading(
        id: m['id'] as int?,
        date: m['date'] as String,
        bookCode: m['book_code'] as String,
        chapterStart: m['chapter_start'] as int,
        chapterEnd: m['chapter_end'] as int,
        orderIndex: (m['order_index'] as int?) ?? 0,
      );
}
