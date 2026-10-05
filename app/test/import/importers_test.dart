import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ruya/database/app_database.dart';
import 'package:ruya/database/repositories/logs_repository.dart';
import 'package:ruya/import/clue_importer.dart';
import 'package:ruya/import/drip_importer.dart';
import 'package:ruya/import/flo_importer.dart';
import 'package:ruya/import/import_models.dart';
import 'package:ruya/import/import_service.dart';
import 'package:ruya/models/flows/flow_enum.dart';
import 'package:ruya/models/period_logs/daily_log_enums.dart';
import 'package:ruya/models/period_logs/log_day.dart';
import 'package:ruya/models/period_logs/symptom.dart';
import 'package:ruya/security/field_cipher.dart';
import 'package:ruya/security/secure_key_value_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final today = DateTime(2026, 6, 15);
DateTime d(int m, int day) => DateTime(2026, m, day);

const floJson = '''
{
  "operationalData": {
    "cycles": [
      {"period_start_date": "2026-03-02T00:00:00", "period_end_date": "2026-03-06T00:00:00"},
      {"period_start_date": "2026-03-30", "period_end_date": "2026-03-29"},
      {"period_start_date": "2026-04-27", "period_end_date": "2026-07-30"},
      {"period_start_date": "not a date"},
      {"period_start_date": "2026-02-30"}
    ]
  }
}''';

final clueJson = jsonEncode([
  {'date': '2026-05-01', 'type': 'period', 'value': {'option': 'heavy'}},
  {'date': '2026-05-02', 'type': 'period', 'value': {'option': 'very_heavy'}},
  {'date': '2026-05-03', 'type': 'period', 'value': {'option': 'none'}},
  {'date': '2026-05-03', 'type': 'spotting', 'value': {'option': 'spotting'}},
  {'date': '2026-05-01', 'type': 'pain', 'value': [{'option': 'period_cramps'}, {'option': 'ovulation_pain'}, {'option': 'pain_free'}]},
  {'date': '2026-05-01', 'type': 'feelings', 'value': [{'option': 'angry'}, {'option': 'confused'}]},
  {'date': '2026-05-02', 'type': 'energy', 'value': {'option': 'exhausted'}},
  {'date': '2026-05-10', 'type': 'sex_life', 'value': [{'option': 'withdrawal'}, {'option': 'high_sex_drive'}]},
  {'date': '2026-05-11', 'type': 'discharge', 'value': {'option': 'egg_white'}},
  {'date': '2026-05-11', 'type': 'digestion', 'value': [{'option': 'nauseous'}, {'option': 'bloated'}]},
  {'date': '2026-05-12', 'type': 'bbt', 'value': {'temperature': 36.7}},
  {'date': '2026-05-13', 'type': 'skin', 'value': {'option': 'good'}},
  {'date': '2026-05-14', 'type': 'period', 'value': {'option': 'none'}},
  {'date': 'garbage', 'type': 'period', 'value': {'option': 'light'}},
]);

const dripCsv = '﻿date,temperature.value,temperature.time,bleeding.value,bleeding.exclude,mucus.feeling,mucus.texture,'
    'note.value,desire.value,sex.solo,sex.partner,sex.condom,sex.pill,sex.none,pain.cramps,pain.backache,'
    'pain.ovulationPain,mood.happy,mood.stressed,mood.fatigue\r\n'
    '2026-04-01,,,2,false,,,"Cramps, ""bad"" day",,,,,,,true,true,,,true,\r\n'
    '2026-04-02,36.55,07:30,0,,,,,2,,true,true,,,,,,true,,true\r\n'
    '2026-04-03,,,,,0,,,,,true,,,true,,,true,,,\r\n'
    '2026-04-04,,,,,,2,,,,,,,,,,,,,\r\n'
    '2026-04-05,,,,,,,,,,,,,,,,,,,\r\n'
    '2026-13-01,,,3,,,,,,,,,,,,,,,,\r\n';

