import 'package:ruya/models/period_logs/log_day.dart';
import 'package:ruya/security/field_cipher.dart';

/// Converts `period_logs` rows between their stored (encrypted) form and plaintext.
///
/// Used by the repository, by JSON export/import and by the encrypted backup so
/// exported data never contains device-bound ciphertext.
class LogRowCodec {
  LogRowCodec._();

  static const String notesColumn = 'period_logs.notes';
  static const String medicationsColumn = 'period_logs.medications';

  /// Row ready to be written to SQLite.
  static Future<Map<String, dynamic>> toDbRow(LogDay log) async {
    final row = log.toMap();
    return encryptRow(row);
  }

  /// Encrypts the sensitive columns of a plaintext row (already-encrypted values are kept).
  static Future<Map<String, dynamic>> encryptRow(Map<String, dynamic> row) async {
    final out = Map<String, dynamic>.from(row);
    out['notes'] = await _encrypt(out['notes'] as String?, notesColumn);
    out['medications'] = await _encrypt(out['medications'] as String?, medicationsColumn);
    return out;
  }

  /// Decrypts the sensitive columns of a stored row.
  static Future<Map<String, dynamic>> decryptRow(Map<String, Object?> row) async {
    final out = Map<String, dynamic>.from(row);
    if (out.containsKey('notes')) {
      out['notes'] = await FieldCipher.instance.decrypt(out['notes'] as String?, column: notesColumn);
    }
    if (out.containsKey('medications')) {
      out['medications'] =
          await FieldCipher.instance.decrypt(out['medications'] as String?, column: medicationsColumn);
    }
    return out;
  }

  static Future<String?> _encrypt(String? value, String column) async {
    if (value == null || value.isEmpty || FieldCipher.isEncrypted(value)) return value;
    return FieldCipher.instance.encrypt(value, column: column);
  }
}
