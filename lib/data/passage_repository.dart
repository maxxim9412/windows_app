import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/passage.dart';
import '../services/auth_service.dart';
import '../utils/date_helpers.dart';

/// График отрывков QT конкретной церкви (Firestore:
/// `churches/{churchId}/passages/{date}`). Ведёт админ церкви, остальные —
/// только чтение. Если у пользователя не выбрана церковь — пусто.
class PassageRepository {
  PassageRepository._();
  static final PassageRepository instance = PassageRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<CollectionReference<Map<String, dynamic>>?> _col() async {
    final cid = await AuthService.instance.currentChurchId();
    if (cid == null) return null;
    return _db.collection('churches').doc(cid).collection('passages');
  }

  Passage _fromDoc(String date, Map<String, dynamic> d) => Passage(
        date: date,
        bookCode: d['book_code'] as String,
        chapter: (d['chapter'] as num).toInt(),
        verseStart: (d['verse_start'] as num).toInt(),
        verseEnd: (d['verse_end'] as num).toInt(),
      );

  Future<Passage?> forDate(DateTime day) async {
    final col = await _col();
    if (col == null) return null;
    final doc = await col.doc(dateKey(day)).get();
    if (!doc.exists) return null;
    return _fromDoc(doc.id, doc.data()!);
  }

  Future<List<Passage>> all() async {
    final col = await _col();
    if (col == null) return const [];
    final q = await col.orderBy(FieldPath.documentId, descending: true).get();
    return q.docs.map((doc) => _fromDoc(doc.id, doc.data())).toList();
  }

  Future<void> upsert(Passage p) async {
    final col = await _col();
    if (col == null) return;
    await col.doc(p.date).set({
      'book_code': p.bookCode,
      'chapter': p.chapter,
      'verse_start': p.verseStart,
      'verse_end': p.verseEnd,
    });
  }

  Future<void> deleteByDate(String date) async {
    final col = await _col();
    if (col == null) return;
    await col.doc(date).delete();
  }
}
