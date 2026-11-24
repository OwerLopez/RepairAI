import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class Journal {
  Journal() : _database = _open();

  final Future<Database> _database;

  static Future<Database> _open() async {
    return openDatabase(
      path.join(await getDatabasesPath(), 'repairs.sqlite'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE sessions (
            id INTEGER PRIMARY KEY,
            started TEXT NOT NULL,
            diagnosis TEXT NOT NULL,
            damage TEXT NOT NULL,
            material TEXT NOT NULL,
            knowledge TEXT NOT NULL,
            plan TEXT NOT NULL,
            before_photo BLOB NOT NULL,
            after_photo BLOB,
            completed_steps INTEGER NOT NULL DEFAULT 0,
            outcome TEXT CHECK(outcome IN ('repaired', 'partial', 'stopped')),
            finished TEXT,
            notes TEXT NOT NULL DEFAULT ''
          )
        ''');
        await db.execute(
          'CREATE TABLE preferences (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
      },
    );
  }

  Future<int> start({
    required Map<String, Object?> diagnosis,
    required String damage,
    required String material,
    required String knowledge,
    required Map<String, dynamic> plan,
    required Uint8List photo,
  }) async {
    return (await _database).insert('sessions', {
      'started': DateTime.now().toUtc().toIso8601String(),
      'diagnosis': jsonEncode(diagnosis),
      'damage': damage,
      'material': material,
      'knowledge': knowledge,
      'plan': jsonEncode(plan),
      'before_photo': photo,
    });
  }

  Future<List<Map<String, Object?>>> list() async {
    return (await _database).query(
      'sessions',
      columns: ['id', 'started', 'plan', 'completed_steps', 'outcome'],
      orderBy: 'id DESC',
    );
  }

  Future<Map<String, Object?>> read(int id) async {
    final rows = await (await _database).query(
      'sessions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.single;
  }

  Future<void> advance(int id, int step) async {
    await (await _database).update(
      'sessions',
      {'completed_steps': step + 1},
      where: 'id = ? AND completed_steps = ? AND outcome IS NULL',
      whereArgs: [id, step],
    );
  }

  Future<void> evidence(int id, Uint8List photo) async {
    await (await _database).update(
      'sessions',
      {'after_photo': photo},
      where: 'id = ? AND outcome IS NULL',
      whereArgs: [id],
    );
  }

  Future<void> finish(int id, String outcome, String notes) async {
    await (await _database).update(
      'sessions',
      {
        'outcome': outcome,
        'notes': notes.trim(),
        'finished': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ? AND outcome IS NULL',
      whereArgs: [id],
    );
  }

  Future<void> delete(int id) async {
    await (await _database).delete(
      'sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<String?> preference(String key) async {
    final rows = await (await _database).query(
      'preferences',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['value'] as String;
  }

  Future<void> setPreference(String key, String? value) async {
    final db = await _database;
    if (value == null) {
      await db.delete('preferences', where: 'key = ?', whereArgs: [key]);
    } else {
      await db.insert('preferences', {
        'key': key,
        'value': value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }
}
