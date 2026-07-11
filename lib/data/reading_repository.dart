import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import '../models/reading.dart';
import '../utils/date_helpers.dart';
import 'db.dart';

/// План чтения по дням + отметки о прочтении.
class ReadingRepository {
  ReadingRepository._();
  static final ReadingRepository instance = ReadingRepository._();

  Future<List<Reading>> forDate(DateTime day) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('readings',
        where: 'date = ?', whereArgs: [dateKey(day)], orderBy: 'order_index, id');
    return rows.map(Reading.fromMap).toList();
  }

  Future<List<Reading>> all() async {
    final db = await AppDatabase.instance.database;
    final rows =
        await db.query('readings', orderBy: 'date DESC, order_index, id');
    return rows.map(Reading.fromMap).toList();
  }

  Future<void> insert(Reading reading) async {
    final db = await AppDatabase.instance.database;
    await db.insert('readings', reading.toMap());
  }

  Future<void> deleteDate(String date) async {
    final db = await AppDatabase.instance.database;
    await db.delete('readings', where: 'date = ?', whereArgs: [date]);
  }

  Future<void> delete(int id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('readings', where: 'id = ?', whereArgs: [id]);
  }

  // --- Отметки о прочтении ---------------------------------------------

  Future<bool> isDone(DateTime day) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('reading_done',
        where: 'date = ?', whereArgs: [dateKey(day)], limit: 1);
    if (rows.isEmpty) return false;
    return (rows.first['done'] as int) == 1;
  }

  Future<void> setDone(DateTime day, bool done) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'reading_done',
      {'date': dateKey(day), 'done': done ? 1 : 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Множество дат (yyyy-MM-dd), отмеченных как прочитанные.
  Future<Set<String>> doneDates() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('reading_done', where: 'done = 1');
    return rows.map((r) => r['date'] as String).toSet();
  }
}
