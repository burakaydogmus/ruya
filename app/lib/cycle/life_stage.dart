import 'dart:convert';

/// A dated stretch of time: hormonal birth control use or a pregnancy.
/// `end == null` means it is still ongoing.
class DateSpan {
  DateSpan(DateTime start, {DateTime? end})
      : start = _d(start),
        end = end == null ? null : _d(end);

  final DateTime start;
  final DateTime? end;

  bool get isOngoing => end == null;

  bool contains(DateTime date) {
    final d = _d(date);
    return !d.isBefore(start) && (end == null || !d.isAfter(end!));
  }

  DateSpan closedAt(DateTime date) => DateSpan(start, end: date.isBefore(start) ? start : date);

  Map<String, String?> toJson() => {'start': _iso(start), 'end': end == null ? null : _iso(end!)};

  static DateSpan? fromJson(Object? json) {
    if (json is! Map) return null;
    final start = DateTime.tryParse('${json['start']}');
    if (start == null) return null;
    final endRaw = json['end'];
    return DateSpan(start, end: endRaw == null ? null : DateTime.tryParse('$endRaw'));
  }

  static List<DateSpan> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return list.map(DateSpan.fromJson).whereType<DateSpan>().toList()
        ..sort((a, b) => a.start.compareTo(b.start));
    } catch (_) {
      return [];
    }
  }

  static String encodeList(List<DateSpan> spans) => jsonEncode(spans.map((s) => s.toJson()).toList());

  static DateTime _d(DateTime d) => DateTime(d.year, d.month, d.day);
  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// How a cycle (period start → next period start) should be treated.
enum CycleKind { natural, withdrawal, pregnancy }

/// Classifies cycles using the user's birth control and pregnancy history.
///
/// * A cycle containing the start of a pregnancy is a pregnancy cycle and is
///   never used for averages.
/// * A cycle whose period started while hormonal birth control was in use is a
///   withdrawal bleed: excluded from natural averages, used only for the
///   "expected bleed" estimate while birth control is still in use.
class CycleClassifier {
  const CycleClassifier({this.birthControl = const [], this.pregnancies = const []});

  final List<DateSpan> birthControl;
  final List<DateSpan> pregnancies;

  bool get isOnBirthControl => birthControl.any((s) => s.isOngoing);

  DateSpan? get activePregnancy {
    for (final p in pregnancies) {
      if (p.isOngoing) return p;
    }
    return null;
  }

  CycleKind classify(DateTime periodStart, DateTime? nextPeriodStart) {
    final start = DateTime(periodStart.year, periodStart.month, periodStart.day);
    for (final p in pregnancies) {
      // Pregnancy start is the last menstrual period (LMP): it belongs to the
      // cycle that begins on/just before it.
      final afterStart = !p.start.isBefore(start);
      final beforeNext = nextPeriodStart == null || p.start.isBefore(nextPeriodStart);
      if (afterStart && beforeNext) return CycleKind.pregnancy;
    }
    if (birthControl.any((s) => s.contains(start))) return CycleKind.withdrawal;
    return CycleKind.natural;
  }

  /// Whether a cycle may be used for the current prediction.
  bool includeForPrediction(DateTime periodStart, DateTime nextPeriodStart) {
    final kind = classify(periodStart, nextPeriodStart);
    if (kind == CycleKind.pregnancy) return false;
    return isOnBirthControl ? kind == CycleKind.withdrawal : kind == CycleKind.natural;
  }
}
