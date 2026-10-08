import 'package:flutter/material.dart';
import 'package:ruya/models/app/user_goal_types_enum.dart';
import 'package:ruya/cycle/life_stage.dart';
import 'dart:convert';
import 'package:ruya/models/birth_control/reversible_contraceptives/reversible_contraceptive_types_enum.dart';
import 'package:ruya/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ruya/utils/constants.dart';
import 'package:ruya/models/themes/app_theme_mode_enum.dart';

enum PeriodHistoryView { list, journal }

/// Home screen widget background.
enum WidgetTheme { system, light, dark, transparent }

/// What the home screen widgets show (shared by every widget size).
class HomeWidgetOptions {
  const HomeWidgetOptions({
    this.showRing = true,
    this.showNextDate = true,
    this.showPhase = true,
    this.showCycleDay = false,
    this.showFertility = true,
    this.showQuickLog = true,
    this.showCompanion = true,
    this.theme = WidgetTheme.system,
  });

  final bool showRing;
  final bool showNextDate;
  final bool showPhase;
  final bool showCycleDay;
  final bool showFertility;
  final bool showQuickLog;

  /// The chosen companion on the medium and large widgets.
  final bool showCompanion;
  final WidgetTheme theme;

  HomeWidgetOptions copyWith({
    bool? showRing,
    bool? showNextDate,
    bool? showPhase,
    bool? showCycleDay,
    bool? showFertility,
    bool? showQuickLog,
    bool? showCompanion,
    WidgetTheme? theme,
  }) =>
      HomeWidgetOptions(
        showRing: showRing ?? this.showRing,
        showNextDate: showNextDate ?? this.showNextDate,
        showPhase: showPhase ?? this.showPhase,
        showCycleDay: showCycleDay ?? this.showCycleDay,
        showFertility: showFertility ?? this.showFertility,
        showQuickLog: showQuickLog ?? this.showQuickLog,
        showCompanion: showCompanion ?? this.showCompanion,
        theme: theme ?? this.theme,
      );
}

class SettingsService extends ChangeNotifier {
  final SharedPreferences _prefs;

  SettingsService(this._prefs) {
    loadSettings();
  }

  // App
  String _languageCode = kDefaultLanguageCode;
  bool _biometricsEnabled = kDefaultBiometricsEnabled;
  bool _dynamicColorEnabled = kDefaultDynamicColorEnabled;
  Color _themeColor = kDefaultThemeColor;
  AppThemeMode _themeMode = kDefaultThemeMode;
  String _startingDayOfWeek = kDefaultStartingDayOfWeek;
  PeriodHistoryView _historyView = kDefaultHistoryView;

  // Nav
  bool _pillNavEnabled = kDefaultPillNavEnabled;
  bool _reversibleContraceptiveNavEnabled = kDefaultReversibleContraceptiveNavEnabled;
  bool _sanitaryNavEnabled = kDefaultSanitaryNavEnabled;
  bool _sexActivityNavEnabled = kDefaultSexActivityNavEnabled;

  // User
  ReversibleContraceptiveTypes _reversibleContraceptiveType = kDefaultReversibleContraceptiveType;
  Map<ReversibleContraceptiveTypes, int> _reversibleContraceptiveDurations = {};
  bool _phasePredictions = kDefaultPhasePredictions;
  bool _displayFertileChance = kDefaultDisplayFertileChance;
  bool _displayFertileWindowOnCalendar = kDefaultDisplayFertileWindowOnCalendar;
  int _lutealPhaseLength = kDefaultLutealPhaseLength;
  int _pmsDays = kDefaultPmsDays;
  bool _showPmsWindow = kDefaultShowPmsWindow;

  // Privacy
  int _pinTimeoutSeconds = kDefaultPinTimeoutSeconds;
  bool _discreteMode = kDefaultDiscreteMode;
  bool _kidMode = kDefaultKidMode;
  List<DateSpan> _birthControlSpans = [];
  List<DateSpan> _pregnancySpans = [];
  HomeWidgetOptions _widgetOptions = const HomeWidgetOptions();

