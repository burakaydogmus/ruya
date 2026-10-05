import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ruya/insights/insight_calculators.dart';
import 'package:ruya/cycle/life_stage.dart';
import 'package:ruya/l10n/app_localizations.dart';
import 'package:ruya/models/cycle_phase/cycle_phase_enum.dart';
import 'package:ruya/models/period_logs/daily_log_enums.dart';

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Pill adherence for the active regimen in the selected range.
class PillAdherenceWidget extends StatelessWidget {
  const PillAdherenceWidget({super.key, required this.adherence});

  final PillAdherence adherence;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final rate = adherence.takenRate;

    Widget stat(String label, int value, Color color) => Expanded(
          child: Column(
            children: [
              Text('$value', style: theme.textTheme.titleLarge?.copyWith(color: color, fontWeight: FontWeight.w600)),
              Text(label, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
            ],
          ),
        );

    return _InsightCard(
      title: l10n.insights_pillTitle,
      subtitle: rate == null ? null : l10n.insights_pillRate((rate * 100).round()),
      child: rate == null
          ? Text(l10n.insights_pillEmpty)
          : Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: rate, minHeight: 10),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    stat(l10n.insights_pillOnTime, adherence.onTime, Colors.green.shade600),
                    stat(l10n.insights_pillLate, adherence.late, Colors.amber.shade700),
                    stat(l10n.insights_pillSkipped, adherence.skipped, Colors.blueGrey),
                    stat(l10n.insights_pillMissed, adherence.missed, theme.colorScheme.error),
                  ],
                ),
              ],
            ),
    );
  }
}

/// Recent cycles with their period and cycle lengths.
class CycleHistoryWidget extends StatelessWidget {
  const CycleHistoryWidget({super.key, required this.entries});

  final List<CycleHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final fmt = DateFormat.yMMMd(l10n.localeName);

    return _InsightCard(
      title: l10n.insights_historyTitle,
      child: entries.isEmpty
          ? Text(l10n.insights_historyEmpty)
          : Column(
              children: [
                Row(
                  children: [
                    Expanded(flex: 4, child: Text(l10n.report_colStart, style: theme.textTheme.labelMedium)),
                    Expanded(flex: 3, child: Text(l10n.report_colPeriod, style: theme.textTheme.labelMedium)),
                    Expanded(flex: 3, child: Text(l10n.report_colCycle, style: theme.textTheme.labelMedium)),
                  ],
                ),
                const Divider(),
                for (final e in entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Row(children: [
                            Flexible(child: Text(fmt.format(e.start))),
                            if (e.kind != CycleKind.natural) ...[
                              const SizedBox(width: 4),
                              Tooltip(
                                message: e.kind == CycleKind.withdrawal
                                    ? l10n.cycleKind_withdrawal
                                    : l10n.cycleKind_pregnancy,
                                child: Icon(
                                  e.kind == CycleKind.withdrawal ? Icons.medication_outlined : Icons.pregnant_woman,
                                  size: 16,
                                ),
                              ),
                            ],
                          ]),
                        ),
                        Expanded(flex: 3, child: Text(l10n.insights_days(e.periodDays))),
                        Expanded(
                          flex: 3,
                          child: Text(
                            e.cycleLength == null ? l10n.insights_historyCurrent : l10n.insights_days(e.cycleLength!),
                            style: e.cycleLength == null ? theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic) : null,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Most frequent moods for each estimated cycle phase.
class MoodByPhaseWidget extends StatelessWidget {
  const MoodByPhaseWidget({super.key, required this.data});

  final Map<CyclePhase, Map<Mood, int>> data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final hasAny = data.values.any((m) => m.isNotEmpty);

    return _InsightCard(
      title: l10n.insights_moodByPhaseTitle,
      subtitle: l10n.insights_moodByPhaseSubtitle,
      child: !hasAny
          ? Text(l10n.insights_moodEmpty)
          : Column(
              children: [
                for (final phase in MoodByPhase.phases)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(phase.icon, size: 18, color: phase.color),
                        const SizedBox(width: 8),
                        SizedBox(width: 120, child: Text(phase.getPhaseName(l10n), style: theme.textTheme.labelLarge)),
                        Expanded(child: Text(_top(data[phase]!, l10n))),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  String _top(Map<Mood, int> counts, AppLocalizations l10n) {
    if (counts.isEmpty) return '–';
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(3).map((e) => '${e.key.emoji} ${e.key.getDisplayName(l10n)} (${e.value})').join('  ');
  }
}
