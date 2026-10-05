import 'package:flutter/material.dart';
import 'package:ruya/controllers/log_ui_controller.dart';
import 'package:ruya/screens/calendar/calendar_screen.dart';
import 'package:ruya/screens/dashboards/logs/widgets/tabs/logs_screen_insights_tab.dart';
import 'package:ruya/screens/log/log_screen.dart';
import 'package:ruya/screens/settings/settings_screen.dart';
import 'package:ruya/screens/today/today_screen.dart';
import 'package:ruya/services/user_service.dart';
import 'package:ruya/services/settings_service.dart';
import 'package:ruya/widgets/main/main_navigation_bar.dart';
import 'package:ruya/widgets/main/app_bar.dart';
import 'package:ruya/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

/// RUYA main navigation: Today · Calendar · Log · Insights · Settings.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildLogDayFab(BuildContext context, AppLocalizations l10n) {
    return FloatingActionButton(
      key: const ValueKey('log_day_fab'),
      tooltip: l10n.fabToolTip_logs,
      onPressed: () {
        context.read<LogUIController>().handleCreateNewLog(
              context: context,
              selectedDate: DateTime.now(),
              symptomService: context.read(),
              age: context.read<UserService>().age,
            );
      },
      child: const Icon(Icons.add),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final discrete = context.select<SettingsService, bool>((s) => s.isDiscreteModeEnabled);

    final pages = <Widget>[
      const TodayScreen(),
      const CalendarScreen(),
      const LogScreen(),
      const LogsScreenInsightsTab(),
      const SettingsScreen(),
    ];

    final titles = <String>[
      discrete ? l10n.discrete_appName : 'RUYA',
      l10n.navBar_calendar,
      l10n.navBar_log,
      l10n.navBar_insights,
      l10n.mainScreen_settingsPageTitle,
    ];

    final fabs = <Widget?>[
      null,
      _buildLogDayFab(context, l10n),
      _buildLogDayFab(context, l10n),
      null,
      null,
    ];

    final index = _selectedIndex.clamp(0, pages.length - 1);

    return Scaffold(
      appBar: TopAppBar(titleText: titles[index]),
      body: pages[index],
      bottomNavigationBar: MainNavigationBar(
        selectedIndex: index,
        onDestinationSelected: _onItemTapped,
      ),
      floatingActionButton: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
        child: fabs[index] == null ? const SizedBox.shrink(key: ValueKey('no_fab')) : KeyedSubtree(key: ValueKey('fab_$index'), child: fabs[index]!),
      ),
    );
  }
}
