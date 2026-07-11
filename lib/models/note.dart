import '../utils/note_questions.dart';

/// Личная заметка/размышление за день. Состоит из ответов на [kNoteQuestions],
/// но хранится и воспринимается как одна заметка.
class Note {
  final int? id;
  final String date; // yyyy-MM-dd — один день = одна заметка
  final List<String> answers; // длина = kNoteFieldCount
  final int updatedAt; // millisecondsSinceEpoch

  Note({
    this.id,
    required this.date,
    required List<String> answers,
    required this.updatedAt,
  }) : answers = _normalize(answers);

  static List<String> _normalize(List<String> a) {
    final list = List<String>.from(a);
    while (list.length < kNoteFieldCount) {
      list.add('');
    }
    return list.sublist(0, kNoteFieldCount);
  }

  bool get isEmpty => answers.every((a) => a.trim().isEmpty);

  /// Есть ли хоть один заполненный ответ (для отметок «сделал сегодня»).
  bool get isDone => !isEmpty;

  /// Единый текст заметки, разбитый по вопросам (для истории/просмотра/обмена).
  String get combined {
    final parts = <String>[];
    for (var i = 0; i < kNoteFieldCount; i++) {
      final answer = answers[i].trim();
      if (answer.isNotEmpty) {
        parts.add('${kNoteQuestions[i]}\n$answer');
      }
    }
    return parts.join('\n\n');
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'date': date,
        'a1': answers[0],
        'a2': answers[1],
        'a3': answers[2],
        'a4': answers[3],
        'updated_at': updatedAt,
      };

  factory Note.fromMap(Map<String, Object?> m) => Note(
        id: m['id'] as int?,
        date: m['date'] as String,
        answers: [
          (m['a1'] as String?) ?? '',
          (m['a2'] as String?) ?? '',
          (m['a3'] as String?) ?? '',
          (m['a4'] as String?) ?? '',
        ],
        updatedAt: (m['updated_at'] as int?) ?? 0,
      );
}
