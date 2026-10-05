import 'dart:math';

import 'package:flutter/material.dart';
import 'package:ruya/l10n/app_localizations.dart';
import 'package:ruya/models/cycles/cycle_stats.dart';
import 'package:ruya/models/periods/period_stats.dart';

/// Average cycle length, its variation and average period duration at a glance.
class CycleOverviewWidget extends StatelessWidget {
  const CycleOverviewWidget({super.key, required this.cycleStats, required this.periodStats});

  final CycleStats? cycleStats;
  final PeriodStats? periodStats;

  /// Population standard deviation of the cycle lengths, rounded to whole days.
  static int? variationDays(CycleStats? stats) {
    final lengths = stats?.cycleLengths ?? const <int>[];
    if (lengths.length < 2) return null;
    final mean = lengths.reduce((a, b) => a + b) / lengths.length;
    final variance = lengths.map((l) => pow(l - mean, 2)).reduce((a, b) => a + b) / lengths.length;
    return sqrt(variance).round();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final variation = variationDays(cycleStats);

    Widget tile(String label, String value) => Expanded(
          child: Column(
            children: [
              Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(label, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
            ],
          ),
        );

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Row(
          children: [
            tile(l10n.insights_avgCycle, cycleStats == null ? '–' : l10n.insights_days(cycleStats!.averageCycleLength)),
            tile(l10n.insights_variation, variation == null ? '–' : '±${l10n.insights_days(variation)}'),
            tile(l10n.insights_avgPeriod, periodStats == null ? '–' : l10n.insights_days(periodStats!.averageLength)),
          ],
        ),
      ),
    );
  }
}
