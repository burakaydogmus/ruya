import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:ruya/services/bag_service.dart';
import 'package:ruya/services/feedback_service.dart';
import 'package:ruya/theme/app_style.dart';
import 'package:ruya/companion/companion_service.dart';
import 'package:home_widget/home_widget.dart';
import 'dart:async';
import 'package:ruya/controllers/log_reversible_contraceptive_ui_controller.dart';
import 'package:ruya/controllers/log_sanitary_ui_controller.dart';
import 'package:ruya/controllers/log_sex_ui_controller.dart';
import 'package:ruya/controllers/log_ui_controller.dart';
import 'package:ruya/coordinators/data_refresh_coordinator.dart';
import 'package:ruya/database/repositories/periods_repository.dart';
import 'package:ruya/database/repositories/logs_repository.dart';
import 'package:ruya/database/repositories/user_repository.dart';
import 'package:ruya/screens/gates/root_gate.dart';
import 'package:ruya/services/symptom_service.dart';
import 'package:ruya/services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:dynamic_color/dynamic_color.dart';
import 'package:ruya/services/notification_service.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:ruya/l10n/app_localizations.dart';
import 'package:ruya/notifiers/theme_notifier.dart';
import 'package:provider/provider.dart';
import 'package:ruya/services/wear_sync_service.dart';
import 'package:ruya/models/themes/app_theme_mode_enum.dart';
import 'package:ruya/notifiers/locale_notifier.dart';
import 'package:ruya/services/settings_service.dart';
import 'package:ruya/services/widget_controller.dart';
import 'package:ruya/services/period_service.dart';
import 'package:ruya/services/log_service.dart';
import 'package:ruya/security/field_cipher.dart';
import 'package:ruya/database/database_encryption.dart';
import 'package:ruya/security/secure_key_value_store.dart';
import 'package:ruya/security/app_lock_controller.dart';
import 'package:ruya/security/pin_service.dart';
import 'package:ruya/screens/lock/lock_screen.dart';
import 'package:ruya/security/discrete_mode.dart';
import 'dart:ui' show PlatformDispatcher;

final watchService = WatchSyncService();
final logsRepository = LogsRepository();

/// Navigator of the app, used to open screens from home-widget taps.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Bumped when data changes outside the UI (Wear OS quick log) so the app refreshes.
final externalLogChanges = ValueNotifier<int>(0);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  tz_data.initializeTimeZones();
  try {
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
  } catch (e) {
    tz.setLocalLocation(tz.getLocation('Etc/UTC'));
  }

  await NotificationService.initialize();

  // Data key for encrypted DB fields (Android Keystore backed). Must be ready
  // before anything reads or writes logs.
  final SecureKeyValueStore secureStore = PlatformSecureKeyValueStore();
  // Full-database encryption (SQLCipher) on Android; migrates a plaintext
  // database once and falls back to it if anything goes wrong.
  if (defaultTargetPlatform == TargetPlatform.android) {
    await DatabaseEncryption.prepare(secureStore);
  }
  try {
    await FieldCipher.instance.init(secureStore);
  } catch (e) {
    // Encrypted fields stay unreadable and new notes cannot be saved, but the
    // rest of the app keeps working. Nothing is written in plaintext.
    debugPrint('FieldCipher init failed: $e');
  }

  final SharedPreferences sharedPrefrences = await SharedPreferences.getInstance();
  final SettingsService settingsService = SettingsService(sharedPrefrences);
  final UserService userService = UserService(UserRepository());
  final SymptomService symptomService = SymptomService(sharedPrefrences);

  final AppLockController appLock = AppLockController(
    pinService: PinService(secureStore),
    timeoutSeconds: () => settingsService.pinTimeoutSeconds,
    biometricsPreferred: () => settingsService.areBiometricsEnabled,
  );
  await appLock.init();

  // Discrete mode must be in effect before anything schedules a notification.
  final discreteMode = DiscreteModeController(settingsService);
  await discreteMode.applySaved(_startupLocalizations(settingsService), pinEnabled: appLock.hasPin);

  watchService.initialize(onPeriodLog: () async {
    await logsRepository.logFromWatch();
    externalLogChanges.value++;
  });

  runApp(buildRuyaApp(
    settingsService: settingsService,
    userService: userService,
    symptomService: symptomService,
    appLock: appLock,
    discreteMode: discreteMode,
  ));

}

/// Localizations for code that runs before MaterialApp (startup notifications).
AppLocalizations _startupLocalizations(SettingsService settings) {
  final code = settings.languageCode == 'system'
      ? PlatformDispatcher.instance.locale.languageCode
      : settings.languageCode;
  final supported = AppLocalizations.supportedLocales.map((l) => l.languageCode);
  return lookupAppLocalizations(Locale(supported.contains(code) ? code : 'en'));
}

