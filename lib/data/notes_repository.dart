import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import '../models/note.dart';
import '../utils/date_helpers.dart';
import 'db.dart';

/// Личные заметки: одна заметка на день (4 ответа), хранится локально.
class NotesRepository {
  NotesRepository._();
  static final NotesRepository instance = NotesRepository._();

  Future<Note?> forDate(DateTime day) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('notes',
        where: 'date = ?', whereArgs: [dateKey(day)], limit: 1);
    if (rows.isEmpty) return null;
    return Note.fromMap(rows.first);
  }

  Future<List<Note>> all() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('notes', orderBy: 'date DESC');
    return rows.map(Note.fromMap).toList();
  }

  /// Сохранить ответы за день. Если все пустые — удаляем запись.
  Future<void> save(DateTime day, List<String> answers) async {
    final db = await AppDatabase.instance.database;
    final key = dateKey(day);
    final note = Note(
      date: key,
      answers: answers,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    if (note.isEmpty) {
      await db.delete('notes', where: 'date = ?', whereArgs: [key]);
      return;
    }
    await db.insert('notes', note.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
