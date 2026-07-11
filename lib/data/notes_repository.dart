import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import '../models/note.dart';
import '../utils/date_helpers.dart';
import 'db.dart';

/// Личные заметки: одна заметка на день, хранится локально.
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

  /// Сохранить заметку дня. Пустой текст — удаляем запись.
  Future<void> save(DateTime day, String content) async {
    final db = await AppDatabase.instance.database;
    final key = dateKey(day);
    if (content.trim().isEmpty) {
      await db.delete('notes', where: 'date = ?', whereArgs: [key]);
      return;
    }
    await db.insert(
      'notes',
      Note(
        date: key,
        content: content,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
