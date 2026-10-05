import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:ruya/security/crypto/aes_gcm.dart';
import 'package:ruya/security/crypto/pbkdf2.dart';
import 'package:ruya/security/secure_key_value_store.dart';

sealed class PinVerifyResult {
  const PinVerifyResult();
}

class PinCorrect extends PinVerifyResult {
  const PinCorrect();
}

class PinWrong extends PinVerifyResult {
  const PinWrong(this.attemptsLeft);
  final int attemptsLeft;
}

class PinLockedOut extends PinVerifyResult {
  const PinLockedOut(this.until);
  final DateTime until;
}

/// PIN storage and verification.
///
/// The PIN is never stored: only `PBKDF2-HMAC-SHA256(pin, salt, iterations)`
/// lives in the secure store. After [maxAttempts] wrong entries the PIN pad is
/// locked for an escalating period (30 s, 1 min, 2 min … capped at 15 min);
/// the counter survives app restarts.
class PinService {
  PinService(this._store, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final SecureKeyValueStore _store;
  final DateTime Function() _clock;

  static const int minLength = 4;
  static const int maxLength = 12;
  static const int iterations = 150000;
  static const int maxAttempts = 5;
  static const Duration baseLockout = Duration(seconds: 30);
  static const Duration maxLockout = Duration(minutes: 15);

  static const String _hashKey = 'ruya_pin_hash';
  static const String _saltKey = 'ruya_pin_salt';
  static const String _iterKey = 'ruya_pin_iterations';
  static const String _lockoutKey = 'ruya_pin_lockout';

  static final RegExp _pinPattern = RegExp(r'^\d+$');

  static bool isValidPin(String pin) =>
      pin.length >= minLength && pin.length <= maxLength && _pinPattern.hasMatch(pin);

  Future<bool> hasPin() async =>
      (await _store.read(_hashKey)) != null && (await _store.read(_saltKey)) != null;

  Future<void> setPin(String pin) async {
    if (!isValidPin(pin)) throw ArgumentError('PIN must be $minLength-$maxLength digits');
    final salt = AesGcm256.randomBytes(16);
    final hash = await _hash(pin, salt, iterations);
    await _store.write(_saltKey, base64Encode(salt));
    await _store.write(_iterKey, '$iterations');
    await _store.write(_hashKey, base64Encode(hash));
    await _store.delete(_lockoutKey);
  }

  Future<void> removePin() async {
    await _store.delete(_hashKey);
    await _store.delete(_saltKey);
    await _store.delete(_iterKey);
    await _store.delete(_lockoutKey);
  }

  /// Remaining lockout, or null if the PIN pad is usable.
  Future<DateTime?> lockedUntil() async {
    final state = await _readLockout();
    final until = state.lockedUntil;
    if (until != null && until.isAfter(_clock())) return until;
    return null;
  }

  Future<PinVerifyResult> verify(String pin) async {
    final until = await lockedUntil();
    if (until != null) return PinLockedOut(until);

    final storedHash = await _store.read(_hashKey);
    final storedSalt = await _store.read(_saltKey);
    if (storedHash == null || storedSalt == null) return const PinCorrect();
    final iter = int.tryParse(await _store.read(_iterKey) ?? '') ?? iterations;

    final candidate = await _hash(pin, base64Decode(storedSalt), iter);
    if (_constantTimeEquals(candidate, base64Decode(storedHash))) {
      await _store.delete(_lockoutKey);
      return const PinCorrect();
    }

    final state = await _readLockout();
    final attempts = state.attempts + 1;
    if (attempts >= maxAttempts) {
      final factor = pow(2, state.lockouts).toInt();
      var duration = baseLockout * factor;
      if (duration > maxLockout) duration = maxLockout;
      final lockedUntil = _clock().add(duration);
      await _writeLockout(_LockoutState(0, state.lockouts + 1, lockedUntil));
      return PinLockedOut(lockedUntil);
    }
    await _writeLockout(_LockoutState(attempts, state.lockouts, null));
    return PinWrong(maxAttempts - attempts);
  }

  static Future<Uint8List> _hash(String pin, List<int> salt, int iterations) =>
      Pbkdf2Sha256.derive(password: utf8.encode(pin), salt: salt, iterations: iterations);

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  Future<_LockoutState> _readLockout() async {
    final raw = await _store.read(_lockoutKey);
    if (raw == null) return const _LockoutState(0, 0, null);
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final until = map['lockedUntil'] as int?;
      return _LockoutState(
        map['attempts'] as int? ?? 0,
        map['lockouts'] as int? ?? 0,
        until == null ? null : DateTime.fromMillisecondsSinceEpoch(until),
      );
    } catch (_) {
      return const _LockoutState(0, 0, null);
    }
  }

  Future<void> _writeLockout(_LockoutState s) => _store.write(
        _lockoutKey,
        jsonEncode({
          'attempts': s.attempts,
          'lockouts': s.lockouts,
          'lockedUntil': s.lockedUntil?.millisecondsSinceEpoch,
        }),
      );
}

class _LockoutState {
  const _LockoutState(this.attempts, this.lockouts, this.lockedUntil);
  final int attempts;

  /// Number of lockouts since the last correct PIN; drives the escalation.
  final int lockouts;
  final DateTime? lockedUntil;
}
