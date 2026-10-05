import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ruya/security/crypto/aes_gcm.dart';
import 'package:ruya/security/crypto/pbkdf2.dart';

class BackupFormatException implements Exception {
  const BackupFormatException(this.message);
  final String message;
  @override
  String toString() => 'BackupFormatException: $message';
}

/// Wrong password, or the file was modified/damaged (GCM tag mismatch).
class BackupPasswordException implements Exception {
  const BackupPasswordException();
}

/// Encrypted RUYA backup envelope (`.ruya` file).
///
/// ```text
/// offset size  field
/// 0      4     magic "RUYA"
/// 4      1     container version (1)
/// 5      1     KDF id (1 = PBKDF2-HMAC-SHA256)
/// 6      4     KDF iterations, uint32 big-endian
/// 10     16    salt
/// 26     12    AES-GCM nonce
/// 38     n     ciphertext of gzip(UTF-8 JSON payload)
/// 38+n   16    GCM tag
/// ```
/// Bytes 0..25 (the header) are authenticated as AAD, so the KDF parameters
/// cannot be tampered with. The JSON payload carries its own `schemaVersion`.
class BackupEnvelope {
  BackupEnvelope._();

  static const List<int> magic = [0x52, 0x55, 0x59, 0x41]; // "RUYA"
  static const int containerVersion = 1;
  static const int kdfPbkdf2Sha256 = 1;
  static const int defaultIterations = 600000;
  static const int saltLength = 16;
  static const int headerLength = 4 + 1 + 1 + 4 + saltLength;
  static const int minPasswordLength = 8;

  static const String fileExtension = 'ruya';
  static const String mimeType = 'application/octet-stream';

  static bool looksLikeBackup(List<int> bytes) =>
      bytes.length > headerLength &&
      bytes[0] == magic[0] &&
      bytes[1] == magic[1] &&
      bytes[2] == magic[2] &&
      bytes[3] == magic[3];

  static Future<Uint8List> seal(
    Map<String, dynamic> payload,
    String password, {
    int iterations = defaultIterations,
  }) async {
    final salt = AesGcm256.randomBytes(saltLength);
    final header = BytesBuilder()
      ..add(magic)
      ..addByte(containerVersion)
      ..addByte(kdfPbkdf2Sha256)
      ..add(_uint32(iterations))
      ..add(salt);
    final headerBytes = header.toBytes();
    final key = await Pbkdf2Sha256.derive(
      password: utf8.encode(password),
      salt: salt,
      iterations: iterations,
    );
    final plain = gzip.encode(utf8.encode(jsonEncode(payload)));
    final sealed = await AesGcm256.seal(plain, key, aad: headerBytes);
    return (BytesBuilder()
          ..add(headerBytes)
          ..add(sealed))
        .toBytes();
  }

  static Future<Map<String, dynamic>> open(List<int> bytes, String password) async {
    if (!looksLikeBackup(bytes)) {
      throw const BackupFormatException('Not a RUYA backup file');
    }
    final version = bytes[4];
    if (version != containerVersion) {
      throw BackupFormatException('Unsupported backup container version $version');
    }
    if (bytes[5] != kdfPbkdf2Sha256) {
      throw BackupFormatException('Unsupported key derivation ${bytes[5]}');
    }
    final iterations = ByteData.sublistView(Uint8List.fromList(bytes.sublist(6, 10))).getUint32(0);
    if (iterations < 10000 || iterations > 10000000) {
      throw const BackupFormatException('Invalid key derivation parameters');
    }
    final header = bytes.sublist(0, headerLength);
    final salt = bytes.sublist(10, headerLength);
    final key = await Pbkdf2Sha256.derive(
      password: utf8.encode(password),
      salt: salt,
      iterations: iterations,
    );
    final List<int> plain;
    try {
      plain = await AesGcm256.open(bytes.sublist(headerLength), key, aad: header);
    } on CryptoAuthenticationException {
      throw const BackupPasswordException();
    }
    try {
      final decoded = jsonDecode(utf8.decode(gzip.decode(plain)));
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      return decoded;
    } catch (_) {
      throw const BackupFormatException('Backup content is damaged');
    }
  }

  static Uint8List _uint32(int value) => Uint8List(4)..buffer.asByteData().setUint32(0, value);
}
