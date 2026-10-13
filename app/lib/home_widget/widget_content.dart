import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:ruya/companion/companion.dart';
import 'package:ruya/cycle/cycle_snapshot.dart';
import 'package:ruya/cycle/life_stage.dart';
import 'package:ruya/l10n/app_localizations.dart';
import 'package:ruya/models/cycle_phase/cycle_phase.dart';
import 'package:ruya/models/cycle_phase/cycle_phase_enum.dart';
import 'package:ruya/models/period_logs/log_day.dart';
import 'package:ruya/models/periods/period.dart';
import 'package:ruya/services/settings_service.dart';

/// Everything one widget shows on one calendar day. All text is localized here
/// so the Android side only has to pick today's entry.
class WidgetDay {
  const WidgetDay({
    required this.epochDay,
    required this.big,
    required this.unit,
    required this.headline,
    this.phase,
    this.cycleDay,
    this.nextDate,
    this.fertility,
    this.progress = 0,
    this.max = 0,
    this.petMood,
    this.petAccessory,
  });

  /// Days since 1970-01-01 (local date), matches Java's LocalDate.toEpochDay().
  final int epochDay;
  final String big;
  final String unit;
  final String headline;
  final String? phase;
  final String? cycleDay;
  final String? nextDate;
  final String? fertility;
  final int progress;
  final int max;

  /// Companion state from the day's log ('calm', 'cozy' or 'comfort'); the
  /// widget switches to the sleepy picture at night by itself.
  final String? petMood;

  /// Accessory for this day only (the party hat on special days).
  final String? petAccessory;

  Map<String, Object?> toJson() => {
        'd': epochDay,
        'big': big,
        'unit': unit,
        'head': headline,
        if (phase != null) 'phase': phase,
        if (cycleDay != null) 'cday': cycleDay,
        if (nextDate != null) 'next': nextDate,
        if (fertility != null) 'fert': fertility,
        'p': progress,
        'm': max,
        if (petMood != null) 'pm': petMood,
        if (petAccessory != null) 'pa': petAccessory,
      };
}

/// Inputs that decide what the widgets may show.
class WidgetContext {
  const WidgetContext({
    required this.options,
    this.discrete = false,
    this.showPhases = true,
    this.showFertileWindow = true,
    this.onBirthControl = false,
    this.pregnancy,
    this.lutealPhaseLength = 14,
    this.pmsDays = 5,
    this.companion,
    this.sticker,
    this.accessory,
    this.isSpecialDate,
    this.todayLog,
  });

  final HomeWidgetOptions options;
  final bool discrete;

  /// Natural cycle with phase predictions enabled.
  final bool showPhases;
  final bool showFertileWindow;
  final bool onBirthControl;
  final DateSpan? pregnancy;
  final int lutealPhaseLength;
  final int pmsDays;

  /// Companion to draw, or null when it must not appear (option off, discrete mode).
  final Companion? companion;

  /// Companion for the sticker widget; it does not depend on the widget options.
  final Companion? sticker;

  /// What the chosen companion wears.
  final Accessory? accessory;

  /// Birthdays and anniversaries, when the companion wears the party hat.
  final bool Function(DateTime day)? isSpecialDate;

  /// Today's log, which decides whether the companion is cozy or comforting.
  final LogDay? todayLog;
}

/// Data written to the widget's shared preferences.
class WidgetPayload {
  const WidgetPayload({
    required this.days,
    required this.title,
    required this.staleText,
    required this.theme,
    required this.showRing,
    required this.showQuickLog,
    this.companion,
    this.sticker,
    this.accessory,
    this.neutral = false,
  });

  final List<WidgetDay> days;
  final String title;

  /// Shown if the app was not opened for longer than [WidgetContentBuilder.daysAhead].
  final String staleText;
  final WidgetTheme theme;
  final bool showRing;
  final bool showQuickLog;
  final Companion? companion;
  final Companion? sticker;
  final Accessory? accessory;

  /// Discrete mode: the sticker widget shows the neutral icon.
  final bool neutral;

  String get daysJson => jsonEncode(days.map((d) => d.toJson()).toList());
}

class WidgetContentBuilder {
  WidgetContentBuilder._();

  /// How many days ahead texts are prepared; the widget refreshes itself at
  /// midnight, so it stays correct for this long without opening the app.
  static const int daysAhead = 35;

  static int epochDay(DateTime d) => DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

  static WidgetPayload build({
    required List<Period> periods,
    required PredictedCycle? predictedCycle,
    required DateTime today,
    required AppLocalizations l10n,
    required WidgetContext context,
  }) {
    final start = DateTime(today.year, today.month, today.day);
    final days = <WidgetDay>[
      for (var i = 0; i < daysAhead; i++)
        _withPet(context, i == 0, DateTime(start.year, start.month, start.day + i), _day(
          day: DateTime(start.year, start.month, start.day + i),
          snapshot: CycleSnapshot.compute(
            periods: periods,
            predictedCycle: predictedCycle,
            now: DateTime(start.year, start.month, start.day + i),
            lutealPhaseLength: context.lutealPhaseLength,
            pmsDays: context.pmsDays,
            pregnancy: context.pregnancy,
            onBirthControl: context.onBirthControl,
          ),
          l10n: l10n,
          ctx: context,
          isToday: i == 0,
        )),
    ];
    return WidgetPayload(
      days: days,
      title: context.discrete ? l10n.discrete_appName : 'RUYA',
      staleText: l10n.widget_staleText,
      theme: context.options.theme,
      showRing: context.options.showRing,
      showQuickLog: context.options.showQuickLog,
      companion: context.discrete ? null : context.companion,
      sticker: context.discrete ? null : context.sticker,
      accessory: context.discrete ? null : context.accessory,
      neutral: context.discrete,
    );
  }

