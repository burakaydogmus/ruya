import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ruya/database/app_database.dart';
import 'package:ruya/database/repositories/logs_repository.dart';
import 'package:ruya/database/repositories/periods_repository.dart';
import 'package:ruya/database/repositories/user_repository.dart';
import 'package:ruya/main.dart';
import 'package:ruya/models/app/user_entry.dart';
import 'package:ruya/models/app/user_goal_types_enum.dart';
import 'package:ruya/models/flows/flow_enum.dart';
import 'package:ruya/models/period_logs/daily_log_enums.dart';
import 'package:ruya/models/period_logs/log_day.dart';
import 'package:ruya/security/app_lock_controller.dart';
import 'package:ruya/security/crypto/pbkdf2.dart';
import 'package:ruya/security/field_cipher.dart';
import 'package:ruya/security/pin_service.dart';
import 'package:ruya/security/secure_key_value_store.dart';
import 'package:ruya/services/settings_service.dart';
import 'package:ruya/services/symptom_service.dart';
import 'package:ruya/services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ruya/services/notification_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// End-to-end UI checks on a phone-sized screen in Turkish, with the real
/// services and an in-memory database. Platform plugins are stubbed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  Pbkdf2Sha256.useNative = false;

  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final name in ['home_widget', 'watch_connectivity/methods']) {
    messenger.setMockMethodCallHandler(MethodChannel(name), (_) async => null);
  }
  messenger.setMockMethodCallHandler(
    const MethodChannel('dexterous.com/flutter/local_notifications'),
    (call) async => switch (call.method) {
      'initialize' || 'requestNotificationsPermission' => true,
      'pendingNotificationRequests' || 'getActiveNotifications' => <Object>[],
      _ => null,
    },
  );

  late InMemorySecureKeyValueStore store;
  WidgetController.hitTestWarningShouldBeFatal = true;

  setUpAll(() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    // Plugins are not auto-registered in tests.
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    await NotificationService.initialize();
  });

  Future<void> seedHistory() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Three 28-day cycles; the last period started 24 days ago -> luteal + PMS.
    final logs = LogsRepository();
    for (final startOffset in [80, 52, 24]) {
      for (var d = 0; d < 5; d++) {
        await logs.upsertLog(LogDay(
          date: today.subtract(Duration(days: startOffset - d)),
          flow: FlowRate.medium,
        ));
      }
    }
    final all = await logs.readAllLogs();
    final mapping = await PeriodsRepository().recalculateAndAssignPeriods(all);
    await logs.updateLogPeriodIds(mapping);
  }

  Future<void> launch(WidgetTester tester, {String? pin, bool seed = true}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({'language': 'tr'});
      PackageInfo.setMockInitialValues(
        appName: 'RUYA', packageName: 'com.burakaydogmus.ruya', version: '1.0.0',
        buildNumber: '1', buildSignature: '',
      );
      store = InMemorySecureKeyValueStore();
      FieldCipher.instance.reset();
      await FieldCipher.instance.init(store);
      await AppDatabase.instance.init(inMemory: true);
      await UserRepository().saveUser(UserEntry(name: 'Test', primaryGoal: UserGoalTypes.general));
      if (seed) await seedHistory();

      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService(prefs);
      final pins = PinService(store);
      if (pin != null) await pins.setPin(pin);
      final lock = AppLockController(
        pinService: pins,
        timeoutSeconds: () => settings.pinTimeoutSeconds,
        biometricsPreferred: () => settings.areBiometricsEnabled,
        biometricsAvailable: () async => false,
      );
      await lock.init(observeLifecycle: false);

      await tester.pumpWidget(buildRuyaApp(
        settingsService: settings,
        userService: UserService(UserRepository()),
        symptomService: SymptomService(prefs),
        appLock: lock,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 800));
    });
    await settle(tester);
  }

  tearDown(() async => AppDatabase.instance.close());

  testWidgets('Today screen shows countdown, phase, mood and quick log', (tester) async {
    await launch(tester);
    expect(find.text('Regline 4 gün kaldı'), findsOneWidget);
    expect(find.text('Bugün: Luteal faz'), findsOneWidget);
    expect(find.text('Beklenen PMS dönemi'), findsOneWidget);
    expect(find.text('Bugün nasıl hissediyorsun?'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('tıbbi tavsiye'), 300);
    expect(find.text('Hızlı kayıt'), findsOneWidget);
  });

  testWidgets('mood quick entry and flow quick log are saved', (tester) async {
    await launch(tester);
    await tapVisible(tester, find.text('Sakin'));
    await settle(tester);
    await tapVisible(tester, find.text('Hafif'));
    await settle(tester);

    final today = await tester.runAsync(() => LogsRepository().readLogForDate(DateTime.now()));
    expect(today!.moods, [Mood.calm]);
    expect(today.flow, FlowRate.light);

    // Toggling the mood again removes it but keeps the flow.
    await tapVisible(tester, find.text('Sakin'));
    await settle(tester);
    final after = await tester.runAsync(() => LogsRepository().readLogForDate(DateTime.now()));
    expect(after!.moods, isEmpty);
    expect(after.flow, FlowRate.light);
  });

  testWidgets('empty state offers to log the first period', (tester) async {
    await launch(tester, seed: false);
    expect(find.text('Henüz regl kaydın yok'), findsOneWidget);
    await tester.tap(find.text('Reglim bugün başladı'));
    await settle(tester);
    final today = await tester.runAsync(() => LogsRepository().readLogForDate(DateTime.now()));
    expect(today!.flow, FlowRate.medium);
    expect(find.text('Regl · 1. gün'), findsOneWidget);
  });

  testWidgets('every main tab renders without layout errors', (tester) async {
    await launch(tester);
    for (final tab in ['Takvim', 'Kayıt', 'İçgörüler', 'Ayarlar', 'Bugün']) {
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(tab)));
      await settle(tester);
    }
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Takvim')));
    await settle(tester);
    expect(find.text('Tahmini regl'), findsOneWidget);
    expect(find.text('PMS (beklenen)'), findsOneWidget);
  });

  testWidgets('daily log sheet saves every field from the calendar FAB', (tester) async {
    await launch(tester);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Kayıt')));
    await settle(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await settle(tester);
    expect(find.text('Günlük Kaydını Tut').evaluate().isNotEmpty || find.text('Gününü kaydet').evaluate().isNotEmpty || find.byType(BottomSheet).evaluate().isNotEmpty, isTrue);

    final sheetList = find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first;
    Future<void> tapText(String text) async {
      await tester.scrollUntilVisible(find.text(text).first, 150, scrollable: sheetList);
      await tapVisible(tester, find.text(text).first);
      await tester.pump();
    }

    await tapText('Orta');
    await tapText('Odaklı');
    await tapText('Kremsi');
    await tapText('Prezervatif');
    await tapText('Korunaklı');
    await tapText('Yüksek');
    final meds = find.widgetWithText(TextField, 'İlaç ekle, ör. ibuprofen');
    await tester.scrollUntilVisible(meds, -200, scrollable: sheetList);
    await tester.enterText(meds, 'Parol');
    await tester.pumpAndSettle();
    final notes = find.widgetWithText(TextField, 'Bugünle ilgili hatırlamak istediğin her şey');
    await tester.scrollUntilVisible(notes, 200, scrollable: sheetList);
    await tester.enterText(notes, 'Not 123');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await settle(tester);

    final log = await tester.runAsync(() => LogsRepository().readLogForDate(DateTime.now()));
    expect(log!.flow, FlowRate.medium);
    expect(log.moods, [Mood.focused]);
    expect(log.discharge, Discharge.creamy);
    expect(log.contraception, [ContraceptionMethod.condom]);
    expect(log.sexActivity, SexActivity.protected);
    expect(log.libido, Libido.high);
    expect(log.medications, ['Parol']);
    expect(log.notes, 'Not 123');
  });

  testWidgets('PIN lock blocks the app until the right PIN is entered', (tester) async {
    await launch(tester, pin: '2580');
    expect(find.text('RUYA kilitli'), findsOneWidget);
    expect(find.text('Bugün nasıl hissediyorsun?'), findsNothing);

    Future<void> enter(String pin) async {
      for (final d in pin.split('')) {
        await tester.tap(find.text(d));
        await tester.pump();
      }
      await tester.tap(find.text('Kilidi aç'));
      await settle(tester);
    }

    await enter('1111');
    expect(find.text('Yanlış PIN. 4 deneme hakkın kaldı.'), findsOneWidget);
    await enter('2580');
    expect(find.text('RUYA kilitli'), findsNothing);
    expect(find.text('Bugün nasıl hissediyorsun?'), findsOneWidget);
  });

  testWidgets('import from other apps is reachable from settings', (tester) async {
    await launch(tester);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Ayarlar')));
    await settle(tester);
    await tapVisible(tester, find.text('Diğer uygulamalardan aktar'));
    await settle(tester);
    expect(find.text('Flo'), findsOneWidget);
    expect(find.text('Clue'), findsOneWidget);
    expect(find.text('drip'), findsOneWidget);
    expect(find.text('Dışa aktarma dosyası seç'), findsOneWidget);
  });

  testWidgets('clinical report screen is reachable from settings', (tester) async {
    await launch(tester);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Ayarlar')));
    await settle(tester);
    await tapVisible(tester, find.text('Klinik rapor (PDF)'));
    await settle(tester);
    expect(find.text('Tarih aralığı'), findsOneWidget);
    await tester.scrollUntilVisible(find.text("PDF'i kaydet"), 200);
    expect(find.text("PDF'i kaydet"), findsOneWidget);
  });

  testWidgets('privacy settings are reachable from settings', (tester) async {
    await launch(tester);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Ayarlar')));
    await settle(tester);
    await tester.tap(find.text('Gizlilik'));
    await settle(tester);
    expect(find.text('PIN kilidi'), findsOneWidget);
    expect(find.text('Şifreli yedek'), findsOneWidget);
    await tester.tap(find.text('Şifreli yedek'));
    await settle(tester);
    expect(find.text('Şifreli yedek oluştur'), findsWidgets);
  });
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

/// Lets real async work (sqflite ffi, isolates) finish, then settles frames.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
}
