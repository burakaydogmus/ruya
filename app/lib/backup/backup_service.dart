import 'dart:typed_data';

import 'package:ruya/backup/backup_format.dart';
import 'package:ruya/database/app_database.dart';
import 'package:ruya/database/log_row_codec.dart';
import 'package:ruya/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// Summary shown to the user before a backup replaces their data.
class BackupPreview {
  const BackupPreview({
    required this.createdAt,
    required this.appVersion,
    required this.schemaVersion,
    required this.dbVersion,
    required this.tableCounts,
    required this.firstLogDate,
    required this.lastLogDate,
  });

  final DateTime? createdAt;
  final String? appVersion;
  final int schemaVersion;
  final int? dbVersion;
  final Map<String, int> tableCounts;
  final DateTime? firstLogDate;
  final DateTime? lastLogDate;

  int count(String table) => tableCounts[table] ?? 0;
  int get logCount => count('period_logs');
  int get periodCount => count('periods');
  int get totalRows => tableCounts.values.fold(0, (a, b) => a + b);
}

/// Full encrypted backup of the database and preferences.
///
/// Payload (inside [BackupEnvelope]):
/// ```json
/// { "format": "ruya-backup", "schemaVersion": 1, "createdAt": "...",
///   "appVersion": "1.0.0", "dbVersion": 12,
///   "tables": { "<table>": [ {row}, ... ] },
///   "preferences": { "<key>": {"t": "bool|int|double|string|list", "v": ...} } }
/// ```
/// * Encrypted DB columns are exported as plaintext (the whole file is
///   encrypted with the backup password) and re-encrypted with this device's
///   key on restore, so backups move between devices.
/// * Rows are restored column-by-column against the current schema, so backups
///   from older DB versions restore cleanly and unknown columns are ignored.
/// * `schemaVersion` describes the payload layout; [migratePayload] upgrades
///   older payloads when the layout changes.
class BackupService {
  BackupService({AppDatabase? database, required this.prefs, required this.appVersion})
      : _db = database ?? AppDatabase.instance;

  final AppDatabase _db;
  final SharedPreferences prefs;
  final String appVersion;

  static const String format = 'ruya-backup';
  static const int schemaVersion = 1;

  /// Preferences that belong to this device and are never exported or overwritten.
  static const Set<String> devicePreferenceKeys = {
    biometricEnabledKey,
    pinTimeoutSecondsKey,
    tamponReminderDateTimeKey,
    'processed_watch_timestamps',
  };

  Future<Uint8List> createEncryptedBackup(
    String password, {
    int iterations = BackupEnvelope.defaultIterations,
  }) async {
    if (password.length < BackupEnvelope.minPasswordLength) {
      throw ArgumentError('Backup password is too short');
    }
    return BackupEnvelope.seal(await buildPayload(), password, iterations: iterations);
  }

  /// Decrypts, validates and migrates a backup file. Does not change any data.
  Future<Map<String, dynamic>> readEncryptedBackup(List<int> bytes, String password) async {
    final payload = await BackupEnvelope.open(bytes, password);
    return migratePayload(payload);
  }

  Future<Map<String, dynamic>> buildPayload() async {
    final db = await _db.database;
    final tables = <String, List<Map<String, dynamic>>>{};
    for (final table in await _userTables(db)) {
      final rows = await db.query(table);
      tables[table] = [
        for (final row in rows)
          table == 'period_logs' ? await LogRowCodec.decryptRow(row) : Map<String, dynamic>.from(row),
      ];
    }

    final preferences = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      if (devicePreferenceKeys.contains(key)) continue;
      final value = prefs.get(key);
      final typed = switch (value) {
        bool v => {'t': 'bool', 'v': v},
        int v => {'t': 'int', 'v': v},
        double v => {'t': 'double', 'v': v},
        String v => {'t': 'string', 'v': v},
        List v => {'t': 'list', 'v': v.map((e) => e.toString()).toList()},
        _ => null,
      };
      if (typed != null) preferences[key] = typed;
    }

