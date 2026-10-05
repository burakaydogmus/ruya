import 'dart:math';

import 'package:ruya/cycle/life_stage.dart';
import 'package:ruya/models/flows/flow_enum.dart';
import 'package:ruya/models/period_logs/log_day.dart';
import 'package:ruya/models/periods/period.dart';

/// Which sections and columns go into the clinical report.
class ClinicalReportOptions {
  const ClinicalReportOptions({
    this.includeSymptoms = true,
    this.includeMood = true,
    this.includeDischarge = true,
    this.includeMedication = true,
    this.includeContraception = true,
    this.includeNotes = true,
    this.includeSexAndLibido = true,
    this.includeName = false,
  });

  final bool includeSymptoms;
  final bool includeMood;
  final bool includeDischarge;
  final bool includeMedication;
  final bool includeContraception;
  final bool includeNotes;

  /// Always false in kid mode.
  final bool includeSexAndLibido;

  /// Print the user's name instead of "anonymous".
  final bool includeName;

  ClinicalReportOptions copyWith({
    bool? includeSymptoms,
    bool? includeMood,
    bool? includeDischarge,
    bool? includeMedication,
    bool? includeContraception,
    bool? includeNotes,
    bool? includeSexAndLibido,
    bool? includeName,
  }) =>
      ClinicalReportOptions(
        includeSymptoms: includeSymptoms ?? this.includeSymptoms,
        includeMood: includeMood ?? this.includeMood,
        includeDischarge: includeDischarge ?? this.includeDischarge,
        includeMedication: includeMedication ?? this.includeMedication,
        includeContraception: includeContraception ?? this.includeContraception,
        includeNotes: includeNotes ?? this.includeNotes,
        includeSexAndLibido: includeSexAndLibido ?? this.includeSexAndLibido,
        includeName: includeName ?? this.includeName,
      );
}

/// One menstrual cycle inside the report range.
class ReportCycle {
  const ReportCycle({
    required this.start,
    required this.periodDays,
    required this.length,
    required this.isOngoing,
    this.isGap = false,
    this.kind = CycleKind.natural,
  });

  final DateTime start;

  /// Logged bleeding span of the period that starts the cycle.
  final int periodDays;

  /// Days until the next period started; for the ongoing cycle, days so far.
  final int length;
  final bool isOngoing;

  /// Implausible length (usually untracked periods): shown, but not averaged.
  final bool isGap;

  /// Natural cycle, withdrawal bleed (hormonal birth control) or pregnancy.
  final CycleKind kind;

  DateTime get end => DateTime(start.year, start.month, start.day + length - 1);
}

/// A day with at least one logged value in the range.
class ReportDay {
  const ReportDay({required this.log, required this.cycleDay});

  final LogDay log;

  /// 1-based day of the cycle the log belongs to, or null before the first period.
  final int? cycleDay;
}

/// Everything the PDF needs, computed on the device from periods and logs.
class ClinicalReportData {
  ClinicalReportData._({
    required this.from,
    required this.to,
    required this.generatedAt,
    required this.cycles,
    required this.days,
    required this.options,
  });

  final DateTime from;
  final DateTime to;
  final DateTime generatedAt;
  final List<ReportCycle> cycles;
  final List<ReportDay> days;
  final ClinicalReportOptions options;

  /// Completed cycles only (an ongoing cycle has no final length yet).
  /// Completed natural cycles: the basis for every average in the report.
  List<ReportCycle> get completedCycles =>
      cycles.where((c) => !c.isOngoing && !c.isGap && c.kind == CycleKind.natural).toList();

  int? get averageCycleLength {
    final c = completedCycles;
    if (c.isEmpty) return null;
    return (c.map((e) => e.length).reduce((a, b) => a + b) / c.length).round();
  }

  int? get shortestCycle => completedCycles.isEmpty ? null : completedCycles.map((c) => c.length).reduce(min);

  int? get longestCycle => completedCycles.isEmpty ? null : completedCycles.map((c) => c.length).reduce(max);

