import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/db.dart';
import '../models/note.dart';
import 'auth_service.dart';
import 'triad_service.dart';

/// Разовый перенос локальных данных (SQLite) в облако.
///
/// Историю: на мобильных заметки жили в SQLite (в облако лишь зеркалировались),
/// а отметки «прочитано» — только в SQLite и нигде больше. Из-за этого прогресс
/// на телефоне и в вебе был разным. Теперь единый источник — Firestore, но
/// накопленное на телефоне нужно сначала поднять наверх, иначе оно пропадёт.
///
/// Локальную БД намеренно НЕ удаляем: пусть останется как страховка.
class LocalMigration {
  LocalMigration._();
  static final LocalMigration instance = LocalMigration._();

  static String _flagFor(String uid) => 'cloud_migrated_v1_$uid';

  /// Безопасно вызывать при каждом запуске: отработает один раз на аккаунт.
  /// Никогда не бросает — если не удалось (например, нет сети), флаг не ставим
  /// и попробуем при следующем запуске.
  Future<void> runIfNeeded() async {
    if (kIsWeb) return; // в вебе локальной БД никогда не было
    final uid = AuthService.instance.uid;
    if (uid == null) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_flagFor(uid)) ?? false) return;

    try {
      await _migrate(uid);
      await prefs.setBool(_flagFor(uid), true);
    } catch (e) {
      debugPrint('[migration] не удалось перенести локальные данные: $e');
    }
  }

  Future<void> _migrate(String uid) async {
    final db = await AppDatabase.instance.database;
    final fs = FirebaseFirestore.instance;
    final userDoc = fs.collection('users').doc(uid);

    // --- Заметки -----------------------------------------------------------
    final rows = await db.query('notes');
    if (rows.isNotEmpty) {
      final triadId = await TriadService.instance.currentTriadId();
      for (final row in rows) {
        final note = Note.fromMap(row);
        if (note.isEmpty) continue;
        final ref = userDoc.collection('notes').doc(note.date);
        final cloud = await ref.get();
        final cloudUpdated = (cloud.data()?['updatedAt'] as num?)?.toInt() ?? -1;
        // Облачная версия свежее — значит её и оставляем.
        if (cloud.exists && cloudUpdated >= note.updatedAt) continue;
        await ref.set({
          'a1': note.answers[0],
          'a2': note.answers[1],
          'a3': note.answers[2],
          'a4': note.answers[3],
          'done': note.isDone,
          'triadId': triadId,
          'updatedAt': note.updatedAt,
        });
      }
    }

    // --- Отметки «прочитано» ----------------------------------------------
    // Их в облаке не было вообще, так что просто доливаем объединением.
    final doneRows = await db.query('reading_done', where: 'done = 1');
    if (doneRows.isNotEmpty) {
      final map = <String, dynamic>{
        for (final r in doneRows) r['date'] as String: true,
      };
      await userDoc.set({'readingDone': map}, SetOptions(merge: true));
    }

    debugPrint('[migration] перенесено заметок: ${rows.length}, '
        'отметок чтения: ${doneRows.length}');
  }
}
