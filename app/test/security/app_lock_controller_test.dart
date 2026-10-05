import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruya/security/app_lock_controller.dart';
import 'package:ruya/security/crypto/pbkdf2.dart';
import 'package:ruya/security/pin_service.dart';
import 'package:ruya/security/secure_key_value_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Pbkdf2Sha256.useNative = false;

  late DateTime now;
  late int timeout;
  late bool biometricResult;
  late bool biometricsWanted;
  late AppLockController lock;
  late PinService pins;

  Future<AppLockController> build({bool withPin = true}) async {
    pins = PinService(InMemorySecureKeyValueStore(), clock: () => now);
    if (withPin) await pins.setPin('1357');
    final c = AppLockController(
      pinService: pins,
      timeoutSeconds: () => timeout,
      biometricsPreferred: () => biometricsWanted,
      biometricAuthenticator: (_) async => biometricResult,
      biometricsAvailable: () async => true,
      clock: () => now,
    );
    await c.init(observeLifecycle: false);
    return c;
  }

  setUp(() {
    now = DateTime(2026, 5, 1, 10);
    timeout = 60;
    biometricResult = true;
    biometricsWanted = false;
  });

  void background() => lock.didChangeAppLifecycleState(AppLifecycleState.paused);
  void resume() => lock.didChangeAppLifecycleState(AppLifecycleState.resumed);

  test('no PIN: never locked', () async {
    lock = await build(withPin: false);
    expect(lock.isLocked, isFalse);
    background();
    now = now.add(const Duration(hours: 1));
    resume();
    expect(lock.isLocked, isFalse);
  });

  test('locked on cold start and unlocked with the right PIN only', () async {
    lock = await build();
    expect(lock.isLocked, isTrue);
    expect(await lock.unlockWithPin('0000'), isA<PinWrong>());
    expect(lock.isLocked, isTrue);
    expect(await lock.unlockWithPin('1357'), isA<PinCorrect>());
    expect(lock.isLocked, isFalse);
  });

  test('re-locks only after the timeout elapsed in background', () async {
    lock = await build();
    await lock.unlockWithPin('1357');

    background();
    now = now.add(const Duration(seconds: 59));
    resume();
    expect(lock.isLocked, isFalse);

    background();
    now = now.add(const Duration(seconds: 60));
    resume();
    expect(lock.isLocked, isTrue);
  });

  test('timeout 0 locks as soon as the app is hidden', () async {
    timeout = 0;
    lock = await build();
    await lock.unlockWithPin('1357');
    lock.didChangeAppLifecycleState(AppLifecycleState.hidden);
    expect(lock.isLocked, isTrue);
  });

  test('pickers run exempt from locking', () async {
    timeout = 0;
    lock = await build();
    await lock.unlockWithPin('1357');
    await lock.runExempt(() async {
      background();
      now = now.add(const Duration(minutes: 5));
      resume();
    });
    expect(lock.isLocked, isFalse);
  });

  test('biometrics need a PIN, the preference and a successful prompt', () async {
    lock = await build();
    expect(lock.canUseBiometrics, isFalse);
    expect(await lock.unlockWithBiometrics('r'), isFalse);

    biometricsWanted = true;
    biometricResult = false;
    expect(await lock.unlockWithBiometrics('r'), isFalse);
    expect(lock.isLocked, isTrue);

    biometricResult = true;
    expect(await lock.unlockWithBiometrics('r'), isTrue);
    expect(lock.isLocked, isFalse);
  });

  test('a PIN lockout also blocks biometrics', () async {
    biometricsWanted = true;
    lock = await build();
    for (var i = 0; i < PinService.maxAttempts; i++) {
      await lock.unlockWithPin('0000');
    }
    expect(await lock.unlockWithBiometrics('r'), isFalse);
    expect(lock.isLocked, isTrue);
  });

  test('removing the PIN unlocks and disables locking', () async {
    lock = await build();
    await lock.removePin();
    expect(lock.isLocked, isFalse);
    expect(lock.hasPin, isFalse);
  });
}
