import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/question.dart';

/// 本地 SQLite 存储，题库只存在本机，不上传。
class BankDatabase {
  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), 'qbank.db');
    _db = await openDatabase(path, version: 1, onCreate: (database, _) {
      return database.execute('''
        CREATE TABLE questions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT,
          question TEXT,
          answer TEXT,
          answer_text TEXT,
          options TEXT
        )
      ''');
    });
    return _db!;
  }

  static Future<void> insertAll(List<Question> qs) async {
    final d = await db;
    final batch = d.batch();
    for (final q in qs) {
      batch.insert('questions', q.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Question>> all() async {
    final d = await db;
    final maps = await d.query('questions');
    return maps.map((m) => Question.fromMap(m)).toList();
  }

  static Future<int> count() async {
    final d = await db;
    final res = await d.rawQuery('SELECT COUNT(*) AS c FROM questions');
    return res.first['c'] as int? ?? 0;
  }

  static Future<void> clear() async {
    final d = await db;
    await d.delete('questions');
  }
}
