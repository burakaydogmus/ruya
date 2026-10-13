import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruya/insights/pattern_detector.dart';
import 'package:ruya/l10n/app_localizations.dart';
import 'package:ruya/models/flows/flow_enum.dart';
import 'package:ruya/models/period_logs/daily_log_enums.dart';
import 'package:ruya/models/period_logs/log_day.dart';
import 'package:ruya/models/period_logs/pain_level_enum.dart';
import 'package:ruya/models/period_logs/symptom.dart';
import 'package:ruya/models/period_logs/symptom_type_enum.dart';
import 'package:ruya/models/periods/period.dart';

Period period(DateTime start) => Period(startDate: start, endDate: start.add(const Duration(days: 4)), totalDays: 5);
Symptom headache() => Symptom(type: SymptomType.headache);

void main() {
  final starts = [DateTime(2026, 6, 1), DateTime(2026, 6, 29), DateTime(2026, 7, 27), DateTime(2026, 8, 24)];
  final periods = starts.map(period).toList();
  LogDay log(DateTime start, int offset, {List<Symptom> symptoms = const [], List<Mood> moods = const [], int? pain}) =>
      LogDay(
        date: start.add(Duration(days: offset)),
        flow: offset >= 0 && offset < 5 ? FlowRate.medium : FlowRate.none,
        symptoms: symptoms,
        moods: moods,
        painLevel: pain,
      );

  test('needs three cycles before it says anything', () {
    final logs = [for (final s in starts.take(2)) log(s, 1, symptoms: [headache()])];
    expect(PatternDetector.detect(periods: periods.take(2).toList(), logs: logs), isEmpty);
  });

  test('a symptom on the same period day in most cycles is noticed, with its day', () {
    final logs = [
      for (final s in starts.take(3)) log(s, 1, symptoms: [headache()]),
      log(starts[3], 1),
    ];
    final found = PatternDetector.detect(periods: periods, logs: logs);
    expect(found, hasLength(1));
    expect(found.single.kind, PatternKind.periodDaySymptom);
    expect(found.single.day, 2);
    expect(found.single.hits, 3);
    expect(found.single.cycles, 4);
  });

  test('something that happened in only half of the cycles is not a pattern', () {
    final logs = [
      for (final s in starts.take(2)) log(s, 0, symptoms: [headache()]),
      log(starts[2], 0),
      log(starts[3], 0),
    ];
    expect(PatternDetector.detect(periods: periods, logs: logs), isEmpty);
  });

  test('moods and symptoms in the three days before a period count once per cycle', () {
    final logs = [
      for (final s in starts) ...[
        log(s, -1, moods: [Mood.irritable]),
        log(s, -2, moods: [Mood.irritable], symptoms: [headache()]),
      ],
    ];
    final found = PatternDetector.detect(periods: periods, logs: logs);
    expect(found.map((p) => p.kind), containsAll([PatternKind.beforePeriodMood, PatternKind.beforePeriodSymptom]));
    expect(found.every((p) => p.hits == 4 && p.cycles == 4), isTrue);
  });

  test('moderate or stronger pain on a period day is noticed, mild pain is not', () {
    final strong = [for (final s in starts) log(s, 0, pain: PainLevel.severe.index)];
    expect(PatternDetector.detect(periods: periods, logs: strong).single.kind, PatternKind.periodDayPain);
    final mild = [for (final s in starts) log(s, 0, pain: PainLevel.mild.index)];
    expect(PatternDetector.detect(periods: periods, logs: mild), isEmpty);
  });

  test('only the six most recent cycles are looked at and the limit is respected', () {
    final many = [for (var i = 0; i < 9; i++) DateTime(2026, 1, 5).add(Duration(days: 28 * i))];
    final logs = [
      for (final s in many) log(s, 0, symptoms: [headache()], pain: PainLevel.severe.index),
    ];
    final found = PatternDetector.detect(periods: many.map(period).toList(), logs: logs);
    expect(found.every((p) => p.cycles == PatternDetector.maxCycles), isTrue);
    expect(PatternDetector.detect(periods: many.map(period).toList(), logs: logs, limit: 1), hasLength(1));
  });

  test('the wording is an observation with counts, in Turkish', () {
    final l10n = lookupAppLocalizations(const Locale('tr'));
    final logs = [for (final s in starts.take(3)) log(s, 1, symptoms: [headache()])];
    final p = PatternDetector.detect(periods: periods, logs: logs).single;
    expect(p.title(l10n), '2. gün: Baş ağrısı');
    expect(p.sentence(l10n), contains('3'));
    expect(p.sentence(l10n), contains('Baş ağrısı'));
  });
}
