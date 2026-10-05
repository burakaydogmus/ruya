import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ruya/l10n/app_localizations.dart';
import 'package:ruya/models/flows/flow_enum.dart';
import 'package:ruya/models/period_logs/daily_log_enums.dart';
import 'package:ruya/models/period_logs/log_day.dart';
import 'package:ruya/models/period_logs/symptom.dart';
import 'package:ruya/models/periods/period.dart';
import 'package:ruya/report/clinical_report_data.dart';
import 'package:ruya/report/clinical_report_pdf.dart';

Period p(DateTime s, int days) =>
    Period(startDate: s, endDate: DateTime(s.year, s.month, s.day + days - 1), totalDays: days);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final periods = [
    p(DateTime(2026, 1, 3), 5),
    p(DateTime(2026, 1, 31), 4), // 28
    p(DateTime(2026, 3, 1), 5), // 29
    p(DateTime(2026, 3, 27), 6), // 26
    p(DateTime(2026, 8, 30), 5), // 156 -> tracking gap, excluded
    p(DateTime(2026, 9, 27), 4), // 28, then ongoing
  ];
  final logs = [
    LogDay(
      date: DateTime(2026, 3, 1),
      flow: FlowRate.heavy,
      painLevel: 3,
      symptoms: [Symptom.fromDbString('cramps'), Symptom.fromDbString('back pain')],
      moods: [Mood.irritable, Mood.tired],
      medications: ['İbuprofen 400 mg'],
      notes: 'Ağrı kesici işe yaradı; şişkinlik çok.',
    ),
    LogDay(
      date: DateTime(2026, 3, 14),
      flow: FlowRate.none,
      discharge: Discharge.eggWhite,
      sexActivity: SexActivity.protected,
      libido: Libido.high,
      contraception: [ContraceptionMethod.condom],
    ),
    LogDay(date: DateTime(2026, 3, 20), flow: FlowRate.none, sexActivity: SexActivity.unprotected),
    LogDay(date: DateTime(2025, 12, 1), flow: FlowRate.light), // out of range
  ];

  ClinicalReportData build([ClinicalReportOptions o = const ClinicalReportOptions()]) => ClinicalReportData.build(
        periods: periods,
        logs: logs,
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 10, 5),
        options: o,
        now: DateTime(2026, 10, 5),
      );

  test('cycles, gaps and summary statistics', () {
    final data = build();
    expect(data.cycles.length, 6);
    expect(data.cycles[3].isGap, isTrue); // 156 days: shown, not averaged
    expect(data.cycles.last.isOngoing, isTrue);
    expect(data.cycles.last.length, 9);
    expect(data.completedCycles.map((c) => c.length), [28, 29, 26, 28]);
    expect(data.averageCycleLength, 28);
    expect(data.shortestCycle, 26);
    expect(data.longestCycle, 29);
    expect(data.cycleVariation, 1);
    expect(data.averagePeriodDays, 5);
  });

  test('daily rows are in range, sorted and carry the cycle day', () {
    final data = build();
    expect(data.days.map((d) => d.log.date), [DateTime(2026, 3, 1), DateTime(2026, 3, 14), DateTime(2026, 3, 20)]);
    expect(data.days.first.cycleDay, 1);
    expect(data.days[1].cycleDay, 14);
  });

  test('excluding sex and libido drops days that only had those (kid mode)', () {
    final data = build(const ClinicalReportOptions(includeSexAndLibido: false));
    expect(data.days.map((d) => d.log.date), [DateTime(2026, 3, 1), DateTime(2026, 3, 14)]);
  });

  test('renders a valid PDF with embedded fonts', () async {
    await initializeDateFormatting('tr');
    final l10n = lookupAppLocalizations(const Locale('tr'));
    final pdf = ClinicalReportPdf(
      regular: await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
      bold: await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
    );
    final bytes = await pdf.render(build(), l10n, personName: 'Ayşe');
    expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
    expect(bytes.length, greaterThan(2000));
    final out = Platform.environment['RUYA_REPORT_OUT'];
    if (out != null) await File(out).writeAsBytes(bytes);
  });
}
