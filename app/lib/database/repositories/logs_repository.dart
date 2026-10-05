import 'package:flutter/material.dart';

import 'package:ruya/database/app_database.dart';
import 'package:ruya/database/log_row_codec.dart';
import 'package:ruya/models/period_logs/daily_log_enums.dart';
import 'package:ruya/database/validation/log_validator.dart';
import 'package:ruya/models/period_logs/log_day.dart';
import 'package:ruya/models/period_logs/symptom.dart';
import 'package:ruya/models/flows/flow_enum.dart';
import 'package:ruya/utils/exceptions.dart';
import 'package:sqflite/sqflite.dart';

class LogsRepository {
  final dbProvider = AppDatabase.instance;
  static const String _whereId = 'id = ?';

  // Helpers

  Future<void> logFromWatch() async {
    debugPrint('Received request from watch! Logging entry now...');

    try {
      final existing = await readLogForDate(DateTime.now());
      if (existing != null) {
        // Today may already hold a mood/notes-only log; mark it as a period day.
        if (existing.flow == FlowRate.none) {
          await upsertLog(existing.copyWith(flow: FlowRate.medium));
          debugPrint('Watch log merged into the existing log for today.');
        } else {
          debugPrint('Watch log ignored: today is already logged as a period day.');
        }
        return;
      }

      final newLog = LogDay(
        date: DateTime.now(),
        flow: FlowRate.medium,
        painLevel: null,
      );

      await upsertLog(newLog);
      debugPrint('Successfully logged period from the watch.');
    } on DuplicateLogException {
      debugPrint('Watch log ignored: A log for today already exists.');
    } catch (e) {
      debugPrint('An error occurred while logging from the watch: $e');
    }
  }

  // Main methods

  /// Updates and inserts a log entry.
  /// If the entry has an ID, it updates the existing log; otherwise, it creates a new one.
  /// Validates for duplicate/future dates before performing the operation.
  /// Throws [DuplicateLogException] if a log already exists for the given date - Use [idToExclude] to exclude an ID when updating.
  /// Throws [FutureDateException] if the date is in the future.
  /// Returns the ID of the inserted or updated log.
  Future<int> upsertLog(LogDay entry) async {
    final validator = LogValidator(this);
    await validator.validate(entry.date, idToExclude: entry.id);

    final db = await dbProvider.database;
    final row = await LogRowCodec.toDbRow(entry);

    return await db.transaction((txn) async {
      int logId;

      if (entry.id != null) {
        logId = entry.id!;
        await txn.update(
          'period_logs',
          row,
          where: 'id = ?',
          whereArgs: [logId],
        );
      } else {
        logId = await txn.insert('period_logs', row..remove('id'));
      }

      await txn.delete(
        'log_symptoms',
        where: 'log_id_fk = ?',
        whereArgs: [logId],
      );

      if (entry.symptoms.isNotEmpty) {
        final batch = txn.batch();
        for (final symptom in entry.symptoms) {
          batch.insert('log_symptoms', {
            'log_id_fk': logId,
            'symptom': symptom.getDbName(),
          });
        }
        await batch.commit(noResult: true);
      }

      await txn.delete('log_moods', where: 'log_id_fk = ?', whereArgs: [logId]);
      if (entry.moods.isNotEmpty) {
        final batch = txn.batch();
        for (final mood in entry.moods.toSet()) {
          batch.insert('log_moods', {'log_id_fk': logId, 'mood': mood.dbValue});
        }
        await batch.commit(noResult: true);
      }

      return logId;
    });
  }

  Future<Map<int, List<Mood>>> _readMoodMap(DatabaseExecutor db) async {
    final rows = await db.query('log_moods');
    final Map<int, List<Mood>> moods = {};
    for (final row in rows) {
      final mood = Mood.fromDb(row['mood'] as String?);
      if (mood == null) continue;
      (moods[row['log_id_fk'] as int] ??= []).add(mood);
    }
    for (final list in moods.values) {
      list.sort((a, b) => a.index.compareTo(b.index));
    }
    return moods;
  }

  Future<Map<int, List<Symptom>>> _readSymptomMap(DatabaseExecutor db) async {
    final symptomsResult = await db.query('log_symptoms');
    final Map<int, List<Symptom>> symptomMap = {};
    for (final row in symptomsResult) {
      final int logId = row['log_id_fk'] as int;
      final String symptom = row['symptom'] as String;
      (symptomMap[logId] ??= []).add(Symptom.fromDbString(symptom));
    }
    return symptomMap;
  }

  Future<List<LogDay>> _rowsToLogs(DatabaseExecutor db, List<Map<String, Object?>> rows) async {
    final symptomMap = await _readSymptomMap(db);
    final moodMap = await _readMoodMap(db);
    final logs = <LogDay>[];
    for (final row in rows) {
      final int logId = row['id'] as int;
      final decrypted = await LogRowCodec.decryptRow(row);
      logs.add(LogDay.fromMap(
        decrypted,
        symptoms: symptomMap[logId] ?? [],
        moods: moodMap[logId] ?? [],
      ));
    }
    return logs;
  }

