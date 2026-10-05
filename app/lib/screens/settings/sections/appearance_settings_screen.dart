import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import 'package:ruya/l10n/app_localizations.dart';
import 'package:ruya/models/themes/app_theme_mode_enum.dart';
import 'package:ruya/notifiers/theme_notifier.dart';

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  Future<void> _showThemeModePicker(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final themeNotifier = context.read<ThemeNotifier>();
    
    final AppThemeMode? result = await showDialog<AppThemeMode>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text(l10n.settingsScreen_appTheme),
          children: AppThemeMode.values.map((mode) {
            return RadioListTile<AppThemeMode>(
              title: Text(mode.getDisplayName(l10n)),
              value: mode,
              groupValue: themeNotifier.themeMode,
              onChanged: (AppThemeMode? value) => Navigator.of(context).pop(value),
            );
          }).toList(),
        );
      },
    );

    if (result != null && result != themeNotifier.themeMode) {
      themeNotifier.setThemeMode(result);
    }
  }

  void _showColorPicker(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeNotifier = context.read<ThemeNotifier>();
  
    Color pickerColor = themeNotifier.themeColor; 

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(l10n.settingsScreen_pickAColor),
          content: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return ColorPicker(
                  pickerColor: pickerColor,
                  onColorChanged: (Color color) {
                    setDialogState(() => pickerColor = color);
                  },
                  pickerAreaHeightPercent: 0.8,
                );
              },
            ),
          ),
          actions: <Widget>[
            ElevatedButton(
              child: Text(l10n.select),
              onPressed: () {
                themeNotifier.setColor(pickerColor);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeNotifier = context.watch<ThemeNotifier>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsScreen_appearance),
      ),
      body: ListView(
        children: [
          ListTile(
            title: Text(l10n.settingsScreen_appTheme),
            subtitle: Text(themeNotifier.themeMode.getDisplayName(l10n)),
            onTap: () => _showThemeModePicker(context),
          ),
          SwitchListTile(
            title: Text(l10n.settingsScreen_dynamicTheme),
            subtitle: Text(l10n.settingsScreen_useWallpaperColors),
            value: themeNotifier.isDynamicEnabled,
            onChanged: (bool value) {
              context.read<ThemeNotifier>().setDynamicThemeEnabled(value);
            },
          ),
          if (!themeNotifier.isDynamicEnabled)
            ListTile(
              title: Text(l10n.settingsScreen_themeColor),
              trailing: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: themeNotifier.themeColor,
                  shape: BoxShape.circle,
                ),
              ),
              onTap: () => _showColorPicker(context),
            ),
        ],
      ),
    );
  }
}