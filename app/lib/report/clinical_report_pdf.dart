import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:ruya/l10n/app_localizations.dart';
import 'package:ruya/models/flows/flow_enum.dart';
import 'package:ruya/models/period_logs/log_day.dart';
import 'package:ruya/models/period_logs/pain_level_enum.dart';
import 'package:ruya/models/period_logs/symptom.dart';
import 'package:ruya/report/clinical_report_data.dart';

/// Renders [ClinicalReportData] to a vector PDF entirely on the device.
///
/// Fonts are embedded (Roboto, Apache 2.0) so Turkish characters render on any
/// viewer. Layout: A4 landscape, summary, cycle history, daily log table.
class ClinicalReportPdf {
  ClinicalReportPdf({required this.regular, required this.bold});

  final ByteData regular;
  final ByteData bold;

  static final PdfColor _accent = PdfColor.fromInt(0xFF7C5CD6);
  static final PdfColor _muted = PdfColor.fromInt(0xFF666666);
  static final PdfColor _rowAlt = PdfColor.fromInt(0xFFF4F1FB);

  Future<Uint8List> render(
    ClinicalReportData data,
    AppLocalizations l10n, {
    String? personName,
  }) async {
    final theme = pw.ThemeData.withFont(base: pw.Font.ttf(regular), bold: pw.Font.ttf(bold));
    final doc = pw.Document(
      title: l10n.report_title,
      author: 'RUYA',
      creator: 'RUYA',
      producer: 'RUYA',
    );
    final dateFmt = DateFormat.yMMMd(l10n.localeName);
    final timeFmt = DateFormat.yMMMd(l10n.localeName).add_Hm();
    final o = data.options;
    final small = pw.TextStyle(fontSize: 8, color: _muted);

    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
        header: (ctx) => ctx.pageNumber == 1
            ? pw.SizedBox()
            : pw.Container(
                alignment: pw.Alignment.centerRight,
                margin: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text('${l10n.report_title} · ${dateFmt.format(data.from)} – ${dateFmt.format(data.to)}', style: small),
              ),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(child: pw.Text(l10n.report_disclaimer, style: small)),
            pw.SizedBox(width: 16),
            pw.Text(l10n.report_page(ctx.pageNumber, ctx.pagesCount), style: small),
          ],
        ),
        build: (ctx) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(l10n.report_title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _accent)),
                    pw.SizedBox(height: 4),
                    pw.Text(l10n.report_range(dateFmt.format(data.from), dateFmt.format(data.to))),
                    pw.Text(l10n.report_person(
                      o.includeName && (personName?.trim().isNotEmpty ?? false) ? personName!.trim() : l10n.report_anonymous,
                    )),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(l10n.report_generated(timeFmt.format(data.generatedAt)), style: small),
                  pw.Text(l10n.report_source, style: small),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          _sectionTitle(l10n.report_summary),
          _summary(data, l10n),
          pw.SizedBox(height: 16),
          _sectionTitle(l10n.report_cycles),
          if (data.cycles.isEmpty)
            pw.Text(l10n.report_noCycles, style: small)
          else
            _table(
              headers: [l10n.report_colStart, l10n.report_colPeriod, l10n.report_colCycle],
              rows: [
                for (final c in data.cycles.reversed)
                  [
                    dateFmt.format(c.start),
                    l10n.insights_days(c.periodDays),
                    c.isOngoing
                        ? l10n.report_ongoing(c.length)
                        : c.isGap
                            ? l10n.report_gap(c.length)
                            : l10n.insights_days(c.length),
                  ],
              ],
            ),
          pw.SizedBox(height: 16),
          _sectionTitle(l10n.report_daily),
          if (data.days.isEmpty)
            pw.Text(l10n.report_noLogs, style: small)
          else
            _table(
              headers: [
                l10n.report_colDate,
                l10n.report_colCycleDay,
                l10n.flow,
                l10n.painLevel_title,
                if (o.includeSymptoms) l10n.dailyLog_symptoms,
                if (o.includeMood) l10n.report_colMood,
                l10n.report_colOther,
                if (o.includeNotes) l10n.dailyLog_notes,
              ],
              rows: [for (final d in data.days) _dayRow(d, data.options, l10n, dateFmt)],
              columnWidths: {
                0: const pw.FixedColumnWidth(62),
                1: const pw.FixedColumnWidth(30),
                2: const pw.FixedColumnWidth(54),
                3: const pw.FixedColumnWidth(54),
              },
            ),
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _sectionTitle(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(text, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _accent)),
      );

  pw.Widget _summary(ClinicalReportData data, AppLocalizations l10n) {
    String days(int? v) => v == null ? '–' : l10n.insights_days(v);
    final completed = data.completedCycles.length;
    final items = <List<String>>[
      [l10n.report_cycleCount, '$completed'],
      [l10n.insights_avgCycle, days(data.averageCycleLength)],
      [l10n.insights_variation, data.cycleVariation == null ? '–' : '±${days(data.cycleVariation)}'],
      [
        l10n.report_shortestLongest,
        data.shortestCycle == null ? '–' : '${days(data.shortestCycle)} / ${days(data.longestCycle)}',
      ],
      [l10n.insights_avgPeriod, days(data.averagePeriodDays)],
      [l10n.report_loggedDays, '${data.days.length}'],
    ];
    return pw.Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        for (final item in items)
          pw.Container(
            width: 180,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(color: _rowAlt, borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(item[0], style: pw.TextStyle(fontSize: 8, color: _muted)),
                pw.SizedBox(height: 2),
                pw.Text(item[1], style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
      ],
    );
  }

  pw.Widget _table({
    required List<String> headers,
    required List<List<String>> rows,
    Map<int, pw.TableColumnWidth>? columnWidths,
  }) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: PdfColor.fromInt(0xFFDDDDDD), width: 0.5),
        bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFDDDDDD), width: 0.5),
      ),
      headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: pw.BoxDecoration(color: _accent),
      headerAlignment: pw.Alignment.centerLeft,
      cellStyle: const pw.TextStyle(fontSize: 8.5),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      oddRowDecoration: pw.BoxDecoration(color: _rowAlt),
      columnWidths: columnWidths,
      defaultColumnWidth: const pw.FlexColumnWidth(),
    );
  }

  List<String> _dayRow(ReportDay d, ClinicalReportOptions o, AppLocalizations l10n, DateFormat fmt) {
    final LogDay log = d.log;
    final other = <String>[
      if (o.includeDischarge && log.discharge != null) '${l10n.report_discharge}: ${log.discharge!.getDisplayName(l10n)}',
      if (o.includeMedication && log.medications.isNotEmpty) '${l10n.dailyLog_medication}: ${log.medications.join(', ')}',
      if (o.includeContraception && log.contraception.isNotEmpty)
        '${l10n.dailyLog_contraception}: ${log.contraception.map((c) => c.getDisplayName(l10n)).join(', ')}',
      if (o.includeSexAndLibido && log.sexActivity != null) '${l10n.dailyLog_sex}: ${log.sexActivity!.getDisplayName(l10n)}',
      if (o.includeSexAndLibido && log.libido != null) '${l10n.dailyLog_libido}: ${log.libido!.getDisplayName(l10n)}',
    ];
    return [
      fmt.format(log.date),
      d.cycleDay?.toString() ?? '–',
      log.flow == FlowRate.none ? '' : log.flow.getDisplayName(l10n),
      log.painLevel == null ? '' : PainLevel.values[log.painLevel!].getDisplayName(l10n),
      if (o.includeSymptoms) log.symptoms.map((s) => s.getDisplayName(l10n)).join(', '),
      if (o.includeMood) log.moods.map((m) => m.getDisplayName(l10n)).join(', '),
      other.join('\n'),
      if (o.includeNotes) log.notes ?? '',
    ];
  }
}
