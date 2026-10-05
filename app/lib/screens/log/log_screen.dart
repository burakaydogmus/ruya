import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ruya/controllers/log_reversible_contraceptive_ui_controller.dart';
import 'package:ruya/controllers/log_sanitary_ui_controller.dart';
import 'package:ruya/controllers/log_sex_ui_controller.dart';
import 'package:ruya/controllers/log_ui_controller.dart';
import 'package:ruya/l10n/app_localizations.dart';
import 'package:ruya/screens/dashboards/logs/widgets/list_view.dart';
import 'package:ruya/screens/dashboards/pills_screen.dart';
import 'package:ruya/screens/dashboards/reversible_contraceptive/reversible_contraceptive_screen.dart';
import 'package:ruya/screens/dashboards/sanitary_screen.dart';
import 'package:ruya/screens/dashboards/sex/sex_screen.dart';
import 'package:ruya/services/settings_service.dart';
import 'package:ruya/services/user_service.dart';

/// Log history plus entry points to the optional Menstrudel trackers
/// (pill, reversible contraceptive, sanitary products, sexual activity).
/// Trackers are shown only when enabled in settings, keeping the bottom
/// navigation at five destinations.
class LogScreen extends StatelessWidget {
  const LogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsService>();

    final trackers = <_Tracker>[
      if (settings.isPillNavEnabled)
        _Tracker(
          icon: Icons.medication_outlined,
          title: l10n.mainScreen_pillsPageTitle,
          page: const PillsScreen(),
        ),
      if (settings.isReversibleContraceptiveNavEnabled)
        _Tracker(
          icon: Icons.verified_user_outlined,
          title: l10n.mainScreen_reversibleContraceptivesPageTitle,
          page: const ReversibleContraceptiveScreen(),
          fab: (ctx) => ctx
              .read<LogReversibleContraceptiveUIController>()
              .handleCreateNewReversibleContraceptiveLog(context: ctx),
          fabTooltip: l10n.fabToolTip_reversibleContraceptive,
        ),
      if (settings.isSanitaryNavEnabled)
        _Tracker(
          icon: Icons.water_drop_outlined,
          title: l10n.mainScreen_sanitaryPageTitle,
          page: const SanitaryScreen(),
          fab: (ctx) => ctx.read<LogSanitaryUIController>().handleCreateNewSanitaryLog(context: ctx),
          fabTooltip: l10n.fabToolTip_sanitary,
        ),
      if (settings.isSexActivityNavEnabled)
        _Tracker(
          icon: Icons.favorite_border_rounded,
          title: l10n.mainSceen_sexActivityPageTitle,
          page: const SexScreen(),
          fab: (ctx) => ctx.read<LogSexUIController>().handleCreateNewSexLog(context: ctx),
          fabTooltip: l10n.fabToolTip_sexActivity,
        ),
    ];

    return Column(
      children: [
        if (trackers.isNotEmpty)
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              itemCount: trackers.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final t = trackers[i];
                return ActionChip(
                  avatar: Icon(t.icon, size: 18),
                  label: Text(t.title),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => _TrackerHost(tracker: t)),
                  ),
                );
              },
            ),
          ),
        Expanded(
          child: PeriodListView(
            onLogTapped: (log) => context.read<LogUIController>().handleEditLog(
                  context: context,
                  log: log,
                  symptomService: context.read(),
                  age: context.read<UserService>().age,
                ),
          ),
        ),
      ],
    );
  }
}

class _Tracker {
  const _Tracker({
    required this.icon,
    required this.title,
    required this.page,
    this.fab,
    this.fabTooltip,
  });

  final IconData icon;
  final String title;
  final Widget page;
  final void Function(BuildContext context)? fab;
  final String? fabTooltip;
}

class _TrackerHost extends StatelessWidget {
  const _TrackerHost({required this.tracker});

  final _Tracker tracker;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tracker.title)),
      body: tracker.page,
      floatingActionButton: tracker.fab == null
          ? null
          : Builder(
              builder: (ctx) => FloatingActionButton(
                tooltip: tracker.fabTooltip,
                onPressed: () => tracker.fab!(ctx),
                child: const Icon(Icons.add),
              ),
            ),
    );
  }
}
