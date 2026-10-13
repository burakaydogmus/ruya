import 'package:flutter/material.dart';
import 'package:ruya/insights/pattern_detector.dart';
import 'package:ruya/l10n/app_localizations.dart';
import 'package:ruya/models/period_logs/log_day.dart';
import 'package:ruya/models/periods/period.dart';
import 'package:ruya/theme/ruya_card.dart';

/// One dot per cycle looked at, filled for the cycles where it happened.
class PatternDots extends StatelessWidget {
  const PatternDots({super.key, required this.pattern});

  final CyclePattern pattern;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var i = 0; i < pattern.cycles; i++)
          Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.only(right: 5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < pattern.hits ? scheme.primary : Colors.transparent,
              border: Border.all(color: scheme.primary, width: 2),
            ),
          ),
      ],
    );
  }
}

/// "What we noticed": things that repeated across the user's own cycles.
/// Counted on the device from her logs; observations, never advice.
class PatternsWidget extends StatelessWidget {
  const PatternsWidget({super.key, required this.periods, required this.logs});

  final List<Period> periods;
  final List<LogDay> logs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final starts = periods.map((p) => DateUtils.dateOnly(p.startDate)).toSet().length;
    final patterns = PatternDetector.detect(periods: periods, logs: logs);

    return RuyaCard(
      color: theme.colorScheme.surfaceContainer,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.pattern_title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(l10n.pattern_subtitle, style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          if (starts < PatternDetector.minCycles)
            Text(l10n.pattern_empty)
          else if (patterns.isEmpty)
            Text(l10n.pattern_none)
          else ...[
            for (final p in patterns)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.title(l10n), style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(p.sentence(l10n), style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 6),
                    PatternDots(pattern: p),
                  ],
                ),
              ),
            Text(l10n.pattern_note, style: muted),
          ],
        ],
      ),
    );
  }
}
