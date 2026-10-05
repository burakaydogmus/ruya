import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ruya/l10n/app_localizations.dart';
import 'package:ruya/screens/lock/pin_setup_screen.dart';
import 'package:ruya/screens/settings/sections/backup_screen.dart';
import 'package:ruya/security/app_lock_controller.dart';
import 'package:ruya/services/settings_service.dart';
import 'package:ruya/utils/constants.dart';
import 'package:ruya/security/discrete_mode.dart';
import 'package:ruya/services/period_service.dart';
import 'package:ruya/coordinators/data_refresh_coordinator.dart';

/// Settings › Privacy: PIN lock, biometric unlock, lock timeout, encrypted backup.
class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  static String timeoutLabel(AppLocalizations l10n, int seconds) {
    if (seconds <= 0) return l10n.privacy_timeoutImmediately;
    if (seconds < 60) return l10n.privacy_timeoutSeconds(seconds);
    return l10n.privacy_timeoutMinutes(seconds ~/ 60);
  }

  Future<void> _togglePin(BuildContext context, bool enable) async {
    final lock = context.read<AppLockController>();
    final settings = context.read<SettingsService>();
    final l10n = AppLocalizations.of(context)!;
    if (enable) {
      final pin = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const PinSetupScreen()),
      );
      if (pin == null) return;
      await lock.setPin(pin);
      if (context.mounted) _snack(context, l10n.privacy_pinEnabled);
      return;
    }
    final ok = await _verifyCurrent(context, l10n.privacy_disablePin);
    if (!ok) return;
    await lock.removePin();
    await settings.setBiometricsEnabled(false);
    if (context.mounted) _snack(context, l10n.privacy_pinDisabled);
  }

  Future<void> _changePin(BuildContext context) async {
    final lock = context.read<AppLockController>();
    final l10n = AppLocalizations.of(context)!;
    if (!await _verifyCurrent(context, l10n.privacy_changePin) || !context.mounted) return;
    final pin = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const PinSetupScreen()),
    );
    if (pin == null) return;
    await lock.setPin(pin);
    if (context.mounted) _snack(context, l10n.privacy_pinChanged);
  }

  Future<bool> _verifyCurrent(BuildContext context, String title) async {
    final lock = context.read<AppLockController>();
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PinVerifyScreen(pinService: lock.pinService, title: title)),
    );
    return ok == true;
  }

  Future<void> _toggleBiometrics(BuildContext context, bool enable) async {
    final lock = context.read<AppLockController>();
    final settings = context.read<SettingsService>();
    final l10n = AppLocalizations.of(context)!;
    if (enable && !await lock.confirmBiometrics(l10n.privacy_biometricConfirm)) return;
    await settings.setBiometricsEnabled(enable);
  }

  Future<void> _pickTimeout(BuildContext context) async {
    final settings = context.read<SettingsService>();
    final l10n = AppLocalizations.of(context)!;
    final current = settings.pinTimeoutSeconds;
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.privacy_timeout),
        children: [
          for (final s in kPinTimeoutOptionsSeconds)
            ListTile(
              leading: Icon(s == current ? Icons.radio_button_checked : Icons.radio_button_unchecked),
              title: Text(timeoutLabel(l10n, s)),
              onTap: () => Navigator.pop(ctx, s),
            ),
        ],
      ),
    );
    if (picked != null) await settings.setPinTimeoutSeconds(picked);
  }

  Future<void> _toggleDiscrete(BuildContext context, bool enable) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    await context.read<DiscreteModeController>().setEnabled(
          enable,
          l10n: l10n,
          periodService: context.read<PeriodService>(),
          coordinator: context.read<DataRefreshCoordinator>(),
        );
    messenger.showSnackBar(SnackBar(content: Text(enable ? l10n.privacy_discreteOn : l10n.privacy_discreteOff)));
  }

  void _snack(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lock = context.watch<AppLockController>();
    final settings = context.watch<SettingsService>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacy_title)),
      body: ListView(
        children: [
          _Header(l10n.privacy_sectionLock),
          SwitchListTile(
            secondary: const Icon(Icons.pin_outlined),
            title: Text(l10n.privacy_pinLock),
            subtitle: Text(l10n.privacy_pinLockSubtitle),
            value: lock.hasPin,
            onChanged: (v) => _togglePin(context, v),
          ),
          if (lock.hasPin)
            ListTile(
              leading: const Icon(Icons.password),
              title: Text(l10n.privacy_changePin),
              onTap: () => _changePin(context),
            ),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: Text(l10n.privacy_biometric),
            subtitle: Text(
              !lock.isBiometricHardwareAvailable
                  ? l10n.securityScreen_noBiometricsAvailable
                  : lock.hasPin
                      ? l10n.privacy_biometricSubtitle
                      : l10n.privacy_biometricNeedsPin,
            ),
            value: lock.hasPin && settings.areBiometricsEnabled,
            onChanged: lock.hasPin && lock.isBiometricHardwareAvailable
                ? (v) => _toggleBiometrics(context, v)
                : null,
          ),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: Text(l10n.privacy_timeout),
            subtitle: Text(timeoutLabel(l10n, settings.pinTimeoutSeconds)),
            enabled: lock.hasPin,
            onTap: () => _pickTimeout(context),
          ),
          const Divider(),
          _Header(l10n.privacy_discrete),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_off_outlined),
            title: Text(l10n.privacy_discrete),
            subtitle: Text(l10n.privacy_discreteSubtitle),
            value: settings.isDiscreteModeEnabled,
            onChanged: (v) => _toggleDiscrete(context, v),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
            child: Text(l10n.privacy_discreteLimits, style: theme.textTheme.bodySmall),
          ),
          const Divider(),
          _Header(l10n.privacy_sectionData),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(l10n.backup_title),
            subtitle: Text(l10n.privacy_backupSubtitle),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BackupScreen())),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.shield_outlined),
                      const SizedBox(width: 8),
                      Expanded(child: Text(l10n.privacy_summaryTitle, style: theme.textTheme.titleSmall)),
                    ]),
                    const SizedBox(height: 8),
                    Text(l10n.privacy_summaryBody, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
