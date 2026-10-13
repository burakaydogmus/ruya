import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ruya/companion/companion.dart';
import 'package:ruya/coordinators/data_refresh_coordinator.dart';
import 'package:ruya/database/repositories/pills_repository.dart';
import 'package:ruya/database/repositories/sanitary_product_repository.dart';
import 'package:ruya/l10n/app_localizations.dart';
import 'package:ruya/services/notification_service.dart';
import 'package:ruya/services/period_service.dart';
import 'package:ruya/services/settings_service.dart';

/// Launcher icons the user can choose (Settings › Appearance). The name under
/// the icon stays "RUYA"; discrete mode overrides the choice with its neutral
/// name and icon. Companion icons become available when the companion arrives.
enum AppIcon {
  ruya('Default', 'assets/icon/ruya.png'),
  pamuk('Pamuk', 'assets/icon/app_pamuk.png', companion: Companion.pamuk, background: Color(0xFFE6DBFF)),
  tarcin('Tarcin', 'assets/icon/app_tarcin.png', companion: Companion.tarcin, background: Color(0xFFFFE2C4)),
  lokum('Lokum', 'assets/icon/app_lokum.png', companion: Companion.lokum, background: Color(0xFFD8F3E6)),
  ay('Ay', 'assets/icon/app_ay.png', background: Color(0xFF2B2560)),
  lale('Lale', 'assets/icon/app_lale.png', background: Color(0xFFFFE9D6));

  const AppIcon(this.alias, this.asset, {this.companion, this.background});

  /// Android activity-alias suffix, see AndroidManifest.xml (`.Launcher<alias>`).
  final String alias;

  /// Picture for the in-app picker (pixel art except for the RUYA logo).
  final String asset;
  final Companion? companion;
  final Color? background;

  static AppIcon byName(String? name) => values.firstWhere((i) => i.name == name, orElse: () => AppIcon.ruya);
}

/// Discrete mode: makes RUYA's visible identity neutral.
///
/// What changes:
/// * launcher name and icon (Android activity-alias swap, see MainActivity.kt)
/// * recents title and in-app header
/// * every notification: neutral title/body, a single neutral channel hidden on
///   the lock screen; channels with revealing names are removed
/// * the home-screen widget shows only a number
/// * lock screen and biometric prompt wording
/// * the recents (overview) thumbnail is blank (also whenever a PIN is set)
///
/// Android limits (cannot be changed by an app at runtime): the name in
/// Settings › Apps and the app name printed by the system above notifications
/// stay "RUYA", and some launchers need a few seconds or a restart to refresh.
/// Android also closes a task when the alias it was started from is disabled,
/// so MainActivity switches the alias only once the app is left.
class DiscreteModeController {
  DiscreteModeController(this._settings);

  static const MethodChannel _channel = MethodChannel('com.burakaydogmus.ruya/app_identity');

  final SettingsService _settings;

  static NeutralNotificationText neutralText(AppLocalizations l10n) => NeutralNotificationText(
        title: l10n.discrete_notificationTitle,
        body: l10n.discrete_notificationBody,
        channelName: l10n.discrete_channelName,
      );

  /// Applies the saved preference at startup (launcher alias + notification wording).
  ///
  /// The recents thumbnail is hidden in discrete mode and whenever a PIN is set
  /// (otherwise the locked app would still be readable in the app switcher).
  Future<void> applySaved(AppLocalizations l10n, {bool pinEnabled = false}) async {
    final enabled = _settings.isDiscreteModeEnabled;
    await NotificationService.setDiscrete(enabled ? neutralText(l10n) : null);
    await _setLauncherIdentity(enabled, onlyIfDifferent: true);
    await updateRecentsPrivacy(pinEnabled: pinEnabled);
  }

  /// Re-evaluates whether the recents thumbnail must be hidden.
  Future<void> updateRecentsPrivacy({required bool pinEnabled}) =>
      _setHideInRecents(_settings.isDiscreteModeEnabled || pinEnabled);

  /// Turns discrete mode on/off and reschedules notifications with the new wording.
  Future<void> setEnabled(
    bool enabled, {
    required AppLocalizations l10n,
    required PeriodService periodService,
    required DataRefreshCoordinator coordinator,
    bool pinEnabled = false,
  }) async {
    await _settings.setDiscreteModeEnabled(enabled);
    await NotificationService.setDiscrete(enabled ? neutralText(l10n) : null);
    await _setLauncherIdentity(enabled);
    await updateRecentsPrivacy(pinEnabled: pinEnabled);
    periodService.forceNotificationReschedule();
    await coordinator.resetAllData();
    await _reschedulePillAndSanitary(l10n);
  }

  /// Changes the launcher icon. In discrete mode the choice is only saved and
  /// takes effect when discrete mode is turned off.
  Future<void> setIcon(AppIcon icon) async {
    await _settings.setAppIcon(icon.name);
    await _setLauncherIdentity(_settings.isDiscreteModeEnabled);
  }

  AppIcon get icon => AppIcon.byName(_settings.appIcon);

  Future<void> _setLauncherIdentity(bool discrete, {bool onlyIfDifferent = false}) async {
    final alias = discrete ? 'Discrete' : icon.alias;
    try {
      if (onlyIfDifferent) {
        final current = await _channel.invokeMethod<String>('currentLauncher');
        if (current == alias) return;
      }
      await _channel.invokeMethod<String>('setLauncher', {'alias': alias});
    } on MissingPluginException {
      // Not on Android (tests, other platforms).
    } on PlatformException catch (e) {
      debugPrint('Discrete launcher switch failed: ${e.message}');
    }
  }

  Future<void> _setHideInRecents(bool hide) async {
    try {
      await _channel.invokeMethod<void>('setHideInRecents', {'hide': hide});
    } on MissingPluginException {
      // Not on Android.
    } on PlatformException catch (e) {
      debugPrint('Hide-in-recents failed: ${e.message}');
    }
  }

  Future<void> _reschedulePillAndSanitary(AppLocalizations l10n) async {
    try {
      final pills = PillsRepository();
      final regimen = await pills.readActivePillRegimen();
      if (regimen?.id != null) {
        final reminder = await pills.readReminderForRegimen(regimen!.id!);
        if (reminder != null && reminder.isEnabled) {
          final parts = reminder.reminderTime.split(':');
          await NotificationService.schedulePillReminder(
            reminderTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
            isEnabled: true,
            title: l10n.notification_pillTitle,
            body: l10n.notification_pillBody,
          );
        }
      }
      final active = await SanitaryProductRepository().getActiveEntry();
      if (active != null && active.reminderTime.isAfter(DateTime.now())) {
        await NotificationService.scheduleSanitaryProductReminder(
          reminderDateTime: active.reminderTime,
          title: l10n.notification_SanitaryProductReminderTitle,
          body: l10n.notification_SanitaryProductReminderBody,
        );
      }
    } catch (e) {
      debugPrint('Rescheduling reminders after discrete change failed: $e');
    }
  }
}
