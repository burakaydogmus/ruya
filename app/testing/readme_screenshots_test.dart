import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
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
import 'package:ruya/models/period_logs/symptom.dart';
import 'package:ruya/models/period_logs/symptom_type_enum.dart';
import 'package:ruya/security/app_lock_controller.dart';
import 'package:ruya/security/crypto/pbkdf2.dart';
import 'package:ruya/security/field_cipher.dart';
import 'package:ruya/security/pin_service.dart';
import 'package:ruya/security/secure_key_value_store.dart';
import 'package:ruya/services/notification_service.dart';
import 'package:ruya/services/settings_service.dart';
import 'package:ruya/services/symptom_service.dart';
import 'package:ruya/services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Renders the README screenshots into `docs/screenshots/` with demo data.
///
/// Not part of `flutter test`; run it explicitly from `app/`:
///   flutter test testing/readme_screenshots_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  Pbkdf2Sha256.useNative = false;

  final outDir = Directory(p.join('..', 'docs', 'screenshots'));
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final name in ['home_widget', 'watch_connectivity/methods', 'com.burakaydogmus.ruya/app_identity']) {
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

  setUp(() {
    messenger.setMockStreamHandler(
      const EventChannel('home_widget/updates'),
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
  });

  setUpAll(() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    await NotificationService.initialize();
    await _loadFonts();
    outDir.createSync(recursive: true);
  });

  tearDown(() async => AppDatabase.instance.close());

  Future<void> launch(WidgetTester tester, {String? pin, Brightness brightness = Brightness.light}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    tester.view.padding = const FakeViewPadding(top: 24 * 2.75);
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({'language': 'tr'});
      PackageInfo.setMockInitialValues(
        appName: 'RUYA', packageName: 'com.burakaydogmus.ruya', version: '1.2.2',
        buildNumber: '5', buildSignature: '',
      );
      final store = InMemorySecureKeyValueStore();
      FieldCipher.instance.reset();
      await FieldCipher.instance.init(store);
      await AppDatabase.instance.init(inMemory: true);
      await UserRepository().saveUser(UserEntry(name: 'Elif', primaryGoal: UserGoalTypes.general));
      await _seedDemoHistory();

      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService(prefs);
      final pins = PinService(store);
      if (pin != null) await pins.setPin(pin);
      final lock = AppLockController(
        pinService: pins,
        timeoutSeconds: () => settings.pinTimeoutSeconds,
        biometricsPreferred: () => settings.areBiometricsEnabled,
        biometricsAvailable: () async => true,
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
    await _settle(tester);
  }

  Future<void> shoot(WidgetTester tester, String name) async {
    await _settle(tester);
    await tester.runAsync(() async {
      final image = await _drawEmoji(tester, await captureImage(find.byType(MaterialApp).evaluate().single));
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File(p.join(outDir.path, '$name.png')).writeAsBytesSync(png!.buffer.asUint8List());
    });
  }

  Future<void> openTab(WidgetTester tester, String tab) async {
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(tab)));
    await _settle(tester);
  }

  // Tests draw without shadows by default; the flag must be restored before
  // the test body ends.
  void screenshot(String description, Future<void> Function(WidgetTester) body) {
    testWidgets(description, (tester) async {
      debugDisableShadows = false;
      try {
        await body(tester);
      } finally {
        debugDisableShadows = true;
      }
    });
  }

  screenshot('today', (tester) async {
    await launch(tester);
    await shoot(tester, '01_today');
  });

  screenshot('calendar', (tester) async {
    await launch(tester);
    await openTab(tester, 'Takvim');
    await shoot(tester, '02_calendar');
  });

  screenshot('daily log', (tester) async {
    await launch(tester);
    await openTab(tester, 'Kayıt');
    await tester.tap(find.byType(FloatingActionButton));
    await _settle(tester);
    final sheet = find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first;
    await tester.drag(sheet, const Offset(0, -450));
    await shoot(tester, '03_daily_log');
  });

  screenshot('insights', (tester) async {
    await launch(tester);
    await openTab(tester, 'İçgörüler');
    final outer = find.byType(Scrollable).first;
    await tester.drag(outer, const Offset(0, -200));
    await shoot(tester, '04_insights');
    await tester.scrollUntilVisible(find.text('Faza göre ruh hali'), 300, scrollable: outer);
    Scrollable.ensureVisible(tester.element(find.text('Faza göre ruh hali')), alignment: 0.05);
    await tester.pumpAndSettle();
    await shoot(tester, '05_insights_mood');
  });

  screenshot('privacy settings', (tester) async {
    await launch(tester, pin: '2580');
    for (final digit in '2580'.split('')) {
      await tester.tap(find.text(digit));
      await tester.pump();
    }
    await tester.tap(find.text('Kilidi aç'));
    await _settle(tester);
    await openTab(tester, 'Ayarlar');
    await tester.tap(find.text('Gizlilik'));
    await _settle(tester);
    await shoot(tester, '06_privacy');
  });

  screenshot('lock screen', (tester) async {
    await launch(tester, pin: '2580');
    await shoot(tester, '07_lock');
  });

  screenshot('today dark', (tester) async {
    await launch(tester, brightness: Brightness.dark);
    await shoot(tester, '08_today_dark');
  });
}

