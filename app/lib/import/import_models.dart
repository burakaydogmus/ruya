import 'package:ruya/models/flows/flow_enum.dart';
import 'package:ruya/models/period_logs/daily_log_enums.dart';
import 'package:ruya/models/period_logs/log_day.dart';
import 'package:ruya/models/period_logs/symptom.dart';

enum ImportSource { flo, clue, drip }

extension ImportSourceName on ImportSource {
  String get displayName => switch (this) {
        ImportSource.flo => 'Flo',
        ImportSource.clue => 'Clue',
        ImportSource.drip => 'drip',
      };
}

/// One day parsed from another app's export, before it becomes a [LogDay].
class ImportedDay {
  ImportedDay(this.date);

  final DateTime date;
  FlowRate flow = FlowRate.none;

  /// Menstrudel symptom DB names (`cramps`, `back pain`, …); unknown names become custom symptoms.
  final Set<String> symptoms = {};
  final List<Mood> moods = [];
  Discharge? discharge;
  Libido? libido;
  SexActivity? sexActivity;
  final Set<ContraceptionMethod> contraception = {};
  final List<String> notes = [];

  void addMood(Mood mood) {
    if (!moods.contains(mood) && moods.length < Mood.maxSelected) moods.add(mood);
  }

  void addNote(String note) {
    final trimmed = note.trim();
    if (trimmed.isNotEmpty) notes.add(trimmed);
  }

  bool get isEmpty =>
      flow == FlowRate.none &&
      symptoms.isEmpty &&
      moods.isEmpty &&
      discharge == null &&
      libido == null &&
      sexActivity == null &&
      contraception.isEmpty &&
      notes.isEmpty;

  LogDay toLogDay() => LogDay(
        date: date,
        flow: flow,
        symptoms: symptoms.map(Symptom.fromDbString).toList(),
        moods: List.of(moods),
        discharge: discharge,
        libido: libido,
        sexActivity: sexActivity,
        contraception: contraception.toList(),
        notes: notes.isEmpty ? null : notes.join('\n'),
      );
}

/// Parsed export. Days are keyed by calendar date (local midnight).
class ImportResult {
  ImportResult(this.source, this.days, {this.skippedEntries = 0});

  final ImportSource source;
  final Map<DateTime, ImportedDay> days;

  /// Rows/entries that could not be read (bad dates, unknown structure).
  final int skippedEntries;
}

/// Adapter for one external app format.
abstract class ExternalImporter {
  const ExternalImporter();

  ImportSource get source;

  /// Returns null when [content] is not in this importer's format.
  ImportResult? tryParse(String content, {DateTime? today});
}

/// Strict `YYYY-MM-DD` parsing (also accepts a longer ISO string and uses its date part).
/// Rejects impossible dates such as 2025-02-30.
DateTime? parseImportDate(Object? raw) {
  if (raw is! String || raw.length < 10) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw);
  if (match == null) return null;
  final y = int.parse(match.group(1)!);
  final m = int.parse(match.group(2)!);
  final d = int.parse(match.group(3)!);
  final date = DateTime(y, m, d);
  if (date.year != y || date.month != m || date.day != d) return null;
  return date;
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
