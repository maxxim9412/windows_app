/// Личная заметка/размышление за конкретный день.
class Note {
  final int? id;
  final String date; // yyyy-MM-dd — один день = одна заметка
  final String content;
  final int updatedAt; // millisecondsSinceEpoch

  const Note({
    this.id,
    required this.date,
    required this.content,
    required this.updatedAt,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'date': date,
        'content': content,
        'updated_at': updatedAt,
      };

  factory Note.fromMap(Map<String, Object?> m) => Note(
        id: m['id'] as int?,
        date: m['date'] as String,
        content: m['content'] as String,
        updatedAt: m['updated_at'] as int,
      );
}
