import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/reading.dart';
import '../services/auth_service.dart';
import '../utils/date_helpers.dart';

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
        verseStart: (m['verse_start'] as num?)?.toInt(),
        verseEnd: (m['verse_end'] as num?)?.toInt(),
        orderIndex: i,
      ));
    }
    return list;
  }

  Map<String, dynamic> _toItem(Reading r) => {
        'book_code': r.bookCode,
        'chapter_start': r.chapterStart,
        'chapter_end': r.chapterEnd,
        if (r.verseStart != null) 'verse_start': r.verseStart,
        if (r.verseEnd != null) 'verse_end': r.verseEnd,
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
    // Сортировка на клиенте — см. пояснение в PassageRepository.all().
    final q = await col.get();
    final docs = q.docs.toList()..sort((a, b) => b.id.compareTo(a.id));
    final list = <Reading>[];
    for (final doc in docs) {
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

  // --- Отметки о прочтении (личные) -------------------------------------
  // Храним в карте `readingDone` профиля пользователя (`users/{uid}`) —
  // одинаково на телефоне и в вебе, поэтому прогресс общий на всех устройствах.
  // Отдельного правила Firestore не нужно: владелец и так пишет свой документ.
  // Раньше на мобильных это была локальная SQLite, и отметки не покидали телефон.

  Future<Map<String, dynamic>> _doneMap() async {
    final uid = AuthService.instance.uid;
    if (uid == null) return const {};
    final doc = await _db.collection('users').doc(uid).get();
    return (doc.data()?['readingDone'] as Map<String, dynamic>?) ?? const {};
  }

  Future<bool> isDone(DateTime day) async {
    final map = await _doneMap();
    return map[dateKey(day)] == true;
  }

  /// Все даты (yyyy-MM-dd), отмеченные как прочитанные — для календаря прогресса.
  Future<Set<String>> doneDates() async {
    final map = await _doneMap();
    return map.entries.where((e) => e.value == true).map((e) => e.key).toSet();
  }

  Future<void> setDone(DateTime day, bool done) async {
    final uid = AuthService.instance.uid;
    if (uid == null) return;
    // merge:true объединяет ключи вложенной карты, не затирая другие даты.
    await _db.collection('users').doc(uid).set({
      'readingDone': {dateKey(day): done},
    }, SetOptions(merge: true));
  }

  // --- Отметки по главам -------------------------------------------------
  // `readingChapters` — карта «дата → {ключ главы → прочитана}». Нужна, чтобы
  // можно было прервать чтение на середине дня и вечером увидеть, где
  // остановился. `readingDone` при этом остаётся отметкой дня целиком — на неё
  // смотрит календарь, и её мы держим в согласии со списком глав.

  /// Ключи глав, прочитанных в этот день.
  Future<Set<String>> doneChapters(DateTime day) async {
    final uid = AuthService.instance.uid;
    if (uid == null) return {};
    final doc = await _db.collection('users').doc(uid).get();
    final byDate =
        doc.data()?['readingChapters'] as Map<String, dynamic>? ?? const {};
    final map = byDate[dateKey(day)] as Map<String, dynamic>? ?? const {};
    return map.entries.where((e) => e.value == true).map((e) => e.key).toSet();
  }

  /// Отметить главу и заодно перезаписать отметку дня одной операцией: иначе
  /// при обрыве между двумя записями день и главы разошлись бы.
  ///
  /// [dayComplete] считает вызывающий — только он знает полный список глав дня.
  Future<void> setChapterDone(
    DateTime day,
    String chapterKey,
    bool done, {
    required bool dayComplete,
  }) async {
    final uid = AuthService.instance.uid;
    if (uid == null) return;
    final key = dateKey(day);
    await _db.collection('users').doc(uid).set({
      'readingChapters': {
        key: {chapterKey: done},
      },
      'readingDone': {key: dayComplete},
    }, SetOptions(merge: true));
  }
}
