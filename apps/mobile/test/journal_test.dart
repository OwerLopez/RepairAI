import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:reparaai/journal.dart';
// ignore: depend_on_referenced_packages
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Journal journal;

  setUp(() async {
    journal = Journal();
    final dbPath = path.join(await getDatabasesPath(), 'repairs.sqlite');
    final db = await openDatabase(
      dbPath,
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
    await db.delete('sessions');
    await db.delete('preferences');
  });

  test('start creates session and returns valid id', () async {
    final id = await journal.start(
      diagnosis: {'status': 'candidate', 'confidence': 0.88},
      damage: 'hole',
      material: 'denim',
      knowledge: 'basic',
      plan: {'id': 'denim-darn', 'title': 'Denim Darning'},
      photo: Uint8List.fromList([1, 2, 3, 4]),
    );

    expect(id, isPositive);
  });

  test('list returns sessions in descending order by id', () async {
    final id1 = await journal.start(
      diagnosis: {'idx': 1},
      damage: 'hole',
      material: 'cotton',
      knowledge: 'basic',
      plan: {'id': 'plan-1'},
      photo: Uint8List.fromList([1]),
    );
    final id2 = await journal.start(
      diagnosis: {'idx': 2},
      damage: 'seam',
      material: 'denim',
      knowledge: 'advanced',
      plan: {'id': 'plan-2'},
      photo: Uint8List.fromList([2]),
    );

    final sessions = await journal.list();

    expect(sessions.length, 2);
    expect(sessions.first['id'], id2);
    expect(sessions[1]['id'], id1);

    // Verify projected columns in list()
    final first = sessions.first;
    expect(first.containsKey('id'), isTrue);
    expect(first.containsKey('started'), isTrue);
    expect(first.containsKey('plan'), isTrue);
    expect(first.containsKey('completed_steps'), isTrue);
    expect(first.containsKey('outcome'), isTrue);
    expect(first.containsKey('before_photo'), isFalse);
    expect(first.containsKey('notes'), isFalse);
  });

  test('read returns all session fields accurately', () async {
    final photoBytes = Uint8List.fromList([10, 20, 30, 40]);
    final diagnosisData = {'status': 'candidate', 'confidence': 0.92};
    final planData = {
      'id': 'denim-darn',
      'title': 'Zurcido visible',
      'steps': ['Paso 1', 'Paso 2'],
    };

    final id = await journal.start(
      diagnosis: diagnosisData,
      damage: 'hole',
      material: 'denim',
      knowledge: 'intermediate',
      plan: planData,
      photo: photoBytes,
    );

    final session = await journal.read(id);

    expect(session['id'], id);
    expect(session['damage'], 'hole');
    expect(session['material'], 'denim');
    expect(session['knowledge'], 'intermediate');
    expect(jsonDecode(session['diagnosis'] as String), diagnosisData);
    expect(jsonDecode(session['plan'] as String), planData);
    expect(session['before_photo'], photoBytes);
    expect(session['after_photo'], isNull);
    expect(session['completed_steps'], 0);
    expect(session['outcome'], isNull);
    expect(session['finished'], isNull);
    expect(session['notes'], '');
    expect(session['started'], isNotEmpty);
    expect(DateTime.tryParse(session['started'] as String), isNotNull);
  });

  test('advance increments completed_steps', () async {
    final id = await journal.start(
      diagnosis: {},
      damage: 'hole',
      material: 'denim',
      knowledge: 'basic',
      plan: {
        'steps': ['step 1', 'step 2', 'step 3'],
      },
      photo: Uint8List.fromList([1]),
    );

    var session = await journal.read(id);
    expect(session['completed_steps'], 0);

    await journal.advance(id, 0);
    session = await journal.read(id);
    expect(session['completed_steps'], 1);

    await journal.advance(id, 1);
    session = await journal.read(id);
    expect(session['completed_steps'], 2);
  });

  test('advance will not advance past current step (idempotent)', () async {
    final id = await journal.start(
      diagnosis: {},
      damage: 'hole',
      material: 'denim',
      knowledge: 'basic',
      plan: {
        'steps': ['step 1', 'step 2'],
      },
      photo: Uint8List.fromList([1]),
    );

    // Attempting to advance with future step (e.g. 2 when current is 0) has no effect
    await journal.advance(id, 2);
    var session = await journal.read(id);
    expect(session['completed_steps'], 0);

    // Advance to 1
    await journal.advance(id, 0);
    session = await journal.read(id);
    expect(session['completed_steps'], 1);

    // Calling advance with old step 0 again has no effect (idempotent)
    await journal.advance(id, 0);
    session = await journal.read(id);
    expect(session['completed_steps'], 1);

    // Calling advance with non-matching step 5 has no effect
    await journal.advance(id, 5);
    session = await journal.read(id);
    expect(session['completed_steps'], 1);
  });

  test('evidence saves after_photo', () async {
    final id = await journal.start(
      diagnosis: {},
      damage: 'hole',
      material: 'denim',
      knowledge: 'basic',
      plan: {},
      photo: Uint8List.fromList([1, 2]),
    );

    final afterPhoto = Uint8List.fromList([99, 100, 101, 102]);
    await journal.evidence(id, afterPhoto);

    final session = await journal.read(id);
    expect(session['after_photo'], afterPhoto);
  });

  test('finish sets outcome, notes, and finished timestamp', () async {
    final id = await journal.start(
      diagnosis: {},
      damage: 'hole',
      material: 'denim',
      knowledge: 'basic',
      plan: {},
      photo: Uint8List.fromList([1]),
    );

    await journal.finish(id, 'repaired', '   Reparado con éxito   ');

    final session = await journal.read(id);
    expect(session['outcome'], 'repaired');
    expect(session['notes'], 'Reparado con éxito');
    expect(session['finished'], isNotNull);
    expect(DateTime.tryParse(session['finished'] as String), isNotNull);

    // When outcome is not null, advance and evidence can no longer modify the session
    await journal.advance(id, 0);
    await journal.evidence(id, Uint8List.fromList([5, 6]));
    final finishedSession = await journal.read(id);
    expect(finishedSession['completed_steps'], 0);
    expect(finishedSession['after_photo'], isNull);
  });

  test('delete removes the session', () async {
    final id = await journal.start(
      diagnosis: {},
      damage: 'hole',
      material: 'denim',
      knowledge: 'basic',
      plan: {},
      photo: Uint8List.fromList([1]),
    );

    var session = await journal.read(id);
    expect(session['id'], id);

    await journal.delete(id);

    final sessions = await journal.list();
    expect(sessions.any((s) => s['id'] == id), isFalse);
    expect(() => journal.read(id), throwsA(isA<StateError>()));
  });

  test('preference handles get, set, update, and delete cycle', () async {
    // Initial get on unset key returns null
    expect(await journal.preference('app_language'), isNull);

    // Set preference
    await journal.setPreference('app_language', 'es');
    expect(await journal.preference('app_language'), 'es');

    // Update preference
    await journal.setPreference('app_language', 'en');
    expect(await journal.preference('app_language'), 'en');

    // Setting null deletes the preference
    await journal.setPreference('app_language', null);
    expect(await journal.preference('app_language'), isNull);
  });
}
