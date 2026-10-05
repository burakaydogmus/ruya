import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ruya/backup/backup_format.dart';
import 'package:ruya/backup/backup_service.dart';
import 'package:ruya/database/app_database.dart';
import 'package:ruya/database/repositories/logs_repository.dart';
import 'package:ruya/database/repositories/pills_repository.dart';
import 'package:ruya/models/birth_control/pills/pill_regimen.dart';
import 'package:ruya/models/flows/flow_enum.dart';
import 'package:ruya/models/period_logs/daily_log_enums.dart';
import 'package:ruya/models/period_logs/log_day.dart';
import 'package:ruya/models/period_logs/symptom.dart';
import 'package:ruya/security/crypto/pbkdf2.dart';
import 'package:ruya/security/field_cipher.dart';
import 'package:ruya/security/secure_key_value_store.dart';
import 'package:ruya/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Low iteration count keeps tests fast; production uses 600k.
const _iter = 20000;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  Pbkdf2Sha256.useNative = false;

  late BackupService service;
  late LogsRepository logs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      themeModeKey: 2,
      lutealPhaseLengthKey: 13,
      biometricEnabledKey: true,
      pinTimeoutSecondsKey: 0,
    });
    FieldCipher.instance.reset();
    await FieldCipher.instance.init(InMemorySecureKeyValueStore());
    await AppDatabase.instance.init(inMemory: true);
    logs = LogsRepository();
    service = BackupService(prefs: await SharedPreferences.getInstance(), appVersion: '1.0.0');
  });

  tearDown(() async => AppDatabase.instance.close());

  Future<void> seed() async {
    await logs.upsertLog(LogDay(
      date: DateTime(2026, 2, 1),
      flow: FlowRate.heavy,
      moods: [Mood.sad],
      notes: 'gizli not',
      medications: ['parol'],
    ));
    await logs.upsertLog(LogDay(date: DateTime(2026, 2, 20), flow: FlowRate.none, discharge: Discharge.eggWhite));
    await PillsRepository().createPillRegimen(PillRegimen(
      name: 'Pack', activePills: 21, placeboPills: 7, startDate: DateTime(2026, 1, 1), isActive: true,
    ));
  }

  test('envelope layout: magic, version, KDF params, and authenticated header', () async {
    final bytes = await BackupEnvelope.seal({'format': 'x'}, 'correct horse', iterations: _iter);
    expect(bytes.sublist(0, 4), [0x52, 0x55, 0x59, 0x41]);
    expect(bytes[4], 1);
    expect(bytes[5], 1);
    expect(ByteData.sublistView(bytes, 6, 10).getUint32(0), _iter);

    // Changing the iteration count in the header must break authentication.
    final tampered = Uint8List.fromList(bytes)..[9] ^= 1;
    expect(() => BackupEnvelope.open(tampered, 'correct horse'),
        throwsA(anyOf(isA<BackupPasswordException>(), isA<BackupFormatException>())));
  });

  test('wrong password and non-backup files are rejected', () async {
    final bytes = await BackupEnvelope.seal({'format': 'x'}, 'correct horse', iterations: _iter);
    expect(() => BackupEnvelope.open(bytes, 'wrong password'), throwsA(isA<BackupPasswordException>()));
    expect(() => BackupEnvelope.open([1, 2, 3], 'x'), throwsA(isA<BackupFormatException>()));
  });

  test('full round trip restores every table, decrypted fields and preferences', () async {
    await seed();
    final bytes = await service.createEncryptedBackup('uzun parola 123', iterations: _iter);
    expect(String.fromCharCodes(bytes), isNot(contains('gizli not')));

    // Wipe everything and change prefs.
    final db = await AppDatabase.instance.database;
    for (final t in ['period_logs', 'log_moods', 'PillRegimen']) {
      await db.delete(t);
    }
    await service.prefs.setInt(lutealPhaseLengthKey, 14);

    final payload = await service.readEncryptedBackup(bytes, 'uzun parola 123');
    final preview = BackupService.preview(payload);
    expect(preview.schemaVersion, BackupService.schemaVersion);
    expect(preview.dbVersion, AppDatabase.schemaVersion);
    expect(preview.logCount, 2);
    expect(preview.count('PillRegimen'), 1);
    expect(preview.firstLogDate, DateTime(2026, 2, 1));
    expect(preview.lastLogDate, DateTime(2026, 2, 20));

    await service.restoreReplacingAll(payload);
    final restored = await logs.readAllLogs();
    expect(restored.length, 2);
    final first = restored.firstWhere((l) => l.flow == FlowRate.heavy);
    expect(first.notes, 'gizli not');
    expect(first.medications, ['parol']);
    expect(first.moods, [Mood.sad]);
    expect((await db.query('period_logs')).first['notes'].toString(), startsWith(FieldCipher.prefix));
    expect((await PillsRepository().readAllPillRegimens()).single.name, 'Pack');
    expect(service.prefs.getInt(lutealPhaseLengthKey), 13);
  });

  test('device-local preferences are neither exported nor overwritten', () async {
    final payload = await service.buildPayload();
    final prefs = payload['preferences'] as Map;
    expect(prefs.containsKey(biometricEnabledKey), isFalse);
    expect(prefs.containsKey(pinTimeoutSecondsKey), isFalse);
    expect(prefs[themeModeKey], {'t': 'int', 'v': 2});
  });

  test('restore replaces existing data instead of merging', () async {
    await seed();
    final payload = await service.buildPayload();
    await logs.upsertLog(LogDay(date: DateTime(2026, 3, 5), flow: FlowRate.light));
    expect((await logs.readAllLogs()).length, 3);
    await service.restoreReplacingAll(payload);
    expect((await logs.readAllLogs()).length, 2);
  });

  test('backups from older DB versions restore and unknown columns are ignored', () async {
    final payload = {
      'format': BackupService.format,
      'schemaVersion': 1,
      'dbVersion': 11,
      'tables': {
        'period_logs': [
          {'id': 7, 'date': '2026-01-10T00:00:00.000', 'flow': 2, 'painLevel': null, 'period_id': null, 'future_col': 'x'},
        ],
        'log_symptoms': [
          {'log_id_fk': 7, 'symptom': 'cramps'},
        ],
        'not_a_table': [{'a': 1}],
      },
    };
    await service.restoreReplacingAll(payload);
    final restored = (await logs.readAllLogs()).single;
    expect(restored.id, 7);
    expect(restored.flow, FlowRate.light);
    expect(restored.symptoms.single.getDbName(), 'cramps');
  });

  test('payloads from a newer schema or foreign files are refused', () {
    expect(() => BackupService.migratePayload({'format': 'ruya-backup', 'schemaVersion': 99, 'tables': {}}),
        throwsA(isA<BackupFormatException>()));
    expect(() => BackupService.migratePayload({'format': 'other', 'schemaVersion': 1, 'tables': {}}),
        throwsA(isA<BackupFormatException>()));
  });
}