  /// Only today's log is known; later days start calm.
  static WidgetDay _withPet(WidgetContext ctx, bool isToday, DateTime date, WidgetDay d) {
    if ((ctx.companion == null && ctx.sticker == null) || ctx.discrete) return d;
    final mood = isToday
        ? companionMoodFor(now: DateTime(2000, 1, 1, 12), todayLog: ctx.todayLog)
        : CompanionMood.calm;
    return WidgetDay(
      epochDay: d.epochDay,
      big: d.big,
      unit: d.unit,
      headline: d.headline,
      phase: d.phase,
      cycleDay: d.cycleDay,
      nextDate: d.nextDate,
      fertility: d.fertility,
      progress: d.progress,
      max: d.max,
      petMood: mood.name,
      petAccessory: ctx.isSpecialDate?.call(date) ?? false ? Accessory.party.name : null,
    );
  }

  static WidgetDay _day({
    required DateTime day,
    required CycleSnapshot snapshot,
    required AppLocalizations l10n,
    required WidgetContext ctx,
    required bool isToday,
  }) {
    final o = ctx.options;
    final dateFmt = DateFormat.MMMMd(l10n.localeName);
    final id = epochDay(day);

    // Discrete mode: a neutral countdown, nothing else.
    if (ctx.discrete) {
      final days = snapshot.daysUntilNextPeriod;
      return WidgetDay(
        epochDay: id,
        big: days == null ? '–' : '${days.abs()}',
        unit: l10n.widget_daysUnit(days?.abs() ?? 0),
        headline: '',
      );
    }

    if (snapshot.pregnancy != null) {
      final due = snapshot.estimatedDueDate!;
      return WidgetDay(
        epochDay: id,
        big: '${snapshot.pregnancyWeek}',
        unit: l10n.pregnancy_weekShort,
        headline: l10n.pregnancy_status(snapshot.pregnancyWeek!, snapshot.pregnancyDayOfWeek!),
        nextDate: o.showNextDate ? l10n.pregnancy_dueDate(DateFormat.yMMMMd(l10n.localeName).format(due)) : null,
        progress: snapshot.pregnancyDays!.clamp(0, CycleSnapshot.pregnancyLengthDays),
        max: CycleSnapshot.pregnancyLengthDays,
      );
    }

    if (!snapshot.hasData) {
      return WidgetDay(epochDay: id, big: '–', unit: '', headline: l10n.today_noData);
    }

    final cycle = snapshot.cycle!;
    final days = snapshot.daysUntilNextPeriod!;
    final bc = snapshot.onBirthControl;
    final String big;
    final String unit;
    final String headline;
    if (snapshot.isPeriodOngoing && isToday) {
      big = '${snapshot.menstruationDay}';
      unit = l10n.widget_periodDayUnit;
      headline = l10n.today_periodDay(snapshot.menstruationDay);
    } else if (days > 0) {
      big = '$days';
      unit = l10n.widget_daysUnit(days);
      headline = bc ? l10n.today_bleedIn(days) : l10n.today_periodIn(days);
    } else if (days == 0) {
      big = '0';
      unit = l10n.widget_daysUnit(0);
      headline = bc ? l10n.today_bleedToday : l10n.today_periodToday;
    } else {
      big = '+${-days}';
      unit = l10n.widget_lateUnit;
      headline = bc ? l10n.today_bleedLate(-days) : l10n.today_periodLate(-days);
    }

    final phasesOn = ctx.showPhases && !bc;
    String? fertility;
    if (o.showFertility && phasesOn) {
      if (ctx.showFertileWindow && snapshot.isOvulationDay) {
        fertility = l10n.today_ovulationChip;
      } else if (ctx.showFertileWindow && snapshot.isInFertileWindow) {
        fertility = l10n.today_fertileChip;
      } else if (snapshot.isInPmsWindow) {
        fertility = l10n.today_pmsChip;
      }
    }
    final cycleDay = snapshot.cycleDay;
    final length = cycle.cycleLength;
    return WidgetDay(
      epochDay: id,
      big: big,
      unit: unit,
      headline: headline,
      phase: o.showPhase && phasesOn && snapshot.phase != CyclePhase.unknown
          ? l10n.today_phaseToday(snapshot.phase.getPhaseName(l10n))
          : null,
      cycleDay: o.showCycleDay && cycleDay != null ? l10n.today_cycleDay(cycleDay) : null,
      nextDate: o.showNextDate && !snapshot.isPeriodOngoing
          ? l10n.today_expectedOn(dateFmt.format(cycle.nextPeriodStart))
          : null,
      fertility: fertility,
      progress: (cycleDay ?? 0).clamp(0, length),
      max: length,
    );
  }
}
