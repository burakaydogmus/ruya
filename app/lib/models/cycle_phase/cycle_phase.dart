import 'package:ruya/l10n/app_localizations.dart';
import 'package:ruya/models/cycle_phase/cycle_phase_enum.dart';

class PredictedCycle {
  final DateTime menstruationStart;
  final DateTime follicularStart;
  final DateTime fertileWindowStart;
  final DateTime ovulationDay;
  final DateTime lutealStart;
  final DateTime nextPeriodStart;

  /// First day of the estimated PMS window (equal to [nextPeriodStart] when disabled).
  final DateTime pmsStart;

  /// Average period duration used for the estimate.
  final int periodDuration;

  PredictedCycle({
    required this.menstruationStart,
    required this.follicularStart,
    required this.fertileWindowStart,
    required this.ovulationDay,
    required this.lutealStart,
    required this.nextPeriodStart,
    DateTime? pmsStart,
    this.periodDuration = 5,
  }) : pmsStart = pmsStart ?? nextPeriodStart;

  /// Last fertile day (ovulation day itself).
  DateTime get fertileWindowEnd => ovulationDay;

  /// Estimated last day of the next period.
  DateTime get nextPeriodEnd =>
      DateTime(nextPeriodStart.year, nextPeriodStart.month, nextPeriodStart.day + periodDuration - 1);

  int get cycleLength => _dayDiff(nextPeriodStart, menstruationStart);

  static DateTime _d(DateTime date) => DateTime(date.year, date.month, date.day);

  static int _dayDiff(DateTime a, DateTime b) =>
      DateTime.utc(a.year, a.month, a.day).difference(DateTime.utc(b.year, b.month, b.day)).inDays;

  bool _inRange(DateTime date, DateTime from, DateTime to) {
    final d = _d(date);
    return !d.isBefore(from) && !d.isAfter(to);
  }

  /// Whether [date] falls in the estimated fertile window (inclusive of ovulation day).
  bool isInFertileWindow(DateTime date) => _inRange(date, fertileWindowStart, fertileWindowEnd);

  bool isOvulationDay(DateTime date) => _d(date) == ovulationDay;

  /// Whether [date] falls in the estimated PMS window before the next period.
  bool isInPmsWindow(DateTime date) {
    final d = _d(date);
    return !d.isBefore(pmsStart) && d.isBefore(nextPeriodStart);
  }

  /// Whether [date] falls in the estimated next period.
  bool isInPredictedNextPeriod(DateTime date) => _inRange(date, nextPeriodStart, nextPeriodEnd);

  /// 1-based day of the cycle for [date], or null if before this cycle.
  int? cycleDayFor(DateTime date) {
    final diff = _dayDiff(date, menstruationStart);
    return diff < 0 ? null : diff + 1;
  }

  /// The same cycle shifted forward by [cycles] cycle lengths (for calendar forecasts).
  PredictedCycle shiftedBy(int cycles) {
    final offset = cycleLength * cycles;
    DateTime s(DateTime d) => DateTime(d.year, d.month, d.day + offset);
    return PredictedCycle(
      menstruationStart: s(menstruationStart),
      follicularStart: s(follicularStart),
      fertileWindowStart: s(fertileWindowStart),
      ovulationDay: s(ovulationDay),
      lutealStart: s(lutealStart),
      nextPeriodStart: s(nextPeriodStart),
      pmsStart: s(pmsStart),
      periodDuration: periodDuration,
    );
  }

  CyclePhase getPhaseForDate(DateTime date) {
    // Normalise to midnight to make comparison work regardless of time
    final d = DateTime(date.year, date.month, date.day);

    if (d.isBefore(menstruationStart)) return CyclePhase.unknown;
    if (d.isBefore(follicularStart)) return CyclePhase.menstruation;
    if (d.isBefore(fertileWindowStart)) return CyclePhase.follicular;
    if (d.isBefore(ovulationDay)) return CyclePhase.fertileWindow;
    if (d == ovulationDay) return CyclePhase.ovulation;
    if (d.isBefore(lutealStart)) return CyclePhase.fertileWindow;
    if (d.isBefore(nextPeriodStart)) return CyclePhase.luteal;
    
    return CyclePhase.late;
  }

  int getDaysLeft(DateTime date, CyclePhase phase) {
    final d = DateTime(date.year, date.month, date.day);

    switch (phase) {
      case CyclePhase.menstruation: // This is based off average and not if the user is currently on their period.
        return follicularStart.difference(d).inDays;
      case CyclePhase.follicular:
        return fertileWindowStart.difference(d).inDays;
      case CyclePhase.fertileWindow:
        if (d.isBefore(ovulationDay)) {
          return ovulationDay.difference(d).inDays;
        } else {
          return lutealStart.difference(d).inDays;
        }
      case CyclePhase.ovulation:
        return lutealStart.difference(d).inDays;
      case CyclePhase.luteal:
        return nextPeriodStart.difference(d).inDays;
      default:
        return 0;
    }
  }

  double getPregnancyChance(DateTime date, CyclePhase phase) {
    // For this I am following the basic strucuture of the diagram from this article:
    // "https://premom.com/getting-pregnant-at-menstrual-cycle-phase/"
    // So this is not actually a % chance, and so the raw % should not be displayed to the user.

    final d = DateTime(date.year, date.month, date.day);

    if (phase != CyclePhase.fertileWindow && phase != CyclePhase.ovulation) { // It's a low chance if not within this window.
      return 0.05;
    }

    final daysToOvulation = ovulationDay.difference(d).inDays;

    switch (daysToOvulation) {
      case 5: return 0.10; // 5 days before
      case 4: return 0.15; // 4 days before
      case 3: return 0.20; // 3 days before
      case 2: return 0.25; // 2 days before
      case 1: return 0.30; // 1 day before
      case 0: return 0.33; // Ovulation Day
      case -1: return 0.10; // Day after
      default: return 0.05;
    }
  }

  /// Returns the l10n translated string for the chance of getting pregnant. (High/Medium/Low)
  String getFertilityLevel(DateTime date, CyclePhase phase, AppLocalizations l10n) {
    final chance = getPregnancyChance(date, phase);
    if (chance >= 0.25) return l10n.fertilityChance_high;
    if (chance >= 0.10) return l10n.fertilityChance_medium;
    return l10n.fertilityChance_low;
  }
}