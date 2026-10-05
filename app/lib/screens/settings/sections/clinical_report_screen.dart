import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ruya/l10n/app_localizations.dart';
import 'package:ruya/report/clinical_report_data.dart';
import 'package:ruya/report/clinical_report_pdf.dart';
import 'package:ruya/security/app_lock_controller.dart';
import 'package:ruya/services/log_service.dart';
import 'package:ruya/services/period_service.dart';
import 'package:ruya/services/user_service.dart';
import 'package:share_plus/share_plus.dart';

/// Builds the clinical PDF for a chosen date range on the device.
class ClinicalReportScreen extends StatefulWidget {
  const ClinicalReportScreen({super.key, this.allowIntimateFields = true});

  /// False in kid mode: sex and libido are never offered or exported.
  final bool allowIntimateFields;

  @override
  State<ClinicalReportScreen> createState() => _ClinicalReportScreenState();
}

class _ClinicalReportScreenState extends State<ClinicalReportScreen> {
  late DateTimeRange _range;
  late ClinicalReportOptions _options;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _range = DateTimeRange(start: DateTime(today.year - 1, today.month, today.day), end: today);
    _options = ClinicalReportOptions(includeSexAndLibido: widget.allowIntimateFields);
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  Future<Uint8List> _render() async {
    final l10n = AppLocalizations.of(context)!;
    final periods = context.read<PeriodService>().periodEntries;
    final logs = context.read<LogService>().logs;
    final name = context.read<UserService>().user?.name;
    final data = ClinicalReportData.build(
      periods: periods,
      logs: logs,
      from: _range.start,
      to: _range.end,
      options: widget.allowIntimateFields ? _options : _options.copyWith(includeSexAndLibido: false),
    );
    final pdf = ClinicalReportPdf(
      regular: await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
      bold: await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
    );
    return pdf.render(data, l10n, personName: name);
  }

  String get _fileName => 'ruya-rapor-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf';

  Future<void> _run(Future<void> Function(Uint8List bytes) deliver) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      final bytes = await _render();
      await deliver(bytes);
    } catch (e) {
      debugPrint('Report failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.reportScreen_failed),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() => _run((bytes) async {
        final l10n = AppLocalizations.of(context)!;
        final messenger = ScaffoldMessenger.of(context);
        final uri = await context.read<AppLockController>().runExempt(
              () => FilePicker.saveFile(fileName: _fileName, bytes: bytes, mimeType: 'application/pdf'),
            );
        if (uri != null) messenger.showSnackBar(SnackBar(content: Text(l10n.reportScreen_saved)));
      });

  Future<void> _share() => _run((bytes) async {
        final lock = context.read<AppLockController>();
        final box = context.findRenderObject() as RenderBox?;
        await lock.runExempt(() => SharePlus.instance.share(ShareParams(
              files: [XFile.fromData(bytes, mimeType: 'application/pdf', name: _fileName)],
              fileNameOverrides: [_fileName],
              sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
            )));
      });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fmt = DateFormat.yMMMd(l10n.localeName);
    final o = _options;

    Widget toggle(String title, bool value, ClinicalReportOptions Function(bool) update) => SwitchListTile(
          title: Text(title),
          value: value,
          onChanged: _busy ? null : (v) => setState(() => _options = update(v)),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reportScreen_title)),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.reportScreen_intro),
              ),
              ListTile(
                leading: const Icon(Icons.date_range),
                title: Text(l10n.reportScreen_range),
                subtitle: Text('${fmt.format(_range.start)} – ${fmt.format(_range.end)}'),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: _busy ? null : _pickRange,
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(l10n.reportScreen_include, style: Theme.of(context).textTheme.titleSmall),
              ),
              toggle(l10n.dailyLog_symptoms, o.includeSymptoms, (v) => o.copyWith(includeSymptoms: v)),
              toggle(l10n.report_colMood, o.includeMood, (v) => o.copyWith(includeMood: v)),
              toggle(l10n.dailyLog_discharge, o.includeDischarge, (v) => o.copyWith(includeDischarge: v)),
              toggle(l10n.dailyLog_medication, o.includeMedication, (v) => o.copyWith(includeMedication: v)),
              toggle(l10n.dailyLog_contraception, o.includeContraception, (v) => o.copyWith(includeContraception: v)),
              if (widget.allowIntimateFields)
                toggle(l10n.reportScreen_sexLibido, o.includeSexAndLibido, (v) => o.copyWith(includeSexAndLibido: v)),
              toggle(l10n.dailyLog_notes, o.includeNotes, (v) => o.copyWith(includeNotes: v)),
              toggle(l10n.reportScreen_name, o.includeName, (v) => o.copyWith(includeName: v)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: Text(l10n.reportScreen_save),
                        onPressed: _busy ? null : _save,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.share_outlined),
                        label: Text(l10n.reportScreen_share),
                        onPressed: _busy ? null : _share,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_busy) const Positioned.fill(child: Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}