  // Notifications
  bool _periodDueNotificationsEnabled = kDefaultPeriodDueNotificationsEnabled;
  bool _loggingReminder = kDefaultLoggingReminder;
  bool _periodOverdueNotificationsEnabled = kDefaultPeriodOverdueNotificationsEnabled;
  bool _fertileWindowNotificationsEnabled = kDefaultFertileWindowNotificationsEnabled;
  bool _ovulationNotificationsEnabled = kDefaultOvulationNotificationsEnabled;
  bool _reversibleContraceptiveNotificationsEnabled = kDefaultReversibleContraceptiveNotificationsEnabled;

  int _notificationDays = kDefaultNotificationDays;
  int _periodOverdueNotificationDays = kDefaultNotificationDays;
  int _reversibleContraceptiveReminderDays = kDefaultReversibleContraceptiveReminderDays;
  int _fertileWindowReminderDaysBefore = kDefaultNotificationDays;
  int _ovulationReminderDays = kDefaultNotificationDays;

  TimeOfDay _notificationTime = kDefaultNotificationTime;
  TimeOfDay _periodOverdueNotificationTime = kDefaultNotificationTime;
  TimeOfDay _loggingReminderTime = kDefaultNotificationTime;
  TimeOfDay _reversibleContraceptiveReminderTime = kDefaultNotificationTime;
  TimeOfDay _fertileWindowReminderTime = kDefaultNotificationTime;
  TimeOfDay _ovulationReminderTime = kDefaultNotificationTime;

  // App

  /// The selected language code for the app (e.g., 'en', 'es', or 'system').
  String get languageCode => _languageCode;
  /// Whether the app requires biometric authentication (e.g., fingerprint, face) on startup.
  bool get areBiometricsEnabled => _biometricsEnabled;
  /// Whether to use Material You dynamic colors from the wallpaper (Android 12+).
  bool get isDynamicThemeEnabled => _dynamicColorEnabled;
  /// The seed color for the app's theme (used if dynamic color is off).
  Color get themeColor => _themeColor;
  /// The app's theme mode (Light, Dark, or System).
  AppThemeMode get themeMode => _themeMode;
  /// The starting day of the week for calendars
  String get startingDayOfWeek => _startingDayOfWeek;
  /// The user's preferred view for the period history (list vs. journal).
  PeriodHistoryView get historyView => _historyView;

  // Nav

  /// Whether the 'Pill' tab is visible in the main navigation bar.
  bool get isPillNavEnabled => _pillNavEnabled;
  /// Reversible Contraceptive navigation enabled
  bool get isReversibleContraceptiveNavEnabled => _reversibleContraceptiveNavEnabled;
  /// Sanitary Products navigation enabled
  bool get isSanitaryNavEnabled => _sanitaryNavEnabled;
  /// Sex Activity navigation enabled
  bool get isSexActivityNavEnabled => _sexActivityNavEnabled && !_kidMode;

  // User

  /// Reversible Contraceptive type selected
  ReversibleContraceptiveTypes get reversibleContraceptiveType => _reversibleContraceptiveType;
  /// Retrieves the duration in days for a specific Reversible Contraceptive type, which determines its estimated renewal date.
  int getReversibleContraceptiveDurationDays(ReversibleContraceptiveTypes type) {
    if (_reversibleContraceptiveDurations.containsKey(type)) {
      return _reversibleContraceptiveDurations[type]!;
    }
    return type.defaultDurationDays; 
  }
  /// Whether phase predictions are enabled.
  bool get arePhasePredictionsEnabled => _phasePredictions;
  /// Whether fertility chance should be displayed on the today tab.
  bool get displayFertileChance => _displayFertileChance;
  /// Whether fertility window should be displayed on the calendar.
  bool get displayFertileWindowOnCalendar => _displayFertileWindowOnCalendar;
  /// Estimated luteal phase length in days (ovulation = next period - this).
  int get lutealPhaseLength => _lutealPhaseLength;
  /// Days before the expected period shown as the estimated PMS window.
  int get pmsDays => _pmsDays;
  bool get showPmsWindow => _showPmsWindow;

  /// Seconds the app may stay in the background before the PIN is required again.
  int get pinTimeoutSeconds => _pinTimeoutSeconds;

  /// Neutral launcher name/icon, notifications and widget text.
  bool get isDiscreteModeEnabled => _discreteMode;