void main() {
  group('FloImporter', () {
    final result = const FloImporter().tryParse(floJson, today: today)!;

    test('expands cycles into medium-flow days', () {
      for (var i = 2; i <= 6; i++) {
        expect(result.days[d(3, i)]!.flow, FlowRate.medium);
      }
    });

    test('end before start becomes a one-day period', () {
      expect(result.days.containsKey(d(3, 30)), isTrue);
      expect(result.days.containsKey(d(3, 31)), isFalse);
    });

    test('long or future spans are capped at 15 days and never pass today', () {
      final april = result.days.keys.where((k) => !k.isBefore(d(4, 27))).toList()..sort();
      expect(april.length, FloImporter.maxPeriodSpanDays);
      expect(april.last.isAfter(today), isFalse);
    });

    test('bad and impossible dates are skipped', () {
      expect(result.skippedEntries, 2);
    });

    test('non-Flo JSON is not recognised', () {
      expect(const FloImporter().tryParse('{"cycles": []}'), isNull);
      expect(const FloImporter().tryParse('[1,2]'), isNull);
    });
  });

  group('ClueImporter', () {
    final result = const ClueImporter().tryParse(clueJson, today: today)!;

    test('flow, spotting and "none" handling', () {
      expect(result.days[d(5, 1)]!.flow, FlowRate.heavy);
      expect(result.days[d(5, 2)]!.flow, FlowRate.heavy);
      expect(result.days[d(5, 3)]!.flow, FlowRate.spotting);
      // A day with only "period: none" carries nothing and is dropped.
      expect(result.days.containsKey(d(5, 14)), isFalse);
    });

    test('pain and feelings map to symptoms/moods, unknown options become notes', () {
      final day = result.days[d(5, 1)]!;
      expect(day.symptoms, {'cramps'});
      expect(day.moods, [Mood.irritable]);
      expect(day.notes, ['ovulation pain', 'confused']);
      expect(result.days[d(5, 2)]!.moods, [Mood.tired]);
    });

    test('sex life, discharge, digestion and BBT', () {
      final sex = result.days[d(5, 10)]!;
      expect(sex.sexActivity, SexActivity.unprotected);
      expect(sex.contraception, {ContraceptionMethod.withdrawal});
      expect(sex.libido, Libido.high);
      final day11 = result.days[d(5, 11)]!;
      expect(day11.discharge, Discharge.eggWhite);
      expect(day11.symptoms, {'nausea', 'digestion'});
      expect(result.days[d(5, 12)]!.notes, ['BBT 36.7°C']);
      expect(result.days.containsKey(d(5, 13)), isFalse);
      expect(result.skippedEntries, 1);
    });

    test('Flo JSON is not mistaken for Clue', () {
      expect(const ClueImporter().tryParse(floJson), isNull);
    });
  });

  group('DripImporter', () {
    final result = const DripImporter().tryParse(dripCsv, today: today)!;

    test('CSV parser handles BOM, CRLF, quotes and escaped quotes', () {
      final rows = DripImporter.parseCsv('a,"b,c","d ""e"""\r\n1,2,3\n');
      expect(rows, [
        ['a', 'b,c', 'd "e"'],
        ['1', '2', '3'],
      ]);
      expect(result.days[d(4, 1)]!.notes.first, 'Cramps, "bad" day');
    });

    test('bleeding, pain and mood columns', () {
      final day = result.days[d(4, 1)]!;
      expect(day.flow, FlowRate.medium);
      expect(day.symptoms, {'cramps', 'back pain'});
      expect(day.moods, [Mood.anxious]);
      expect(result.days[d(4, 2)]!.flow, FlowRate.spotting);
    });

    test('desire, sex with contraception, temperature', () {
      final day = result.days[d(4, 2)]!;
      expect(day.libido, Libido.high);
      expect(day.sexActivity, SexActivity.protected);
      expect(day.contraception, {ContraceptionMethod.condom});
      expect(day.notes, ['BBT 36.55°C @ 07:30']);
      expect(day.moods, [Mood.happy, Mood.tired]);
    });

    test('sex without contraception is unprotected; mucus and ovulation pain', () {
      final day = result.days[d(4, 3)]!;
      expect(day.sexActivity, SexActivity.unprotected);
      expect(day.discharge, Discharge.dry);
      expect(day.notes, ['ovulation pain']);
      expect(result.days[d(4, 4)]!.discharge, Discharge.eggWhite);
    });

    test('empty rows are dropped, bad dates skipped', () {
      expect(result.days.containsKey(d(4, 5)), isFalse);
      expect(result.skippedEntries, 1);
    });

    test('other CSV files are not recognised', () {
      expect(const DripImporter().tryParse('name,value\na,1\n'), isNull);
    });
  });

  group('ExternalImportService', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    setUp(() async {
      FieldCipher.instance.reset();
      await FieldCipher.instance.init(InMemorySecureKeyValueStore());
      await AppDatabase.instance.init(inMemory: true);
    });
    tearDown(() async => AppDatabase.instance.close());

    test('detects the format', () {
      expect(ExternalImportService.parse(floJson, today: today).source, ImportSource.flo);
      expect(ExternalImportService.parse(clueJson, today: today).source, ImportSource.clue);
      expect(ExternalImportService.parse(dripCsv, today: today).source, ImportSource.drip);
      expect(() => ExternalImportService.parse('hello'), throwsA(isA<ImportFormatException>()));
      expect(() => ExternalImportService.parse('{"a":1}'), throwsA(isA<ImportFormatException>()));
    });

    test('preview lists conflicts and apply never overwrites existing days', () async {
      final repo = LogsRepository();
      await repo.upsertLog(LogDay(
        date: d(4, 1),
        flow: FlowRate.light,
        symptoms: [Symptom.fromDbString('acne')],
        notes: 'mine',
      ));

      final service = ExternalImportService(logsRepository: repo);
      final result = ExternalImportService.parse(dripCsv, today: today);
      final preview = await service.preview(result);
      expect(preview.conflictingDays, [d(4, 1)]);
      expect(preview.newDays, [d(4, 2), d(4, 3), d(4, 4)]);
      expect(preview.flowDays, 1);

      final added = await service.apply(result);
      expect(added, 3);
      final kept = (await repo.readLogForDate(d(4, 1)))!;
      expect(kept.flow, FlowRate.light);
      expect(kept.notes, 'mine');
      expect(kept.symptoms.single.getDbName(), 'acne');

      final imported = (await repo.readLogForDate(d(4, 2)))!;
      expect(imported.libido, Libido.high);
      expect(imported.moods, [Mood.happy, Mood.tired]);
      expect(imported.notes, 'BBT 36.55°C @ 07:30');

      // Re-importing the same file adds nothing.
      expect(await service.apply(result), 0);
    });
  });
}
