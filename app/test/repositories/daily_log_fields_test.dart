import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ruya/database/app_database.dart';
import 'package:ruya/database/repositories/logs_repository.dart';
import 'package:ruya/database/repositories/periods_repository.dart';
import 'package:ruya/models/flows/flow_enum.dart';
import 'package:ruya/models/period_logs/daily_log_enums.dart';
import 'package:ruya/models/period_logs/log_day.dart';
import 'package:ruya/security/field_cipher.dart';
import 'package:ruya/security/secure_key_value_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  databaseFactory = databaseFactoryFfi;
  sqfliteFfiInit();

  late LogsRepository repository;

  setUp(() async {
    FieldCipher.instance.reset();
    await FieldCipher.instance.init(InMemorySecureKeyValueStore());
    await AppDatabase.instance.init(inMemory: true);
    repository = LogsRepository();
  });

  tearDown(() async => AppDatabase.instance.close());

  LogDay fullLog() => LogDay(
        date: DateTime(2025, 9, 3),
        flow: FlowRate.light,
        painLevel: 2,
        moods: [Mood.tired, Mood.anxious],
        discharge: Discharge.eggWhite,
        libido: Libido.high,
        sexActivity: SexActivity.protected,
        contraception: [ContraceptionMethod.condom, ContraceptionMethod.pill],
        medications: ['Ibuprofen 400mg', 'Demir'],
        notes: 'Özel not ✨',
      );

  test('all daily log fields round-trip', () async {
    await repository.upsertLog(fullLog());
    final log = (await repository.readAllLogs()).single;
    expect(log.moods, [Mood.tired, Mood.anxious]);
    expect(log.discharge, Discharge.eggWhite);
    expect(log.libido, Libido.high);
    expect(log.sexActivity, SexActivity.protected);
    expect(log.contraception, [ContraceptionMethod.condom, ContraceptionMethod.pill]);
    expect(log.medications, ['Ibuprofen 400mg', 'Demir']);
    expect(log.notes, 'Özel not ✨');
    expect(log.hasContent, isTrue);
  });

  test('notes and medications are encrypted at rest', () async {
    await repository.upsertLog(fullLog());
    final db = await AppDatabase.instance.database;
    final row = (await db.query('period_logs')).single;
    expect(row['notes'], startsWith(FieldCipher.prefix));
    expect(row['notes'].toString(), isNot(contains('Özel')));
    expect(row['medications'], startsWith(FieldCipher.prefix));
    expect(row['medications'].toString(), isNot(contains('Ibuprofen')));
  });

  test('unreadable ciphertext does not crash reading', () async {
    await repository.upsertLog(fullLog());
    // Simulate a lost Keystore key.
    FieldCipher.instance.reset();
    await FieldCipher.instance.init(InMemorySecureKeyValueStore());
    final log = (await repository.readAllLogs()).single;
    expect(log.notes, isNull);
    expect(log.medications, isEmpty);
    expect(log.moods, [Mood.tired, Mood.anxious]);
  });

  test('updating moods replaces them and deleting a log removes children', () async {
    final id = await repository.upsertLog(fullLog());
    await repository.upsertLog(fullLog().copyWith(id: id, moods: [Mood.happy]));
    expect((await repository.readLog(id)).moods, [Mood.happy]);

    await repository.deleteLog(id);
    final db = await AppDatabase.instance.database;
    expect(await db.query('log_moods'), isEmpty);
    expect(await db.query('log_symptoms'), isEmpty);
  });

  test('readLogForDate and readLogsSince use calendar dates', () async {
    await repository.upsertLog(fullLog());
    await repository.upsertLog(LogDay(date: DateTime(2025, 8, 1), flow: FlowRate.none, notes: 'x'));
    expect((await repository.readLogForDate(DateTime(2025, 9, 3, 18))), isNotNull);
    expect(await repository.readLogForDate(DateTime(2025, 9, 4)), isNull);
    final since = await repository.readLogsSince(DateTime(2025, 9, 1));
    expect(since.length, 1);
  });

  test('watch log marks an existing mood-only day as a period day', () async {
    final today = DateTime.now();
    await repository.upsertLog(LogDay(date: today, flow: FlowRate.none, moods: [Mood.calm]));
    await repository.logFromWatch();
    final log = (await repository.readAllLogs()).single;
    expect(log.flow, FlowRate.medium);
    expect(log.moods, [Mood.calm]);
  });

  test('JSON export is plaintext and re-import keeps every field', () async {
    PackageInfo.setMockInitialValues(
      appName: 'RUYA', packageName: 'com.burakaydogmus.ruya', version: '1.0.0',
      buildNumber: '1', buildSignature: '',
    );
    await repository.upsertLog(fullLog());
    final manager = PeriodsRepository().manager;
    final json = await manager.exportDataAsJson();
    expect(json, contains('Özel not'));
    expect(json, isNot(contains(FieldCipher.prefix)));

    await manager.clearAllData();
    expect(await repository.readAllLogs(), isEmpty);

    await manager.importDataFromJson(json);
    final log = (await repository.readAllLogs()).single;
    expect(log.notes, 'Özel not ✨');
    expect(log.moods, [Mood.tired, Mood.anxious]);
    final db = await AppDatabase.instance.database;
    expect((await db.query('period_logs')).single['notes'], startsWith(FieldCipher.prefix));
  });
}
