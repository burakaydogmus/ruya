import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:ruya/companion/companion_service.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:ruya/backup/backup_format.dart';
import 'package:ruya/backup/backup_service.dart';
import 'package:ruya/coordinators/data_refresh_coordinator.dart';
import 'package:ruya/l10n/app_localizations.dart';
import 'package:ruya/security/app_lock_controller.dart';
import 'package:ruya/services/settings_service.dart';
import 'package:ruya/services/symptom_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Encrypted, password-protected backup export and restore (with preview).
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  String? _busyText;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<BackupService> _service() async {
    final info = await PackageInfo.fromPlatform();
    return BackupService(prefs: await SharedPreferences.getInstance(), appVersion: info.version);
  }

  void _snack(String text, {bool error = false}) {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? scheme.error : null,
    ));
  }

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context)!;
    final lock = context.read<AppLockController>();
    final password = _password.text;
    if (password.length < BackupEnvelope.minPasswordLength) {
      _snack(l10n.backup_passwordTooShort(BackupEnvelope.minPasswordLength), error: true);
      return;
    }
    if (password != _confirm.text) {
      _snack(l10n.backup_passwordMismatch, error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busyText = l10n.backup_encrypting);
    try {
      final bytes = await (await _service()).createEncryptedBackup(password);
      final name = 'ruya-backup-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.${BackupEnvelope.fileExtension}';
      final uri = await lock.runExempt(() => FilePicker.saveFile(
            fileName: name,
            bytes: bytes,
            mimeType: BackupEnvelope.mimeType,
          ));
      if (uri != null) {
        _password.clear();
        _confirm.clear();
        _snack(l10n.backup_exported);
      }
    } catch (e) {
      debugPrint('Backup export failed: $e');
      _snack(l10n.backup_exportFailed, error: true);
    } finally {
      if (mounted) setState(() => _busyText = null);
    }
  }

  Future<void> _import() async {
    final l10n = AppLocalizations.of(context)!;
    final lock = context.read<AppLockController>();
    final files = await lock.runExempt(() => FilePicker.pickFiles());
    if (files.isEmpty || !mounted) return;
    final bytes = await files.first.readAsBytes();
    if (!BackupEnvelope.looksLikeBackup(bytes)) {
      _snack(l10n.backup_notABackup, error: true);
      return;
    }
    if (!mounted) return;
    final password = await _askPassword();
    if (password == null || !mounted) return;

    setState(() => _busyText = l10n.backup_decrypting);
    final BackupService service;
    final Map<String, dynamic> payload;
    try {
      service = await _service();
      payload = await service.readEncryptedBackup(bytes, password);
    } on BackupPasswordException {
      _snack(l10n.backup_wrongPassword, error: true);
      return;
    } on BackupFormatException catch (e) {
      _snack('${l10n.backup_invalidFile} (${e.message})', error: true);
      return;
    } catch (e) {
      debugPrint('Backup read failed: $e');
      _snack(l10n.backup_invalidFile, error: true);
      return;
    } finally {
      if (mounted) setState(() => _busyText = null);
    }

    if (!mounted) return;
    final confirmed = await _showPreview(BackupService.preview(payload));
    if (confirmed != true || !mounted) return;

    final coordinator = context.read<DataRefreshCoordinator>();
    final settings = context.read<SettingsService>();
    final symptoms = context.read<SymptomService>();
    final companions = context.read<CompanionService>();
    setState(() => _busyText = l10n.backup_restoring);
    try {
      await service.restoreReplacingAll(payload);
      await settings.loadSettings();
      await symptoms.load();
      await companions.load();
      await coordinator.resetAllData();
      _snack(l10n.backup_restored);
    } catch (e) {
      debugPrint('Backup restore failed: $e');
      _snack(l10n.backup_restoreFailed, error: true);
    } finally {
      if (mounted) setState(() => _busyText = null);
    }
  }

  Future<String?> _askPassword() {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.backup_enterPassword),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.backup_password),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: Text(l10n.backup_open)),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<bool?> _showPreview(BackupPreview p) {
    final l10n = AppLocalizations.of(context)!;
    final dateFmt = DateFormat.yMMMd(l10n.localeName);
    final created = p.createdAt == null ? '–' : DateFormat.yMMMd(l10n.localeName).add_Hm().format(p.createdAt!);
    final range = p.firstLogDate == null
        ? '–'
        : '${dateFmt.format(p.firstLogDate!)} – ${dateFmt.format(p.lastLogDate!)}';

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(label)),
              const SizedBox(width: 12),
              Flexible(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w600))),
            ],
          ),
        );

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.backup_previewTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              row(l10n.backup_previewCreated, created),
              row(l10n.backup_previewVersion, '${p.appVersion ?? '–'} · schema ${p.schemaVersion} · db ${p.dbVersion ?? '–'}'),
              row(l10n.backup_previewLogs, '${p.logCount}'),
              row(l10n.backup_previewRange, range),
              row(l10n.backup_previewPeriods, '${p.periodCount}'),
              row(l10n.backup_previewOther,
                  '${p.count('PillIntake') + p.count('larc_logs') + p.count('sanitary_product_logs') + p.count('sexual_activity_logs')}'),
              const SizedBox(height: 12),
              Text(
                l10n.backup_previewWarning,
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.backup_replaceAndRestore)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final busy = _busyText != null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.backup_title)),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.backup_intro, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 20),
              Text(l10n.backup_exportTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: _obscure,
                enabled: !busy,
                decoration: InputDecoration(
                  labelText: l10n.backup_password,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirm,
                obscureText: _obscure,
                enabled: !busy,
                decoration: InputDecoration(
                  labelText: l10n.backup_passwordConfirm,
                  border: const OutlineInputBorder(),
                  helperText: l10n.backup_passwordHelper(BackupEnvelope.minPasswordLength),
                  helperMaxLines: 3,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.lock_outline),
                label: Text(l10n.backup_exportButton),
                onPressed: busy ? null : _export,
              ),
              const Divider(height: 40),
              Text(l10n.backup_importTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(l10n.backup_importBody, style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.restore),
                label: Text(l10n.backup_importButton),
                onPressed: busy ? null : _import,
              ),
            ],
          ),
          if (busy)
            Positioned.fill(
              child: ColoredBox(
                color: theme.colorScheme.surface.withValues(alpha: 0.8),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(_busyText!),
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
