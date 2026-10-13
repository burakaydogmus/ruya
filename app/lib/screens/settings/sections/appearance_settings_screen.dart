import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import 'package:ruya/companion/companion_service.dart';
import 'package:ruya/l10n/app_localizations.dart';
import 'package:ruya/models/themes/app_theme_mode_enum.dart';
import 'package:ruya/notifiers/theme_notifier.dart';
import 'package:ruya/screens/today/today_customize_screen.dart';
import 'package:ruya/security/discrete_mode.dart';
import 'package:ruya/services/feedback_service.dart';
import 'package:ruya/services/settings_service.dart';
import 'package:ruya/theme/app_style.dart';
import 'package:ruya/widgets/effects/confetti.dart';

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
    final theme = Theme.of(context);
    final klasik = themeNotifier.style == AppStyle.klasik;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsScreen_appearance),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(l10n.appearance_stylePack, style: theme.textTheme.titleMedium),
          ),
          for (final style in AppStyle.values)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: StylePackTile(
                style: style,
                selected: themeNotifier.style == style,
                klasikColor: themeNotifier.themeColor,
                onTap: () {
                  if (themeNotifier.style == style) return;
                  themeNotifier.setStyle(style);
                  context.read<FeedbackService>().celebrate();
                  Confetti.burst(context);
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              l10n.appearance_stylePackHint,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          ListTile(
            title: Text(l10n.settingsScreen_appTheme),
            subtitle: Text(themeNotifier.themeMode.getDisplayName(l10n)),
            onTap: () => _showThemeModePicker(context),
          ),
          if (klasik)
            SwitchListTile(
              title: Text(l10n.settingsScreen_dynamicTheme),
              subtitle: Text(l10n.settingsScreen_useWallpaperColors),
              value: themeNotifier.isDynamicEnabled,
              onChanged: (bool value) {
                context.read<ThemeNotifier>().setDynamicThemeEnabled(value);
              },
            ),
          if (klasik && !themeNotifier.isDynamicEnabled)
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
          const Divider(height: 32),
          const _AppIconPicker(),
          const Divider(height: 32),
          ListTile(
            title: Text(l10n.today_customize),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TodayCustomizeScreen()),
            ),
          ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(l10n.feedback_title, style: theme.textTheme.titleMedium),
          ),
          const _FeedbackSettings(),
        ],
      ),
    );
  }
}

