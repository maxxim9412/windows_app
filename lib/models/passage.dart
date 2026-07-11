import '../utils/bible_books.dart';

/// Отрывок, назначенный администратором на конкретный день.
class Passage {
  final int? id;
  final String date; // yyyy-MM-dd — день, на который назначен отрывок
  final String bookCode;
  final int chapter;
  final int verseStart;
  final int verseEnd;

  const Passage({
    this.id,
    required this.date,
    required this.bookCode,
    required this.chapter,
    required this.verseStart,
    required this.verseEnd,
  });

  /// Адрес отрывка в привычном виде, напр. «От Иоанна 3:16–17».
  String get reference {
    final vs = verseStart == verseEnd ? '$verseStart' : '$verseStart–$verseEnd';
    return '${bookName(bookCode)} $chapter:$vs';
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'date': date,
        'book_code': bookCode,
        'chapter': chapter,
        'verse_start': verseStart,
        'verse_end': verseEnd,
      };

  factory Passage.fromMap(Map<String, Object?> m) => Passage(
        id: m['id'] as int?,
        date: m['date'] as String,
        bookCode: m['book_code'] as String,
        chapter: m['chapter'] as int,
        verseStart: m['verse_start'] as int,
        verseEnd: m['verse_end'] as int,
      );
}
