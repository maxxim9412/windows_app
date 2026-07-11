import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Единая точка доступа к локальной БД (заметки + расписание отрывков).
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    return _db ??= await _open();
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'bible_reflection.db');
    return openDatabase(
      path,
      version: 2,
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
      },
    );
  }
}
