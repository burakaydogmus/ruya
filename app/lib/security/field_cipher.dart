import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:ruya/security/crypto/aes_gcm.dart';
import 'package:ruya/security/secure_key_value_store.dart';

/// Column-level encryption for free-text fields in SQLite (notes, medication names).
///
/// A random 256-bit data key is created on first launch and kept in the platform
/// secure store (Android Keystore). Encrypted values look like `enc:v1:<base64>`
/// where the payload is `nonce || ciphertext || tag` and the column name is bound
/// as AAD so values cannot be swapped between columns.
///
/// Values without the prefix are treated as legacy plaintext and returned as-is,
/// which keeps Menstrudel data and imports readable.
class FieldCipher {
  FieldCipher._();

  static final FieldCipher instance = FieldCipher._();

  static const String prefix = 'enc:v1:';
  static const String _keyName = 'ruya_field_key_v1';

  Uint8List? _key;

  bool get isReady => _key != null;

  /// Loads the data key or creates it on first launch.
  Future<void> init(SecureKeyValueStore store) async {
    final existing = await store.read(_keyName);
    if (existing != null) {
      final decoded = base64Decode(existing);
      if (decoded.length != AesGcm256.keyLength) {
        throw StateError('Stored field key has an invalid length');
      }
      _key = decoded;
      return;
    }
    final key = AesGcm256.randomBytes(AesGcm256.keyLength);
    await store.write(_keyName, base64Encode(key));
    _key = key;
  }

  @visibleForTesting
  void reset() => _key = null;

  static bool isEncrypted(String? value) => value != null && value.startsWith(prefix);

  /// Encrypts [plain] for [column]. Null/empty values are stored as null.
  Future<String?> encrypt(String? plain, {required String column}) async {
    if (plain == null || plain.isEmpty) return null;
    final key = _key;
    if (key == null) {
      throw StateError('FieldCipher used before init(): refusing to store plaintext');
    }
    final sealed = await AesGcm256.seal(utf8.encode(plain), key, aad: utf8.encode(column));
    return '$prefix${base64Encode(sealed)}';
  }

  /// Decrypts a stored value. Returns null if the value cannot be decrypted
  /// (for example after the Keystore key was lost); the caller shows it as locked.
  Future<String?> decrypt(String? stored, {required String column}) async {
    if (stored == null || !isEncrypted(stored)) return stored;
    final key = _key;
    if (key == null) return null;
    try {
      final payload = base64Decode(stored.substring(prefix.length));
      final clear = await AesGcm256.open(payload, key, aad: utf8.encode(column));
      return utf8.decode(clear);
    } catch (e) {
      debugPrint('FieldCipher: could not decrypt $column ($e)');
      return null;
    }
  }
}
