import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ruya/companion/companion.dart';
import 'package:ruya/cycle/life_stage.dart';
import 'package:ruya/home_widget/widget_content.dart';
import 'package:ruya/l10n/app_localizations.dart';
import 'package:ruya/models/flows/flow_enum.dart';
import 'package:ruya/models/period_logs/log_day.dart';
import 'package:ruya/models/period_logs/pain_level_enum.dart';
import 'package:ruya/models/periods/period.dart';
import 'package:ruya/services/settings_service.dart';
import 'package:ruya/utils/cycle_phase_predictor.dart';

DateTime d(int m, int day) => DateTime(2026, m, day);
Period p(DateTime s, [int days = 5]) =>
    Period(startDate: s, endDate: s.add(Duration(days: days - 1)), totalDays: days);

void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    await initializeDateFormatting('tr');
    l10n = lookupAppLocalizations(const Locale('tr'));
  });

  final periods = [p(d(8, 10)), p(d(9, 7)), p(d(10, 5))];
  final cycle = CyclePhasePredictor.predictCycle(
    lastPeriodStartDate: d(10, 5),
    averageCycleLength: 28,
    averagePeriodDuration: 5,
  );

  WidgetPayload build({
    HomeWidgetOptions options = const HomeWidgetOptions(),
    bool discrete = false,
    DateSpan? pregnancy,
    DateTime? today,
    Companion? companion,
    LogDay? todayLog,
  }) =>
      WidgetContentBuilder.build(
        periods: periods,
        predictedCycle: cycle,
        today: today ?? d(10, 25),
        l10n: l10n,
        context: WidgetContext(
          options: options,
          discrete: discrete,
          pregnancy: pregnancy,
          companion: companion,
          todayLog: todayLog,
        ),
      );

  test('prepares one entry per day, keyed by local epoch day', () {
    final payload = build();
    expect(payload.days.length, WidgetContentBuilder.daysAhead);
    expect(payload.days.first.epochDay, WidgetContentBuilder.epochDay(d(10, 25)));
    expect(payload.days[1].epochDay - payload.days.first.epochDay, 1);
    final json = jsonDecode(payload.daysJson) as List;
    expect((json.first as Map)['big'], '8');
  });

  test('countdown changes every day and turns into lateness after the due date', () {
    final days = build().days;
    expect(days[0].big, '8'); // 25 Oct -> 2 Nov (5 Oct + 28)
    expect(days[0].headline, 'Regline 8 gün kaldı');
    expect(days[7].big, '1');
    expect(days[8].big, '0');
    expect(days[8].headline, 'Reglin bugün bekleniyor');
    expect(days[10].big, '+2');
    expect(days[10].unit, 'gün gecikti');
  });

  test('phase, fertility, next date and cycle day follow the options', () {
    final all = build(
      today: d(10, 19),
      options: const HomeWidgetOptions(showCycleDay: true),
    ).days.first;
    expect(all.phase, 'Bugün: Yumurtlama');
    expect(all.fertility, 'Tahmini yumurtlama günü'); // 2 Nov - 14 = 19 Oct
    expect(all.cycleDay, 'Döngünün 15. günü · tahmini');
    expect(all.nextDate, contains('Beklenen başlangıç'));
    expect(all.max, 28);
    expect(all.progress, 15);

    final minimal = build(
      today: d(10, 19),
      options: const HomeWidgetOptions(showPhase: false, showFertility: false, showNextDate: false),
    ).days.first;
    expect(minimal.phase, isNull);
    expect(minimal.fertility, isNull);
    expect(minimal.nextDate, isNull);
    expect(minimal.cycleDay, isNull);
  });

  test('discrete mode shows only a neutral number', () {
    final payload = build(discrete: true);
    final day = payload.days.first;
    expect(payload.title, 'Ajanda');
    expect(day.big, '8');
    expect(day.headline, isEmpty);
    expect(day.phase, isNull);
    expect(day.nextDate, isNull);
    expect(day.fertility, isNull);
  });

  test('pregnancy shows weeks and due date', () {
    final day = build(pregnancy: DateSpan(d(8, 1))).days.first;
    expect(day.big, '12');
    expect(day.unit, 'hafta');
    expect(day.headline, 'Gebelik · 12 hafta 1 gün');
    expect(day.max, 280);
  });

  test('payload carries ring, quick log and theme options', () {
    final payload = build(options: const HomeWidgetOptions(showRing: false, showQuickLog: false, theme: WidgetTheme.dark));
    expect(payload.showRing, isFalse);
    expect(payload.showQuickLog, isFalse);
    expect(payload.theme, WidgetTheme.dark);
  });

  test('the companion follows today\'s log and never shows in discrete mode', () {
    final calm = build(companion: Companion.lokum);
    expect(calm.companion, Companion.lokum);
    expect(calm.days.first.petMood, 'calm');
    expect((jsonDecode(calm.daysJson) as List).first['pm'], 'calm');

    final period = build(companion: Companion.lokum, todayLog: LogDay(date: d(10, 25), flow: FlowRate.medium));
    expect(period.days.first.petMood, 'cozy');
    expect(period.days[1].petMood, 'calm');

    final pain = build(
      companion: Companion.lokum,
      todayLog: LogDay(date: d(10, 25), flow: FlowRate.none, painLevel: PainLevel.severe.index),
    );
    expect(pain.days.first.petMood, 'comfort');

    final hidden = build(companion: Companion.lokum, discrete: true);
    expect(hidden.companion, isNull);
    expect(hidden.days.first.petMood, isNull);

    expect(build().companion, isNull);
  });
}
