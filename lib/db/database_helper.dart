import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/task.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _table = 'tasks';
  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'todo.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) => db.execute('''
        CREATE TABLE $_table (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          description TEXT NOT NULL DEFAULT '',
          priority INTEGER NOT NULL DEFAULT 1,
          due_date INTEGER,
          is_completed INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL
        )
      '''),
    );
  }

  // Create
  Future<int> insert(Task task) async {
    final db = await database;
    return db.insert(_table, task.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Read
  Future<List<Task>> getTasks() async {
    final db = await database;
    final rows = await db.query(_table);
    return rows.map(Task.fromMap).toList();
  }

  // Update
  Future<int> update(Task task) async {
    final db = await database;
    return db.update(_table, task.toMap(),
        where: 'id = ?', whereArgs: [task.id]);
  }

  // Toggle completion
  Future<int> setCompleted(int id, bool completed) async {
    final db = await database;
    return db.update(_table, {'is_completed': completed ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  // Delete
  Future<int> delete(int id) async {
    final db = await database;
    return db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteCompleted() async {
    final db = await database;
    return db.delete(_table, where: 'is_completed = 1');
  }
}
