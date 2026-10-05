import 'package:flutter/material.dart';
import 'package:ruya/coordinators/data_refresh_coordinator.dart';
import 'package:ruya/models/flows/flow_enum.dart';
import 'package:ruya/models/period_logs/log_day.dart';
import 'package:ruya/services/symptom_service.dart';
import 'package:ruya/widgets/sheets/daily_log_sheet.dart';
import 'package:provider/provider.dart';
import 'package:ruya/utils/exceptions.dart';
import 'package:ruya/services/log_service.dart';
import 'package:ruya/services/period_service.dart';
import 'package:ruya/services/settings_service.dart';
import 'package:ruya/l10n/app_localizations.dart';

class LogUIController extends ChangeNotifier {

  /// Opens the daily log editor for [selectedDate]. If that day already has a
  /// log it is edited instead of failing with a duplicate error.
  Future<void> handleCreateNewLog({
    required BuildContext context,
    required DateTime selectedDate,
    required SymptomService symptomService,
    required int? age,
  }) async {
    final existing = context.read<LogService>().logMap[DateUtils.dateOnly(selectedDate)];
    await _openSheet(
      context: context,
      date: selectedDate,
      existing: existing,
      symptomService: symptomService,
      age: age,
    );
  }

  /// Orchestrates editing or deleting an existing log.
  Future<void> handleEditLog({
    required BuildContext context,
    required LogDay log,
    required SymptomService symptomService,
    int? age,
  }) {
    return _openSheet(
      context: context,
      date: log.date,
      existing: log,
      symptomService: symptomService,
      age: age,
    );
  }

  /// Applies a quick change to the log of [date] (creating it if needed) without
  /// opening the editor. Used by the Today screen quick actions.
  /// An update that leaves the log empty deletes it.
  ///
  /// Updates are serialised so quick successive taps always see the saved log
  /// (otherwise a second tap could try to insert a duplicate day).
  Future<void> quickUpdate({
    required BuildContext context,
    required DateTime date,
    required LogDay Function(LogDay current) update,
  }) {
    final next = _quickQueue.then((_) async {
      if (!context.mounted) return;
      final logService = context.read<LogService>();
      final current = logService.logMap[DateUtils.dateOnly(date)] ??
          LogDay(date: date, flow: FlowRate.none);
      final updated = update(current);
      if (!updated.hasContent && updated.id != null) {
        await _apply(context, DailyLogDeleted(updated), showSnack: false);
      } else if (updated.hasContent) {
        await _apply(context, DailyLogSaved(updated), showSnack: false);
      }
    });
    _quickQueue = next.catchError((_) {});
    return next;
  }

  Future<void> _quickQueue = Future.value();

  Future<void> _openSheet({
    required BuildContext context,
    required DateTime date,
    required LogDay? existing,
    required SymptomService symptomService,
    required int? age,
  }) async {
    final logService = context.read<LogService>();
    final result = await DailyLogSheet.show(
      context,
      date: date,
      existing: existing,
      symptomService: symptomService,
      age: age,
      medicationSuggestions: logService.recentMedications(),
    );
    if (result == null || !context.mounted) return;
    await _apply(context, result);
  }

  Future<void> _apply(BuildContext context, DailyLogSheetResult result, {bool showSnack = true}) async {
    final logService = context.read<LogService>();
    final periodService = context.read<PeriodService>();
    final coordinator = context.read<DataRefreshCoordinator>();
    final settings = context.read<SettingsService>();
    final l10n = AppLocalizations.of(context)!;

    try {
      switch (result) {
        case DailyLogSaved(:final log):
          if (!log.hasContent && log.id == null) return;
          await logService.saveLog(log);
          if (!context.mounted) return;
          await periodService.scheduleLoggingReminder(log: log, settings: settings, l10n: l10n);
          if (showSnack && context.mounted) _showSuccess(context, l10n.dailyLog_saved);
        case DailyLogDeleted(:final log):
          if (log.id == null) return;
          await logService.deleteLog(log.id!);
          if (showSnack && context.mounted) _showSuccess(context, l10n.dailyLog_deleted);
      }
      coordinator.onLogsChanged(l10n);
    } on DuplicateLogException catch (e) {
      if (context.mounted) _showError(context, e.message);
    } on FutureDateException catch (e) {
      if (context.mounted) _showError(context, e.message);
    } catch (e) {
      debugPrint('Saving log failed: $e');
      if (context.mounted) _showError(context, l10n.dailyLog_error);
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
  }
}
