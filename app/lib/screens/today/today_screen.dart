import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ruya/theme/ruya_card.dart';
import 'package:ruya/companion/companion_card.dart';
import 'package:ruya/companion/companion_service.dart';
import 'package:ruya/controllers/log_ui_controller.dart';
import 'package:ruya/cycle/cycle_snapshot.dart';
import 'package:ruya/l10n/app_localizations.dart';
import 'package:ruya/models/cycle_phase/cycle_phase_enum.dart';
import 'package:ruya/models/flows/flow_enum.dart';
import 'package:ruya/models/period_logs/daily_log_enums.dart';
import 'package:ruya/models/period_logs/log_day.dart';
import 'package:ruya/models/period_logs/pain_level_enum.dart';
import 'package:ruya/insights/pattern_detector.dart';
import 'package:ruya/screens/today/bag_screen.dart';
import 'package:ruya/screens/today/today_customize_screen.dart';
import 'package:ruya/services/bag_service.dart';
import 'package:ruya/services/feedback_service.dart';
import 'package:ruya/services/log_service.dart';
import 'package:ruya/services/period_service.dart';
import 'package:ruya/services/settings_service.dart';
import 'package:ruya/services/user_service.dart';
import 'package:ruya/widgets/insights/patterns.dart';

/// RUYA home: days until the expected period, today's estimated phase,
/// a mood quick entry and a quick log. Deliberately free of statistics.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final periodService = context.watch<PeriodService>();
    final logService = context.watch<LogService>();
    final settings = context.watch<SettingsService>();
    final companions = context.watch<CompanionService>();

    if (!logService.hasLoadedOnce) {
      return const Center(child: CircularProgressIndicator());
    }

    final snapshot = periodService.cycleSnapshot;
    final todayLog = logService.logMap[DateUtils.dateOnly(DateTime.now())];
    final showPhases = settings.isNaturalCycle && settings.arePhasePredictionsEnabled;
    // Discrete mode must not show anything that hints at the app's purpose.
    final showCompanion =
        !settings.isDiscreteModeEnabled && companions.isLoaded && !companions.isHidden;

    final discrete = settings.isDiscreteModeEnabled;
    final patterns = PatternDetector.detect(periods: periodService.periodEntries, logs: logService.logs, limit: 1);
    final bag = context.watch<BagService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      bag.ensureDefaults(defaultBagItems(l10n));
      bag.syncCycle(snapshot.cycle?.nextPeriodStart.toIso8601String());
    });

    Widget? build(TodayTile tile) => switch (tile) {
          TodayTile.companion => showCompanion ? CompanionCard(todayLog: todayLog) : null,
          TodayTile.countdown => snapshot.pregnancy != null
              ? _PregnancyCard(snapshot: snapshot)
              : _CountdownCard(snapshot: snapshot, todayLog: todayLog),
          TodayTile.phase => !snapshot.hasData
              ? null
              : showPhases
                  ? _PhaseCard(snapshot: snapshot, showFertility: settings.displayFertileChance)
                  : _InfoCard(text: l10n.today_phasesHidden),
          TodayTile.bag => discrete || !snapshot.hasData || snapshot.pregnancy != null || !bag.isReady
              ? null
              : _BagTile(snapshot: snapshot),
          TodayTile.mood => _MoodCard(todayLog: todayLog),
          TodayTile.pattern => patterns.isEmpty ? null : _PatternTile(pattern: patterns.first),
          TodayTile.quickLog => _QuickLogCard(todayLog: todayLog),
        };

    // Half tiles sit side by side when two of them follow each other.
    final visible = <(TodayTile, Widget)>[
      for (final t in settings.todayTiles)
        if (!settings.hiddenTodayTiles.contains(t))
          if (build(t) case final Widget w) (t, w),
    ];
    final rows = <Widget>[];
    for (var i = 0; i < visible.length; i++) {
      final (tile, widget) = visible[i];
      // the info card that replaces hidden phases needs the full width
      final half = tile.half && !(tile == TodayTile.phase && !showPhases);
      final next = i + 1 < visible.length ? visible[i + 1] : null;
      final nextHalf = next != null && next.$1.half && !(next.$1 == TodayTile.phase && !showPhases);
      if (half && nextHalf) {
        rows.add(IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Expanded(child: widget), const SizedBox(width: 10), Expanded(child: next.$2)],
          ),
        ));
        i++;
      } else {
        rows.add(widget);
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        for (final r in rows) ...[r, const SizedBox(height: 12)],
        Center(
          child: TextButton.icon(
            icon: const Icon(Icons.dashboard_customize_outlined, size: 18),
            label: Text(l10n.today_customize),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TodayCustomizeScreen()),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.today_disclaimer,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

/// "Pack your bag": progress of the checklist, highlighted when the period is near.
class _BagTile extends StatelessWidget {
  const _BagTile({required this.snapshot});

  final CycleSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final bag = context.watch<BagService>();
    final items = bag.items ?? const <String>[];
    final days = snapshot.daysUntilNextPeriod;
    final soon = !snapshot.isPeriodOngoing && days != null && days >= 0 && days <= 2;
    final done = bag.doneCount;
    return RuyaCard(
      color: soon ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainer,
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BagScreen())),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.backpack_outlined, size: 20),
              const SizedBox(width: 6),
              Expanded(child: Text(l10n.bag_title, style: theme.textTheme.titleSmall)),
            ],
          ),
          const SizedBox(height: 8),
          Text(l10n.bag_ready(done, items.length), style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: items.isEmpty ? 0 : done / items.length, minHeight: 6),
          ),
          if (soon) ...[
            const SizedBox(height: 8),
            Text(l10n.bag_soon(days), style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// The clearest thing that repeated across the user's own cycles.
class _PatternTile extends StatelessWidget {
  const _PatternTile({required this.pattern});

  final CyclePattern pattern;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return RuyaCard(
      color: theme.colorScheme.surfaceContainer,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.pattern_title, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(pattern.title(l10n), style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(pattern.sentence(l10n), style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          PatternDots(pattern: pattern),
        ],
      ),
    );
  }
}

Future<void> _quick(BuildContext context, LogDay Function(LogDay) update) {
  context.read<FeedbackService>().select();
  return context.read<LogUIController>().quickUpdate(
        context: context,
        date: DateTime.now(),
        update: update,
      );
}

Future<void> _openFullLog(BuildContext context) {
  return context.read<LogUIController>().handleCreateNewLog(
        context: context,
        selectedDate: DateTime.now(),
        symptomService: context.read(),
        age: context.read<UserService>().age,
      );
}

class _CountdownCard extends StatelessWidget {
  const _CountdownCard({required this.snapshot, required this.todayLog});

  final CycleSnapshot snapshot;
  final LogDay? todayLog;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (!snapshot.hasData) {
      return RuyaCard(
        color: scheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.today_noData, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(l10n.today_noDataBody),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.water_drop),
                label: Text(l10n.today_startPeriod),
                onPressed: () => _quick(context, (log) => log.copyWith(flow: FlowRate.medium)),
              ),
            ],
          ),
        ),
      );
    }

    final days = snapshot.daysUntilNextPeriod!;
    final bc = snapshot.onBirthControl;
    final String headline;
    if (snapshot.isPeriodOngoing) {
      headline = l10n.today_periodDay(snapshot.menstruationDay);
    } else if (days > 0) {
      headline = bc ? l10n.today_bleedIn(days) : l10n.today_periodIn(days);
    } else if (days == 0) {
      headline = bc ? l10n.today_bleedToday : l10n.today_periodToday;
    } else {
      headline = bc ? l10n.today_bleedLate(-days) : l10n.today_periodLate(-days);
    }
    final expected = DateFormat.MMMMd(l10n.localeName).format(snapshot.cycle!.nextPeriodStart);
    final isPeriodToday = todayLog != null && todayLog!.flow != FlowRate.none;

    return RuyaCard(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.water_drop_outlined, color: scheme.onPrimaryContainer),
                const SizedBox(width: 8),
                _EstimateTag(label: l10n.today_estimateTag),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              headline,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!snapshot.isPeriodOngoing) ...[
              const SizedBox(height: 4),
              Text(
                l10n.today_expectedOn(expected),
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onPrimaryContainer),
              ),
            ],
            if (snapshot.basedOnDefaults) ...[
              const SizedBox(height: 8),
              Text(
                l10n.today_basedOnDefaults,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onPrimaryContainer),
              ),
            ],
            if (!snapshot.isPeriodOngoing && !isPeriodToday && days <= 3) ...[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.water_drop),
                label: Text(l10n.today_startPeriod),
                onPressed: () => _quick(context, (log) => log.copyWith(flow: FlowRate.medium)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PregnancyCard extends StatelessWidget {
  const _PregnancyCard({required this.snapshot});

  final CycleSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final due = DateFormat.yMMMMd(l10n.localeName).format(snapshot.estimatedDueDate!);
    final progress = (snapshot.pregnancyDays! / CycleSnapshot.pregnancyLengthDays).clamp(0.0, 1.0);

    return RuyaCard(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.pregnant_woman, color: scheme.onTertiaryContainer),
              const SizedBox(width: 8),
              _EstimateTag(label: l10n.today_estimateTag),
            ]),
            const SizedBox(height: 12),
            Text(
              l10n.pregnancy_status(snapshot.pregnancyWeek!, snapshot.pregnancyDayOfWeek!),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: scheme.onTertiaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(l10n.pregnancy_dueDate(due), style: TextStyle(color: scheme.onTertiaryContainer)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: progress, minHeight: 8),
            ),
            const SizedBox(height: 10),
            Text(
              '${l10n.pregnancy_pausedNote} ${l10n.pregnancy_disclaimer}',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onTertiaryContainer),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhaseCard extends StatelessWidget {
  const _PhaseCard({required this.snapshot, required this.showFertility});

  final CycleSnapshot snapshot;
  final bool showFertility;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final phase = snapshot.phase;
    final chips = <Widget>[
      if (showFertility && snapshot.isOvulationDay)
        _StatusChip(icon: Icons.egg_outlined, label: l10n.today_ovulationChip)
      else if (showFertility && snapshot.isInFertileWindow)
        _StatusChip(icon: Icons.favorite_outline, label: l10n.today_fertileChip),
      if (snapshot.isInPmsWindow) _StatusChip(icon: Icons.cloud_outlined, label: l10n.today_pmsChip),
    ];

    return RuyaCard(
      color: theme.colorScheme.surfaceContainerHigh,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: Icon(phase.icon),
            title: Text(phase.getPhaseName(l10n)),
            content: Text('${phase.getDescription(l10n)}\n\n${l10n.today_disclaimer}'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.ok))],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: phase.color.withValues(alpha: 0.25),
                      child: Icon(phase.icon, size: 18, color: theme.colorScheme.onSurface),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.today_phaseToday(phase.getPhaseName(l10n)),
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (snapshot.cycleDay != null) ...[
                      const SizedBox(height: 2),
                      Text(l10n.today_cycleDay(snapshot.cycleDay!), style: theme.textTheme.bodySmall),
                    ],
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 6, children: chips),
                    ],
                  ],
                ),
              ),
              Icon(Icons.info_outline, size: 18, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoodCard extends StatelessWidget {
  const _MoodCard({required this.todayLog});

  final LogDay? todayLog;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final selected = todayLog?.moods ?? const <Mood>[];

    return RuyaCard(
      color: theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.today_moodTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: Mood.values.map((mood) {
                final isSelected = selected.contains(mood);
                return FilterChip(
                  showCheckmark: false,
                  avatar: Text(mood.emoji),
                  label: Text(mood.getDisplayName(l10n)),
                  selected: isSelected,
                  onSelected: (_) => _quick(context, (log) {
                    final moods = List<Mood>.of(log.moods);
                    if (isSelected) {
                      moods.remove(mood);
                    } else if (moods.length < Mood.maxSelected) {
                      moods.add(mood);
                    }
                    return log.copyWith(moods: moods);
                  }),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickLogCard extends StatelessWidget {
  const _QuickLogCard({required this.todayLog});

  final LogDay? todayLog;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final flow = todayLog?.flow ?? FlowRate.none;
    final pain = todayLog?.painLevel;
    final symptomCount = todayLog?.symptoms.length ?? 0;

    return RuyaCard(
      color: theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.today_quickLog, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(l10n.flow, style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: FlowRate.periodFlows.map((f) {
                return ChoiceChip(
                  label: Text(f.getDisplayName(l10n)),
                  selected: flow == f,
                  onSelected: (v) => _quick(context, (log) => log.copyWith(flow: v ? f : FlowRate.none)),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Text(l10n.painLevel_title, style: theme.textTheme.labelLarge),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: PainLevel.values.map((level) {
                final isSelected = pain == level.intValue;
                return IconButton(
                  icon: Icon(level.icon),
                  iconSize: 32,
                  tooltip: level.getDisplayName(l10n),
                  color: isSelected ? level.color : theme.colorScheme.onSurfaceVariant,
                  onPressed: () => _quick(
                    context,
                    (log) => isSelected
                        ? log.copyWith(clearPainLevel: true)
                        : log.copyWith(painLevel: level.intValue),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.healing_outlined, size: 18),
                    label: Text(l10n.today_symptomsCount(symptomCount)),
                    onPressed: () => _openFullLog(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.edit_note, size: 18),
                    label: Text(l10n.today_fullLog),
                    onPressed: () => _openFullLog(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return RuyaCard(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: ListTile(leading: const Icon(Icons.info_outline), title: Text(text)),
    );
  }
}

class _EstimateTag extends StatelessWidget {
  const _EstimateTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.onPrimaryContainer.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onPrimaryContainer)),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSecondaryContainer),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
