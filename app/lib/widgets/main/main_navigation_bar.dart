import 'package:flutter/material.dart';
import 'package:ruya/l10n/app_localizations.dart';

/// Fixed five-destination navigation. Optional trackers (pill, LARC, sanitary,
/// sex) live inside the Log destination instead of adding more tabs.
class MainNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onDestinationSelected;

  const MainNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      indicatorColor: Theme.of(context).colorScheme.primaryContainer,
      destinations: <Widget>[
        NavigationDestination(
          selectedIcon: const Icon(Icons.wb_twilight),
          icon: const Icon(Icons.wb_twilight_outlined),
          label: l10n.navBar_today,
        ),
        NavigationDestination(
          selectedIcon: const Icon(Icons.calendar_month),
          icon: const Icon(Icons.calendar_month_outlined),
          label: l10n.navBar_calendar,
        ),
        NavigationDestination(
          selectedIcon: const Icon(Icons.book),
          icon: const Icon(Icons.book_outlined),
          label: l10n.navBar_log,
        ),
        NavigationDestination(
          selectedIcon: const Icon(Icons.insights),
          icon: const Icon(Icons.insights_outlined),
          label: l10n.navBar_insights,
        ),
        NavigationDestination(
          selectedIcon: const Icon(Icons.settings),
          icon: const Icon(Icons.settings_outlined),
          label: l10n.navBar_settings,
        ),
      ],
    );
  }
}