/// Six cycles of 27–30 days; the current one started 12 days ago, so the
/// fertile window is on screen. Moods and symptoms fill the insights.
Future<void> _seedDemoHistory() async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  DateTime day(int offset) => today.subtract(Duration(days: offset));

  const starts = [154, 125, 98, 70, 40, 12];
  const flows = [FlowRate.heavy, FlowRate.heavy, FlowRate.medium, FlowRate.medium, FlowRate.light, FlowRate.spotting];
  final logs = <int, LogDay>{};
  for (final (i, start) in starts.indexed) {
    final length = 4 + i % 3;
    for (var d = 0; d < length; d++) {
      logs[start - d] = LogDay(
        date: day(start - d),
        flow: flows[(d * flows.length / length).floor()],
        painLevel: d < 2 ? 3 - d : null,
        symptoms: [
          if (d == 0) Symptom(type: SymptomType.cramps),
          if (d < 2) Symptom(type: SymptomType.fatigue),
          if (d == 1 && i.isEven) Symptom(type: SymptomType.backPain),
        ],
        moods: [if (d == 0) Mood.tired, if (d == 1) Mood.sad, if (d == 3) Mood.calm],
      );
    }
    // Ovulation-time and PMS-time moods, so "mood by phase" has data.
    final next = i + 1 < starts.length ? starts[i + 1] : null;
    if (next != null) {
      logs[start - 13] = LogDay(date: day(start - 13), flow: FlowRate.none, moods: [Mood.energetic, Mood.confident], libido: Libido.high);
      logs[start - 8] = LogDay(date: day(start - 8), flow: FlowRate.none, moods: [Mood.happy, Mood.focused]);
      logs[next + 3] = LogDay(
        date: day(next + 3), flow: FlowRate.none,
        moods: [Mood.irritable, Mood.anxious],
        symptoms: [Symptom(type: SymptomType.bloating), Symptom(type: SymptomType.tenderBreasts)],
      );
      logs[next + 1] = LogDay(date: day(next + 1), flow: FlowRate.none, moods: [Mood.moodSwings], symptoms: [Symptom(type: SymptomType.acne)]);
    }
  }
  logs[4] = LogDay(date: day(4), flow: FlowRate.none, moods: [Mood.calm]);
  logs[1] = LogDay(date: day(1), flow: FlowRate.none, moods: [Mood.focused], discharge: Discharge.creamy);
  logs[0] = LogDay(date: today, flow: FlowRate.none, moods: [Mood.happy, Mood.energetic], discharge: Discharge.eggWhite);

  final repo = LogsRepository();
  for (final log in logs.values) {
    await repo.upsertLog(log);
  }
  final mapping = await PeriodsRepository().recalculateAndAssignPeriods(await repo.readAllLogs());
  await repo.updateLogPeriodIds(mapping);
}

/// Tests render text with a box font; load Roboto and Material icons from the
/// Flutter SDK so the screenshots look like the device. Color emoji do not
/// render in tests (font fallback is off), so they are painted afterwards.
Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT']!;
  final material = p.join(root, 'bin', 'cache', 'artifacts', 'material_fonts');
  final emoji = p.join(root, 'engine', 'src', 'flutter', 'txt', 'third_party', 'fonts', 'NotoColorEmoji.ttf');

  Future<ByteData> read(String path) async => ByteData.sublistView(File(path).readAsBytesSync());

  final roboto = FontLoader('Roboto');
  for (final weight in ['Light', 'Regular', 'Medium', 'Bold', 'Black']) {
    roboto.addFont(read(p.join(material, 'Roboto-$weight.ttf')));
  }
  await roboto.load();
  _emojiFont = _ColorEmojiFont(File(emoji).readAsBytesSync());

  await (FontLoader('MaterialIcons')..addFont(read(p.join(material, 'MaterialIcons-Regular.otf')))).load();
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
}

late _ColorEmojiFont _emojiFont;