  /// Returns the log stored for the calendar day of [date], if any.
  Future<LogDay?> readLogForDate(DateTime date) async {
    final db = await dbProvider.database;
    final result = await db.query(
      'period_logs',
      where: 'date(date) = date(?)',
      whereArgs: [date.toIso8601String()],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return (await _rowsToLogs(db, result)).first;
  }

  Future<List<LogDay>> readAllLogs() async {
    final db = await dbProvider.database;

    const orderBy = 'date DESC';
    final logsResult = await db.query('period_logs', orderBy: orderBy);

    return _rowsToLogs(db, logsResult);
  }

  Future<LogDay> readLog(int id) async {
    final db = await dbProvider.database;

    final result = await db.query(
      'period_logs',
      where: _whereId,
      whereArgs: [id],
    );

    if (result.isEmpty) {
      throw Exception('Log with id $id not found');
    }

    return (await _rowsToLogs(db, result)).first;
  }

  /// Reads all logs since the given date, including their associated symptoms.
  Future<List<LogDay>> readLogsSince(DateTime date) async {
    final db = await dbProvider.database;

    // `date` is ISO-8601 TEXT; Menstrudel compared it with an int, which matched everything.
    final logsResult = await db.query(
      'period_logs',
      where: 'date >= ?',
      whereArgs: [date.toIso8601String()],
      orderBy: 'date DESC',
    );

    return _rowsToLogs(db, logsResult);
  }

  Future<void> updateLogPeriodIds(Map<int, int> mapping) async {
    final db = await dbProvider.database;
    final batch = db.batch();

    batch.update('period_logs', {'period_id': -1});

    mapping.forEach((logId, periodId) {
      batch.update(
        'period_logs',
        {'period_id': periodId},
        where: 'id = ?',
        whereArgs: [logId],
      );
    });

    await batch.commit(noResult: true);
  }

  Future<int> deleteLog(int id) async {
    final db = await dbProvider.database;
    // Foreign keys are not enabled (Menstrudel legacy), so remove children explicitly.
    return await db.transaction((txn) async {
      await txn.delete('log_symptoms', where: 'log_id_fk = ?', whereArgs: [id]);
      await txn.delete('log_moods', where: 'log_id_fk = ?', whereArgs: [id]);
      return txn.delete(
        'period_logs',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  /// Inserts [logs] in one transaction, skipping any calendar day that already
  /// has a log (existing data always wins) and days in the future.
  /// Returns the number of logs inserted.
  Future<int> insertNewLogs(List<LogDay> logs) async {
    final db = await dbProvider.database;
    final existing = (await db.query('period_logs', columns: ['date']))
        .map((r) => DateTime.parse(r['date'] as String))
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final toInsert = <LogDay>[];
    for (final log in logs) {
      final day = DateTime(log.date.year, log.date.month, log.date.day);
      if (day.isAfter(today) || !existing.add(day) || !log.hasContent) continue;
      toInsert.add(log);
    }
    final rows = [for (final log in toInsert) await LogRowCodec.toDbRow(log)];

    await db.transaction((txn) async {
      for (var i = 0; i < toInsert.length; i++) {
        final log = toInsert[i];
        final id = await txn.insert('period_logs', rows[i]..remove('id'));
        final batch = txn.batch();
        for (final symptom in log.symptoms.toSet()) {
          batch.insert('log_symptoms', {'log_id_fk': id, 'symptom': symptom.getDbName()},
              conflictAlgorithm: ConflictAlgorithm.ignore);
        }
        for (final mood in log.moods.toSet()) {
          batch.insert('log_moods', {'log_id_fk': id, 'mood': mood.dbValue},
              conflictAlgorithm: ConflictAlgorithm.ignore);
        }
        await batch.commit(noResult: true);
      }
    });
    return toInsert.length;
  }

  /// Mood counts for logs since [date], used for insights.
  Future<Map<Mood, int>> getMoodFrequencySince(DateTime date) async {
    final db = await dbProvider.database;
    final result = await db.rawQuery(
      'SELECT mood, COUNT(mood) as count FROM log_moods WHERE log_id_fk IN (SELECT id FROM period_logs WHERE date >= ?) GROUP BY mood',
      [date.toIso8601String()],
    );
    final Map<Mood, int> counts = {};
    for (final row in result) {
      final mood = Mood.fromDb(row['mood'] as String?);
      if (mood != null) counts[mood] = row['count'] as int;
    }
    return counts;
  }

  Future<bool> existsOnDate(DateTime date, {int? excludeId}) async {
    final db = await dbProvider.database;
    
    String where = 'date(date) = date(?)';
    List<Object?> args = [date.toIso8601String()];

    if (excludeId != null) {
      where += ' AND id != ?';
      args.add(excludeId);
    }

    final result = await db.query(
      'period_logs',
      where: where,
      whereArgs: args,
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Calculates the usage count for every symptom in the database.
  /// This is used for insights and to show the most common symptoms in the UI.
  /// Is filtered by date to only include recent logs for more relevant insights.
  Future<Map<Symptom, int>> getSymptomFrequencySince(DateTime date) async {
    final db = await dbProvider.database;

    final result = await db.rawQuery(
      'SELECT symptom, COUNT(symptom) as count FROM log_symptoms WHERE log_id_fk IN (SELECT id FROM period_logs WHERE date >= ?) GROUP BY symptom',
      [date.toIso8601String()],
    );

    if (result.isEmpty) {
      return {};
    }
    return {
      for (var row in result)
        Symptom.fromDbString(row['symptom'] as String): row['count'] as int,
    };
  }

  Future<int> getSingleSymptomFrequency(Symptom symptom) async {
    final db = await dbProvider.database;

    var key = symptom.getDbName();

    final result = await db.rawQuery(
      'SELECT symptom, COUNT(symptom) as count FROM log_symptoms WHERE symptom LIKE \'$key\' GROUP BY symptom',
    );

    return result.length == 1 ? result[0]["count"] as int : 0;
  }
}
