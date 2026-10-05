import 'dart:convert';

import 'package:ruya/import/import_models.dart';
import 'package:ruya/models/flows/flow_enum.dart';

/// Flo "data export" JSON: `operationalData.cycles[]` with
/// `period_start_date` / `period_end_date`.
///
/// Flo does not export flow intensity, so period days are imported as medium.
/// A single cycle is capped at [maxPeriodSpanDays] so a corrupt end date cannot
/// create weeks of fake bleeding; end dates in the future are cut at today.
class FloImporter extends ExternalImporter {
  const FloImporter();

  static const int maxPeriodSpanDays = 15;

  @override
  ImportSource get source => ImportSource.flo;

  @override
  ImportResult? tryParse(String content, {DateTime? today}) {
    final Object? json;
    try {
      json = jsonDecode(content);
    } catch (_) {
      return null;
    }
    if (json is! Map) return null;
    final operational = json['operationalData'];
    final cycles = operational is Map ? operational['cycles'] : null;
    if (cycles is! List || cycles.isEmpty) return null;

    final now = dateOnly(today ?? DateTime.now());
    final days = <DateTime, ImportedDay>{};
    var skipped = 0;
    for (final cycle in cycles) {
      if (cycle is! Map) {
        skipped++;
        continue;
      }
      final start = parseImportDate(cycle['period_start_date']);
      if (start == null || start.isAfter(now)) {
        skipped++;
        continue;
      }
      var end = parseImportDate(cycle['period_end_date']) ?? start;
      if (end.isBefore(start)) end = start;
      if (end.isAfter(now)) end = now;
      var span = DateTime.utc(end.year, end.month, end.day)
              .difference(DateTime.utc(start.year, start.month, start.day))
              .inDays +
          1;
      if (span > maxPeriodSpanDays) span = maxPeriodSpanDays;
      for (var i = 0; i < span; i++) {
        final d = DateTime(start.year, start.month, start.day + i);
        days.putIfAbsent(d, () => ImportedDay(d)).flow = FlowRate.medium;
      }
    }
    if (days.isEmpty) return null;
    return ImportResult(source, days, skippedEntries: skipped);
  }
}
