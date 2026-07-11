import 'package:sqflite/sqflite.dart';

import '../models/passage.dart';
import '../utils/date_helpers.dart';
import 'db.dart';

/// Расписание отрывков по дням. В MVP наполняется администратором,
/// при первом запуске подсевается несколько примеров на ближайшие будни.
class PassageRepository {
  PassageRepository._();
  static final PassageRepository instance = PassageRepository._();

  Future<Passage?> forDate(DateTime day) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('passages',
        where: 'date = ?', whereArgs: [dateKey(day)], limit: 1);
    if (rows.isEmpty) return null;
    return Passage.fromMap(rows.first);
  }

  Future<List<Passage>> all() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('passages', orderBy: 'date DESC');
    return rows.map(Passage.fromMap).toList();
  }

  /// Добавить/заменить отрывок на день (один день — один отрывок).
  Future<void> upsert(Passage passage) async {
    final db = await AppDatabase.instance.database;
    await db.insert('passages', passage.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(int id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('passages', where: 'id = ?', whereArgs: [id]);
  }

  /// Подсев примеров при первом запуске: раздаём отрывки из образца
  /// на ближайшие 5 будних дней, начиная с сегодня.
  Future<void> seedIfEmpty() async {
    final existing = await all();
    if (existing.isNotEmpty) return;

    const samples = [
      ('jn', 3, 16, 17),
      ('mf', 5, 3, 10),
      ('ps', 22, 1, 6),
      ('rim', 8, 1, 4),
      ('flp', 4, 4, 7),
    ];

    var day = dateOnly(DateTime.now());
    for (final s in samples) {
      while (!isWeekday(day)) {
        day = day.add(const Duration(days: 1));
      }
      await upsert(Passage(
        date: dateKey(day),
        bookCode: s.$1,
        chapter: s.$2,
        verseStart: s.$3,
        verseEnd: s.$4,
      ));
      day = day.add(const Duration(days: 1));
    }
  }
}
