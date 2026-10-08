import 'package:flutter/material.dart';
import 'package:ruya/l10n/app_localizations.dart';

import 'package:ruya/screens/settings/sections/appearance_settings_screen.dart';
import 'package:ruya/screens/settings/sections/birth_control_settings_screen.dart';
import 'package:ruya/screens/settings/sections/log_settings_screen.dart';
import 'package:ruya/screens/settings/sections/cycle_notifications_and_predictions_screen.dart';
import 'package:ruya/screens/settings/sections/data_settings_screen.dart';
import 'package:ruya/screens/settings/sections/privacy_settings_screen.dart';
import 'package:ruya/screens/settings/sections/external_import_screen.dart';
import 'package:ruya/screens/settings/sections/clinical_report_screen.dart';
import 'package:ruya/screens/settings/sections/life_stage_widgets.dart';
import 'package:ruya/screens/settings/sections/widget_settings_screen.dart';
import 'package:ruya/screens/settings/sections/preferences_settings_screen.dart';
import 'package:ruya/screens/settings/sections/user_settings_screen.dart';
import 'package:provider/provider.dart';
import 'package:ruya/services/settings_service.dart';


class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return ListView(
      children: [
        _SettingsSectionButton(
          title: l10n.settingsScreen_userProfile,
          icon: Icons.person_outline,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileSettingsScreen()),
            );
          },
        ),

        _SettingsSectionButton(
          title: l10n.settingsScreen_preferences,
          icon: Icons.tune_outlined,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PreferencesSettingsScreen()),
            );
          },
        ),
        _SettingsSectionButton(
          title: l10n.settingsScreen_appearance,
          icon: Icons.palette_outlined,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AppearanceSettingsScreen()),
            );
          },
        ),
        _SettingsSectionButton(
          title: l10n.settingsScreen_widget,
          icon: Icons.widgets_outlined,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const WidgetSettingsScreen()),
            );
          },
        ),
        _SettingsSectionButton(
          title: l10n.settingsScreen_privacy,
          icon: Icons.shield_outlined,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PrivacySettingsScreen()),
            );
          },
        ),
        _SettingsSectionButton(
          title: l10n.settingsScreen_LoggingScreen,
          icon: Icons.book_outlined,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => LogSettingsScreen(logsRepo: context.read())),
            );
          },
        ),
        _SettingsSectionButton(
          title: l10n.settingsScreen_cycleNotificationsAndPredictions,
          icon: Icons.water_drop_outlined,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CycleNotificationsAndPredictionsScreen()),
            );
          },
        ),
        _SettingsSectionButton(
          title: l10n.settingsScreen_birthControl,
          icon: Icons.medical_information_outlined,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const BirthControlSettingsScreen()),
            );
          },
        ),
        _SettingsSectionButton(
          title: l10n.pregnancy_title,
          icon: Icons.pregnant_woman_outlined,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PregnancyModeScreen()),
            );
          },
        ),
        _SettingsSectionButton(
          title: l10n.settingsScreen_dataManagement,
          icon: Icons.storage_outlined,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DataSettingsScreen()),
            );
          },
        ),
        _SettingsSectionButton(
          title: l10n.reportScreen_title,
          icon: Icons.picture_as_pdf_outlined,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ClinicalReportScreen(
                  allowIntimateFields: context.read<SettingsService>().showIntimateFields,
                ),
              ),
            );
          },
        ),
        _SettingsSectionButton(
          title: l10n.settingsScreen_importOtherApps,
          icon: Icons.move_to_inbox_outlined,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ExternalImportScreen()),
            );
          },
        ),
      ],
    );
  }
}

class _SettingsSectionButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _SettingsSectionButton({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios),
      onTap: onTap,
    );
  }
}