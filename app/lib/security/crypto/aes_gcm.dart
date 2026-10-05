import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Thrown when decryption fails (wrong key/password, tampered or truncated data).
class CryptoAuthenticationException implements Exception {
  const CryptoAuthenticationException([this.message = 'Authentication failed']);
  final String message;
  @override
  String toString() => 'CryptoAuthenticationException: $message';
}

/// AES-256-GCM with a 96-bit random nonce and a 128-bit tag.
///
/// Wire format of [seal]: `nonce(12) || ciphertext || tag(16)`, the same layout
/// Mooneva uses (WebCrypto default), so payloads are self-contained.
class AesGcm256 {
  AesGcm256._();

  static const int keyLength = 32;
  static const int nonceLength = 12;
  static const int tagLength = 16;

  static final AesGcm _algorithm = AesGcm.with256bits(nonceLength: nonceLength);
  static final Random _random = Random.secure();

  /// Cryptographically secure random bytes.
  static Uint8List randomBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  static Future<Uint8List> seal(
    List<int> plaintext,
    List<int> key, {
    List<int> aad = const [],
  }) async {
    _checkKey(key);
    final box = await _algorithm.encrypt(
      plaintext,
      secretKey: SecretKey(List<int>.unmodifiable(key)),
      nonce: randomBytes(nonceLength),
      aad: aad,
    );
    return Uint8List.fromList(box.concatenation());
  }

  static Future<Uint8List> open(
    List<int> sealed,
    List<int> key, {
    List<int> aad = const [],
  }) async {
    _checkKey(key);
    if (sealed.length < nonceLength + tagLength) {
      throw const CryptoAuthenticationException('Ciphertext too short');
    }
    try {
      final box = SecretBox.fromConcatenation(
        sealed,
        nonceLength: nonceLength,
        macLength: tagLength,
        copy: true,
      );
      final clear = await _algorithm.decrypt(
        box,
        secretKey: SecretKey(List<int>.unmodifiable(key)),
        aad: aad,
      );
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw const CryptoAuthenticationException();
    }
  }

  static void _checkKey(List<int> key) {
    if (key.length != keyLength) {
      throw ArgumentError('AES-256 key must be $keyLength bytes, got ${key.length}');
    }
  }
}
