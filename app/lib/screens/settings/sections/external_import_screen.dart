import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ruya/coordinators/data_refresh_coordinator.dart';
import 'package:ruya/import/import_models.dart';
import 'package:ruya/import/import_service.dart';
import 'package:ruya/l10n/app_localizations.dart';
import 'package:ruya/security/app_lock_controller.dart';

/// Import history exported from Flo, Clue or drip. Always previews first and
/// never overwrites days that already exist in RUYA.
class ExternalImportScreen extends StatefulWidget {
  const ExternalImportScreen({super.key});

  @override
  State<ExternalImportScreen> createState() => _ExternalImportScreenState();
}

class _ExternalImportScreenState extends State<ExternalImportScreen> {
  bool _busy = false;

  void _snack(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ));
  }

  Future<void> _pickAndImport() async {
    final l10n = AppLocalizations.of(context)!;
    final lock = context.read<AppLockController>();
    final coordinator = context.read<DataRefreshCoordinator>();
    final files = await lock.runExempt(() => FilePicker.pickFiles());
    if (files.isEmpty || !mounted) return;

    setState(() => _busy = true);
    final service = ExternalImportService();
    ImportPreview preview;
    try {
      final file = files.first;
      final size = await file.length();
      if (size > ExternalImportService.maxFileBytes) {
        _snack(l10n.import_tooLarge, error: true);
        return;
      }
      final content = utf8.decode(await file.readAsBytes(), allowMalformed: true);
      final result = ExternalImportService.parse(content);
      preview = await service.preview(result);
    } on ImportFormatException {
      _snack(l10n.import_unrecognised, error: true);
      return;
    } catch (e) {
      debugPrint('External import failed: $e');
      _snack(l10n.import_failed, error: true);
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    if (!mounted) return;
    if (preview.newDays.isEmpty) {
      _snack(l10n.import_nothingNew);
      return;
    }
    final confirmed = await _showPreview(preview);
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final added = await service.apply(preview.result);
      if (!mounted) return;
      // The import wrote straight to the database, so reload before recalculating.
      await coordinator.onExternalLogsChanged(l10n);
      if (!mounted) return;
      _snack(l10n.import_done(added));
    } catch (e) {
      debugPrint('External import apply failed: $e');
      _snack(l10n.import_failed, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _showPreview(ImportPreview p) {
    final l10n = AppLocalizations.of(context)!;
    final fmt = DateFormat.yMMMd(l10n.localeName);
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
        title: Text(l10n.import_previewTitle(p.source.displayName)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              row(l10n.import_previewNewDays, '${p.newDays.length}'),
              row(l10n.import_previewFlowDays, '${p.flowDays}'),
              row(l10n.backup_previewRange, '${fmt.format(p.firstDate!)} – ${fmt.format(p.lastDate!)}'),
              if (p.conflictingDays.isNotEmpty) row(l10n.import_previewKept, '${p.conflictingDays.length}'),
              if (p.result.skippedEntries > 0) row(l10n.import_previewSkipped, '${p.result.skippedEntries}'),
              const SizedBox(height: 12),
              Text(l10n.import_previewNote, style: Theme.of(ctx).textTheme.bodySmall),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.import_confirm)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    Widget source(String name, String how) => ListTile(
          leading: const Icon(Icons.description_outlined),
          title: Text(name),
          subtitle: Text(how),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.import_title)),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(l10n.import_intro, style: theme.textTheme.bodyMedium),
              ),
              const SizedBox(height: 8),
              source('Flo', l10n.import_floHow),
              source('Clue', l10n.import_clueHow),
              source('drip', l10n.import_dripHow),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  icon: const Icon(Icons.file_open_outlined),
                  label: Text(l10n.import_pickFile),
                  onPressed: _busy ? null : _pickAndImport,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(l10n.import_safety, style: theme.textTheme.bodySmall),
              ),
            ],
          ),
          if (_busy)
            Positioned.fill(
              child: ColoredBox(
                color: theme.colorScheme.surface.withValues(alpha: 0.7),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}
