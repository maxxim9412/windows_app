import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/note.dart';
import '../services/auth_service.dart';
import '../services/triad_service.dart';
import '../utils/date_helpers.dart';

/// Личные заметки: одна заметка на день (4 ответа). Единственное хранилище —
/// Firestore (`users/{uid}/notes/{date}`), одинаково на телефоне и в вебе,
/// поэтому прогресс на всех устройствах общий.
///
/// Раньше на мобильных основой была локальная SQLite, а в облако заметки лишь
/// зеркалировались — из-за этого телефон и веб расходились. Офлайн при этом не
/// потерян: у Firestore на мобильных включён кэш, чтение идёт из него, а записи
/// накапливаются и уходят при появлении сети.
class NotesRepository {
  NotesRepository._();
  static final NotesRepository instance = NotesRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>>? _col() {
    final uid = AuthService.instance.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('notes');
  }

  Note _fromDoc(String date, Map<String, dynamic> d) => Note(
        date: date,
        answers: [
          (d['a1'] as String?) ?? '',
          (d['a2'] as String?) ?? '',
          (d['a3'] as String?) ?? '',
          (d['a4'] as String?) ?? '',
        ],
        updatedAt: (d['updatedAt'] as num?)?.toInt() ?? 0,
      );

  Future<Note?> forDate(DateTime day) async {
    final col = _col();
    if (col == null) return null;
    final doc = await col.doc(dateKey(day)).get();
    if (!doc.exists) return null;
    return _fromDoc(doc.id, doc.data()!);
  }

  Future<List<Note>> all() async {
    final col = _col();
    if (col == null) return const [];
    // Сортируем на клиенте: id документа = дата (yyyy-MM-dd), т.е. лексикографи-
    // ческий порядок совпадает с хронологическим, а orderBy по documentId в
    // вебе ненадёжен.
    final q = await col.get();
    final notes = q.docs.map((doc) => _fromDoc(doc.id, doc.data())).toList();
    notes.sort((a, b) => b.date.compareTo(a.date));
    return notes;
  }

  /// Сохранить ответы за день. Если все пустые — удаляем запись.
  ///
  /// Подтверждения сервера намеренно не ждём: Firestore уже положил запись в
  /// локальный кэш и досинхронизирует сам. Иначе при плохой сети автосохранение
  /// «висело» бы, показывая «Сохранение…» на уже сохранённой заметке.
  Future<void> save(DateTime day, List<String> answers) async {
    final col = _col();
    if (col == null) return;
    final key = dateKey(day);
    final note = Note(
      date: key,
      answers: answers,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    final ref = col.doc(key);

    if (note.isEmpty) {
      unawaited(ref.delete().catchError(_logError));
      return;
    }
    // Кому видна заметка: участникам ВСЕХ моих троек (человек может быть в
    // нескольких). visibleTo проверяется правилом; triadId остаётся для
    // заметок и клиентов старого формата.
    final triadId = await TriadService.instance.currentTriadId();
    final visibleTo = await TriadService.instance.visibleToUids();
    unawaited(ref.set({
      'a1': note.answers[0],
      'a2': note.answers[1],
      'a3': note.answers[2],
      'a4': note.answers[3],
      'done': note.isDone,
      'triadId': triadId,
      'visibleTo': visibleTo,
      'updatedAt': note.updatedAt,
    }).catchError(_logError));
  }

  void _logError(Object e) => debugPrint('[notes] запись не прошла: $e');

  /// Живой поток заметки участника за день (для отметок «кто сделал сегодня»).
  Stream<Note?> memberNoteStream(String uid, DateTime day) {
    final key = dateKey(day);
    return _db
        .collection('users')
        .doc(uid)
        .collection('notes')
        .doc(key)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return _fromDoc(key, doc.data()!);
    }).handleError((_) => null);
  }

  /// Заметка участника тройки за день (для обмена и отметок).
  Future<Note?> fetchMemberNote(String uid, DateTime day) async {
    final key = dateKey(day);
    try {
      final doc = await _db
          .collection('users')
          .doc(uid)
          .collection('notes')
          .doc(key)
          .get();
      if (!doc.exists) return null;
      return _fromDoc(key, doc.data()!);
    } catch (_) {
      return null;
    }
  }
}
