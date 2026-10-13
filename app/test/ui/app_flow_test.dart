import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:ruya/companion/companion.dart';
import 'package:ruya/companion/companion_card.dart';
import 'package:ruya/companion/companion_scene.dart';
import 'package:ruya/companion/companion_service.dart';
import 'package:ruya/models/period_logs/symptom.dart';
import 'package:ruya/models/period_logs/symptom_type_enum.dart';
import 'package:ruya/screens/settings/sections/appearance_settings_screen.dart';
import 'package:ruya/screens/today/today_customize_screen.dart';
import 'package:ruya/theme/app_style.dart';
import 'package:ruya/companion/companion_sprite.dart';
import 'package:ruya/screens/settings/settings_screen.dart';
import 'package:ruya/screens/today/today_screen.dart';
import 'package:ruya/coordinators/data_refresh_coordinator.dart';
import 'package:ruya/database/app_database.dart';
import 'package:ruya/import/import_service.dart';
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
import 'package:ruya/screens/settings/sections/widget_settings_screen.dart';
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
  final identityCalls = <MethodCall>[];
  var launcherAlias = 'Default';
  messenger.setMockMethodCallHandler(
    const MethodChannel('com.burakaydogmus.ruya/app_identity'),
    (call) async {
      identityCalls.add(call);
      if (call.method == 'setHideInRecents') return null;
      if (call.method == 'setLauncher') launcherAlias = (call.arguments as Map)['alias'] as String;
      return launcherAlias;
    },
  );
  WidgetController.hitTestWarningShouldBeFatal = true;

  setUp(() {
    launcherAlias = 'Default';
    // Home widget taps arrive on an event stream.
    messenger.setMockStreamHandler(
      const EventChannel('home_widget/updates'),
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
  });

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

  Future<void> launch(WidgetTester tester,
      {String? pin, bool seed = true, Map<String, Object> initialPrefs = const {}, Future<void> Function()? beforeStart}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    // Companion animations run on timers; tests use the reduced-motion path.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({'language': 'tr', ...initialPrefs});
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
      if (beforeStart != null) await beforeStart();

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
    await revealOnToday(tester, find.text('Bugün nasıl hissediyorsun?'));
    await revealOnToday(tester, find.text('Hızlı kayıt'));
    await revealOnToday(tester, find.textContaining('tıbbi tavsiye'));
  });

  testWidgets('mood quick entry and flow quick log are saved', (tester) async {
    await launch(tester);
    await revealOnToday(tester, find.text('Sakin'));
    await tapVisible(tester, find.text('Sakin'));
    await settle(tester);
    await revealOnToday(tester, find.text('Hafif'));
    await tapVisible(tester, find.text('Hafif'));
    await settle(tester);

    final today = await tester.runAsync(() => LogsRepository().readLogForDate(DateTime.now()));
    expect(today!.moods, [Mood.calm]);
    expect(today.flow, FlowRate.light);

    // Toggling the mood again removes it but keeps the flow.
    await tester.scrollUntilVisible(find.text('Sakin'), -200, scrollable: todayScrollable());
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
    expect(find.text('Regline 4 gün kaldı'), findsNothing);

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
    expect(find.text('Regline 4 gün kaldı'), findsOneWidget);
  });

  testWidgets('import from other apps is reachable from settings', (tester) async {
    await launch(tester);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Ayarlar')));
    await settle(tester);
    await scrollToTap(tester, find.text('Diğer uygulamalardan aktar'), within: SettingsScreen);
    await settle(tester);
    expect(find.text('Flo'), findsOneWidget);
    expect(find.text('Clue'), findsOneWidget);
    expect(find.text('drip'), findsOneWidget);
    expect(find.text('Dışa aktarma dosyası seç'), findsOneWidget);
  });

  testWidgets('imported history shows up without restarting the app', (tester) async {
    await launch(tester, seed: false);
    expect(find.text('Henüz regl kaydın yok'), findsOneWidget);

    final now = DateTime.now();
    String day(int offset) {
      final d = DateTime(now.year, now.month, now.day - offset);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }
    final csv = StringBuffer('date,bleeding.value\n');
    for (final start in [80, 52, 24]) {
      for (var d = 0; d < 5; d++) {
        csv.write('${day(start - d)},2\n');
      }
    }
    final coordinator = tester.element(find.byType(NavigationBar)).read<DataRefreshCoordinator>();
    await tester.runAsync(() async {
      final service = ExternalImportService();
      expect(await service.apply(ExternalImportService.parse(csv.toString())), 15);
      // The import screen does exactly this after writing to the database.
      await coordinator.onExternalLogsChanged();
    });
    await settle(tester);
    expect(find.text('Henüz regl kaydın yok'), findsNothing);
    expect(find.text('Regline 4 gün kaldı'), findsOneWidget);
  });

  testWidgets('bleeding days without a period are grouped on start', (tester) async {
    final now = DateTime.now();
    final logs = <LogDay>[
      for (final start in [80, 52, 24])
        for (var d = 0; d < 5; d++)
          LogDay(date: DateTime(now.year, now.month, now.day - start + d), flow: FlowRate.medium),
    ];
    // Earlier versions inserted imported days without assigning periods.
    await launch(tester, seed: false, beforeStart: () async {
      await LogsRepository().insertNewLogs(logs);
      await LogsRepository().updateLogPeriodIds({});
    });
    expect(find.text('Henüz regl kaydın yok'), findsNothing);
    expect(find.text('Regline 4 gün kaldı'), findsOneWidget);
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

  testWidgets('discrete mode swaps the launcher identity and neutral titles', (tester) async {
    await launch(tester);
    identityCalls.clear();
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Ayarlar')));
    await settle(tester);
    await tester.tap(find.text('Gizlilik'));
    await settle(tester);
    await tapVisible(tester, find.text('Gizli mod').last);
    await settle(tester);
    expect(identityCalls.where((c) => c.method == 'setLauncher').single.arguments, {'alias': 'Discrete'});
    expect(NotificationService.isDiscrete, isTrue);

    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await settle(tester);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Bugün')));
    await settle(tester);
    expect(find.text('Ajanda'), findsOneWidget);
    expect(find.text('RUYA'), findsNothing);
    // The companion would give the app away, so it is gone everywhere.
    expect(find.byType(CompanionCard), findsNothing);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Ayarlar')));
    await settle(tester);
    expect(find.text('Arkadaşlar'), findsNothing);

    // Turning it off restores RUYA.
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Ayarlar')));
    await settle(tester);
    await tester.tap(find.text('Gizlilik'));
    await settle(tester);
    await tapVisible(tester, find.text('Gizli mod').last);
    await settle(tester);
    expect(launcherAlias, 'Default');
    expect(NotificationService.isDiscrete, isFalse);
  });

  testWidgets('the companion greets on Today and the album shows who is still coming', (tester) async {
    await launch(tester);
    expect(find.byType(CompanionCard), findsOneWidget);
    expect(find.text('Pamuk'), findsOneWidget);

    await tester.tap(find.byType(CompanionSprite));
    await settle(tester);
    expect(
      find.text('Hihi, gıdıklanıyorum!').evaluate().isNotEmpty ||
          find.text('Yaşasın, buradasın!').evaluate().isNotEmpty,
      isTrue,
    );

    await tester.tap(find.byTooltip('Arkadaşlar'));
    await settle(tester);
    expect(find.text('Bugün tanıştık'), findsOneWidget);
    expect(find.text('Arkadaşın'), findsOneWidget);
    expect(find.text('7 gün sonra geliyor'), findsOneWidget);
    expect(find.text('365 gün sonra geliyor'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Bugün ekranında göster'),
      250,
      scrollable: find.descendant(of: find.byKey(const ValueKey('albumList')), matching: find.byType(Scrollable)).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bugün ekranında göster'));
    await settle(tester);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await settle(tester);
    expect(find.byType(CompanionCard), findsNothing);
  });

  testWidgets('wardrobe, room and hide and seek open up as the days pass', (tester) async {
    await launch(tester, beforeStart: () async {
      final now = DateTime.now();
      final today = DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch ~/ 86400000;
      await CompanionRepository().write({
        'first_seen_day': '${today - 100}',
        'max_seen_day': '$today',
        'announced': 'pamuk,fistik,tarcin,lokum',
      });
    });
    final companions = tester.element(find.byType(TodayScreen)).read<CompanionService>();
    expect(companions.unlocked, hasLength(4));

    await tester.tap(find.byTooltip('Arkadaşlar'));
    await settle(tester);
    await tester.tap(find.text('Gardırop'));
    await settle(tester);
    expect(find.text('Doğum gününde ya da ilk yıl dönümünde gelir'), findsOneWidget);
    await tapVisible(tester, find.text('Fiyonk'));
    await settle(tester);
    expect(companions.wearing(Companion.pamuk), Accessory.bow);
    await tapVisible(tester, find.text('Doğum gününde ya da ilk yıl dönümünde gelir')); // not there yet
    await settle(tester);
    expect(companions.wearing(Companion.pamuk), Accessory.bow);

    await tester.tap(find.text('Oda'));
    await settle(tester);
    final scene = find.byType(CompanionScene);
    expect(find.descendant(of: scene, matching: find.byType(CompanionSprite)), findsOneWidget);
    // Hide and seek: one of the three spots is right, the others say so kindly.
    await tapVisible(tester, find.text('Saklambaç oyna'));
    await settle(tester);
    expect(find.text('Pamuk nerede?'), findsOneWidget);
    final box = tester.getRect(scene);
    final u = box.width / CompanionScene.artWidth;
    for (final (x, y) in const [(22.0, 72.0), (139.0, 70.0), (36.0, 33.0)]) {
      if (find.text('Buldun beni!').evaluate().isNotEmpty) break;
      await tester.tapAt(box.topLeft + Offset(x * u, y * u));
      await settle(tester);
    }
    expect(find.text('Buldun beni!'), findsOneWidget);
    expect(find.text('Saklambaç oyna'), findsOneWidget);

    await tapVisible(tester, find.text('Hepsi birlikte'));
    await settle(tester);
    expect(find.descendant(of: scene, matching: find.byType(CompanionSprite)), findsNWidgets(4));
  });

  testWidgets('the bag checklist ticks from Today and counts what is ready', (tester) async {
    await launch(tester);
    await revealOnToday(tester, find.text('Çantam'));
    expect(find.text('0 / 5 hazır'), findsOneWidget);
    await tapVisible(tester, find.text('Çantam'));
    await settle(tester);
    expect(find.text('Ped ya da tampon'), findsOneWidget);
    await tapVisible(tester, find.text('Çikolata'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Şarj aleti');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(find.text('Şarj aleti'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await settle(tester);
    expect(find.text('1 / 6 hazır'), findsOneWidget);
  });

  testWidgets('Today tiles can be hidden; the countdown always stays', (tester) async {
    await launch(tester);
    await revealOnToday(tester, find.text('Bugün ekranını düzenle'));
    await tapVisible(tester, find.text('Bugün ekranını düzenle'));
    await settle(tester);
    expect(find.byType(TodayCustomizeScreen), findsOneWidget);
    Switch switchOf(String label) =>
        tester.widget(find.descendant(of: find.widgetWithText(ListTile, label), matching: find.byType(Switch)));
    expect(switchOf('Geri sayım').onChanged, isNull);
    await tester.tap(find.descendant(of: find.widgetWithText(ListTile, 'Ruh hali'), matching: find.byType(Switch)));
    await settle(tester);
    expect(switchOf('Ruh hali').value, isFalse);
    final settings = tester.element(find.byType(TodayCustomizeScreen)).read<SettingsService>();
    expect(settings.hiddenTodayTiles, {TodayTile.mood});

    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await settle(tester);
    await revealOnToday(tester, find.text('Hızlı kayıt'));
    expect(find.text('Bugün nasıl hissediyorsun?'), findsNothing);
    await tester.scrollUntilVisible(find.text('Regline 4 gün kaldı'), -200, scrollable: todayScrollable());
    expect(find.text('Regline 4 gün kaldı'), findsOneWidget);
  });

  testWidgets('look packs restyle the app and the icon choice reaches the launcher', (tester) async {
    await launch(tester);
    RuyaStyle style() => RuyaStyle.of(tester.element(find.byType(SettingsScreen, skipOffstage: false)));
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Ayarlar')));
    await settle(tester);
    expect(style().style, AppStyle.piksel);
    expect(style().pixel, isTrue);
    await tester.tap(find.text('Görünüm'));
    await settle(tester);
    await tapVisible(tester, find.widgetWithText(StylePackTile, 'Bahçe'));
    await settle(tester);
    expect(style().style, AppStyle.bahce);
    expect(style().pixel, isFalse);

    identityCalls.clear();
    await scrollToTap(tester, find.text('Pamuk'), within: AppearanceSettingsScreen);
    await settle(tester);
    expect(identityCalls.where((c) => c.method == 'setLauncher').single.arguments, {'alias': 'Pamuk'});
    // Tarçın has not arrived yet, so its icon waits with it.
    expect(find.text('30 gün sonra'), findsOneWidget);
    expect(find.text('Tarçın'), findsNothing);

    // Discrete mode takes the icon over and gives the choice back afterwards.
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await settle(tester);
    await tester.tap(find.text('Gizlilik'));
    await settle(tester);
    await tapVisible(tester, find.text('Gizli mod').last);
    await settle(tester);
    expect(launcherAlias, 'Discrete');
    expect(style().discrete, isTrue);
    await tapVisible(tester, find.text('Gizli mod').last);
    await settle(tester);
    expect(launcherAlias, 'Pamuk');
  });

  testWidgets('what repeated across cycles shows on Today and in the insights', (tester) async {
    await launch(tester, beforeStart: () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final logs = LogsRepository();
      for (final startOffset in [80, 52, 24]) {
        final day = today.subtract(Duration(days: startOffset - 1));
        final existing = await logs.readLogForDate(day);
        await logs.upsertLog(LogDay(
          id: existing!.id,
          date: day,
          flow: FlowRate.medium,
          periodId: existing.periodId,
          symptoms: [Symptom(type: SymptomType.headache)],
        ));
      }
    });
    await revealOnToday(tester, find.text('2. gün: Baş ağrısı'));
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('İçgörüler')));
    await settle(tester);
    final outer = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.textContaining('yalnızca gözlemdir'), 300, scrollable: outer);
    expect(find.text('2. gün: Baş ağrısı'), findsOneWidget);
    expect(find.textContaining('Son 3 döngünün 3 tanesinde'), findsOneWidget);
  });

  testWidgets('insights show overview, mood by phase and cycle history', (tester) async {
    await launch(tester);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('İçgörüler')));
    await settle(tester);
    expect(find.text('Ortalama döngü'), findsOneWidget);
    final outer = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Faza göre ruh hali'), 300, scrollable: outer);
    expect(find.text('Faza göre ruh hali'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Döngü geçmişi'), 300, scrollable: outer);
    await tester.scrollUntilVisible(find.text('şu anki'), 200, scrollable: outer);
    expect(find.text('şu anki'), findsOneWidget);
    expect(find.text('28 gün'), findsWidgets);
  });

  testWidgets('kid mode hides sex and libido in the log sheet and calendar', (tester) async {
    await launch(tester, initialPrefs: {'kid_mode': true, 'sex_activity_nav_enabled': true});
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Takvim')));
    await settle(tester);
    expect(find.text('Cinsel ilişki'), findsNothing);
    expect(find.text('Doğum kontrolü'), findsOneWidget);

    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Kayıt')));
    await settle(tester);
    // The sexual activity tracker is hidden even though its toggle is on.
    expect(find.text('Cinsel Aktivite'), findsNothing);
    await tester.tap(find.byType(FloatingActionButton));
    await settle(tester);
    final sheetList = find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('Notlar'), 300, scrollable: sheetList);
    expect(find.text('Doğum kontrolü'), findsOneWidget);
    expect(find.text('Cinsel ilişki'), findsNothing);
    expect(find.text('Libido'), findsNothing);
  });

  String isoDaysAgo(int days) {
    final n = DateTime.now();
    final d = DateTime(n.year, n.month, n.day - days);
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  testWidgets('pregnancy mode shows weeks and due date instead of predictions', (tester) async {
    await launch(tester, initialPrefs: {'pregnancy_spans': '[{"start":"${isoDaysAgo(88)}","end":null}]'});
    expect(find.text('Gebelik · 12 hafta 4 gün'), findsOneWidget);
    expect(find.textContaining('Tahmini doğum tarihi'), findsOneWidget);
    expect(find.textContaining('Regline'), findsNothing);
    expect(find.textContaining('Bugün:'), findsNothing);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Takvim')));
    await settle(tester);
    expect(find.text('PMS (beklenen)'), findsNothing);
  });

  testWidgets('birth control mode predicts the expected bleed and hides phases', (tester) async {
    await launch(tester, initialPrefs: {'hormonal_bc_spans': '[{"start":"${isoDaysAgo(60)}","end":null}]'});
    expect(find.text('Beklenen kanamaya 4 gün kaldı'), findsOneWidget);
    expect(find.text('Hormonal doğum kontrolü açıkken faz tahminleri gösterilmez.'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Takvim')));
    await settle(tester);
    expect(find.text('Tahmini kanama'), findsOneWidget);
    expect(find.text('Doğurgan (tahmini)'), findsNothing);
  });

  testWidgets('pregnancy mode can be started and ended from settings', (tester) async {
    await launch(tester);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Ayarlar')));
    await settle(tester);
    await tapVisible(tester, find.text('Gebelik modu'));
    await settle(tester);
    await tester.tap(find.text('Gebelik modunu başlat'));
    await settle(tester);
    await tester.tap(find.text('Tamam'));
    await settle(tester);
    expect(find.text('Gebelik modunu sonlandır'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await settle(tester);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Bugün')));
    await settle(tester);
    expect(find.textContaining('Gebelik ·'), findsOneWidget);
  });

  testWidgets('widget settings preview reacts to content and size choices', (tester) async {
    await launch(tester);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Ayarlar')));
    await settle(tester);
    await tapVisible(tester, find.text("Ana ekran widget'ı"));
    await settle(tester);
    expect(find.byType(WidgetPreview), findsOneWidget);
    expect(find.text('Regline 4 gün kaldı'), findsOneWidget);
    expect(find.textContaining('Döngünün'), findsNothing);
    final petInPreview = find.descendant(of: find.byType(WidgetPreview), matching: find.byType(CompanionFrame));
    expect(petInPreview, findsOneWidget); // the medium widget shows the companion

    await scrollToTap(tester, find.text('Arkadaşın'), within: WidgetSettingsScreen);
    await settle(tester);
    await tester.scrollUntilVisible(find.byType(WidgetPreview), -300);
    expect(petInPreview, findsNothing);

    await tapVisible(tester, find.text('Döngü günü'));
    await settle(tester);
    await tester.scrollUntilVisible(find.byType(WidgetPreview), -300);
    expect(find.textContaining('Döngünün 25. günü'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Küçük\n2×2'), -300);
    await tapVisible(tester, find.text('Küçük\n2×2'));
    await settle(tester);
    expect(find.text('Regline 4 gün kaldı'), findsNothing); // small shows only the countdown
    // The sticker is only the companion and does not follow the "companion" switch above.
    await tapVisible(tester, find.text('Çıkartma\n2×2'));
    await settle(tester);
    expect(petInPreview, findsOneWidget);
    expect(find.textContaining('yazı, sayı ve çerçeve yok'), findsOneWidget);
    await tapVisible(tester, find.text("Ana ekrana ekle"));
    await settle(tester);
    expect(find.textContaining('uzun bas'), findsOneWidget); // pinning unsupported in tests
  });

  testWidgets('privacy settings are reachable from settings', (tester) async {
    await launch(tester);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Ayarlar')));
    await settle(tester);
    expect(find.text('Hakkında'), findsNothing);
    await tester.tap(find.text('Gizlilik'));
    await settle(tester);
    expect(find.text('PIN kilidi'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Şifreli yedek'), 200);
    await tapVisible(tester, find.text('Şifreli yedek'));
    await settle(tester);
    expect(find.text('Şifreli yedek oluştur'), findsWidgets);
  });
}

/// Scrolls the lazy list inside [within] until [finder] is built, then taps it.
Future<void> scrollToTap(WidgetTester tester, Finder finder, {required Type within}) async {
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find.descendant(of: find.byType(within), matching: find.byType(Scrollable)).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

Finder todayScrollable() => find.descendant(of: find.byType(TodayScreen), matching: find.byType(Scrollable)).first;

/// The Today screen is a lazy list; scroll until [finder] is built and on screen.
Future<void> revealOnToday(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: todayScrollable());
  await tester.pumpAndSettle();
  expect(finder, findsWidgets);
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
