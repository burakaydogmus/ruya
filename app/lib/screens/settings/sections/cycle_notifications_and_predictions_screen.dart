import 'package:ruya/utils/constants.dart';
import 'package:ruya/coordinators/data_refresh_coordinator.dart';
import 'package:flutter/material.dart';
import 'package:ruya/l10n/app_localizations.dart';
import 'package:ruya/services/settings_service.dart';
import 'package:provider/provider.dart';

class CycleNotificationsAndPredictionsScreen extends StatelessWidget {
  const CycleNotificationsAndPredictionsScreen({super.key});

  Future<void> _selectPeriodReminderTime(BuildContext context) async {
    final settingsService = context.read<SettingsService>();
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: settingsService.notificationTime,
    );

    if (pickedTime != null && pickedTime != settingsService.notificationTime) {
      await settingsService.setNotificationTime(pickedTime);
    }
  }

  Future<void> _selectOverduePeriodReminderTime(BuildContext context) async {
    final settingsService = context.read<SettingsService>();
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: settingsService.periodOverdueNotificationTime,
    );

    if (pickedTime != null && pickedTime != settingsService.periodOverdueNotificationTime) {
      await settingsService.setPeriodOverdueNotificationTime(pickedTime);
    }
  }

  Future<void> _selectFertileWindowReminderTime(BuildContext context) async {
    final settingsService = context.read<SettingsService>();
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: settingsService.fertileWindowReminderTime,
    );

    if (pickedTime != null && pickedTime != settingsService.fertileWindowReminderTime) {
      await settingsService.setFertileWindowReminderTime(pickedTime);
    }
  }

  Future<void> _selectOvulationReminderTime(BuildContext context) async {
    final settingsService = context.read<SettingsService>();
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: settingsService.fertileWindowReminderTime,
    );

    if (pickedTime != null && pickedTime != settingsService.fertileWindowReminderTime) {
      await settingsService.setOvulationReminderTime(pickedTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settingsService = context.watch<SettingsService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsScreen_cycleNotificationsAndPredictions),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text(l10n.settingsScreen_enablePhasePredictions),
            value: settingsService.isNaturalCycle ? settingsService.arePhasePredictionsEnabled : false,
            onChanged: settingsService.isNaturalCycle 
              ? (bool value) {
                  context.read<SettingsService>().setPhasePredictions(value);
                }
              : null,
          ),
          if (settingsService.arePhasePredictionsEnabled && settingsService.isNaturalCycle) ...[
            CheckboxListTile(
              title: Text(l10n.settingsScreen_displayFertileChance),
              value: settingsService.displayFertileChance,
              onChanged: (val) => settingsService.setDisplayFertileChance(val ?? false),
            ),
            CheckboxListTile(
              title: Text(l10n.settingsScreen_displayFertileWindowOnCalendar),
              value: settingsService.displayFertileWindowOnCalendar,
              onChanged: (val) => settingsService.setDisplayFertileWindowOnCalendar(val ?? false),
            ),
            CheckboxListTile(
              title: Text(l10n.cycleSettings_showPms),
              value: settingsService.showPmsWindow,
              onChanged: (val) async {
                await settingsService.setShowPmsWindow(val ?? false);
                if (context.mounted) _refreshPredictions(context);
              },
            ),
            _StepperTile(
              title: l10n.cycleSettings_lutealLength,
              subtitle: l10n.cycleSettings_lutealLengthHint,
              value: settingsService.lutealPhaseLength,
              min: kMinLutealPhaseLength,
              max: kMaxLutealPhaseLength,
              onChanged: (v) async {
                await settingsService.setLutealPhaseLength(v);
                if (context.mounted) _refreshPredictions(context);
              },
            ),
            if (settingsService.showPmsWindow)
              _StepperTile(
                title: l10n.cycleSettings_pmsDays,
                subtitle: l10n.cycleSettings_pmsDaysHint,
                value: settingsService.pmsDays,
                min: kMinPmsDays,
                max: kMaxPmsDays,
                onChanged: (v) async {
                  await settingsService.setPmsDays(v);
                  if (context.mounted) _refreshPredictions(context);
                },
              ),
          ],
          const Divider(),
          SwitchListTile(
              title: Text(l10n.settingsScreen_cycleNotificationsAndPredictions),
              value: settingsService.arePeriodDueNotificationsEnabled,
              onChanged: (bool value) {
                context.read<SettingsService>().setNotificationsEnabled(value);
              },
            ),
          if (settingsService.arePeriodDueNotificationsEnabled) ...[
            ListTile(
              title: Text(l10n.settingsScreen_remindMeBefore),
              trailing: DropdownButton<int>(
                value: settingsService.notificationDays,
                items: [1, 2, 3].map((int days) {
                  return DropdownMenuItem<int>(
                    value: days,
                    child: Text(l10n.dayCount(days)),
                  );
                }).toList(),
                onChanged: (int? newDays) {
                  if (newDays != null) {
                    context.read<SettingsService>().setNotificationDays(newDays);
                  }
                },
              ),
            ),
            ListTile(
              title: Text(l10n.settingsScreen_notificationTime),
              trailing: Text(
                settingsService.notificationTime.format(context),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () => _selectPeriodReminderTime(context),
            ),
          ],
          const Divider(),
          SwitchListTile(
            title: Text(l10n.settingsScreen_overduePeriodReminder),
            value: settingsService.arePeriodOverdueNotificationsEnabled,
            onChanged: (bool value) {
              context.read<SettingsService>().setPeriodOverdueNotificationsEnabled(value);
            },
          ),
          if (settingsService.arePeriodOverdueNotificationsEnabled) ...[
            ListTile(
              title: Text(l10n.settingsScreen_remindMeAfter),
              trailing: DropdownButton<int>(
                value: settingsService.periodOverdueNotificationDays,
                items: [1, 2, 3].map((int days) {
                  return DropdownMenuItem<int>(
                    value: days,
                    child: Text(l10n.dayCount(days)),
                  );
                }).toList(),
                onChanged: (int? newDays) {
                  if (newDays != null) {
                    context
                        .read<SettingsService>()
                        .setPeriodOverdueNotificationDays(newDays);
                  }
                },
              ),
            ),
            ListTile(
              title: Text(l10n.settingsScreen_notificationTime),
              trailing: Text(
                settingsService.periodOverdueNotificationTime.format(context),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () => _selectOverduePeriodReminderTime(context),
            ),
          ],
          const Divider(),
          SwitchListTile(
            title: Text(l10n.settingsScreen_fertileWindowReminder),
            value: settingsService.areFertileWindowNotificationsEnabled,
            onChanged: (bool value) {
              context.read<SettingsService>().setFertileWindowNotificationsEnabled(value);
            },
          ),
          if (settingsService.areFertileWindowNotificationsEnabled) ...[
            ListTile(
              title: Text(l10n.settingsScreen_remindMeBefore),
              trailing: DropdownButton<int>(
                value: settingsService.fertileWindowReminderDaysBefore,
                items: [1, 2, 3].map((int days) {
                  return DropdownMenuItem<int>(
                    value: days,
                    child: Text(l10n.dayCount(days)),
                  );
                }).toList(),
                onChanged: (int? newDays) {
                  if (newDays != null) {
                    context.read<SettingsService>().setFertileWindowReminderDaysBefore(newDays);
                  }
                },
              ),
            ),
            ListTile(
              title: Text(l10n.settingsScreen_notificationTime),
              trailing: Text(
                settingsService.fertileWindowReminderTime.format(context),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () => _selectFertileWindowReminderTime(context),
            ),
          ],
          const Divider(),
          SwitchListTile(
            title: Text(l10n.settingsScreen_ovulationDayReminder),
            value: settingsService.areOvulationNotificationsEnabled,
            onChanged: (bool value) {
              context.read<SettingsService>().setOvulationNotificationsEnabled(value);
            },
          ),
          if (settingsService.areOvulationNotificationsEnabled) ...[
            ListTile(
              title: Text(l10n.settingsScreen_remindMeBefore),
              trailing: DropdownButton<int>(
                value: settingsService.ovulationReminderDays,
                items: [1, 2, 3].map((int days) {
                  return DropdownMenuItem<int>(
                    value: days,
                    child: Text(l10n.dayCount(days)),
                  );
                }).toList(),
                onChanged: (int? newDays) {
                  if (newDays != null) {
                    context.read<SettingsService>().setOvulationReminderDaysBefore(newDays);
                  }
                },
              ),
            ),
            ListTile(
              title: Text(l10n.settingsScreen_notificationTime),
              trailing: Text(
                settingsService.ovulationReminderTime.format(context),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () => _selectOvulationReminderTime(context),
            ),
          ],
        ],
      ),
    );
  }
}

/// Recomputes predictions after a cycle setting changed.
void _refreshPredictions(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  context.read<DataRefreshCoordinator>().onLogsChanged(l10n);
}

class _StepperTile extends StatelessWidget {
  const _StepperTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          SizedBox(width: 28, child: Text('$value', textAlign: TextAlign.center)),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}
