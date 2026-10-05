import 'package:ruya/l10n/app_localizations.dart';
import 'package:ruya/services/log_service.dart';
import 'package:ruya/services/period_service.dart';
import 'package:ruya/services/widget_controller.dart';

class DataRefreshCoordinator {
  final LogService logService;
  final PeriodService periodService;
  final WidgetController widgetController;

  AppLocalizations? _l10n;
  bool _hasTriggeredInitialRefresh = false;

  DataRefreshCoordinator({
    required this.logService,
    required this.periodService,
    required this.widgetController,
  }) {
    logService.addListener(_onLogServiceChanged);
  }

  void registerL10n(AppLocalizations l10n) {
    _l10n = l10n;
    _tryInitialRefresh();
  }

  void _onLogServiceChanged() {
    _tryInitialRefresh();
  }

  void _tryInitialRefresh() {
    if (_hasTriggeredInitialRefresh) return;
    if (!logService.hasLoadedOnce) return;
    if (_l10n == null) return;

    _hasTriggeredInitialRefresh = true;

    periodService.refreshData(
      currentLogs: logService.logs,
      l10n: _l10n!,
      widgetController: widgetController,
    );
  }

  Future<void> resetAllData() async {
    _hasTriggeredInitialRefresh = false;
    await logService.loadLogs();
    await periodService.refreshData(
      currentLogs: logService.logs,
      l10n: _l10n!,
      widgetController: widgetController,
    );
  }

  void onLogsChanged(AppLocalizations l10n) async {
    final updates = await periodService.recalculatePeriods(
      logService.logs,
    );

    await logService.updateLogPeriodReferences(updates);

    periodService.refreshData(
      currentLogs: logService.logs,
      l10n: l10n,
      widgetController: widgetController,
    );
  }

  /// Reloads logs written outside the UI (e.g. the Wear OS quick log) and
  /// recalculates periods, predictions, notifications and the widget.
  Future<void> onExternalLogsChanged() async {
    await logService.loadLogs();
    final l10n = _l10n;
    if (l10n != null) onLogsChanged(l10n);
  }

  void dispose() {
    logService.removeListener(_onLogServiceChanged);
  }
}
