import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_clean_calendar/controllers/clean_calendar_controller.dart';
import 'package:scrollable_clean_calendar/scrollable_clean_calendar.dart';
import 'package:scrollable_clean_calendar/utils/enums.dart';
import 'package:ruya/controllers/log_ui_controller.dart';
import 'package:ruya/cycle/cycle_snapshot.dart';
import 'package:ruya/database/repositories/sex_repository.dart';
import 'package:ruya/l10n/app_localizations.dart';
import 'package:ruya/models/flows/flow_enum.dart';
import 'package:ruya/models/period_logs/log_day.dart';
import 'package:ruya/models/prefrences/day_of_week_enum.dart';
import 'package:ruya/services/log_service.dart';
import 'package:ruya/services/period_service.dart';
import 'package:ruya/services/settings_service.dart';
import 'package:ruya/services/user_service.dart';

/// Calendar colours. Kept in one place so the legend always matches the cells.
class _CalendarColors {
  _CalendarColors(ColorScheme scheme)
      : predicted = scheme.error,
        fertile = Colors.teal.withValues(alpha: 0.22),
        ovulation = Colors.teal.shade600,
        pms = Colors.deepPurple.shade300,
        sex = Colors.pink.shade400,
        contraception = Colors.indigo.shade400,
        other = scheme.outline;

  final Color predicted;
  final Color fertile;
  final Color ovulation;
  final Color pms;
  final Color sex;
  final Color contraception;
  final Color other;
}

