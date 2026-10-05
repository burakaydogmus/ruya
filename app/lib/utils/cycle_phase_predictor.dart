import 'dart:math';

import 'package:ruya/models/cycle_phase/cycle_phase.dart';

/// A utility class for calculating when each cycle phase is due based on user data.
/// This is to be used with natural cycles only. If user is on the pill it should not be used.
///
/// Model (same as Mooneva, documented in docs/RUYA_ARCHITECTURE.md):
/// * next period    = last period start + average cycle length
/// * ovulation      = next period - luteal length (default 14, clamped to the cycle)
/// * fertile window = [ovulation - 5, ovulation]
/// * PMS window     = [next period - pmsDays, next period - 1]
///
/// All values are estimates and must be presented as such in the UI.
class CyclePhasePredictor {
  static const int defaultLutealPhaseLength = 14;
  static const int defaultPmsDays = 5;

  /// Days before ovulation that count as fertile (sperm survival).
  static const int fertileDaysBeforeOvulation = 5;

  static PredictedCycle predictCycle({
    required DateTime lastPeriodStartDate,
    required int averageCycleLength,
    required int averagePeriodDuration,
    int lutealPhaseLength = defaultLutealPhaseLength,
    int pmsDays = defaultPmsDays,
  }) {
    final start = DateTime(lastPeriodStartDate.year, lastPeriodStartDate.month, lastPeriodStartDate.day);
    final cycleLength = max(1, averageCycleLength);
    final periodDuration = max(1, averagePeriodDuration);
    // The luteal phase cannot be longer than the part of the cycle after the period.
    final luteal = min(lutealPhaseLength, max(1, cycleLength - periodDuration));

    final nextPeriodStart = _addDays(start, cycleLength);
    final ovulationDay = _addDays(nextPeriodStart, -luteal);
    final fertileStart = _addDays(ovulationDay, -fertileDaysBeforeOvulation);
    final int pms = pmsDays.clamp(0, max(0, luteal - 1)).toInt();

    return PredictedCycle(
      menstruationStart: start,
      follicularStart: _addDays(start, periodDuration),
      fertileWindowStart: fertileStart,
      ovulationDay: ovulationDay,
      lutealStart: _addDays(ovulationDay, 1),
      nextPeriodStart: nextPeriodStart,
      pmsStart: _addDays(nextPeriodStart, -pms),
      periodDuration: periodDuration,
    );
  }

  /// Calendar-day arithmetic that is safe across DST changes.
  static DateTime _addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);
}
