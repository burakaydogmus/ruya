import 'dart:isolate';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// PBKDF2-HMAC-SHA256 over raw password bytes.
///
/// On Android the work runs in Kotlin (`javax.crypto.Mac`), which is far faster
/// than the pure Dart implementation for high iteration counts. Everywhere else
/// (unit tests, other platforms) the Dart implementation runs in a background
/// isolate. Both produce identical output because both hash the raw bytes.
class Pbkdf2Sha256 {
  Pbkdf2Sha256._();

  static const MethodChannel _channel = MethodChannel('com.burakaydogmus.ruya/crypto');

  /// Set to false in tests to force the Dart implementation.
  @visibleForTesting
  static bool useNative = true;

  static Future<Uint8List> derive({
    required List<int> password,
    required List<int> salt,
    required int iterations,
    int lengthBytes = 32,
  }) async {
    if (iterations < 1) throw ArgumentError.value(iterations, 'iterations');
    if (useNative && !kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final result = await _channel.invokeMethod<Uint8List>('pbkdf2Sha256', {
          'password': Uint8List.fromList(password),
          'salt': Uint8List.fromList(salt),
          'iterations': iterations,
          'length': lengthBytes,
        });
        if (result != null && result.length == lengthBytes) return result;
      } on MissingPluginException {
        // Fall through to the Dart implementation.
      } on PlatformException catch (e) {
        debugPrint('Native PBKDF2 failed, using Dart fallback: ${e.code}');
      }
    }
    final p = Uint8List.fromList(password);
    final s = Uint8List.fromList(salt);
    return Isolate.run(() => _dartDerive(p, s, iterations, lengthBytes));
  }

  static Future<Uint8List> _dartDerive(
    Uint8List password,
    Uint8List salt,
    int iterations,
    int lengthBytes,
  ) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: lengthBytes * 8,
    );
    final key = await pbkdf2.deriveKey(secretKey: SecretKey(password), nonce: salt);
    return Uint8List.fromList(await key.extractBytes());
  }
}
