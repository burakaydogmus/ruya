import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ruya/coordinators/data_refresh_coordinator.dart';
import 'package:ruya/cycle/life_stage.dart';
import 'package:ruya/l10n/app_localizations.dart';
import 'package:ruya/services/period_service.dart';
import 'package:ruya/services/settings_service.dart';

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

Future<DateTime?> _pickDate(BuildContext context, {required DateTime initial, required String help, DateTime? first}) {
  final today = _today();
  return showDatePicker(
    context: context,
    initialDate: initial.isAfter(today) ? today : initial,
    firstDate: first ?? DateTime(2000),
    lastDate: today,
    helpText: help,
  );
}

/// Recomputes predictions, notifications and the widget after a mode change.
void _refresh(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  context.read<PeriodService>().forceNotificationReschedule();
  context.read<DataRefreshCoordinator>().onLogsChanged(l10n);
}

/// "I use hormonal birth control" switch with start/end dates (birth control mode).
class BirthControlModeTile extends StatelessWidget {
  const BirthControlModeTile({super.key});

  Future<void> _toggle(BuildContext context, bool enable) async {
    final settings = context.read<SettingsService>();
    final l10n = AppLocalizations.of(context)!;
    final active = settings.birthControlSpans.where((s) => s.isOngoing).firstOrNull;
    final date = await _pickDate(
      context,
      initial: _today(),
      first: enable ? null : active?.start,
      help: enable ? l10n.birthControl_pickStart : l10n.birthControl_pickEnd,
    );
    if (date == null || !context.mounted) return;
    if (enable) {
      await settings.startHormonalBirthControl(date);
    } else {
      await settings.stopHormonalBirthControl(date);
    }
    if (context.mounted) _refresh(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsService>();
    final active = settings.birthControlSpans.where((s) => s.isOngoing).firstOrNull;
    return SwitchListTile(
      secondary: const Icon(Icons.medication_liquid_outlined),
      title: Text(l10n.birthControl_mode),
      subtitle: Text(
        active == null
            ? l10n.birthControl_modeSubtitle
            : '${l10n.birthControl_since(DateFormat.yMMMd(l10n.localeName).format(active.start))}\n${l10n.birthControl_modeSubtitle}',
      ),
      isThreeLine: true,
      value: active != null,
      onChanged: (v) => _toggle(context, v),
    );
  }
}

/// Settings > Pregnancy mode.
class PregnancyModeScreen extends StatelessWidget {
  const PregnancyModeScreen({super.key});

  Future<void> _start(BuildContext context) async {
    final settings = context.read<SettingsService>();
    final l10n = AppLocalizations.of(context)!;
    final lastPeriod = context.read<PeriodService>().lastPeriod?.startDate;
    final lmp = await _pickDate(context, initial: lastPeriod ?? _today(), help: l10n.pregnancy_pickLmp);
    if (lmp == null || !context.mounted) return;
    await settings.startPregnancy(lmp);
    if (!context.mounted) return;
    _refresh(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.pregnancy_started)));
  }

  Future<void> _end(BuildContext context, DateSpan active) async {
    final settings = context.read<SettingsService>();
    final l10n = AppLocalizations.of(context)!;
    final end = await _pickDate(context, initial: _today(), first: active.start, help: l10n.pregnancy_pickEnd);
    if (end == null || !context.mounted) return;
    await settings.endPregnancy(end);
    if (!context.mounted) return;
    _refresh(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.pregnancy_ended)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final settings = context.watch<SettingsService>();
    final active = settings.activePregnancy;
    final past = settings.pregnancySpans.where((s) => !s.isOngoing).toList().reversed.toList();
    final fmt = DateFormat.yMMMd(l10n.localeName);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pregnancy_title)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l10n.pregnancy_intro),
          ),
          const SizedBox(height: 16),
          if (active == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton.icon(
                icon: const Icon(Icons.pregnant_woman),
                label: Text(l10n.pregnancy_start),
                onPressed: () => _start(context),
              ),
            )
          else ...[
            ListTile(
              leading: const Icon(Icons.event),
              title: Text(l10n.pregnancy_lmp),
              subtitle: Text(fmt.format(active.start)),
            ),
            ListTile(
              leading: const Icon(Icons.child_friendly_outlined),
              title: Text(l10n.pregnancy_dueDate(
                fmt.format(DateTime(active.start.year, active.start.month, active.start.day + 280)),
              )),
              subtitle: Text(l10n.pregnancy_disclaimer),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.stop_circle_outlined),
                label: Text(l10n.pregnancy_end),
                onPressed: () => _end(context, active),
              ),
            ),
          ],
          if (past.isNotEmpty) ...[
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(l10n.pregnancy_history, style: theme.textTheme.titleSmall),
            ),
            for (final p in past)
              ListTile(
                leading: const Icon(Icons.history),
                title: Text('${fmt.format(p.start)} – ${fmt.format(p.end!)}'),
              ),
          ],
        ],
      ),
    );
  }
}
