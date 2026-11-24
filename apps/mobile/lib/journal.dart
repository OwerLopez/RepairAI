import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// SQLite persistence manager for repair sessions and user preferences.
class Journal {
  /// Creates a new [Journal] instance with an active SQLite database connection.
  Journal() : _database = _open();

  final Future<Database> _database;

  static Future<Database> _open() async {
    if (kIsWeb) databaseFactory = databaseFactoryFfiWeb;
    return openDatabase(
      kIsWeb
          ? 'repairs.sqlite'
          : path.join(await getDatabasesPath(), 'repairs.sqlite'),
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

  /// Inserts a new repair session into the journal and returns its assigned integer [id].
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

  /// Lists all logged repair sessions ordered by most recent first.
  Future<List<Map<String, Object?>>> list() async {
    return (await _database).query(
      'sessions',
      columns: ['id', 'started', 'plan', 'completed_steps', 'outcome'],
      orderBy: 'id DESC',
    );
  }

  /// Reads a single repair session by its unique integer [id].
  Future<Map<String, Object?>> read(int id) async {
    final rows = await (await _database).query(
      'sessions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.single;
  }

  /// Increments the progress of session [id] from [step] to the next step.
  Future<void> advance(int id, int step) async {
    await (await _database).update(
      'sessions',
      {'completed_steps': step + 1},
      where: 'id = ? AND completed_steps = ? AND outcome IS NULL',
      whereArgs: [id, step],
    );
  }

  /// Updates session [id] with the post-repair outcome evidence [photo].
  Future<void> evidence(int id, Uint8List photo) async {
    await (await _database).update(
      'sessions',
      {'after_photo': photo},
      where: 'id = ? AND outcome IS NULL',
      whereArgs: [id],
    );
  }

  /// Records final completion [outcome] and user [notes] for session [id].
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

  /// Deletes a specific repair session [id] from the database.
  Future<void> delete(int id) async {
    await (await _database).delete(
      'sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Purges all repair sessions and user preferences from the database.
  Future<void> deleteAll() async {
    final db = await _database;
    await db.delete('sessions');
    await db.delete('preferences');
  }

  /// Retrieves a saved user preference by [key], returning null if not found.
  Future<String?> preference(String key) async {
    final rows = await (await _database).query(
      'preferences',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['value'] as String;
  }

  /// Stores or clears a user preference [value] for [key].
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
