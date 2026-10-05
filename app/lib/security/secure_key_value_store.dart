import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Minimal key/value interface over the platform secure store, so security
/// services can be unit-tested with [InMemorySecureKeyValueStore].
abstract class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Android: values are AES-GCM encrypted with a key held in the Android Keystore.
class PlatformSecureKeyValueStore implements SecureKeyValueStore {
  PlatformSecureKeyValueStore()
      : _storage = const FlutterSecureStorage(
          // Never silently wipe on a Keystore error: losing the data key would make
          // encrypted fields unreadable. Errors surface to the caller instead.
          aOptions: AndroidOptions(resetOnError: false),
        );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class InMemorySecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
