import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Единая точка доступа к локальной БД (заметки + расписание отрывков).
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    return _db ??= await _open();
  }

  Future<Database> _open() async {
    final String path;
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWebNoWebWorker; // SQLite через WASM в браузере
      path = 'bible_reflection.db';
    } else {
      final dir = await getDatabasesPath();
      path = p.join(dir, 'bible_reflection.db');
    }
    return openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE passages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            book_code TEXT NOT NULL,
            chapter INTEGER NOT NULL,
            verse_start INTEGER NOT NULL,
            verse_end INTEGER NOT NULL
          )
        ''');
        await db.execute('CREATE UNIQUE INDEX idx_passages_date ON passages(date)');

        // Заметка = 4 ответа на вопросы (a1..a4).
        await db.execute('''
          CREATE TABLE notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            a1 TEXT NOT NULL DEFAULT '',
            a2 TEXT NOT NULL DEFAULT '',
            a3 TEXT NOT NULL DEFAULT '',
            a4 TEXT NOT NULL DEFAULT '',
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('CREATE UNIQUE INDEX idx_notes_date ON notes(date)');

        await _createReadingTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Переход от единого поля content к 4 полям a1..a4.
          for (final col in ['a1', 'a2', 'a3', 'a4']) {
            await db.execute(
                "ALTER TABLE notes ADD COLUMN $col TEXT NOT NULL DEFAULT ''");
          }
          // Старый текст переносим в первый ответ, если колонка content была.
          try {
            await db.execute(
                'UPDATE notes SET a1 = content WHERE content IS NOT NULL');
          } catch (_) {
            // content отсутствует — ничего не делаем.
          }
        }
        if (oldVersion < 3) {
          await _createReadingTables(db);
        }
        if (oldVersion < 4) {
          // Убираем устаревшую колонку notes.content (NOT NULL), которая
          // ломала вставку 4-польных заметок. SQLite не умеет DROP COLUMN на
          // старых версиях — пересобираем таблицу.
          await db.execute('ALTER TABLE notes RENAME TO notes_old');
          await db.execute('''
            CREATE TABLE notes (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT NOT NULL,
              a1 TEXT NOT NULL DEFAULT '',
              a2 TEXT NOT NULL DEFAULT '',
              a3 TEXT NOT NULL DEFAULT '',
              a4 TEXT NOT NULL DEFAULT '',
              updated_at INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            INSERT INTO notes (id, date, a1, a2, a3, a4, updated_at)
            SELECT id, date, a1, a2, a3, a4, updated_at FROM notes_old
          ''');
          await db.execute('DROP TABLE notes_old');
          await db.execute('CREATE UNIQUE INDEX idx_notes_date ON notes(date)');
        }
      },
    );
  }

  Future<void> _createReadingTables(Database db) async {
    // План ежедневного чтения: главы на день (может быть несколько строк на дату).
    await db.execute('''
      CREATE TABLE readings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        book_code TEXT NOT NULL,
        chapter_start INTEGER NOT NULL,
        chapter_end INTEGER NOT NULL,
        order_index INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_readings_date ON readings(date)');

    // Отметки о прочтении (одна на день).
    await db.execute('''
      CREATE TABLE reading_done (
        date TEXT PRIMARY KEY,
        done INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }
}