/// Provider tree + app. Shared by [main] and widget tests.
Widget buildRuyaApp({
  required SettingsService settingsService,
  required UserService userService,
  required SymptomService symptomService,
  required AppLockController appLock,
  DiscreteModeController? discreteMode,
}) {
  return MultiProvider(
    providers: [
      // --- Core services ---
      ChangeNotifierProvider(create: (_) => settingsService),
      ChangeNotifierProvider(create: (_) => userService),
      ChangeNotifierProvider(create: (_) => symptomService),
      ChangeNotifierProvider.value(value: appLock),
      Provider.value(value: discreteMode ?? DiscreteModeController(settingsService)),

      // --- Repositories ---
      Provider(create: (_) => LogsRepository()),
      Provider(create: (_) => PeriodsRepository()),

      // --- UI state ---
      ChangeNotifierProvider(
        create: (context) => ThemeNotifier(context.read<SettingsService>()),
      ),
      ChangeNotifierProvider(
        create: (context) => LocaleNotifier(context.read<SettingsService>()),
      ),

      // --- Integrations ---
      Provider(create: (_) => WidgetController()),
      Provider(create: (context) => FeedbackService(context.read<SettingsService>())),
      ChangeNotifierProvider(create: (_) => BagService()),

      // --- Domain services ---
      ChangeNotifierProvider(
        create: (context) => LogService(context.read<LogsRepository>()),
      ),
      ChangeNotifierProvider(create: (_) => CompanionService(CompanionRepository())..load()),
      ChangeNotifierProvider(
        create: (context) => PeriodService(
          context.read<SettingsService>(),
          context.read<PeriodsRepository>(),
        ),
      ),
      Provider(
        create: (context) => DataRefreshCoordinator(
          logService: context.read<LogService>(),
          periodService: context.read<PeriodService>(),
          widgetController: context.read<WidgetController>(),
          companionService: context.read<CompanionService>(),
        ),
      ),

      // --- Controllers ---
      ChangeNotifierProvider(create: (_) => LogUIController()),
      ChangeNotifierProvider(create: (_) => LogSanitaryUIController()),
      ChangeNotifierProvider(create: (_) => LogSexUIController()),
      ChangeNotifierProvider(create: (_) => LogReversibleContraceptiveUIController())
    ],
    child: const MainApp(),
  );
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  // Tapping the home-screen widget simply opens the app (Menstrudel showed a
  // debug dialog with the launch URI here).

  @override
  void initState() {
    super.initState();
    externalLogChanges.addListener(_onExternalLogChange);
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_onWidgetLaunch);
    _widgetClicks = HomeWidget.widgetClicked.listen(_onWidgetLaunch);
  }

  StreamSubscription<Uri?>? _widgetClicks;

  /// The widget's "+" button opens today's daily log (`ruya://widget/log`);
  /// any other tap just opens the app.
  void _onWidgetLaunch(Uri? uri) {
    if (uri == null || uri.host != 'widget' || uri.path != '/log') return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Wait until onboarding is done and the main screen is shown.
      for (var i = 0; i < 20; i++) {
        final ctx = rootNavigatorKey.currentContext;
        if (ctx != null && ctx.mounted && ctx.read<UserService>().user != null && !ctx.read<LogService>().isLoading) {
          await ctx.read<LogUIController>().handleCreateNewLog(
                context: ctx,
                selectedDate: DateTime.now(),
                symptomService: ctx.read(),
                age: ctx.read<UserService>().age,
              );
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    });
  }

  @override
  void dispose() {
    externalLogChanges.removeListener(_onExternalLogChange);
    _widgetClicks?.cancel();
    super.dispose();
  }

  void _onExternalLogChange() => context.read<DataRefreshCoordinator>().onExternalLogsChanged();
  @override
  Widget build(BuildContext context) {
    final themeNotifier = context.watch<ThemeNotifier>();
    final localeNotifier = context.watch<LocaleNotifier>();
    final discrete = context.select<SettingsService, bool>((s) => s.isDiscreteModeEnabled);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme lightColorScheme;
        ColorScheme darkColorScheme;

        final bool useDynamicTheme = themeNotifier.isDynamicEnabled;

        if (useDynamicTheme && lightDynamic != null && darkDynamic != null) {
          lightColorScheme = lightDynamic.harmonized();
          darkColorScheme = darkDynamic.harmonized();
        } else {
          final Color seed = themeNotifier.themeColor;

          lightColorScheme = ColorScheme.fromSeed(seedColor: seed);
          darkColorScheme = ColorScheme.fromSeed(
            seedColor: seed,
            brightness: Brightness.dark,
          );
        }

        return MaterialApp(
          navigatorKey: rootNavigatorKey,
          debugShowCheckedModeBanner: false,
          locale: localeNotifier.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          onGenerateTitle: (context) {
            final l10n = AppLocalizations.of(context)!;
            // Shown in the recents screen.
            return discrete ? l10n.discrete_appName : l10n.appTitle;
          },
          builder: (context, child) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final l10n = AppLocalizations.of(context);
              if (l10n != null) {
                context.read<DataRefreshCoordinator>().registerL10n(l10n);
              }
            });
            return AppLockGate(child: child!);
          },
          theme: buildRuyaTheme(
            style: themeNotifier.style,
            brightness: Brightness.light,
            klasikScheme: lightColorScheme,
            discrete: discrete,
          ),
          darkTheme: buildRuyaTheme(
            style: themeNotifier.style,
            brightness: Brightness.dark,
            klasikScheme: darkColorScheme,
            discrete: discrete,
          ),
          themeMode: themeNotifier.themeMode.getThemeMode(),
          home: const RootGate(),
        );
      },
    );
  }
}