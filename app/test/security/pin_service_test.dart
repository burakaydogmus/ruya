import 'package:flutter_test/flutter_test.dart';
import 'package:ruya/security/crypto/pbkdf2.dart';
import 'package:ruya/security/pin_service.dart';
import 'package:ruya/security/secure_key_value_store.dart';

void main() {
  setUpAll(() => Pbkdf2Sha256.useNative = false);

  late InMemorySecureKeyValueStore store;
  late DateTime now;
  late PinService pins;

  setUp(() {
    store = InMemorySecureKeyValueStore();
    now = DateTime(2026, 1, 1, 12);
    pins = PinService(store, clock: () => now);
  });

  test('validates PIN format', () {
    expect(PinService.isValidPin('1234'), isTrue);
    expect(PinService.isValidPin('123456789012'), isTrue);
    expect(PinService.isValidPin('123'), isFalse);
    expect(PinService.isValidPin('1234567890123'), isFalse);
    expect(PinService.isValidPin('12a4'), isFalse);
  });

  test('stores only a salted hash and verifies', () async {
    expect(await pins.hasPin(), isFalse);
    await pins.setPin('2468');
    expect(await pins.hasPin(), isTrue);
    expect(store.values.values.any((v) => v.contains('2468')), isFalse);
    expect(await pins.verify('2468'), isA<PinCorrect>());
    expect(await pins.verify('1111'), isA<PinWrong>());
  });

  test('locks out after 5 wrong attempts with escalating duration', () async {
    await pins.setPin('2468');
    for (var i = 0; i < 4; i++) {
      final r = await pins.verify('0000');
      expect((r as PinWrong).attemptsLeft, 4 - i);
    }
    final locked = await pins.verify('0000');
    expect(locked, isA<PinLockedOut>());
    expect((locked as PinLockedOut).until, now.add(const Duration(seconds: 30)));

    // Even the correct PIN is rejected while locked.
    expect(await pins.verify('2468'), isA<PinLockedOut>());

    now = now.add(const Duration(seconds: 31));
    for (var i = 0; i < 4; i++) {
      await pins.verify('0000');
    }
    final second = await pins.verify('0000') as PinLockedOut;
    expect(second.until, now.add(const Duration(minutes: 1)));

    now = now.add(const Duration(minutes: 2));
    expect(await pins.verify('2468'), isA<PinCorrect>());
    expect(await pins.lockedUntil(), isNull);
  });

  test('removing the PIN clears hash and lockout', () async {
    await pins.setPin('2468');
    await pins.verify('0000');
    await pins.removePin();
    expect(await pins.hasPin(), isFalse);
    expect(store.values, isEmpty);
  });
}
