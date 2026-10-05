import 'package:flutter_test/flutter_test.dart';
import 'package:ruya/insights/insight_calculators.dart';
import 'package:ruya/models/birth_control/pills/pill_intake.dart';
import 'package:ruya/models/birth_control/pills/pill_regimen.dart';
import 'package:ruya/models/birth_control/pills/pill_status_enum.dart';
import 'package:ruya/models/cycle_phase/cycle_phase_enum.dart';
import 'package:ruya/models/flows/flow_enum.dart';
import 'package:ruya/models/period_logs/daily_log_enums.dart';
import 'package:ruya/models/period_logs/log_day.dart';
import 'package:ruya/models/periods/period.dart';
import 'package:ruya/utils/cycle_phase_predictor.dart';

DateTime d(int m, int day) => DateTime(2026, m, day);
Period p(DateTime s, int days) => Period(startDate: s, endDate: s.add(Duration(days: days - 1)), totalDays: days);

void main() {
  group('PillAdherence', () {
    final regimen = PillRegimen(name: 'P', activePills: 21, placeboPills: 7, startDate: d(1, 1), isActive: true);
    PillIntake intake(DateTime day, PillIntakeStatus s) =>
        PillIntake(regimenId: 1, takenAt: day, scheduledDate: day, status: s, pillNumberInCycle: 1);

    test('counts only active pill days, today only once logged', () {
      // 1 Jan .. 30 Jan: 21 active (1-21), 7 placebo (22-28), 29-30 active again.
      final intakes = [
        for (var i = 1; i <= 18; i++) intake(d(1, i), PillIntakeStatus.taken),
        intake(d(1, 19), PillIntakeStatus.late),
        intake(d(1, 20), PillIntakeStatus.skipped),
        // 21 missed, 29 taken, 30 (today) not yet
        intake(d(1, 29), PillIntakeStatus.taken),
      ];
      final a = PillAdherence.compute(regimen: regimen, intakes: intakes, since: d(1, 1), now: d(1, 30));
      expect(a.expected, 22);
      expect(a.onTime, 19);
      expect(a.late, 1);
      expect(a.skipped, 1);
      expect(a.missed, 1);
      expect(a.takenRate, closeTo(20 / 22, 1e-9));
    });

    test('respects the since date and empty history', () {
      final a = PillAdherence.compute(regimen: regimen, intakes: const [], since: d(1, 15), now: d(1, 17));
      expect(a.expected, 2); // 15, 16 (17 = today without entry)
      expect(a.missed, 2);
      expect(PillAdherence.empty.takenRate, isNull);
    });
  });

  test('CycleHistory lists newest first with lengths to the next period', () {
    final h = CycleHistory.build([p(d(1, 1), 5), p(d(2, 1), 4), p(d(3, 1), 6)]);
    expect(h.map((e) => e.start), [d(3, 1), d(2, 1), d(1, 1)]);
    expect(h.first.cycleLength, isNull);
    expect(h[1].cycleLength, 28);
    expect(h[2].cycleLength, 31);
    expect(h[1].periodDays, 4);
  });

  test('MoodByPhase assigns moods to the phase of their own cycle', () {
    final periods = [p(d(3, 1), 5), p(d(3, 29), 5)]; // 28-day cycle, ovulation 15 Mar (cycle day 15)
    LogDay mood(DateTime day, Mood m) => LogDay(date: day, flow: FlowRate.none, moods: [m]);
    final logs = [
      mood(d(3, 2), Mood.tired), // day 2 menstrual
      mood(d(3, 9), Mood.energetic), // day 9 follicular (fertile starts day 10)
      mood(d(3, 13), Mood.happy), // day 13 fertile
      mood(d(3, 15), Mood.happy), // day 15 ovulation -> fertile window bucket
      mood(d(3, 20), Mood.irritable), // day 20 luteal
      mood(d(3, 30), Mood.sad), // next cycle day 2 -> menstrual
      LogDay(date: d(2, 1), flow: FlowRate.none, moods: [Mood.calm]), // before any period: skipped
    ];
    final r = MoodByPhase.compute(periods: periods, logs: logs);
    expect(r[CyclePhase.menstruation], {Mood.tired: 1, Mood.sad: 1});
    expect(r[CyclePhase.follicular], {Mood.energetic: 1});
    expect(r[CyclePhase.fertileWindow], {Mood.happy: 2});
    expect(r[CyclePhase.luteal], {Mood.irritable: 1});
  });

  test('MoodByPhase agrees with CyclePhasePredictor for every day of a cycle', () {
    for (final length in [24, 28, 33]) {
      final periods = [p(d(3, 1), 5), p(DateTime(2026, 3, 1 + length), 5)];
      final predicted = CyclePhasePredictor.predictCycle(
        lastPeriodStartDate: d(3, 1),
        averageCycleLength: length,
        averagePeriodDuration: 5,
      );
      for (var i = 0; i < length; i++) {
        final day = DateTime(2026, 3, 1 + i);
        final r = MoodByPhase.compute(
          periods: periods,
          logs: [LogDay(date: day, flow: FlowRate.none, moods: [Mood.calm])],
        );
        final bucket = r.entries.firstWhere((e) => e.value.isNotEmpty).key;
        var expected = predicted.getPhaseForDate(day);
        if (expected == CyclePhase.ovulation) expected = CyclePhase.fertileWindow;
        expect(bucket, expected, reason: 'length $length, cycle day ${i + 1}');
      }
    }
  });
}
