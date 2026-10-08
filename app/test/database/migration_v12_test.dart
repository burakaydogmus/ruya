import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:ruya/database/app_database.dart';
import 'package:ruya/database/database_migrator.dart';
import 'package:ruya/database/repositories/logs_repository.dart';
import 'package:ruya/models/flows/flow_enum.dart';
import 'package:ruya/models/period_logs/daily_log_enums.dart';
import 'package:ruya/security/field_cipher.dart';
import 'package:ruya/security/secure_key_value_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Creates a database exactly as Menstrudel v4 (schema v11) would.
Future<void> _createMenstrudelV11(String path) async {
  final db = await databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 11,
      onCreate: (db, version) async {
        await DatabaseMigrator.createPeriodTables(db);
        await DatabaseMigrator.createLogTables(db);
        await DatabaseMigrator.createPillTables(db);
        await DatabaseMigrator.createLarcTables(db);
        await DatabaseMigrator.createSanitaryProductTables(db);
        await DatabaseMigrator.createSexualActivityTables(db);
        await DatabaseMigrator.createUserTables(db);
      },
    ),
  );
  final periodId = await db.insert('periods', {
    'start_date': DateTime(2025, 9, 1).millisecondsSinceEpoch,
    'end_date': DateTime(2025, 9, 2).millisecondsSinceEpoch,
    'total_days': 2,
  });
  final logId = await db.insert('period_logs', {
    'date': DateTime(2025, 9, 1).toIso8601String(),
    'flow': FlowRate.heavy.index,
    'painLevel': 3,
    'period_id': periodId,
  });
  await db.insert('period_logs', {
    'date': DateTime(2025, 9, 2).toIso8601String(),
    'flow': FlowRate.light.index,
    'painLevel': null,
    'period_id': periodId,
  });
  await db.insert('log_symptoms', {'log_id_fk': logId, 'symptom': 'cramps'});
  await db.insert('PillRegimen', {
    'name': 'Pack',
    'active_pills': 21,
    'placebo_pills': 7,
    'start_date': '2025-09-01',
    'is_active': 1,
  });
  await db.close();
}

Future<Map<String, List<String>>> _schema(Database db) async {
  final tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
  );
  final Map<String, List<String>> schema = {};
  for (final t in tables) {
    final name = t['name'] as String;
    final cols = await db.rawQuery('PRAGMA table_info($name)');
    schema[name] = cols.map((c) => '${c['name']}:${c['type']}').toList()..sort();
  }
  return schema;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('ruya_migration');
    FieldCipher.instance.reset();
    await FieldCipher.instance.init(InMemorySecureKeyValueStore());
  });

  tearDown(() async {
    await AppDatabase.instance.close().catchError((_) {});
    await tmp.delete(recursive: true);
  });

  test('upgrading a Menstrudel v11 database keeps every existing record', () async {
    final path = p.join(tmp.path, 'v11.db');
    await _createMenstrudelV11(path);

    final db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onUpgrade: DatabaseMigrator.upgrade,
      ),
    );

    expect(await db.getVersion(), AppDatabase.schemaVersion);
    expect(await db.query('companion'), isEmpty);
    final logs = await db.query('period_logs', orderBy: 'date');
    expect(logs.length, 2);
    expect(logs.first['flow'], FlowRate.heavy.index);
    expect(logs.first['painLevel'], 3);
    expect(logs.first['notes'], isNull);
    expect(logs.first['discharge'], isNull);
    expect((await db.query('log_symptoms')).single['symptom'], 'cramps');
    expect((await db.query('periods')).length, 1);
    expect((await db.query('PillRegimen')).single['name'], 'Pack');
    expect(await db.query('log_moods'), isEmpty);
    await db.close();
  });

  test('fresh install and migrated install have the same schema', () async {
    final migratedPath = p.join(tmp.path, 'migrated.db');
    await _createMenstrudelV11(migratedPath);
    final migrated = await databaseFactoryFfi.openDatabase(
      migratedPath,
      options: OpenDatabaseOptions(version: 12, onUpgrade: DatabaseMigrator.upgrade),
    );

    final fresh = await AppDatabase.instance.init(inMemory: true);

    expect(await _schema(fresh), await _schema(migrated));
    await migrated.close();
  });

  test('migrated rows are readable and extendable through LogsRepository', () async {
    await AppDatabase.instance.init(inMemory: true);
    final repo = LogsRepository();
    final db = await AppDatabase.instance.database;
    // Simulate a legacy row written before v12 (no new columns set).
    await db.insert('period_logs', {
      'date': DateTime(2025, 9, 1).toIso8601String(),
      'flow': FlowRate.medium.index,
    });

    final legacy = (await repo.readAllLogs()).single;
    expect(legacy.moods, isEmpty);
    expect(legacy.notes, isNull);

    await repo.upsertLog(legacy.copyWith(
      moods: [Mood.calm],
      discharge: Discharge.creamy,
      notes: 'ok',
    ));
    final updated = (await repo.readAllLogs()).single;
    expect(updated.flow, FlowRate.medium);
    expect(updated.moods, [Mood.calm]);
    expect(updated.discharge, Discharge.creamy);
    expect(updated.notes, 'ok');
  });
}
