import 'package:flutter/material.dart';
import 'package:ruya/l10n/app_localizations.dart';
import 'package:ruya/models/period_logs/daily_log_enums.dart';

/// Most frequently logged moods in the selected range.
class MoodFrequencyWidget extends StatelessWidget {
  const MoodFrequencyWidget({super.key, required this.moodCounts});

  final Map<Mood, int> moodCounts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final entries = moodCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (sum, e) => sum + e.value);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.insights_moodTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              Text(l10n.insights_moodEmpty, style: theme.textTheme.bodyMedium)
            else
              for (final e in entries.take(6))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(width: 28, child: Text(e.key.emoji, style: const TextStyle(fontSize: 18))),
                      SizedBox(width: 110, child: Text(e.key.getDisplayName(l10n))),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: total == 0 ? 0 : e.value / total,
                            minHeight: 8,
                          ),
                        ),
                      ),
                      SizedBox(width: 36, child: Text('${e.value}', textAlign: TextAlign.end)),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
