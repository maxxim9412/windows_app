import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import '../models/reading.dart';
import '../services/auth_service.dart';
import '../utils/date_helpers.dart';
import 'db.dart';

/// План чтения конкретной церкви (Firestore:
/// `churches/{churchId}/readings/{date}`, поле `items`). Ведёт админ церкви.
/// Отметки «прочитано» — личные, локально (SQLite `reading_done`).
class ReadingRepository {
  ReadingRepository._();
  static final ReadingRepository instance = ReadingRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<CollectionReference<Map<String, dynamic>>?> _col() async {
    final cid = await AuthService.instance.currentChurchId();
    if (cid == null) return null;
    return _db.collection('churches').doc(cid).collection('readings');
  }

  List<Reading> _parse(String date, Map<String, dynamic> d) {
    final items = (d['items'] as List?) ?? const [];
    final list = <Reading>[];
    for (var i = 0; i < items.length; i++) {
      final m = items[i] as Map<String, dynamic>;
      list.add(Reading(
        date: date,
        bookCode: m['book_code'] as String,
        chapterStart: (m['chapter_start'] as num).toInt(),
        chapterEnd: (m['chapter_end'] as num).toInt(),
        orderIndex: i,
      ));
    }
    return list;
  }

  Map<String, dynamic> _toItem(Reading r) => {
        'book_code': r.bookCode,
        'chapter_start': r.chapterStart,
        'chapter_end': r.chapterEnd,
      };

  Future<List<Reading>> forDate(DateTime day) async {
    final col = await _col();
    if (col == null) return const [];
    final doc = await col.doc(dateKey(day)).get();
    if (!doc.exists) return const [];
    return _parse(doc.id, doc.data()!);
  }

  Future<List<Reading>> all() async {
    final col = await _col();
    if (col == null) return const [];
    final q = await col.orderBy(FieldPath.documentId, descending: true).get();
    final list = <Reading>[];
    for (final doc in q.docs) {
      list.addAll(_parse(doc.id, doc.data()));
    }
    return list;
  }

  Future<void> setDateItems(String date, List<Reading> items) async {
    final col = await _col();
    if (col == null) return;
    await col.doc(date).set({'items': items.map(_toItem).toList()});
  }

  Future<void> addPortion(String date, Reading r) async {
    final existing = await forDate(DateTime.parse(date));
    await setDateItems(date, [...existing, r]);
  }

  Future<void> deleteDate(String date) async {
    final col = await _col();
    if (col == null) return;
    await col.doc(date).delete();
  }

  Future<void> removePortion(String date, int orderIndex) async {
    final items = await forDate(DateTime.parse(date));
    items.removeWhere((r) => r.orderIndex == orderIndex);
    if (items.isEmpty) {
      await deleteDate(date);
    } else {
      await setDateItems(date, items);
    }
  }

  // --- Отметки о прочтении (личные, локально) ---------------------------

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
}
