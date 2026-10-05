import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:ruya/security/crypto/aes_gcm.dart';
import 'package:ruya/security/secure_key_value_store.dart';
import 'package:sqflite/sqflite.dart' as plain;
import 'package:sqflite_sqlcipher/sqflite.dart' as cipher;

/// Full-database encryption with SQLCipher (Android).
///
/// * The database file is `app_database_enc.db`, encrypted with a random
///   256-bit passphrase kept in the platform secure store (Android Keystore).
/// * An existing plaintext `app_database.db` (Menstrudel / RUYA ≤ 1.0) is
///   migrated once with `sqlcipher_export`. The plaintext file is deleted only
///   after the encrypted copy was reopened and verified (schema version and
///   row counts); on any failure the plaintext database stays in use.
/// * Column-level AES-GCM (FieldCipher) stays on top as defense in depth.
class DatabaseEncryption {
  DatabaseEncryption._();

  static const String plainFileName = 'app_database.db';
  static const String encryptedFileName = 'app_database_enc.db';
  static const String _keyName = 'ruya_db_passphrase_v1';

  static String? _passphrase;

  /// True once a passphrase is available and the encrypted database is in use.
  static bool get isEnabled => _passphrase != null;

  @visibleForTesting
  static void reset() => _passphrase = null;

  /// Loads or creates the passphrase and migrates a plaintext database.
  /// Returns false if encryption could not be set up (the app then keeps using
  /// the plaintext database, as before).
  static Future<bool> prepare(SecureKeyValueStore store) async {
    try {
      var passphrase = await store.read(_keyName);
      if (passphrase == null) {
        passphrase = _hex(AesGcm256.randomBytes(32));
        await store.write(_keyName, passphrase);
      }
      final dir = await plain.getDatabasesPath();
      final plainPath = p.join(dir, plainFileName);
      final encPath = p.join(dir, encryptedFileName);

      if (File(plainPath).existsSync() && !File(encPath).existsSync()) {
        await _migrate(plainPath, encPath, passphrase);
      }
      if (File(plainPath).existsSync() && !File(encPath).existsSync()) {
        // Migration failed; keep the plaintext database rather than lose data.
        return false;
      }
      _passphrase = passphrase;
      return true;
    } catch (e) {
      debugPrint('Database encryption unavailable: $e');
      return false;
    }
  }

  /// Opens the encrypted database (call only when [isEnabled]).
  static Future<plain.Database> open({
    required int version,
    required plain.OnDatabaseCreateFn onCreate,
    required plain.OnDatabaseVersionChangeFn onUpgrade,
  }) async {
    final dir = await plain.getDatabasesPath();
    return cipher.openDatabase(
      p.join(dir, encryptedFileName),
      password: _passphrase,
      version: version,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
    );
  }

  static Future<void> _migrate(String plainPath, String encPath, String passphrase) async {
    plain.Database? source;
    try {
      // SQLCipher opens a plaintext database when no key is given.
      source = await cipher.openDatabase(plainPath, password: '', singleInstance: false);
      final version = await source.getVersion();
      final counts = await _rowCounts(source);
      await source.execute("ATTACH DATABASE '${_escape(encPath)}' AS encrypted KEY '$passphrase'");
      await source.rawQuery("SELECT sqlcipher_export('encrypted')");
      await source.execute('PRAGMA encrypted.user_version = $version');
      await source.execute('DETACH DATABASE encrypted');
      await source.close();
      source = null;

      final check = await cipher.openDatabase(encPath, password: passphrase, singleInstance: false);
      try {
        final ok = await check.getVersion() == version && mapEquals(await _rowCounts(check), counts);
        if (!ok) throw StateError('Encrypted copy does not match the original');
      } finally {
        await check.close();
      }

      for (final suffix in const ['', '-journal', '-wal', '-shm']) {
        final f = File('$plainPath$suffix');
        if (f.existsSync()) f.deleteSync();
      }
      debugPrint('Database migrated to SQLCipher (${counts.length} tables)');
    } catch (e) {
      debugPrint('SQLCipher migration failed, keeping plaintext database: $e');
      await source?.close();
      for (final suffix in const ['', '-journal', '-wal', '-shm']) {
        final f = File('$encPath$suffix');
        if (f.existsSync()) f.deleteSync();
      }
    }
  }

  static Future<Map<String, int>> _rowCounts(plain.Database db) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' "
      "AND name != 'android_metadata' ORDER BY name",
    );
    return {
      for (final t in tables)
        t['name'] as String: plain.Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM "${t['name']}"')) ?? 0,
    };
  }

  static String _escape(String s) => s.replaceAll("'", "''");

  static String _hex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// Debug helper: first bytes of the database file ("SQLite format 3" = plaintext).
  @visibleForTesting
  static Future<String> fileHeader(String path) async {
    final raf = await File(path).open();
    try {
      return latin1.decode(await raf.read(15), allowInvalid: true);
    } finally {
      await raf.close();
    }
  }
}
