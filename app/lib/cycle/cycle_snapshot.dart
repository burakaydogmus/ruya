import 'package:ruya/cycle/life_stage.dart';
import 'package:ruya/models/cycle_phase/cycle_phase.dart';
import 'package:ruya/models/cycle_phase/cycle_phase_enum.dart';
import 'package:ruya/models/periods/period.dart';
import 'package:ruya/utils/cycle_phase_predictor.dart';

/// Per-day estimate flags used by the calendar.
class DayForecast {
  const DayForecast({
    this.predictedPeriod = false,
    this.fertile = false,
    this.ovulation = false,
    this.pms = false,
  });

  final bool predictedPeriod;
  final bool fertile;
  final bool ovulation;
  final bool pms;

  static const none = DayForecast();
}

/// A read-only view of "where am I in my cycle today" for the Today screen,
/// the calendar and the home widget. Pure Dart, no Flutter or DB access.
///
/// Every value here is an estimate; the UI must word it as such
/// ("tahmini", "beklenen", "yaklaşık").
class CycleSnapshot {
  CycleSnapshot._({
    required this.today,
    required this.cycle,
    required this.forecastCycles,
    required this.isPeriodOngoing,
    required this.menstruationDay,
    required this.phase,
    required this.basedOnDefaults,
    this.pregnancy,
    this.onBirthControl = false,
  });

  /// Cycle length used when only one period has been logged.
  static const int defaultCycleLength = 28;
  static const int forecastCycleCount = 3;

  final DateTime today;

  /// Current estimated cycle (anchored on the last logged period), or null with no data.
  final PredictedCycle? cycle;

  /// Current cycle followed by the next estimated cycles.
  final List<PredictedCycle> forecastCycles;

  final bool isPeriodOngoing;

  /// 1-based day of the ongoing period (0 when not on a period).
  final int menstruationDay;
  final CyclePhase phase;

  /// True when the estimate uses the default cycle length (fewer than 2 periods).
  final bool basedOnDefaults;

  /// Active pregnancy (predictions are paused while set).
  final DateSpan? pregnancy;

  /// While on hormonal birth control the forecast is an expected withdrawal bleed.
  final bool onBirthControl;

  static const int pregnancyLengthDays = 280;

  /// Days since the last menstrual period (gestational age).
  int? get pregnancyDays => pregnancy == null ? null : _dayDiff(today, pregnancy!.start);

  /// Completed pregnancy weeks (12 weeks 3 days → 12), counted from the LMP.
  int? get pregnancyWeek => pregnancyDays == null ? null : pregnancyDays! ~/ 7;

  int? get pregnancyDayOfWeek => pregnancyDays == null ? null : pregnancyDays! % 7;

  /// Estimated due date: LMP + 280 days (Naegele's rule).
  DateTime? get estimatedDueDate => pregnancy == null
      ? null
      : DateTime(pregnancy!.start.year, pregnancy!.start.month, pregnancy!.start.day + pregnancyLengthDays);

  bool get hasData => cycle != null;

  /// Days until the expected period; negative when the period is late.
  int? get daysUntilNextPeriod => cycle == null ? null : _dayDiff(cycle!.nextPeriodStart, today);

  bool get isLate => (daysUntilNextPeriod ?? 0) < 0;

  int? get cycleDay => cycle?.cycleDayFor(today);

  bool get isInFertileWindow => cycle?.isInFertileWindow(today) ?? false;

  bool get isOvulationDay => cycle?.isOvulationDay(today) ?? false;

  bool get isInPmsWindow => !isPeriodOngoing && (cycle?.isInPmsWindow(today) ?? false);

  static CycleSnapshot compute({
    required List<Period> periods,
    required PredictedCycle? predictedCycle,
    required DateTime now,
    int lutealPhaseLength = CyclePhasePredictor.defaultLutealPhaseLength,
    int pmsDays = CyclePhasePredictor.defaultPmsDays,
    DateSpan? pregnancy,
    bool onBirthControl = false,
  }) {
    final today = _d(now);
    if (pregnancy != null) {
      return CycleSnapshot._(
        today: today,
        cycle: null,
        forecastCycles: const [],
        isPeriodOngoing: false,
        menstruationDay: 0,
        phase: CyclePhase.unknown,
        basedOnDefaults: false,
        pregnancy: pregnancy,
      );
    }
    if (periods.isEmpty) {
      return CycleSnapshot._(
        today: today,
        cycle: null,
        forecastCycles: const [],
        isPeriodOngoing: false,
        menstruationDay: 0,
        phase: CyclePhase.unknown,
        basedOnDefaults: false,
      );
    }

    final sorted = List<Period>.from(periods)..sort((a, b) => a.startDate.compareTo(b.startDate));
    final last = sorted.last;
    final lastStart = _d(last.startDate);
    final lastEnd = _d(last.endDate);

    var basedOnDefaults = false;
    var cycle = predictedCycle;
    if (cycle == null) {
      basedOnDefaults = true;
      cycle = CyclePhasePredictor.predictCycle(
        lastPeriodStartDate: lastStart,
        averageCycleLength: defaultCycleLength,
        averagePeriodDuration: last.totalDays > 0 ? last.totalDays : 5,
        lutealPhaseLength: lutealPhaseLength,
        pmsDays: pmsDays,
      );
    }

    // A period is ongoing when today is inside the last logged period and that
    // period was logged up to today (Menstrudel semantics).
    final ongoing = !today.isBefore(lastStart) && today == lastEnd;
    final menstruationDay = ongoing ? _dayDiff(today, lastStart) + 1 : 0;

    var phase = cycle.getPhaseForDate(today);
    if (ongoing) {
      phase = CyclePhase.menstruation;
    } else if (phase == CyclePhase.menstruation && lastEnd.isBefore(today)) {
      // The average says "still bleeding" but the user's log ended: move on.
      phase = CyclePhase.follicular;
    }

    return CycleSnapshot._(
      today: today,
      cycle: cycle,
      forecastCycles: [for (var i = 0; i < forecastCycleCount; i++) cycle.shiftedBy(i)],
      isPeriodOngoing: ongoing,
      menstruationDay: menstruationDay,
      phase: phase,
      basedOnDefaults: basedOnDefaults,
      onBirthControl: onBirthControl,
    );
  }

  /// Estimate flags for a calendar [day].
  ///
  /// Predicted period days are only reported for days after today; fertile,
  /// ovulation and PMS flags are reported from the current cycle onwards.
  DayForecast forecastFor(DateTime day) {
    final current = cycle;
    if (current == null) return DayForecast.none;
    final d = _d(day);
    if (d.isBefore(current.menstruationStart)) return DayForecast.none;

    var predictedPeriod = false;
    var fertile = false;
    var ovulation = false;
    var pms = false;
    for (final c in forecastCycles) {
      if (d.isAfter(today) && c.isInPredictedNextPeriod(d)) predictedPeriod = true;
      if (c.isInFertileWindow(d)) fertile = true;
      if (c.isOvulationDay(d)) ovulation = true;
      if (c.isInPmsWindow(d)) pms = true;
    }
    return DayForecast(
      predictedPeriod: predictedPeriod,
      fertile: fertile && !predictedPeriod,
      ovulation: ovulation && !predictedPeriod,
      pms: pms && !predictedPeriod,
    );
  }

  static DateTime _d(DateTime date) => DateTime(date.year, date.month, date.day);

  static int _dayDiff(DateTime a, DateTime b) =>
      DateTime.utc(a.year, a.month, a.day).difference(DateTime.utc(b.year, b.month, b.day)).inDays;
}