/// Paints the emoji of every visible text over the captured screen: the box
/// the missing glyph left behind is filled with the surrounding color, then
/// the Noto Color Emoji bitmap is drawn in its place.
Future<ui.Image> _drawEmoji(WidgetTester tester, ui.Image screen) async {
  final dpr = tester.view.devicePixelRatio;
  final pixels = (await screen.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  Color pixelAt(Offset logical) {
    final x = (logical.dx * dpr).round().clamp(0, screen.width - 1);
    final y = (logical.dy * dpr).round().clamp(0, screen.height - 1);
    final i = (y * screen.width + x) * 4;
    return Color.fromARGB(255, pixels.getUint8(i), pixels.getUint8(i + 1), pixels.getUint8(i + 2));
  }

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..drawImage(screen, Offset.zero, Paint());
  for (final paragraph in find.byType(RichText).evaluate().map((e) => e.renderObject! as RenderParagraph)) {
    final text = paragraph.text.toPlainText(includeSemanticsLabels: false);
    final fontSize = paragraph.text.style?.fontSize ?? 14;
    // ignore: valid_regexps (the analyzer does not know Unicode property escapes)
    for (final match in RegExp(r'\p{Extended_Pictographic}\u{FE0F}?', unicode: true).allMatches(text)) {
      final boxes = paragraph.getBoxesForSelection(TextSelection(baseOffset: match.start, extentOffset: match.end));
      if (boxes.isEmpty) continue;
      final rect = boxes.map((b) => b.toRect()).reduce((a, b) => a.expandToInclude(b));
      final topLeft = paragraph.localToGlobal(rect.topLeft);
      final global = topLeft & rect.size;
      // Skip text that is scrolled away or covered (e.g. by a bottom sheet).
      // Chips do not hit-test their avatar, so a near ancestor is enough.
      final hit = HitTestResult();
      tester.binding.hitTestInView(hit, global.center, tester.view.viewId);
      final targets = hit.path.map((entry) => entry.target).toSet();
      final near = <RenderObject>[];
      for (RenderObject? node = paragraph; node != null && near.length < 8; node = node.parent) {
        near.add(node);
      }
      if (!near.any(targets.contains)) continue;

      canvas.drawRect(
        Rect.fromLTWH(global.left * dpr, global.top * dpr, global.width * dpr, global.height * dpr),
        Paint()..color = pixelAt(global.centerLeft - const Offset(1.5, 0)),
      );
      // Emoji newer than the SDK's Noto font (e.g. 🫶) are left blank.
      final bitmap = await _emojiFont.image(match.group(0)!.runes.first);
      if (bitmap == null) continue;
      final scale = paragraph.getTransformTo(null).getMaxScaleOnAxis();
      final size = fontSize * scale * 1.17;
      canvas.drawImageRect(
        bitmap,
        Offset.zero & Size(bitmap.width.toDouble(), bitmap.height.toDouble()),
        Rect.fromCenter(center: global.center * dpr, width: size * dpr, height: size * dpr),
        Paint()..filterQuality = FilterQuality.high,
      );
    }
  }
  return recorder.endRecording().toImage(screen.width, screen.height);
}

/// Reads PNG glyphs out of a CBDT/CBLC color font (Noto Color Emoji).
class _ColorEmojiFont {
  _ColorEmojiFont(Uint8List bytes) : _data = ByteData.sublistView(bytes) {
    for (var i = 0; i < _data.getUint16(4); i++) {
      final record = 12 + 16 * i;
      _tables[String.fromCharCodes(bytes.sublist(record, record + 4))] = _data.getUint32(record + 8);
    }
  }

  final ByteData _data;
  final _tables = <String, int>{};
  final _cache = <int, ui.Image?>{};

  Future<ui.Image?> image(int codePoint) async {
    if (_cache.containsKey(codePoint)) return _cache[codePoint];
    final glyph = _glyphId(codePoint);
    final png = glyph == null ? null : _png(glyph);
    ui.Image? image;
    if (png != null) {
      final codec = await ui.instantiateImageCodec(png);
      image = (await codec.getNextFrame()).image;
    }
    return _cache[codePoint] = image;
  }

  /// cmap format 12 (Windows, full Unicode).
  int? _glyphId(int codePoint) {
    final cmap = _tables['cmap']!;
    for (var i = 0; i < _data.getUint16(cmap + 2); i++) {
      final record = cmap + 4 + 8 * i;
      final table = cmap + _data.getUint32(record + 4);
      if (_data.getUint16(table) != 12) continue;
      for (var g = 0; g < _data.getUint32(table + 12); g++) {
        final group = table + 16 + 12 * g;
        final start = _data.getUint32(group);
        if (codePoint >= start && codePoint <= _data.getUint32(group + 4)) {
          return _data.getUint32(group + 8) + codePoint - start;
        }
      }
    }
    return null;
  }

  /// First strike; index subtable format 1, image format 17 (small metrics + PNG).
  Uint8List? _png(int glyph) {
    final cblc = _tables['CBLC']!;
    final cbdt = _tables['CBDT']!;
    final arrayOffset = _data.getUint32(cblc + 8);
    for (var i = 0; i < _data.getUint32(cblc + 8 + 8); i++) {
      final entry = cblc + arrayOffset + 8 * i;
      final first = _data.getUint16(entry);
      if (glyph < first || glyph > _data.getUint16(entry + 2)) continue;
      final subtable = cblc + arrayOffset + _data.getUint32(entry + 4);
      if (_data.getUint16(subtable) != 1 || _data.getUint16(subtable + 2) != 17) return null;
      final imageData = cbdt + _data.getUint32(subtable + 4) + _data.getUint32(subtable + 8 + 4 * (glyph - first));
      final length = _data.getUint32(imageData + 5);
      return _data.buffer.asUint8List(_data.offsetInBytes + imageData + 9, length);
    }
    return null;
  }
}