/// Month calendar showing recorded and estimated cycle information.
///
/// Visual language (kept intentionally sparse):
/// * recorded period: filled circle (flow colour)
/// * estimated period: outlined circle
/// * estimated fertile window: soft teal background, ovulation: teal ring
/// * estimated PMS: short bar under the number
/// * sex / contraception / other entries: tiny markers below the day
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CleanCalendarController? _controller;
  DateTime? _controllerMinDate;
  Set<DateTime> _sexLogDates = {};

  @override
  void initState() {
    super.initState();
    _loadSexLogs();
  }

  Future<void> _loadSexLogs() async {
    try {
      final logs = await SexRepository().getAllLogs();
      if (!mounted) return;
      setState(() => _sexLogDates = logs.map((l) => DateUtils.dateOnly(l.dateTime)).toSet());
    } catch (e) {
      debugPrint('Calendar: could not load sex logs: $e');
    }
  }

  CleanCalendarController _controllerFor(DateTime? earliestLog, SettingsService settings) {
    final now = DateUtils.dateOnly(DateTime.now());
    final yearAgo = DateTime(now.year - 1, now.month, 1);
    final minDate = earliestLog != null && earliestLog.isBefore(yearAgo)
        ? DateTime(earliestLog.year, earliestLog.month, 1)
        : yearAgo;
    if (_controller == null || _controllerMinDate != minDate) {
      _controllerMinDate = minDate;
      _controller = CleanCalendarController(
        minDate: minDate,
        maxDate: DateTime(now.year, now.month + 4, 0),
        initialFocusDate: now,
        weekdayStart: DayOfWeek.fromString(settings.startingDayOfWeek).toTableCalendar,
        onDayTapped: _onDayTapped,
      );
    }
    return _controller!;
  }

  void _onDayTapped(DateTime day) {
    if (DateUtils.dateOnly(day).isAfter(DateUtils.dateOnly(DateTime.now()))) return;
    context.read<LogUIController>().handleCreateNewLog(
          context: context,
          selectedDate: day,
          symptomService: context.read(),
          age: context.read<UserService>().age,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final logService = context.watch<LogService>();
    final periodService = context.watch<PeriodService>();
    final settings = context.watch<SettingsService>();
    final colors = _CalendarColors(scheme);

    if (!logService.hasLoadedOnce) return const Center(child: CircularProgressIndicator());

    final snapshot = periodService.cycleSnapshot;
    final phasesOn = settings.isNaturalCycle && settings.arePhasePredictionsEnabled;
    final showFertile = phasesOn && settings.displayFertileWindowOnCalendar;
    final showPms = phasesOn && settings.showPmsWindow;
    final showSex = settings.showIntimateFields;
    final controller = _controllerFor(logService.earliestLogDate, settings);
    final todayMs = DateUtils.dateOnly(DateTime.now()).millisecondsSinceEpoch;

    return Column(
      children: [
        _Legend(colors: colors, showFertile: showFertile, showPms: showPms, showSex: showSex),
        const Divider(height: 1),
        Expanded(
          child: ScrollableCleanCalendar(
            calendarController: controller,
            layout: Layout.BEAUTY,
            locale: l10n.localeName,
            dayBuilder: (context, values) {
              final day = DateUtils.dateOnly(values.day);
              final log = logService.logMap[day];
              final forecast = snapshot.forecastFor(day);
              return _DayCell(
                day: day,
                log: log,
                forecast: forecast,
                isToday: day.millisecondsSinceEpoch == todayMs,
                isFuture: day.millisecondsSinceEpoch > todayMs,
                showFertile: showFertile,
                showPms: showPms,
                hasSexLog: _sexLogDates.contains(day),
                showSex: showSex,
                colors: colors,
                onTap: () => _onDayTapped(day),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.log,
    required this.forecast,
    required this.isToday,
    required this.isFuture,
    required this.showFertile,
    required this.showPms,
    required this.hasSexLog,
    required this.showSex,
    required this.colors,
    required this.onTap,
  });

  final DateTime day;
  final LogDay? log;
  final DayForecast forecast;
  final bool isToday;
  final bool isFuture;
  final bool showFertile;
  final bool showPms;
  final bool hasSexLog;

  /// False in kid mode.
  final bool showSex;
  final _CalendarColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final recordedPeriod = log != null && log!.flow != FlowRate.none;
    final predictedPeriod = !recordedPeriod && forecast.predictedPeriod;
    final fertile = showFertile && !recordedPeriod && forecast.fertile;
    final ovulation = showFertile && !recordedPeriod && forecast.ovulation;
    final pms = showPms && !recordedPeriod && forecast.pms;

    final hadSex = showSex && (hasSexLog || (log?.sexActivity?.hadSex ?? false));
    final contraception = log?.contraception.isNotEmpty ?? false;
    final otherContent = log != null &&
        (log!.symptoms.isNotEmpty ||
            log!.moods.isNotEmpty ||
            log!.painLevel != null ||
            log!.discharge != null ||
            log!.medications.isNotEmpty ||
            (log!.notes?.isNotEmpty ?? false));

    Color? fill;
    BoxBorder? border;
    Color textColor = isFuture ? scheme.onSurface.withAlpha(110) : scheme.onSurface;
    if (recordedPeriod) {
      fill = log!.flow.color;
      textColor = Colors.white;
    } else if (predictedPeriod) {
      fill = colors.predicted.withValues(alpha: 0.10);
      border = Border.all(color: colors.predicted.withValues(alpha: 0.7), width: 1.5);
      textColor = colors.predicted;
    } else if (ovulation) {
      border = Border.all(color: colors.ovulation, width: 2);
    }
    if (isToday && border == null) {
      border = Border.all(color: scheme.primary, width: 2);
    }

    final markers = <Widget>[
      if (hadSex) Icon(Icons.favorite, size: 9, color: colors.sex),
      if (contraception) Icon(Icons.shield, size: 9, color: colors.contraception),
      if (otherContent && !hadSex && !contraception)
        Container(width: 5, height: 5, decoration: BoxDecoration(color: colors.other, shape: BoxShape.circle)),
    ];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: fertile
            ? BoxDecoration(color: colors.fertile, borderRadius: BorderRadius.circular(8))
            : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: fill, shape: BoxShape.circle, border: border),
              child: Text(
                '${day.day}',
                style: TextStyle(
                  color: textColor,
                  fontWeight: isToday || recordedPeriod || ovulation ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            SizedBox(
              height: 4,
              child: pms
                  ? Container(
                      width: 16,
                      height: 3,
                      decoration: BoxDecoration(color: colors.pms, borderRadius: BorderRadius.circular(2)),
                    )
                  : null,
            ),
            SizedBox(
              height: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final m in markers) Padding(padding: const EdgeInsets.symmetric(horizontal: 1), child: m),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.colors, required this.showFertile, required this.showPms, required this.showSex});

  final _CalendarColors colors;
  final bool showFertile;
  final bool showPms;
  final bool showSex;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelSmall;

    Widget item(Widget swatch, String label) => Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Row(mainAxisSize: MainAxisSize.min, children: [swatch, const SizedBox(width: 5), Text(label, style: style)]),
        );
    Widget circle({Color? fill, Color? border}) => Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: border == null ? null : Border.all(color: border, width: 1.5),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Wrap(
        runSpacing: 6,
        children: [
          item(circle(fill: FlowRate.medium.color), l10n.calendar_legendPeriod),
          item(circle(fill: colors.predicted.withValues(alpha: 0.1), border: colors.predicted), l10n.calendar_legendPredicted),
          if (showFertile) ...[
            item(Container(width: 14, height: 12, decoration: BoxDecoration(color: colors.fertile, borderRadius: BorderRadius.circular(3))),
                l10n.calendar_legendFertile),
            item(circle(border: colors.ovulation), l10n.calendar_legendOvulation),
          ],
          if (showPms)
            item(Container(width: 14, height: 3, color: colors.pms), l10n.calendar_legendPms),
          if (showSex) item(Icon(Icons.favorite, size: 12, color: colors.sex), l10n.calendar_legendSex),
          item(Icon(Icons.shield, size: 12, color: colors.contraception), l10n.calendar_legendContraception),
          item(circle(border: scheme.primary), l10n.today),
        ],
      ),
    );
  }
}
