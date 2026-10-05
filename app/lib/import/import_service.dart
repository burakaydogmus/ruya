import 'package:ruya/database/repositories/logs_repository.dart';
import 'package:ruya/import/clue_importer.dart';
import 'package:ruya/import/drip_importer.dart';
import 'package:ruya/import/flo_importer.dart';
import 'package:ruya/import/import_models.dart';
import 'package:ruya/models/flows/flow_enum.dart';

class ImportFormatException implements Exception {
  const ImportFormatException(this.message);
  final String message;
  @override
  String toString() => 'ImportFormatException: $message';
}

/// What an import would do, shown to the user before anything is written.
class ImportPreview {
  const ImportPreview({
    required this.result,
    required this.newDays,
    required this.conflictingDays,
  });

  final ImportResult result;

  /// Days that will be added.
  final List<DateTime> newDays;

  /// Days already logged in RUYA. They are kept as they are and not imported.
  final List<DateTime> conflictingDays;

  ImportSource get source => result.source;
  int get totalDays => result.days.length;
  int get flowDays => newDays.where((d) => result.days[d]!.flow != FlowRate.none).length;
  DateTime? get firstDate => newDays.isEmpty ? null : newDays.first;
  DateTime? get lastDate => newDays.isEmpty ? null : newDays.last;
}

/// Detects the export format, previews and applies an import.
///
/// Existing RUYA data is never overwritten: a day that already has a log keeps
/// it completely (same rule as Mooneva: "existing day wins").
class ExternalImportService {
  ExternalImportService({LogsRepository? logsRepository}) : _logs = logsRepository ?? LogsRepository();

  final LogsRepository _logs;

  static const int maxFileBytes = 50 * 1024 * 1024;
  static const List<ExternalImporter> importers = [FloImporter(), ClueImporter(), DripImporter()];

  /// Parses [content] with the first importer that recognises it.
  static ImportResult parse(String content, {DateTime? today}) {
    final trimmed = content.trimLeft();
    final looksJson = trimmed.startsWith('{') || trimmed.startsWith('[');
    for (final importer in importers) {
      final isJsonImporter = importer.source != ImportSource.drip;
      if (looksJson != isJsonImporter) continue;
      final result = importer.tryParse(content, today: today);
      if (result != null) return result;
    }
    throw const ImportFormatException('Unrecognised export file');
  }

  Future<ImportPreview> preview(ImportResult result) async {
    final existing = (await _logs.readAllLogs()).map((l) => dateOnly(l.date)).toSet();
    final dates = result.days.keys.toList()..sort();
    return ImportPreview(
      result: result,
      newDays: dates.where((d) => !existing.contains(d)).toList(),
      conflictingDays: dates.where(existing.contains).toList(),
    );
  }

  /// Inserts the new days. Returns the number of days added.
  Future<int> apply(ImportResult result) async {
    final logs = [for (final day in result.days.values) day.toLogDay()];
    return _logs.insertNewLogs(logs);
  }
}
