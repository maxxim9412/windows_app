import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import '../models/passage.dart';

/// Загружает текст перевода из ассета и отдаёт текст отрывка по адресу.
///
/// Формат ассета (assets/bible/synodal_sample.json):
/// { "books": { "<code>": { "name": "...", "chapters": { "<num>": { "<verse>": "текст" } } } } }
class BibleRepository {
  BibleRepository._();
  static final BibleRepository instance = BibleRepository._();

  static const String _assetPath = 'assets/bible/synodal_sample.json';

  Map<String, dynamic>? _books; // code -> book json

  Future<void> _ensureLoaded() async {
    if (_books != null) return;
    final raw = await rootBundle.loadString(_assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    _books = (json['books'] as Map<String, dynamic>?) ?? {};
  }

  /// Возвращает список стихов отрывка: (номер, текст).
  /// Пустой список — если текста для этого адреса нет в подключённой базе.
  Future<List<({int verse, String text})>> versesFor(Passage passage) async {
    await _ensureLoaded();
    final book = _books![passage.bookCode] as Map<String, dynamic>?;
    if (book == null) return const [];
    final chapters = book['chapters'] as Map<String, dynamic>?;
    final chapter = chapters?['${passage.chapter}'] as Map<String, dynamic>?;
    if (chapter == null) return const [];

    final result = <({int verse, String text})>[];
    for (var v = passage.verseStart; v <= passage.verseEnd; v++) {
      final text = chapter['$v'];
      if (text is String) result.add((verse: v, text: text));
    }
    return result;
  }

  /// Проверка, что текст отрывка есть в базе (для подсказки администратору).
  Future<bool> hasText(Passage passage) async {
    final verses = await versesFor(passage);
    return verses.isNotEmpty;
  }

  /// Все стихи главы (по порядку номеров). Пусто, если главы нет в базе.
  Future<List<({int verse, String text})>> chapterVerses(
      String bookCode, int chapter) async {
    await _ensureLoaded();
    final book = _books![bookCode] as Map<String, dynamic>?;
    if (book == null) return const [];
    final chapters = book['chapters'] as Map<String, dynamic>?;
    final ch = chapters?['$chapter'] as Map<String, dynamic>?;
    if (ch == null) return const [];

    final result = <({int verse, String text})>[];
    for (final entry in ch.entries) {
      final v = int.tryParse(entry.key);
      final text = entry.value;
      if (v != null && text is String) result.add((verse: v, text: text));
    }
    result.sort((a, b) => a.verse.compareTo(b.verse));
    return result;
  }
}
