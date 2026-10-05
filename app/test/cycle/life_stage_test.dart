import 'package:flutter_test/flutter_test.dart';
import 'package:ruya/cycle/cycle_snapshot.dart';
import 'package:ruya/cycle/life_stage.dart';
import 'package:ruya/models/periods/period.dart';
import 'package:ruya/report/clinical_report_data.dart';
import 'package:ruya/utils/period_predictor.dart';

DateTime d(int y, int m, int day) => DateTime(y, m, day);
Period p(DateTime s, [int days = 5]) =>
    Period(startDate: s, endDate: s.add(Duration(days: days - 1)), totalDays: days);

void main() {
  test('DateSpan JSON round trip and contains', () {
    final spans = [DateSpan(d(2026, 1, 1), end: d(2026, 3, 31)), DateSpan(d(2026, 6, 1))];
    final decoded = DateSpan.decodeList(DateSpan.encodeList(spans));
    expect(decoded.length, 2);
    expect(decoded.first.end, d(2026, 3, 31));
    expect(decoded.last.isOngoing, isTrue);
    expect(decoded.first.contains(DateTime(2026, 3, 31, 23)), isTrue);
    expect(decoded.first.contains(d(2026, 4, 1)), isFalse);
    expect(DateSpan.decodeList('not json'), isEmpty);
  });

  group('CycleClassifier', () {
    final c = CycleClassifier(
      birthControl: [DateSpan(d(2026, 2, 1), end: d(2026, 4, 30))],
      pregnancies: [DateSpan(d(2025, 1, 10), end: d(2025, 10, 1))],
    );

    test('classifies natural, withdrawal and pregnancy cycles', () {
      expect(c.classify(d(2026, 1, 5), d(2026, 2, 2)), CycleKind.natural);
      expect(c.classify(d(2026, 2, 2), d(2026, 3, 2)), CycleKind.withdrawal);
      expect(c.classify(d(2025, 1, 10), d(2025, 11, 20)), CycleKind.pregnancy);
      expect(c.classify(d(2025, 1, 5), d(2025, 11, 20)), CycleKind.pregnancy);
      expect(c.classify(d(2024, 12, 10), d(2025, 1, 10)), CycleKind.natural);
    });

    test('prediction uses natural cycles off birth control, withdrawal cycles on it', () {
      expect(c.includeForPrediction(d(2026, 1, 5), d(2026, 2, 2)), isTrue);
      expect(c.includeForPrediction(d(2026, 2, 2), d(2026, 3, 2)), isFalse);
      final onBc = CycleClassifier(birthControl: [DateSpan(d(2026, 2, 1))]);
      expect(onBc.isOnBirthControl, isTrue);
      expect(onBc.includeForPrediction(d(2026, 1, 5), d(2026, 2, 2)), isFalse);
      expect(onBc.includeForPrediction(d(2026, 2, 2), d(2026, 3, 2)), isTrue);
    });
  });

  test('withdrawal bleeds do not change the natural cycle average', () {
    final periods = [
      p(d(2026, 1, 1)), p(d(2026, 1, 31)), p(d(2026, 3, 2)), // 30, 30 natural
      p(d(2026, 3, 30)), p(d(2026, 4, 27)), // 28, 28: started on birth control
    ];
    final bcEnded = CycleClassifier(birthControl: [DateSpan(d(2026, 3, 1), end: d(2026, 5, 20))]);
    final natural = PeriodPredictor.estimateNextPeriod(periods, d(2026, 6, 1), includeCycle: bcEnded.includeForPrediction);
    expect(natural!.averageCycleLength, 30);

    final bcActive = CycleClassifier(birthControl: [DateSpan(d(2026, 3, 1))]);
    final withdrawal = PeriodPredictor.estimateNextPeriod(periods, d(2026, 5, 1), includeCycle: bcActive.includeForPrediction);
    expect(withdrawal!.averageCycleLength, 28);
  });

  test('pregnancy snapshot: weeks, days and due date; no period forecast', () {
    final s = CycleSnapshot.compute(
      periods: [p(d(2026, 1, 1))],
      predictedCycle: null,
      now: d(2026, 3, 30),
      pregnancy: DateSpan(d(2026, 1, 1)),
    );
    expect(s.pregnancyDays, 88);
    expect(s.pregnancyWeek, 12);
    expect(s.pregnancyDayOfWeek, 4);
    expect(s.estimatedDueDate, d(2026, 10, 8));
    expect(s.hasData, isFalse);
    expect(s.forecastFor(d(2026, 4, 5)), same(DayForecast.none));
  });

  test('clinical report labels cycle types and averages natural cycles only', () {
    final data = ClinicalReportData.build(
      periods: [p(d(2026, 1, 1)), p(d(2026, 1, 31)), p(d(2026, 3, 2)), p(d(2026, 3, 30)), p(d(2026, 4, 27))],
      logs: const [],
      from: d(2026, 1, 1),
      to: d(2026, 6, 1),
      classifier: CycleClassifier(birthControl: [DateSpan(d(2026, 3, 1))]),
      now: d(2026, 5, 10),
    );
    expect(data.cycles.map((c) => c.kind), [
      CycleKind.natural,
      CycleKind.natural,
      CycleKind.withdrawal,
      CycleKind.withdrawal,
      CycleKind.withdrawal, // ongoing
    ]);
    expect(data.averageCycleLength, 30);
    expect(data.completedCycles.length, 2);
  });
}