class _FeedbackSettings extends StatelessWidget {
  const _FeedbackSettings();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsService>();
    final feedback = context.read<FeedbackService>();
    return Column(
      children: [
        SwitchListTile(
          title: Text(l10n.feedback_haptics),
          subtitle: Text(l10n.feedback_hapticsHint),
          value: settings.areHapticsEnabled,
          onChanged: settings.setHapticsEnabled,
        ),
        SwitchListTile(
          title: Text(l10n.feedback_sounds),
          subtitle: Text(l10n.feedback_soundsHint),
          value: settings.areUiSoundsEnabled,
          onChanged: settings.setUiSoundsEnabled,
        ),
        SwitchListTile(
          title: Text(l10n.feedback_petSounds),
          subtitle: Text(l10n.feedback_petSoundsHint),
          value: settings.arePetSoundsEnabled,
          onChanged: settings.setPetSoundsEnabled,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          // a Wrap: three buttons do not fit one line on narrow phones or in long languages
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 4,
            children: [
              Padding(padding: const EdgeInsets.only(right: 8), child: Text(l10n.feedback_try)),
              for (final (name, label) in [('save', l10n.feedback_trySave), ('select', l10n.feedback_trySelect), ('celebrate', l10n.feedback_tryCelebrate)])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: OutlinedButton(
                    onPressed: () {
                      switch (name) {
                        case 'save':
                          feedback.save();
                        case 'select':
                          feedback.select();
                        default:
                          feedback.celebrate();
                      }
                      if (settings.areUiSoundsEnabled) return;
                      feedback.preview(name);
                    },
                    child: Text(label),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Launcher icon choices. Companion icons unlock with the companion; in
/// discrete mode the neutral icon always wins.
class _AppIconPicker extends StatelessWidget {
  const _AppIconPicker();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final settings = context.watch<SettingsService>();
    final companions = context.watch<CompanionService>();
    final discrete = settings.isDiscreteModeEnabled;
    final current = AppIcon.byName(settings.appIcon);

    String label(AppIcon icon) => switch (icon) {
          AppIcon.ruya => 'RUYA',
          AppIcon.ay => AppStyle.ay.label(l10n),
          AppIcon.lale => AppStyle.lale.label(l10n),
          _ => companions.nickname(icon.companion!) ?? icon.companion!.defaultName(l10n),
        };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(l10n.appIcon_title, style: theme.textTheme.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            discrete ? l10n.appIcon_discreteNote : l10n.appIcon_hint,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 14,
            runSpacing: 12,
            children: [
              for (final icon in AppIcon.values)
                Builder(builder: (context) {
                  final c = icon.companion;
                  final locked = c != null && companions.isLoaded && !companions.isUnlocked(c);
                  final selected = icon == current;
                  final enabled = !discrete && !locked;
                  return Semantics(
                    button: true,
                    selected: selected,
                    enabled: enabled,
                    label: label(icon),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: !enabled || selected
                          ? null
                          : () {
                              context.read<FeedbackService>().select();
                              context.read<DiscreteModeController>().setIcon(icon);
                            },
                      child: SizedBox(
                        width: 76,
                        child: Column(
                          children: [
                            Opacity(
                              opacity: discrete ? 0.45 : 1,
                              child: Container(
                                width: 64,
                                height: 64,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: icon.background ?? Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                                    width: selected ? 3 : 1,
                                  ),
                                ),
                                child: locked
                                    ? Icon(Icons.lock_outline, color: Colors.black.withValues(alpha: 0.35))
                                    : Padding(
                                        padding: EdgeInsets.all(icon == AppIcon.ruya ? 0 : 6),
                                        child: Image.asset(
                                          icon.asset,
                                          filterQuality: icon == AppIcon.ruya ? FilterQuality.medium : FilterQuality.none,
                                          excludeFromSemantics: true,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              locked ? l10n.unlock_inDays(companions.daysUntil(c)) : label(icon),
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: selected ? FontWeight.w800 : null,
                                color: locked ? theme.colorScheme.onSurfaceVariant : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }
}

/// One look in the picker, drawn in its own colours.
class StylePackTile extends StatelessWidget {
  const StylePackTile({
    super.key,
    required this.style,
    required this.selected,
    required this.klasikColor,
    required this.onTap,
  });

  final AppStyle style;
  final bool selected;
  final Color klasikColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brightness = Theme.of(context).brightness;
    final StylePalette p;
    if (style == AppStyle.klasik) {
      final scheme = ColorScheme.fromSeed(seedColor: klasikColor, brightness: brightness);
      p = StylePalette(
        background: scheme.surfaceContainerLow, card: scheme.surface, ink: scheme.onSurface,
        muted: scheme.onSurfaceVariant, primary: scheme.primary, onPrimary: scheme.onPrimary,
        soft: scheme.primaryContainer, line: scheme.outlineVariant, accent: scheme.tertiary,
      );
    } else {
      p = paletteOf(style, brightness);
    }
    final pixel = style == AppStyle.piksel;
    final radius = BorderRadius.circular(pixel ? 8 : 18);
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: p.background,
            borderRadius: radius,
            border: Border.all(
              color: selected ? Theme.of(context).colorScheme.primary : (pixel ? p.line : p.line),
              width: selected ? 3 : (pixel ? 2 : 1),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      style.label(l10n),
                      style: TextStyle(
                        fontFamily: pixel ? kPixelFont : (style == AppStyle.klasik ? null : kBodyFont),
                        fontWeight: FontWeight.w800,
                        fontSize: pixel ? 19 : 16,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(style.blurb(l10n), style: TextStyle(fontSize: 12.5, color: p.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              for (final c in [p.primary, p.accent, p.soft, p.card])
                Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.only(left: 5),
                  decoration: BoxDecoration(
                    color: c,
                    shape: pixel ? BoxShape.rectangle : BoxShape.circle,
                    border: Border.all(color: p.line, width: pixel ? 2 : 1),
                  ),
                ),
              if (selected) ...[
                const SizedBox(width: 8),
                Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 22),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
