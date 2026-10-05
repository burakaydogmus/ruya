import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';
import 'package:ruya/security/pin_service.dart';

/// Decides when the app must show the PIN lock.
///
/// * Cold start: locked if a PIN is set.
/// * Background: the time is remembered; on resume the app locks again when
///   `elapsed >= timeout`. A timeout of 0 locks as soon as the app is hidden,
///   so the recents snapshot also shows the lock screen.
/// * System pickers/share sheets also send the app to the background; wrap them
///   in [runExempt] so they do not trigger a lock (Mooneva's "picker grace").
class AppLockController extends ChangeNotifier with WidgetsBindingObserver {
  AppLockController({
    required PinService pinService,
    required int Function() timeoutSeconds,
    required bool Function() biometricsPreferred,
    Future<bool> Function(String reason)? biometricAuthenticator,
    Future<bool> Function()? biometricsAvailable,
    DateTime Function()? clock,
  })  : _pins = pinService,
        _timeoutSeconds = timeoutSeconds,
        _biometricsPreferred = biometricsPreferred,
        _authenticate = biometricAuthenticator ?? _defaultBiometricAuth,
        _biometricsAvailable = biometricsAvailable ?? _defaultBiometricsAvailable,
        _clock = clock ?? DateTime.now;

  final PinService _pins;
  final int Function() _timeoutSeconds;
  final bool Function() _biometricsPreferred;
  final Future<bool> Function(String reason) _authenticate;
  final Future<bool> Function() _biometricsAvailable;
  final DateTime Function() _clock;

  static const Duration _exemptGrace = Duration(seconds: 3);

  bool _ready = false;
  bool _hasPin = false;
  bool _locked = false;
  bool _biometricHardware = false;
  bool _observing = false;
  int _exemptDepth = 0;
  DateTime? _exemptUntil;
  DateTime? _backgroundedAt;

  bool get isReady => _ready;
  bool get hasPin => _hasPin;
  bool get isLocked => _locked;
  bool get isBiometricHardwareAvailable => _biometricHardware;

  /// Biometric unlock is offered only on top of a PIN, which stays the fallback.
  bool get canUseBiometrics => _hasPin && _biometricHardware && _biometricsPreferred();

  PinService get pinService => _pins;

  Future<void> init({bool observeLifecycle = true}) async {
    _hasPin = await _pins.hasPin();
    _locked = _hasPin;
    try {
      _biometricHardware = await _biometricsAvailable();
    } catch (_) {
      _biometricHardware = false;
    }
    if (observeLifecycle && !_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    _ready = true;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool get _isExempt =>
      _exemptDepth > 0 || (_exemptUntil != null && _clock().isBefore(_exemptUntil!));

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        if (!_hasPin || _isExempt) return;
        _backgroundedAt ??= _clock();
        if (_timeoutSeconds() <= 0) lockNow();
      case AppLifecycleState.resumed:
        final since = _backgroundedAt;
        _backgroundedAt = null;
        if (!_hasPin || since == null || _isExempt) return;
        final elapsed = _clock().difference(since).inSeconds;
        if (elapsed >= _timeoutSeconds()) lockNow();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Runs [action] (file picker, share sheet, biometric prompt…) without locking.
  Future<T> runExempt<T>(Future<T> Function() action) async {
    _exemptDepth++;
    try {
      return await action();
    } finally {
      _exemptDepth--;
      _exemptUntil = _clock().add(_exemptGrace);
      _backgroundedAt = null;
    }
  }

  void lockNow() {
    if (!_hasPin || _locked) return;
    _locked = true;
    notifyListeners();
  }

  Future<PinVerifyResult> unlockWithPin(String pin) async {
    final result = await _pins.verify(pin);
    if (result is PinCorrect) _unlock();
    return result;
  }

  Future<bool> unlockWithBiometrics(String reason) async {
    if (!canUseBiometrics) return false;
    // A lockout from wrong PINs also blocks biometrics until it expires.
    if (await _pins.lockedUntil() != null) return false;
    final ok = await runExempt(() async {
      try {
        return await _authenticate(reason);
      } catch (e) {
        debugPrint('Biometric unlock failed: $e');
        return false;
      }
    });
    if (ok) _unlock();
    return ok;
  }

  /// Asks for biometrics once to confirm the user can use them (when enabling).
  Future<bool> confirmBiometrics(String reason) async {
    if (!_biometricHardware) return false;
    return runExempt(() async {
      try {
        return await _authenticate(reason);
      } catch (_) {
        return false;
      }
    });
  }

  Future<void> setPin(String pin) async {
    await _pins.setPin(pin);
    _hasPin = true;
    _locked = false;
    notifyListeners();
  }

  Future<void> removePin() async {
    await _pins.removePin();
    _hasPin = false;
    _locked = false;
    notifyListeners();
  }

  void _unlock() {
    _locked = false;
    _backgroundedAt = null;
    notifyListeners();
  }

  static Future<bool> _defaultBiometricAuth(String reason) =>
      LocalAuthentication().authenticate(localizedReason: reason, biometricOnly: true);

  static Future<bool> _defaultBiometricsAvailable() async {
    final auth = LocalAuthentication();
    if (!await auth.isDeviceSupported()) return false;
    return (await auth.getAvailableBiometrics()).isNotEmpty;
  }
}
