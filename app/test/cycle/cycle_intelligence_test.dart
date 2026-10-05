import 'package:flutter_test/flutter_test.dart';
import 'package:ruya/cycle/cycle_snapshot.dart';
import 'package:ruya/models/cycle_phase/cycle_phase_enum.dart';
import 'package:ruya/models/periods/period.dart';
import 'package:ruya/utils/cycle_phase_predictor.dart';
import 'package:ruya/utils/period_predictor.dart';

DateTime d(int m, int day) => DateTime(2026, m, day);

Period period(DateTime start, int days) => Period(
      startDate: start,
      endDate: DateTime(start.year, start.month, start.day + days - 1),
      totalDays: days,
    );

void main() {
  group('CyclePhasePredictor', () {
    final cycle = CyclePhasePredictor.predictCycle(
      lastPeriodStartDate: DateTime(2026, 3, 1, 14, 30), // time of day must not matter
      averageCycleLength: 28,
      averagePeriodDuration: 5,
    );

    test('next period, ovulation, fertile window and PMS for a 28-day cycle', () {
      expect(cycle.nextPeriodStart, d(3, 29));
      expect(cycle.nextPeriodEnd, d(4, 2));
      expect(cycle.ovulationDay, d(3, 15)); // 29 - 14
      expect(cycle.fertileWindowStart, d(3, 10));
      expect(cycle.fertileWindowEnd, d(3, 15));
      expect(cycle.pmsStart, d(3, 24)); // 5 days before
      expect(cycle.follicularStart, d(3, 6));
      expect(cycle.lutealStart, d(3, 16));
    });

    test('phase for each day of the cycle', () {
      expect(cycle.getPhaseForDate(d(2, 28)), CyclePhase.unknown);
      expect(cycle.getPhaseForDate(d(3, 1)), CyclePhase.menstruation);
      expect(cycle.getPhaseForDate(d(3, 5)), CyclePhase.menstruation);
      expect(cycle.getPhaseForDate(d(3, 6)), CyclePhase.follicular);
      expect(cycle.getPhaseForDate(d(3, 10)), CyclePhase.fertileWindow);
      expect(cycle.getPhaseForDate(DateTime(2026, 3, 15, 23, 59)), CyclePhase.ovulation);
      expect(cycle.getPhaseForDate(d(3, 16)), CyclePhase.luteal);
      expect(cycle.getPhaseForDate(d(3, 28)), CyclePhase.luteal);
      expect(cycle.getPhaseForDate(d(3, 29)), CyclePhase.late);
    });

    test('window helpers are inclusive and exclusive where expected', () {
      expect(cycle.isInFertileWindow(d(3, 9)), isFalse);
      expect(cycle.isInFertileWindow(d(3, 15)), isTrue);
      expect(cycle.isInFertileWindow(d(3, 16)), isFalse);
      expect(cycle.isInPmsWindow(d(3, 23)), isFalse);
      expect(cycle.isInPmsWindow(d(3, 24)), isTrue);
      expect(cycle.isInPmsWindow(d(3, 28)), isTrue);
      expect(cycle.isInPmsWindow(d(3, 29)), isFalse);
      expect(cycle.cycleDayFor(d(3, 1)), 1);
      expect(cycle.cycleDayFor(d(3, 28)), 28);
    });

    test('custom luteal length and PMS days; PMS can be disabled', () {
      final c = CyclePhasePredictor.predictCycle(
        lastPeriodStartDate: d(3, 1),
        averageCycleLength: 30,
        averagePeriodDuration: 4,
        lutealPhaseLength: 12,
        pmsDays: 0,
      );
      expect(c.ovulationDay, d(3, 19)); // 31 - 12
      expect(c.isInPmsWindow(d(3, 30)), isFalse);
    });

    test('luteal phase is clamped for very short cycles', () {
      final c = CyclePhasePredictor.predictCycle(
        lastPeriodStartDate: d(3, 1),
        averageCycleLength: 15,
        averagePeriodDuration: 7,
      );
      // luteal = min(14, 15 - 7) = 8 -> ovulation day 16 - 8 = 8
      expect(c.ovulationDay, d(3, 8));
      expect(c.ovulationDay.isBefore(c.nextPeriodStart), isTrue);
    });

    test('shiftedBy moves every date by whole cycles across DST', () {
      final next = cycle.shiftedBy(1);
      expect(next.menstruationStart, d(3, 29));
      expect(next.ovulationDay, d(4, 12));
      expect(next.nextPeriodStart, d(4, 26));
    });
  });

  group('CycleSnapshot', () {
    final periods = [period(d(1, 4), 5), period(d(2, 1), 5), period(d(3, 1), 5)];

    CycleSnapshot at(DateTime now, {List<Period>? list}) {
      final p = list ?? periods;
      final prediction = PeriodPredictor.estimateNextPeriod(p, now);
      final cycle = prediction == null
          ? null
          : CyclePhasePredictor.predictCycle(
              lastPeriodStartDate: p.map((e) => e.startDate).reduce((a, b) => a.isAfter(b) ? a : b),
              averageCycleLength: prediction.averageCycleLength,
              averagePeriodDuration: prediction.averagePeriodDuration,
            );
      return CycleSnapshot.compute(periods: p, predictedCycle: cycle, now: now);
    }

    test('empty history has no data', () {
      final s = CycleSnapshot.compute(periods: const [], predictedCycle: null, now: d(3, 1));
      expect(s.hasData, isFalse);
      expect(s.daysUntilNextPeriod, isNull);
      expect(s.forecastFor(d(3, 5)), same(DayForecast.none));
    });

    test('days until next period and phase in the luteal PMS window', () {
      final s = at(DateTime(2026, 3, 25, 9));
      expect(s.cycle!.nextPeriodStart, d(3, 29));
      expect(s.daysUntilNextPeriod, 4);
      expect(s.phase, CyclePhase.luteal);
      expect(s.isInPmsWindow, isTrue);
      expect(s.basedOnDefaults, isFalse);
      expect(s.cycleDay, 25);
    });

    test('late period is negative days', () {
      final s = at(d(4, 2));
      expect(s.daysUntilNextPeriod, -4);
      expect(s.isLate, isTrue);
      expect(s.phase, CyclePhase.late);
    });

    test('ongoing period overrides the average-based phase', () {
      final ongoing = [...periods.take(2), period(d(3, 1), 7)];
      final s = at(d(3, 7), list: ongoing);
      expect(s.isPeriodOngoing, isTrue);
      expect(s.menstruationDay, 7);
      expect(s.phase, CyclePhase.menstruation);
    });

    test('finished period moves to follicular even if the average is longer', () {
      final short = [period(d(1, 4), 6), period(d(2, 1), 6), period(d(3, 1), 2)];
      final s = at(d(3, 4), list: short);
      expect(s.isPeriodOngoing, isFalse);
      expect(s.phase, CyclePhase.follicular);
    });

    test('single period falls back to default 28-day estimate', () {
      final s = at(d(3, 10), list: [period(d(3, 1), 4)]);
      expect(s.basedOnDefaults, isTrue);
      expect(s.cycle!.nextPeriodStart, d(3, 29));
    });

    test('calendar forecast flags', () {
      final s = at(d(3, 12));
      expect(s.forecastFor(d(3, 15)).ovulation, isTrue);
      expect(s.forecastFor(d(3, 13)).fertile, isTrue);
      expect(s.forecastFor(d(3, 26)).pms, isTrue);
      expect(s.forecastFor(d(3, 30)).predictedPeriod, isTrue);
      expect(s.forecastFor(d(3, 30)).pms, isFalse);
      // Next cycles are forecast too.
      expect(s.forecastFor(d(4, 12)).ovulation, isTrue);
      expect(s.forecastFor(d(4, 27)).predictedPeriod, isTrue);
      // Nothing before the current cycle.
      expect(s.forecastFor(d(2, 20)), same(DayForecast.none));
    });
  });
}
