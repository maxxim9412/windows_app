import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/passage.dart';
import '../utils/date_helpers.dart';

/// Общий для всех пользователей график отрывков QT (Firestore, коллекция
/// `passages`, id документа = дата yyyy-MM-dd). Наполняет администратор,
/// остальные видят только для чтения.
class PassageRepository {
  PassageRepository._();
  static final PassageRepository instance = PassageRepository._();

  final CollectionReference<Map<String, dynamic>> _col =
      FirebaseFirestore.instance.collection('passages');

  Passage _fromDoc(String date, Map<String, dynamic> d) => Passage(
        date: date,
        bookCode: d['book_code'] as String,
        chapter: (d['chapter'] as num).toInt(),
        verseStart: (d['verse_start'] as num).toInt(),
        verseEnd: (d['verse_end'] as num).toInt(),
      );

  Future<Passage?> forDate(DateTime day) async {
    final doc = await _col.doc(dateKey(day)).get();
    if (!doc.exists) return null;
    return _fromDoc(doc.id, doc.data()!);
  }

  Future<List<Passage>> all() async {
    final q =
        await _col.orderBy(FieldPath.documentId, descending: true).get();
    return q.docs.map((doc) => _fromDoc(doc.id, doc.data())).toList();
  }

  /// Добавить/заменить отрывок на день (только админ — по правилам Firestore).
  Future<void> upsert(Passage p) async {
    await _col.doc(p.date).set({
      'book_code': p.bookCode,
      'chapter': p.chapter,
      'verse_start': p.verseStart,
      'verse_end': p.verseEnd,
    });
  }

  Future<void> deleteByDate(String date) async {
    await _col.doc(date).delete();
  }
}