  /// Kid mode hides sex and libido everywhere (log, calendar, sex tracker, PDF).
  /// Stored data is kept untouched.
  bool get isKidModeEnabled => _kidMode;

  /// Whether sex/libido fields and the sexual activity tracker may be shown.
  bool get showIntimateFields => !_kidMode;

  /// History of hormonal birth control use (birth control mode).
  List<DateSpan> get birthControlSpans => List.unmodifiable(_birthControlSpans);

  /// History of pregnancies; the start is the last menstrual period.
  List<DateSpan> get pregnancySpans => List.unmodifiable(_pregnancySpans);

  bool get isOnHormonalBirthControl => _birthControlSpans.any((s) => s.isOngoing);

  DateSpan? get activePregnancy => _pregnancySpans.where((s) => s.isOngoing).firstOrNull;

  bool get isPregnancyModeActive => activePregnancy != null;

  HomeWidgetOptions get widgetOptions => _widgetOptions;

  CycleClassifier get cycleClassifier =>
      CycleClassifier(birthControl: _birthControlSpans, pregnancies: _pregnancySpans);


  // Notifications

  /// Whether notifications for the *upcoming* period (due) are enabled.
  bool get arePeriodDueNotificationsEnabled => _periodDueNotificationsEnabled;
  /// Whether the logging reminder is enabled
  bool get isLoggingReminderNotificationEnabled => _loggingReminder;
  /// Whether notifications for an *overdue* period are enabled.
  bool get arePeriodOverdueNotificationsEnabled => _periodOverdueNotificationsEnabled;
  /// Whether fertile window notifications are enabled
  bool get areFertileWindowNotificationsEnabled => _fertileWindowNotificationsEnabled;
  /// Whether ovulation notifications are enabled
  bool get areOvulationNotificationsEnabled => _ovulationNotificationsEnabled;
  /// If reversible contraceptive notifications are enabled
  bool get reversibleContraceptiveNotificationsEnabled => _reversibleContraceptiveNotificationsEnabled;

  /// How many days *before* the period is due to send the notification.
  int get notificationDays => _notificationDays;
  /// How many days *after* the period is due to send the overdue notification.
  int get periodOverdueNotificationDays => _periodOverdueNotificationDays;
  /// The amount of days before reversible contraceptive renew date notificaiton shuold be sent
  int get reversibleContraceptiveReminderDays => _reversibleContraceptiveReminderDays;
  /// The amount of days before fertile window notification should be sent
  int get fertileWindowReminderDaysBefore => _fertileWindowReminderDaysBefore;
  /// The amount of days before ovulation notification should be sent
  int get ovulationReminderDays => _ovulationReminderDays;

  /// The time of day to send the 'period due' notification.
  TimeOfDay get notificationTime => _notificationTime;
  /// The time of day to send the 'period overdue' notification.
  TimeOfDay get periodOverdueNotificationTime => _periodOverdueNotificationTime;
  /// The time of day the logging reminder should be sent
  TimeOfDay get loggingReminderTime => _loggingReminderTime;
  /// The time of day the reversible contraceptive renew notification should be sent
  TimeOfDay get reversibleContraceptiveReminderTime => _reversibleContraceptiveReminderTime;
  /// The time of day the fertile window notification should be sent
  TimeOfDay get fertileWindowReminderTime => _fertileWindowReminderTime;
  /// The time of day the ovulation notification should be sent
  TimeOfDay get ovulationReminderTime => _ovulationReminderTime;

  // Other