  /// Standard deviation of completed cycle lengths in days (rounded).
  int? get cycleVariation {
    final lengths = completedCycles.map((c) => c.length).toList();
    if (lengths.length < 2) return null;
    final mean = lengths.reduce((a, b) => a + b) / lengths.length;
    final v = lengths.map((l) => pow(l - mean, 2)).reduce((a, b) => a + b) / lengths.length;
    return sqrt(v).round();
  }

  int? get averagePeriodDays {
    final natural = cycles.where((c) => c.kind == CycleKind.natural).toList();
    if (natural.isEmpty) return null;
    return (natural.map((c) => c.periodDays).reduce((a, b) => a + b) / natural.length).round();
  }

  /// Valid cycle lengths are 10–130 days (same bounds as the predictor);
  /// longer gaps usually mean untracked periods and are excluded from averages.
  static const int _minCycle = 10;
  static const int _maxCycle = 130;

  static ClinicalReportData build({
    required List<Period> periods,
    required List<LogDay> logs,
    required DateTime from,
    required DateTime to,
    ClinicalReportOptions options = const ClinicalReportOptions(),
    CycleClassifier classifier = const CycleClassifier(),
    DateTime? now,
  }) {
    final start = _d(from);
    final end = _d(to);
    final today = _d(now ?? DateTime.now());
    final sorted = List<Period>.from(periods)..sort((a, b) => a.startDate.compareTo(b.startDate));

    final cycles = <ReportCycle>[];
    for (var i = 0; i < sorted.length; i++) {
      final p = sorted[i];
      final s = _d(p.startDate);
      if (s.isBefore(start) || s.isAfter(end)) continue;
      if (i + 1 < sorted.length) {
        final length = _diff(_d(sorted[i + 1].startDate), s);
        final kind = classifier.classify(s, _d(sorted[i + 1].startDate));
        cycles.add(ReportCycle(
          start: s,
          periodDays: p.totalDays,
          length: length,
          isOngoing: false,
          // Long pregnancy cycles are labelled as pregnancy, not as a tracking gap.
          isGap: kind == CycleKind.natural && (length < _minCycle || length > _maxCycle),
          kind: kind,
        ));
      } else {
        cycles.add(ReportCycle(
          start: s,
          periodDays: p.totalDays,
          length: _diff(today, s) + 1,
          isOngoing: true,
          kind: classifier.classify(s, null),
        ));
      }
    }

    final starts = sorted.map((p) => _d(p.startDate)).toList();
    final days = <ReportDay>[];
    for (final log in logs) {
      final d = _d(log.date);
      if (d.isBefore(start) || d.isAfter(end)) continue;
      if (!_hasReportableContent(log, options)) continue;
      DateTime? anchor;
      for (final s in starts) {
        if (s.isAfter(d)) break;
        anchor = s;
      }
      days.add(ReportDay(log: log, cycleDay: anchor == null ? null : _diff(d, anchor) + 1));
    }
    days.sort((a, b) => a.log.date.compareTo(b.log.date));

    return ClinicalReportData._(
      from: start,
      to: end,
      generatedAt: now ?? DateTime.now(),
      cycles: cycles,
      days: days,
      options: options,
    );
  }

  static bool _hasReportableContent(LogDay log, ClinicalReportOptions o) =>
      log.flow != FlowRate.none ||
      log.painLevel != null ||
      (o.includeSymptoms && log.symptoms.isNotEmpty) ||
      (o.includeMood && log.moods.isNotEmpty) ||
      (o.includeDischarge && log.discharge != null) ||
      (o.includeMedication && log.medications.isNotEmpty) ||
      (o.includeContraception && log.contraception.isNotEmpty) ||
      (o.includeNotes && (log.notes?.isNotEmpty ?? false)) ||
      (o.includeSexAndLibido && (log.sexActivity != null || log.libido != null));

  static DateTime _d(DateTime d) => DateTime(d.year, d.month, d.day);

  static int _diff(DateTime a, DateTime b) =>
      DateTime.utc(a.year, a.month, a.day).difference(DateTime.utc(b.year, b.month, b.day)).inDays;
}
