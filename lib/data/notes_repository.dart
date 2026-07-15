import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import '../models/note.dart';
import '../services/auth_service.dart';
import '../services/triad_service.dart';
import '../utils/date_helpers.dart';
import 'db.dart';

/// Личные заметки: одна заметка на день (4 ответа). На мобильных основное
/// хранилище — локальная SQLite (с зеркалированием в Firestore). В вебе
/// браузерная SQLite ненадёжна (iOS Safari), поэтому там читаем/пишем прямо
/// в Firestore — те же документы `users/{uid}/notes/{date}`.
class NotesRepository {
  NotesRepository._();
  static final NotesRepository instance = NotesRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Note _noteFromCloud(String date, Map<String, dynamic> d) => Note(
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
    if (kIsWeb) {
      final uid = AuthService.instance.uid;
      if (uid == null) return null;
      final doc = await _db
          .collection('users')
          .doc(uid)
          .collection('notes')
          .doc(dateKey(day))
          .get();
      if (!doc.exists) return null;
      return _noteFromCloud(doc.id, doc.data()!);
    }
    final db = await AppDatabase.instance.database;
    final rows = await db.query('notes',
        where: 'date = ?', whereArgs: [dateKey(day)], limit: 1);
    if (rows.isEmpty) return null;
    return Note.fromMap(rows.first);
  }

  Future<List<Note>> all() async {
    if (kIsWeb) {
      final uid = AuthService.instance.uid;
      if (uid == null) return const [];
      final q =
          await _db.collection('users').doc(uid).collection('notes').get();
      // Сортируем на клиенте: id документа = дата (yyyy-MM-dd), заметок мало,
      // а orderBy по documentId лишний раз нагружает правила Firestore.
      final notes =
          q.docs.map((doc) => _noteFromCloud(doc.id, doc.data())).toList();
      notes.sort((a, b) => b.date.compareTo(a.date));
      return notes;
    }
    final db = await AppDatabase.instance.database;
    final rows = await db.query('notes', orderBy: 'date DESC');
    return rows.map(Note.fromMap).toList();
  }

  /// Сохранить ответы за день. Если все пустые — удаляем запись.
  Future<void> save(DateTime day, List<String> answers) async {
    final key = dateKey(day);
    final note = Note(
      date: key,
      answers: answers,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    if (kIsWeb) {
      // В вебе локальной БД нет — пишем сразу в облако (ждём, чтобы заметка
      // точно сохранилась при уходе со страницы).
      await _syncToCloud(key, note);
      return;
    }
    final db = await AppDatabase.instance.database;
    if (note.isEmpty) {
      await db.delete('notes', where: 'date = ?', whereArgs: [key]);
    } else {
      await db.insert('notes', note.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    // Облако — фоном: не ждём подтверждения сервера, чтобы автосохранение
    // не «висело» при медленной сети. Firestore досинхронизирует сам.
    unawaited(_syncToCloud(key, note));
  }

  /// Зеркалируем заметку в Firestore: users/{uid}/notes/{date}.
  Future<void> _syncToCloud(String key, Note note) async {
    final uid = AuthService.instance.uid;
    if (uid == null) return;
    final ref = _db.collection('users').doc(uid).collection('notes').doc(key);
    try {
      if (note.isEmpty) {
        await ref.delete();
        return;
      }
      final triadId = await TriadService.instance.currentTriadId();
      await ref.set({
        'a1': note.answers[0],
        'a2': note.answers[1],
        'a3': note.answers[2],
        'a4': note.answers[3],
        'done': note.isDone,
        'triadId': triadId,
        'updatedAt': note.updatedAt,
      });
    } catch (_) {
      // Оффлайн/ошибка сети — Firestore досинхронизирует позже.
    }
  }

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
      final d = doc.data()!;
      return Note(
        date: key,
        answers: [
          (d['a1'] as String?) ?? '',
          (d['a2'] as String?) ?? '',
          (d['a3'] as String?) ?? '',
          (d['a4'] as String?) ?? '',
        ],
        updatedAt: (d['updatedAt'] as int?) ?? 0,
      );
    }).handleError((_) => null);
  }

  /// Заметка участника тройки за день (для обмена и отметок).
  Future<Note?> fetchMemberNote(String uid, DateTime day) async {
    final key = dateKey(day);
    try {
      final doc =
          await _db.collection('users').doc(uid).collection('notes').doc(key).get();
      if (!doc.exists) return null;
      final d = doc.data()!;
      return Note(
        date: key,
        answers: [
          (d['a1'] as String?) ?? '',
          (d['a2'] as String?) ?? '',
          (d['a3'] as String?) ?? '',
          (d['a4'] as String?) ?? '',
        ],
        updatedAt: (d['updatedAt'] as int?) ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}