  /// Returns true if user is on natural cycle (Not using pill or affecting reversible contraceptive).
  bool get isNaturalCycle {
    if (isOnHormonalBirthControl || isPregnancyModeActive) return false;
    if (_pillNavEnabled) return false;
    
    if (_reversibleContraceptiveNavEnabled) {
      // Only the Copper IUD allows for a natural hormonal cycle.
      return _reversibleContraceptiveType == ReversibleContraceptiveTypes.copperIud;
    }
    return true;
  }
  
  
  Future<void> loadSettings() async {
    // App
    _languageCode = _loadString(languageKey, kDefaultLanguageCode);
    _biometricsEnabled = _loadBool(biometricEnabledKey, kDefaultBiometricsEnabled);
    _dynamicColorEnabled = _loadBool(dynamicColorKey, kDefaultDynamicColorEnabled);
    _themeColor = _loadThemeColor();
    _themeMode = _loadThemeMode();
    _startingDayOfWeek = _loadString(startingDayOfWeekKey, kDefaultStartingDayOfWeek);
    _historyView = _loadHistoryView();

    // Nav
    _pillNavEnabled = _loadBool(pillNavEnabledKey, kDefaultPillNavEnabled);
    _reversibleContraceptiveNavEnabled = _loadBool(reversibleContraceptiveNavEnabledKey, kDefaultReversibleContraceptiveNavEnabled);
    _sanitaryNavEnabled = _loadBool(sanitaryNavEnabledKey, kDefaultSanitaryNavEnabled);
    _sexActivityNavEnabled = _loadBool(sexActivityNavEnabledKey, kDefaultSexActivityNavEnabled);

    //User
    _reversibleContraceptiveType = _loadReversibleContraceptiveType();
    _reversibleContraceptiveDurations = _loadReversibleContraceptiveDurations();
    _phasePredictions = _loadBool(phasePredictionsKey, kDefaultPhasePredictions);
    _displayFertileChance = _loadBool(displayFertileChanceKey, kDefaultDisplayFertileChance);
    _displayFertileWindowOnCalendar = _loadBool(displayFertileWindowOnCalendarKey, kDefaultDisplayFertileWindowOnCalendar);
    _lutealPhaseLength = _loadInt(lutealPhaseLengthKey, kDefaultLutealPhaseLength)
        .clamp(kMinLutealPhaseLength, kMaxLutealPhaseLength);
    _pmsDays = _loadInt(pmsDaysKey, kDefaultPmsDays).clamp(kMinPmsDays, kMaxPmsDays);
    _showPmsWindow = _loadBool(showPmsWindowKey, kDefaultShowPmsWindow);

    // Privacy
    _pinTimeoutSeconds = _loadInt(pinTimeoutSecondsKey, kDefaultPinTimeoutSeconds);
    _discreteMode = _loadBool(discreteModeKey, kDefaultDiscreteMode);
    _kidMode = _loadBool(kidModeKey, kDefaultKidMode);
    _birthControlSpans = DateSpan.decodeList(_prefs.getString(hormonalBirthControlSpansKey));
    _pregnancySpans = DateSpan.decodeList(_prefs.getString(pregnancySpansKey));
    _widgetOptions = HomeWidgetOptions(
      showRing: _loadBool(widgetShowRingKey, true),
      showNextDate: _loadBool(widgetShowNextDateKey, true),
      showPhase: _loadBool(widgetShowPhaseKey, true),
      showCycleDay: _loadBool(widgetShowCycleDayKey, false),
      showFertility: _loadBool(widgetShowFertilityKey, true),
      showQuickLog: _loadBool(widgetShowQuickLogKey, true),
      showCompanion: _loadBool(widgetShowCompanionKey, true),
      theme: WidgetTheme.values.firstWhere(
        (t) => t.name == _prefs.getString(widgetThemeKey),
        orElse: () => WidgetTheme.system,
      ),
    );

    // Notifications
    _periodDueNotificationsEnabled = _loadBool(periodDueNotificationsEnabledKey, kDefaultPeriodDueNotificationsEnabled);
    _periodOverdueNotificationsEnabled = _loadBool(periodOverdueNotificationsEnabledKey, kDefaultPeriodOverdueNotificationsEnabled);
    _reversibleContraceptiveNotificationsEnabled = _loadBool(reversibleContraceptiveNotificationsEnabledKey, kDefaultReversibleContraceptiveNotificationsEnabled);
    _fertileWindowNotificationsEnabled = _loadBool(fertileWindowNotificationsEnabledKey, kDefaultFertileWindowNotificationsEnabled);
    _ovulationNotificationsEnabled = _loadBool(ovulationNotificationsEnabledKey, kDefaultOvulationNotificationsEnabled);
    _loggingReminder = _loadBool(loggingReminderKey, kDefaultLoggingReminder);

    _notificationDays = _loadInt(notificationDaysKey, kDefaultNotificationDays);
    _periodOverdueNotificationDays = _loadInt(periodOverdueNotificationDaysKey, kDefaultNotificationDays);
    _reversibleContraceptiveReminderDays = _loadInt(reversibleContraceptiveNotificationDaysKey, kDefaultReversibleContraceptiveReminderDays);
    _fertileWindowReminderDaysBefore = _loadInt(fertileWindowReminderDaysBeforeKey, kDefaultNotificationDays);
    _ovulationReminderDays = _loadInt(ovulationReminderDaysBeforeKey, kDefaultNotificationDays);

    _notificationTime = _loadTimeOfDay(notificationTimeKey, kDefaultNotificationTime);
    _periodOverdueNotificationTime = _loadTimeOfDay(periodOverdueNotificationTimeKey, kDefaultNotificationTime);
    _loggingReminderTime = _loadTimeOfDay(loggingReminderTimeKey, kDefaultNotificationTime);
    _fertileWindowReminderTime = _loadTimeOfDay(fertileWindowReminderTimeKey, kDefaultNotificationTime);
    _ovulationReminderTime = _loadTimeOfDay(ovulationReminderTimeKey, kDefaultNotificationTime);
    _reversibleContraceptiveReminderTime = _loadTimeOfDay(reversibleContraceptiveNotificationTimeKey, kDefaultNotificationTime);

    notifyListeners();
  }

