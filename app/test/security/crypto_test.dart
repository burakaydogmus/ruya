import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ruya/security/crypto/aes_gcm.dart';
import 'package:ruya/security/crypto/pbkdf2.dart';
import 'package:ruya/security/field_cipher.dart';
import 'package:ruya/security/secure_key_value_store.dart';

String _hex(List<int> b) => b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();

void main() {
  setUpAll(() => Pbkdf2Sha256.useNative = false);

  group('PBKDF2-HMAC-SHA256', () {
    // RFC 7914 §11 test vector.
    test('matches the RFC 7914 vector (passwd/salt, c=1, dkLen=64)', () async {
      final out = await Pbkdf2Sha256.derive(
        password: utf8.encode('passwd'),
        salt: utf8.encode('salt'),
        iterations: 1,
        lengthBytes: 64,
      );
      expect(
        _hex(out),
        '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc'
        '49ca9cccf179b645991664b39d77ef317c71b845b1e30bd509112041d3a19783',
      );
    });

    test('matches the RFC 7914 vector (Password/NaCl, c=80000, dkLen=64)', () async {
      final out = await Pbkdf2Sha256.derive(
        password: utf8.encode('Password'),
        salt: utf8.encode('NaCl'),
        iterations: 80000,
        lengthBytes: 64,
      );
      expect(
        _hex(out),
        '4ddcd8f60b98be21830cee5ef22701f9641a4418d04c0414aeff08876b34ab56'
        'a1d425a1225833549adb841b51c9b3176a272bdebba1d078478f62b397f33c8d',
      );
    });
  });

  group('AES-256-GCM', () {
    final key = Uint8List.fromList(List.generate(32, (i) => i));

    test('round-trips and uses a fresh nonce each time', () async {
      final a = await AesGcm256.seal(utf8.encode('merhaba'), key);
      final b = await AesGcm256.seal(utf8.encode('merhaba'), key);
      expect(a, isNot(equals(b)));
      expect(a.length, 12 + 7 + 16);
      expect(utf8.decode(await AesGcm256.open(a, key)), 'merhaba');
    });

    test('rejects tampering, wrong key and wrong AAD', () async {
      final sealed = await AesGcm256.seal(utf8.encode('secret'), key, aad: utf8.encode('a'));
      final tampered = Uint8List.fromList(sealed)..[15] ^= 1;
      expect(() => AesGcm256.open(tampered, key, aad: utf8.encode('a')),
          throwsA(isA<CryptoAuthenticationException>()));
      final otherKey = Uint8List.fromList(List.filled(32, 9));
      expect(() => AesGcm256.open(sealed, otherKey, aad: utf8.encode('a')),
          throwsA(isA<CryptoAuthenticationException>()));
      expect(() => AesGcm256.open(sealed, key, aad: utf8.encode('b')),
          throwsA(isA<CryptoAuthenticationException>()));
    });
  });

  group('FieldCipher', () {
    test('creates the data key once and reuses it', () async {
      final store = InMemorySecureKeyValueStore();
      final cipher = FieldCipher.instance..reset();
      await cipher.init(store);
      final enc = await cipher.encrypt('not', column: 'c');
      cipher.reset();
      await cipher.init(store);
      expect(await cipher.decrypt(enc, column: 'c'), 'not');
      expect(store.values.length, 1);
    });

    test('plaintext legacy values pass through and empty values stay null', () async {
      final cipher = FieldCipher.instance..reset();
      await cipher.init(InMemorySecureKeyValueStore());
      expect(await cipher.decrypt('legacy note', column: 'c'), 'legacy note');
      expect(await cipher.encrypt('', column: 'c'), isNull);
      expect(await cipher.encrypt(null, column: 'c'), isNull);
    });

    test('refuses to write plaintext before init', () async {
      final cipher = FieldCipher.instance..reset();
      expect(() => cipher.encrypt('x', column: 'c'), throwsStateError);
    });
  });
}
