import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ruya/l10n/app_localizations.dart';
import 'package:ruya/screens/lock/pin_pad.dart';
import 'package:ruya/security/app_lock_controller.dart';
import 'package:ruya/security/pin_service.dart';
import 'package:ruya/services/settings_service.dart';

/// Wraps the whole app and covers it with [LockScreen] while locked.
/// The app below stays mounted (state is kept) but is hidden from touch and
/// accessibility services.
class AppLockGate extends StatelessWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<AppLockController>();
    if (!lock.isReady) {
      return const ColoredBox(color: Colors.black, child: SizedBox.expand());
    }
    final locked = lock.isLocked;
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          excluding: locked,
          child: IgnorePointer(ignoring: locked, child: Offstage(offstage: locked, child: child)),
        ),
        if (locked) const LockScreen(),
      ],
    );
  }
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String? _message;
  DateTime? _lockedUntil;
  Timer? _ticker;
  bool _triedBiometricsOnce = false;

  @override
  void initState() {
    super.initState();
    _refreshLockout();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoBiometrics());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _refreshLockout() async {
    final until = await context.read<AppLockController>().pinService.lockedUntil();
    if (!mounted) return;
    _setLockout(until);
  }

  void _setLockout(DateTime? until) {
    _ticker?.cancel();
    setState(() => _lockedUntil = until);
    if (until == null) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (DateTime.now().isAfter(until)) {
        _ticker?.cancel();
        setState(() {
          _lockedUntil = null;
          _message = null;
        });
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _maybeAutoBiometrics() async {
    final lock = context.read<AppLockController>();
    if (_triedBiometricsOnce || !lock.canUseBiometrics || _lockedUntil != null) return;
    _triedBiometricsOnce = true;
    await _biometrics();
  }

  Future<void> _biometrics() async {
    final l10n = AppLocalizations.of(context)!;
    final discrete = context.read<SettingsService>().isDiscreteModeEnabled;
    await context.read<AppLockController>().unlockWithBiometrics(
      discrete ? l10n.auth_unlockReasonNeutral : l10n.auth_unlockReason,
    );
  }

  Future<bool> _submit(String pin) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await context.read<AppLockController>().unlockWithPin(pin);
    if (!mounted) return false;
    switch (result) {
      case PinCorrect():
        return true;
      case PinWrong(:final attemptsLeft):
        setState(() => _message = l10n.lock_wrongPin(attemptsLeft));
      case PinLockedOut(:final until):
        setState(() => _message = null);
        _setLockout(until);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final lock = context.watch<AppLockController>();
    final discrete = context.select<SettingsService, bool>((s) => s.isDiscreteModeEnabled);
    final until = _lockedUntil;
    final remaining = until == null ? 0 : until.difference(DateTime.now()).inSeconds + 1;

    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (discrete)
                  Icon(Icons.lock_outline, size: 64, color: theme.colorScheme.primary)
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset('assets/icon/ruya.png', width: 72, height: 72),
                  ),
                const SizedBox(height: 16),
                Text(discrete ? l10n.lock_titleNeutral : l10n.lock_title, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: Text(
                    until != null ? l10n.lock_lockedOut(remaining) : (_message ?? l10n.lock_enterPin),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: until != null || _message != null ? theme.colorScheme.error : null,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                PinPad(
                  enabled: until == null,
                  onSubmit: _submit,
                  submitLabel: l10n.lock_unlock,
                  extraAction: lock.canUseBiometrics
                      ? IconButton(
                          iconSize: 32,
                          icon: const Icon(Icons.fingerprint),
                          onPressed: until == null ? _biometrics : null,
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                if (_message != null || until != null)
                  Text(
                    l10n.lock_forgotHint,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