  TimeOfDay _loadTimeOfDay(String key, TimeOfDay defaultTime) {
    final String? storedTime = _prefs.getString(key);
    if (storedTime == null) {
      return defaultTime;
    }
    final parts = storedTime.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  bool _loadBool(String key, bool defaultValue) {
    final bool? storedValue = _prefs.getBool(key);
    return storedValue ?? defaultValue;
  }

  int _loadInt(String key, int defaultValue) {
    final int? storedValue = _prefs.getInt(key);
    return storedValue ?? defaultValue;
  }

  String _loadString(String key, String defaultValue) {
    final String? storedValue = _prefs.getString(key);
    return storedValue ?? defaultValue;
  }

  PeriodHistoryView _loadHistoryView() {
    final viewName = _prefs.getString(historyViewKey);
    return PeriodHistoryView.values.firstWhere(
      (e) => e.name == viewName,
      orElse: () => PeriodHistoryView.journal,
    );
  }

  Color _loadThemeColor() {
    final colorValue = _prefs.getInt(themeColorKey) ?? kDefaultThemeColor.toARGB32();
    return Color(colorValue);
  }

  AppThemeMode _loadThemeMode() {
    final themeIndex = _prefs.getInt(themeModeKey) ?? AppThemeMode.system.index;
    return AppThemeMode.values[themeIndex];
  }

  Map<ReversibleContraceptiveTypes, int> _loadReversibleContraceptiveDurations() {
    final String? storedDurationsJson = _prefs.getString(reversibleContraceptiveDurationsKey);
    if (storedDurationsJson != null) {
      final Map<String, dynamic> decodedMap = json.decode(storedDurationsJson);
      
      return decodedMap.map((key, value) {
        final type = ReversibleContraceptiveTypes.values.firstWhere((e) => e.name == key);
        return MapEntry(type, value as int);
      });
    } else {
      return {};
    }
  }

  ReversibleContraceptiveTypes _loadReversibleContraceptiveType() {
    try {
      final String? reversibleContraceptiveTypeString = _prefs.getString(reversibleContraceptiveTypeKey);
      return ReversibleContraceptiveTypes.values.firstWhere(
        (e) => e.name == reversibleContraceptiveTypeString,
      );
    } catch (e) {
      debugPrint('Corrupt saved reversible contraceptive type. Resetting to default.');
      return kDefaultReversibleContraceptiveType;
    }
  }

  Future<void> deleteAllSettings() async {
    await _prefs.clear();
    await loadSettings();
  }

  Future<void> setPillNavEnabled(bool isEnabled) async {
    _pillNavEnabled = isEnabled;
    notifyListeners();
    await _prefs.setBool(pillNavEnabledKey, isEnabled);
  }

  Future<void> setSanitaryNavEnabled(bool isEnabled) async {
    _sanitaryNavEnabled = isEnabled;
    await _prefs.setBool(sanitaryNavEnabledKey, isEnabled);
    notifyListeners();
  }
  
  Future<void> setReversibleContraceptiveNavEnabled(bool isEnabled) async {
    _reversibleContraceptiveNavEnabled = isEnabled;
    await _prefs.setBool(reversibleContraceptiveNavEnabledKey, isEnabled);
    notifyListeners();
  }

  Future<void> setSexActivityNavEnabled(bool isEnabled) async {
    _sexActivityNavEnabled = isEnabled;
    await _prefs.setBool(sexActivityNavEnabledKey, isEnabled);
    notifyListeners();
  }

  Future<void> setReversibleContraceptiveType(ReversibleContraceptiveTypes type) async {
    _reversibleContraceptiveType = type;
    await _prefs.setString(reversibleContraceptiveTypeKey, type.name);
    notifyListeners();
  }

  Future<void> setReversibleContraceptiveDurationForType(ReversibleContraceptiveTypes type, int durationDays) async {
    _reversibleContraceptiveDurations[type] = durationDays;
    final Map<String, int> mapForStorage = _reversibleContraceptiveDurations.map(
      (key, value) => MapEntry(key.name, value),
    );
    final String encodedJson = json.encode(mapForStorage);
    await _prefs.setString(reversibleContraceptiveDurationsKey, encodedJson);
    notifyListeners();
  }

  Future<void> setReversibleContraceptiveNotificationsEnabled(bool enabled) async {
    _reversibleContraceptiveNotificationsEnabled = enabled;
    await _prefs.setBool(reversibleContraceptiveNotificationsEnabledKey, enabled);
    if (!enabled) {
      await NotificationService.cancelReversibleContraceptiveReminder();
    }
    notifyListeners();
  }

  Future<void> setReversibleContraceptiveReminderDays(int days) async {
    _reversibleContraceptiveReminderDays = days;
    await _prefs.setInt(reversibleContraceptiveNotificationDaysKey, days);
    notifyListeners();
  }

  Future<void> setReversibleContraceptiveReminderTime(TimeOfDay time) async {
    _reversibleContraceptiveReminderTime = time;
    final String formattedTime = '${time.hour}:${time.minute}';
    await _prefs.setString(reversibleContraceptiveNotificationTimeKey, formattedTime);
    notifyListeners();
  }

  Future<void> setLanguageCode(String code) async {
    _languageCode = code;
    await _prefs.setString(languageKey, code);
    notifyListeners();
  }

  Future<void> setBiometricsEnabled(bool isEnabled) async {
    _biometricsEnabled = isEnabled;
    await _prefs.setBool(biometricEnabledKey, isEnabled);
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    _periodDueNotificationsEnabled = enabled;
    await _prefs.setBool(periodDueNotificationsEnabledKey, enabled);
    if (!enabled) {
      // Menstrudel cancelled the pill reminder here by mistake.
      await NotificationService.cancelPeriodDueNotification();
    }
    notifyListeners();
  }

  Future<void> setNotificationDays(int days) async {
    _notificationDays = days;
    await _prefs.setInt(notificationDaysKey, days);
    notifyListeners();
  }

  Future<void> setNotificationTime(TimeOfDay time) async {
    _notificationTime = time;
    final String formattedTime = '${time.hour}:${time.minute}';
    await _prefs.setString(notificationTimeKey, formattedTime);
    notifyListeners();
  }

  Future<void> setPeriodOverdueNotificationsEnabled(bool isEnabled) async {
    _periodOverdueNotificationsEnabled = isEnabled;
    await _prefs.setBool(periodOverdueNotificationsEnabledKey, isEnabled);
    if (!isEnabled) await NotificationService.cancelPeriodOverdueNotification();
    notifyListeners();
  }

  Future<void> setPeriodOverdueNotificationDays(int days) async {
    _periodOverdueNotificationDays = days;
    await _prefs.setInt(periodOverdueNotificationDaysKey, days);
    notifyListeners();
  }

  Future<void> setPeriodOverdueNotificationTime(TimeOfDay time) async {
    _periodOverdueNotificationTime = time;
    final String formattedTime = '${time.hour}:${time.minute}';
    await _prefs.setString(periodOverdueNotificationTimeKey, formattedTime);
    notifyListeners();
  }

  Future<void> setLoggingReminder(bool isEnabled) async {
    _loggingReminder = isEnabled;
    await _prefs.setBool(loggingReminderKey, isEnabled);
    notifyListeners();
  }

  Future<void> setLoggingReminderTime(TimeOfDay time) async {
    _loggingReminderTime = time;
    final String formattedTime = '${time.hour}:${time.minute}';
    await _prefs.setString(loggingReminderTimeKey, formattedTime);
    notifyListeners();
  }

  Future<void> setFertileWindowNotificationsEnabled(bool enabled) async {
    _fertileWindowNotificationsEnabled = enabled;
    await _prefs.setBool(fertileWindowNotificationsEnabledKey, enabled);
    if (!enabled) {
      await NotificationService.cancelFertileWindowNotification();
    }
    notifyListeners();
  }

  Future<void> setFertileWindowReminderTime(TimeOfDay time) async {
    _fertileWindowReminderTime = time;
    final String formattedTime = '${time.hour}:${time.minute}';
    await _prefs.setString(fertileWindowReminderTimeKey, formattedTime);
    notifyListeners();
  }

  Future<void> setFertileWindowReminderDaysBefore(int days) async {
    _fertileWindowReminderDaysBefore = days;
    await _prefs.setInt(fertileWindowReminderDaysBeforeKey, days);
    notifyListeners();
  }

  Future<void> setOvulationNotificationsEnabled(bool enabled) async {
    _ovulationNotificationsEnabled = enabled;
    await _prefs.setBool(ovulationNotificationsEnabledKey, enabled);
    if (!_ovulationNotificationsEnabled) {
      await NotificationService.cancelOvulationNotification();
    }
    notifyListeners();
  }

  Future<void> setOvulationReminderTime(TimeOfDay time) async {
    _ovulationReminderTime = time;
    final String formattedTime = '${time.hour}:${time.minute}';
    await _prefs.setString(ovulationReminderTimeKey, formattedTime);
    notifyListeners();
  }

  Future<void> setOvulationReminderDaysBefore(int days) async {
    _ovulationReminderDays = days;
    await _prefs.setInt(ovulationReminderDaysBeforeKey, days);
    notifyListeners();
  }

  Future<void> setHistoryView(PeriodHistoryView view) async {
    _historyView = view;
    await _prefs.setString(historyViewKey, view.name);
    notifyListeners();
  }

  Future<void> setDynamicColorEnabled(bool isEnabled) async {
    _dynamicColorEnabled = isEnabled;
    await _prefs.setBool(dynamicColorKey, isEnabled);
    notifyListeners();
  }

  Future<void> setThemeColor(Color color) async {
    _themeColor = color;
    await _prefs.setInt(themeColorKey, color.toARGB32());
    notifyListeners();
  }

  Future<void> setThemeMode(AppThemeMode theme) async {
    _themeMode = theme;
    await _prefs.setInt(themeModeKey, theme.index);
    notifyListeners();
  }

  Future<void> setStartingDayOfWeek(String day) async {
    _startingDayOfWeek = day;
    await _prefs.setString(startingDayOfWeekKey, day);
    notifyListeners();
  }

  Future<void> applySettingsForGoal(UserGoalTypes goal) async {
    final preset = goal.settings;

    // I'm not using the class methods because they will each notifyListeners which would result in 2 notify events.

    _sanitaryNavEnabled = preset.sanitaryNav;
    _sexActivityNavEnabled = preset.sexNav;

    await Future.wait([
      _prefs.setBool(sanitaryNavEnabledKey, _sanitaryNavEnabled),
      _prefs.setBool(sexActivityNavEnabledKey, _sexActivityNavEnabled)
    ]);
    
    notifyListeners();
  }

  /// Enable/Disable phase predictions
  Future<void> setPhasePredictions(bool enabled) async {
    _phasePredictions = enabled;
    await _prefs.setBool(phasePredictionsKey, enabled);
    notifyListeners();
  }

  /// Enable/Disable fertile chance display on today tab
  Future<void> setDisplayFertileChance(bool enabled) async {
    _displayFertileChance = enabled;
    await _prefs.setBool(displayFertileChanceKey, enabled);
    notifyListeners();
  }

  /// Enable/Disable fertile window display on calendar
  Future<void> setDisplayFertileWindowOnCalendar(bool enabled) async {
    _displayFertileWindowOnCalendar = enabled;
    await _prefs.setBool(displayFertileWindowOnCalendarKey, enabled);
    notifyListeners();
  }

  Future<void> setLutealPhaseLength(int days) async {
    _lutealPhaseLength = days.clamp(kMinLutealPhaseLength, kMaxLutealPhaseLength);
    await _prefs.setInt(lutealPhaseLengthKey, _lutealPhaseLength);
    notifyListeners();
  }

  Future<void> setPmsDays(int days) async {
    _pmsDays = days.clamp(kMinPmsDays, kMaxPmsDays);
    await _prefs.setInt(pmsDaysKey, _pmsDays);
    notifyListeners();
  }

  Future<void> setShowPmsWindow(bool enabled) async {
    _showPmsWindow = enabled;
    await _prefs.setBool(showPmsWindowKey, enabled);
    notifyListeners();
  }

  Future<void> setPinTimeoutSeconds(int seconds) async {
    _pinTimeoutSeconds = seconds < 0 ? 0 : seconds;
    await _prefs.setInt(pinTimeoutSecondsKey, _pinTimeoutSeconds);
    notifyListeners();
  }

  Future<void> setDiscreteModeEnabled(bool enabled) async {
    _discreteMode = enabled;
    await _prefs.setBool(discreteModeKey, enabled);
    notifyListeners();
  }

  Future<void> setKidModeEnabled(bool enabled) async {
    _kidMode = enabled;
    await _prefs.setBool(kidModeKey, enabled);
    notifyListeners();
  }

  /// Starts birth control mode from [start] (closes nothing if already active).
  Future<void> startHormonalBirthControl(DateTime start) async {
    if (isOnHormonalBirthControl) return;
    _birthControlSpans = [..._birthControlSpans, DateSpan(start)]..sort((a, b) => a.start.compareTo(b.start));
    await _prefs.setString(hormonalBirthControlSpansKey, DateSpan.encodeList(_birthControlSpans));
    notifyListeners();
  }

  /// Ends birth control mode on [end] (inclusive).
  Future<void> stopHormonalBirthControl(DateTime end) async {
    _birthControlSpans = [for (final s in _birthControlSpans) s.isOngoing ? s.closedAt(end) : s];
    await _prefs.setString(hormonalBirthControlSpansKey, DateSpan.encodeList(_birthControlSpans));
    notifyListeners();
  }

  /// Starts pregnancy mode; [lastMenstrualPeriod] is the first day of the last period.
  Future<void> startPregnancy(DateTime lastMenstrualPeriod) async {
    if (isPregnancyModeActive) return;
    _pregnancySpans = [..._pregnancySpans, DateSpan(lastMenstrualPeriod)]..sort((a, b) => a.start.compareTo(b.start));
    await _prefs.setString(pregnancySpansKey, DateSpan.encodeList(_pregnancySpans));
    notifyListeners();
  }

  /// Ends pregnancy mode on [end]; predictions resume from the next logged period.
  Future<void> endPregnancy(DateTime end) async {
    _pregnancySpans = [for (final s in _pregnancySpans) s.isOngoing ? s.closedAt(end) : s];
    await _prefs.setString(pregnancySpansKey, DateSpan.encodeList(_pregnancySpans));
    notifyListeners();
  }

  Future<void> setWidgetOptions(HomeWidgetOptions o) async {
    _widgetOptions = o;
    await Future.wait([
      _prefs.setBool(widgetShowRingKey, o.showRing),
      _prefs.setBool(widgetShowNextDateKey, o.showNextDate),
      _prefs.setBool(widgetShowPhaseKey, o.showPhase),
      _prefs.setBool(widgetShowCycleDayKey, o.showCycleDay),
      _prefs.setBool(widgetShowFertilityKey, o.showFertility),
      _prefs.setBool(widgetShowQuickLogKey, o.showQuickLog),
      _prefs.setBool(widgetShowCompanionKey, o.showCompanion),
      _prefs.setString(widgetThemeKey, o.theme.name),
    ]);
    notifyListeners();
  }
}