    return {
      'format': format,
      'schemaVersion': schemaVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'appVersion': appVersion,
      'dbVersion': await db.getVersion(),
      'tables': tables,
      'preferences': preferences,
    };
  }

  /// Validates the payload and upgrades it to [schemaVersion].
  static Map<String, dynamic> migratePayload(Map<String, dynamic> payload) {
    if (payload['format'] != format) {
      throw const BackupFormatException('Not a RUYA backup');
    }
    final version = payload['schemaVersion'];
    if (version is! int || version < 1) {
      throw const BackupFormatException('Missing schemaVersion');
    }
    if (version > schemaVersion) {
      throw const BackupFormatException('Backup was created by a newer RUYA version');
    }
    // Future layout changes: `if (version < 2) payload = _v1ToV2(payload);`
    if (payload['tables'] is! Map) {
      throw const BackupFormatException('Backup has no data');
    }
    return payload;
  }

  static BackupPreview preview(Map<String, dynamic> payload) {
    final tables = (payload['tables'] as Map).cast<String, dynamic>();
    final counts = <String, int>{
      for (final e in tables.entries) e.key: (e.value is List) ? (e.value as List).length : 0,
    };
    DateTime? first;
    DateTime? last;
    for (final row in (tables['period_logs'] as List?) ?? const []) {
      final date = row is Map ? DateTime.tryParse('${row['date']}') : null;
      if (date == null) continue;
      if (first == null || date.isBefore(first)) first = date;
      if (last == null || date.isAfter(last)) last = date;
    }
    return BackupPreview(
      createdAt: DateTime.tryParse('${payload['createdAt']}')?.toLocal(),
      appVersion: payload['appVersion'] as String?,
      schemaVersion: payload['schemaVersion'] as int,
      dbVersion: payload['dbVersion'] as int?,
      tableCounts: counts,
      firstLogDate: first,
      lastLogDate: last,
    );
  }

  /// Replaces all current data with the backup, in a single transaction.
  /// If anything fails nothing is changed.
  Future<void> restoreReplacingAll(Map<String, dynamic> payload) async {
    final migrated = migratePayload(payload);
    final tables = (migrated['tables'] as Map).cast<String, dynamic>();
    final db = await _db.database;
    final currentTables = await _userTables(db);

    // Prepare (and encrypt) everything before touching the database.
    final prepared = <String, List<Map<String, dynamic>>>{};
    for (final table in currentTables) {
      final columns = await _columns(db, table);
      final rows = (tables[table] as List?) ?? const [];
      final out = <Map<String, dynamic>>[];
      for (final raw in rows) {
        if (raw is! Map) continue;
        final row = <String, dynamic>{
          for (final e in raw.entries)
            if (columns.contains(e.key)) e.key as String: e.value,
        };
        out.add(table == 'period_logs' ? await LogRowCodec.encryptRow(row) : row);
      }
      prepared[table] = out;
    }

    await db.transaction((txn) async {
      for (final table in currentTables) {
        await txn.delete(table);
        final batch = txn.batch();
        for (final row in prepared[table]!) {
          batch.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      }
    });

    final preferences = (migrated['preferences'] as Map?)?.cast<String, dynamic>() ?? const {};
    for (final e in preferences.entries) {
      if (devicePreferenceKeys.contains(e.key) || e.value is! Map) continue;
      final v = (e.value as Map)['v'];
      switch ((e.value as Map)['t']) {
        case 'bool' when v is bool:
          await prefs.setBool(e.key, v);
        case 'int' when v is int:
          await prefs.setInt(e.key, v);
        case 'double' when v is num:
          await prefs.setDouble(e.key, v.toDouble());
        case 'string' when v is String:
          await prefs.setString(e.key, v);
        case 'list' when v is List:
          await prefs.setStringList(e.key, v.map((x) => '$x').toList());
      }
    }
  }

  static Future<List<String>> _userTables(DatabaseExecutor db) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%' AND name != 'android_metadata' ORDER BY name",
    );
    return rows.map((r) => r['name'] as String).toList();
  }

  static Future<Set<String>> _columns(DatabaseExecutor db, String table) async {
    final rows = await db.rawQuery('PRAGMA table_info("$table")');
    return rows.map((r) => r['name'] as String).toSet();
  }
}
