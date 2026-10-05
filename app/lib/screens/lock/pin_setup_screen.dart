import 'package:flutter/material.dart';
import 'package:ruya/l10n/app_localizations.dart';
import 'package:ruya/screens/lock/pin_pad.dart';
import 'package:ruya/security/pin_service.dart';

/// Asks for a new PIN twice. Pops with the PIN, or null when cancelled.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String? _first;
  String? _error;
  final _padKey = GlobalKey<PinPadState>();

  Future<bool> _onSubmit(String pin) async {
    final l10n = AppLocalizations.of(context)!;
    if (_first == null) {
      setState(() {
        _first = pin;
        _error = null;
      });
      return false;
    }
    if (pin != _first) {
      setState(() {
        _first = null;
        _error = l10n.pinSetup_mismatch;
      });
      return false;
    }
    Navigator.of(context).pop(pin);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pinSetup_title)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                _first == null ? l10n.pinSetup_enterNew : l10n.pinSetup_confirm,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                _error ?? l10n.pinSetup_hint(PinService.minLength, PinService.maxLength),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: _error != null ? theme.colorScheme.error : null),
              ),
              const SizedBox(height: 24),
              PinPad(
                key: _padKey,
                onSubmit: _onSubmit,
                submitLabel: _first == null ? l10n.pinSetup_next : l10n.save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Verifies the current PIN (with lockout). Pops true when correct.
class PinVerifyScreen extends StatefulWidget {
  const PinVerifyScreen({super.key, required this.pinService, required this.title});

  final PinService pinService;
  final String title;

  @override
  State<PinVerifyScreen> createState() => _PinVerifyScreenState();
}

class _PinVerifyScreenState extends State<PinVerifyScreen> {
  String? _message;

  Future<bool> _onSubmit(String pin) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await widget.pinService.verify(pin);
    if (!mounted) return false;
    switch (result) {
      case PinCorrect():
        Navigator.of(context).pop(true);
        return true;
      case PinWrong(:final attemptsLeft):
        setState(() => _message = l10n.lock_wrongPin(attemptsLeft));
      case PinLockedOut(:final until):
        final seconds = until.difference(DateTime.now()).inSeconds + 1;
        setState(() => _message = l10n.lock_lockedOut(seconds));
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(l10n.pinVerify_current, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              SizedBox(
                height: 36,
                child: Text(
                  _message ?? '',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
              ),
              PinPad(onSubmit: _onSubmit, submitLabel: l10n.pinSetup_next),
            ],
          ),
        ),
      ),
    );
  }
}
