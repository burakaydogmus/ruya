import 'dart:math';

import 'package:ruya/cycle/life_stage.dart';

import 'package:ruya/models/birth_control/pills/pill_intake.dart';
import 'package:ruya/models/birth_control/pills/pill_regimen.dart';
import 'package:ruya/models/birth_control/pills/pill_status_enum.dart';
import 'package:ruya/models/cycle_phase/cycle_phase_enum.dart';
import 'package:ruya/models/period_logs/daily_log_enums.dart';
import 'package:ruya/models/period_logs/log_day.dart';
import 'package:ruya/models/periods/period.dart';

DateTime _d(DateTime d) => DateTime(d.year, d.month, d.day);

int _diff(DateTime a, DateTime b) =>
    DateTime.utc(a.year, a.month, a.day).difference(DateTime.utc(b.year, b.month, b.day)).inDays;

/// Pill adherence for active (non-placebo) pill days.
class PillAdherence {
  const PillAdherence({
    required this.expected,
    required this.onTime,
    required this.late,
    required this.skipped,
    required this.missed,
  });

  final int expected;
  final int onTime;
  final int late;
  final int skipped;

  /// Active pill days with no entry at all.
  final int missed;

  /// Share of active pills that were taken (on time or late), 0..1.
  double? get takenRate => expected == 0 ? null : (onTime + late) / expected;

  static const empty = PillAdherence(expected: 0, onTime: 0, late: 0, skipped: 0, missed: 0);

  /// Counts every active pill day from max(regimen start, [since]) up to
  /// yesterday; today counts only once an entry exists (it can still be taken).
  static PillAdherence compute({
    required PillRegimen regimen,
    required List<PillIntake> intakes,
    required DateTime since,
    DateTime? now,
  }) {
    final today = _d(now ?? DateTime.now());
    final start = _d(regimen.startDate);
    final packLength = regimen.activePills + regimen.placeboPills;
    if (packLength <= 0 || regimen.activePills <= 0) return empty;

    final byDay = <DateTime, PillIntake>{for (final i in intakes) _d(i.scheduledDate): i};
    var from = _d(since).isAfter(start) ? _d(since) : start;
    var expected = 0, onTime = 0, late = 0, skipped = 0, missed = 0;
    for (var day = from; !day.isAfter(today); day = DateTime(day.year, day.month, day.day + 1)) {
      final indexInPack = _diff(day, start) % packLength;
      if (indexInPack >= regimen.activePills) continue; // placebo / break
      final intake = byDay[day];
      if (day == today && intake == null) continue;
      expected++;
      switch (intake?.status) {
        case PillIntakeStatus.taken:
          onTime++;
        case PillIntakeStatus.late:
          late++;
        case PillIntakeStatus.skipped:
          skipped++;
        case null:
          missed++;
      }
    }
    return PillAdherence(expected: expected, onTime: onTime, late: late, skipped: skipped, missed: missed);
  }
}

/// One row of the cycle history list.
class CycleHistoryEntry {
  const CycleHistoryEntry({
    required this.start,
    required this.periodDays,
    this.cycleLength,
    this.kind = CycleKind.natural,
  });

  final CycleKind kind;

  final DateTime start;
  final int periodDays;

  /// Null for the current (unfinished) cycle.
  final int? cycleLength;
}

class CycleHistory {
  CycleHistory._();

  /// Most recent first, at most [limit] entries.
  static List<CycleHistoryEntry> build(
    List<Period> periods, {
    int limit = 12,
    CycleClassifier classifier = const CycleClassifier(),
  }) {
    final sorted = List<Period>.from(periods)..sort((a, b) => a.startDate.compareTo(b.startDate));
    final entries = <CycleHistoryEntry>[
      for (var i = 0; i < sorted.length; i++)
        CycleHistoryEntry(
          start: _d(sorted[i].startDate),
          periodDays: sorted[i].totalDays,
          cycleLength: i + 1 < sorted.length ? _diff(sorted[i + 1].startDate, sorted[i].startDate) : null,
          kind: classifier.classify(
            sorted[i].startDate,
            i + 1 < sorted.length ? _d(sorted[i + 1].startDate) : null,
          ),
        ),
    ];
    return entries.reversed.take(limit).toList();
  }
}

/// Mood counts grouped by the (estimated) cycle phase of the day they were logged.
///
/// Phase per day uses the actual cycle the day belongs to: period days are
/// menstrual; ovulation ≈ next period − luteal length; the 5 days before it plus
/// ovulation day are the fertile window; after that luteal. Days in a cycle
/// longer than [maxCycleLength] (tracking gaps) or after the last period without
/// a known cycle length beyond [maxCycleLength] are skipped.
class MoodByPhase {
  MoodByPhase._();

  static const int maxCycleLength = 45;
  static const List<CyclePhase> phases = [
    CyclePhase.menstruation,
    CyclePhase.follicular,
    CyclePhase.fertileWindow,
    CyclePhase.luteal,
  ];

  static Map<CyclePhase, Map<Mood, int>> compute({
    required List<Period> periods,
    required List<LogDay> logs,
    int lutealPhaseLength = 14,
    int defaultCycleLength = 28,
  }) {
    final sorted = List<Period>.from(periods)..sort((a, b) => a.startDate.compareTo(b.startDate));
    final result = {for (final p in phases) p: <Mood, int>{}};
    if (sorted.isEmpty) return result;

    for (final log in logs) {
      if (log.moods.isEmpty) continue;
      final day = _d(log.date);
      final idx = sorted.lastIndexWhere((p) => !_d(p.startDate).isAfter(day));
      if (idx < 0) continue;
      final period = sorted[idx];
      final start = _d(period.startDate);
      final cycleLength = idx + 1 < sorted.length ? _diff(sorted[idx + 1].startDate, start) : defaultCycleLength;
      final cycleDay = _diff(day, start) + 1;
      if (cycleLength > maxCycleLength || cycleDay > maxCycleLength) continue;

      final luteal = min(lutealPhaseLength, max(1, cycleLength - period.totalDays));
      // 1-based cycle day of ovulation; same as CyclePhasePredictor (next period - luteal).
      final ovulationDay = cycleLength - luteal + 1;
      final CyclePhase phase;
      if (cycleDay <= period.totalDays) {
        phase = CyclePhase.menstruation;
      } else if (cycleDay > ovulationDay) {
        phase = CyclePhase.luteal;
      } else if (cycleDay >= ovulationDay - 5) {
        phase = CyclePhase.fertileWindow;
      } else {
        phase = CyclePhase.follicular;
      }
      final counts = result[phase]!;
      for (final mood in log.moods) {
        counts[mood] = (counts[mood] ?? 0) + 1;
      }
    }
    return result;
  }
}
