import 'package:ruya/l10n/app_localizations.dart';
import 'package:ruya/models/flows/flow_enum.dart';
import 'package:ruya/models/period_logs/daily_log_enums.dart';
import 'package:ruya/models/period_logs/log_day.dart';
import 'package:ruya/models/period_logs/pain_level_enum.dart';
import 'package:ruya/models/period_logs/symptom.dart';
import 'package:ruya/models/periods/period.dart';

enum PatternKind {
  /// A symptom logged on the same day of the period.
  periodDaySymptom,

  /// Moderate or stronger pain on the same day of the period.
  periodDayPain,

  /// A symptom logged in the three days before a period.
  beforePeriodSymptom,

  /// A mood logged in the three days before a period.
  beforePeriodMood,
}

/// Something that repeated across the user's own cycles. Plain counting on the
/// device; an observation, never a diagnosis.
class CyclePattern {
  const CyclePattern({
    required this.kind,
    required this.hits,
    required this.cycles,
    this.day,
    this.symptom,
    this.mood,
  });

  final PatternKind kind;

  /// Cycles in which it happened, out of [cycles] looked at.
  final int hits;
  final int cycles;

  /// Day of the period (1 = first day) for the period-day kinds.
  final int? day;
  final Symptom? symptom;
  final Mood? mood;

  String title(AppLocalizations l10n) => switch (kind) {
        PatternKind.periodDaySymptom => l10n.pattern_titleDay(symptom!.getDisplayName(l10n), day!),
        PatternKind.periodDayPain => l10n.pattern_titleDay(l10n.pattern_pain, day!),
        PatternKind.beforePeriodSymptom => l10n.pattern_titleBefore(symptom!.getDisplayName(l10n)),
        PatternKind.beforePeriodMood => l10n.pattern_titleBefore(mood!.getDisplayName(l10n)),
      };

  String sentence(AppLocalizations l10n) => switch (kind) {
        PatternKind.periodDaySymptom => l10n.pattern_daySentence(cycles, hits, day!, symptom!.getDisplayName(l10n)),
        PatternKind.periodDayPain => l10n.pattern_daySentence(cycles, hits, day!, l10n.pattern_pain),
        PatternKind.beforePeriodSymptom => l10n.pattern_beforeSentence(cycles, hits, symptom!.getDisplayName(l10n)),
        PatternKind.beforePeriodMood => l10n.pattern_beforeSentence(cycles, hits, mood!.getDisplayName(l10n)),
      };
}

class PatternDetector {
  PatternDetector._();

  /// A pattern needs at least this many cycles of data…
  static const int minCycles = 3;

  /// …and must show up in at least three of them and in 60% of them.
  static const int minHits = 3;
  static const double minShare = 0.6;

  /// Only the most recent cycles are looked at.
  static const int maxCycles = 6;
  static const int daysBefore = 3;
  static const int periodDays = 3;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static List<CyclePattern> detect({required List<Period> periods, required List<LogDay> logs, int limit = 5}) {
    final starts = periods.map((p) => _day(p.startDate)).toSet().toList()..sort();
    if (starts.length < minCycles) return const [];
    final recent = starts.length > maxCycles ? starts.sublist(starts.length - maxCycles) : starts;
    final n = recent.length;
    final byDay = {for (final l in logs) _day(l.date): l};
    LogDay? at(DateTime start, int offset) => byDay[DateTime(start.year, start.month, start.day + offset)];

    final found = <CyclePattern>[];
    bool keep(int hits) => hits >= minHits && hits / n >= minShare;

    // period-day symptoms and pain: best day per symptom
    final daySymptoms = <String, Map<int, int>>{};
    final symptomByKey = <String, Symptom>{};
    final painByDay = <int, int>{};
    for (final start in recent) {
      for (var d = 1; d <= periodDays; d++) {
        final log = at(start, d - 1);
        if (log == null) continue;
        if (log.flow == FlowRate.none && d > 1) continue;
        for (final s in log.symptoms) {
          final key = s.getDbName();
          symptomByKey[key] = s;
          (daySymptoms[key] ??= {})[d] = ((daySymptoms[key] ?? {})[d] ?? 0) + 1;
        }
        if ((log.painLevel ?? 0) >= PainLevel.moderate.index) painByDay[d] = (painByDay[d] ?? 0) + 1;
      }
    }
    for (final e in daySymptoms.entries) {
      final best = (e.value.entries.toList()..sort((a, b) => b.value != a.value ? b.value - a.value : a.key - b.key)).first;
      if (keep(best.value)) {
        found.add(CyclePattern(
          kind: PatternKind.periodDaySymptom, hits: best.value, cycles: n, day: best.key, symptom: symptomByKey[e.key],
        ));
      }
    }
    if (painByDay.isNotEmpty) {
      final best = (painByDay.entries.toList()..sort((a, b) => b.value != a.value ? b.value - a.value : a.key - b.key)).first;
      if (keep(best.value)) {
        found.add(CyclePattern(kind: PatternKind.periodDayPain, hits: best.value, cycles: n, day: best.key));
      }
    }

    // the three days before a period
    final beforeSymptoms = <String, int>{};
    final beforeMoods = <Mood, int>{};
    for (final start in recent) {
      final seenSymptoms = <String>{};
      final seenMoods = <Mood>{};
      for (var d = 1; d <= daysBefore; d++) {
        final log = at(start, -d);
        if (log == null) continue;
        for (final s in log.symptoms) {
          symptomByKey[s.getDbName()] = s;
          seenSymptoms.add(s.getDbName());
        }
        seenMoods.addAll(log.moods);
      }
      for (final k in seenSymptoms) {
        beforeSymptoms[k] = (beforeSymptoms[k] ?? 0) + 1;
      }
      for (final m in seenMoods) {
        beforeMoods[m] = (beforeMoods[m] ?? 0) + 1;
      }
    }
    for (final e in beforeSymptoms.entries) {
      if (keep(e.value)) {
        found.add(CyclePattern(kind: PatternKind.beforePeriodSymptom, hits: e.value, cycles: n, symptom: symptomByKey[e.key]));
      }
    }
    for (final e in beforeMoods.entries) {
      if (keep(e.value)) {
        found.add(CyclePattern(kind: PatternKind.beforePeriodMood, hits: e.value, cycles: n, mood: e.key));
      }
    }

    found.sort((a, b) => b.hits != a.hits ? b.hits - a.hits : a.kind.index - b.kind.index);
    return found.take(limit).toList();
  }
}
