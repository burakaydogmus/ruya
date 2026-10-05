import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruya/services/notification_service.dart';
import 'package:ruya/utils/constants.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];

  setUpAll(() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async {
        calls.add(call);
        return switch (call.method) {
          'initialize' || 'requestNotificationsPermission' => true,
          'pendingNotificationRequests' => <Object>[],
          _ => null,
        };
      },
    );
    await NotificationService.initialize();
  });

  setUp(calls.clear);
  tearDown(() => NotificationService.setDiscrete(null));

  List<Map> scheduled() =>
      calls.where((c) => c.method == 'zonedSchedule').map((c) => c.arguments as Map).toList();

  final future = DateTime.now().add(const Duration(days: 10));

  test('due and overdue period reminders use different IDs', () async {
    await NotificationService.schedulePeriodNotifications(
      scheduledTime: future,
      notificationTime: const TimeOfDay(hour: 9, minute: 0),
      title: 'due',
      body: 'b',
      daysBefore: 1,
    );
    await NotificationService.schedulePeriodNotifications(
      scheduledTime: future,
      notificationTime: const TimeOfDay(hour: 9, minute: 0),
      title: 'late',
      body: 'b',
      daysAfter: 2,
    );
    final ids = scheduled().map((a) => a['id']).toList();
    expect(ids, [periodDueNotificationId, periodOverdueNotificationId]);
  });

  test('discrete mode replaces text and channel and hides on the lock screen', () async {
    await NotificationService.setDiscrete(
      const NeutralNotificationText(title: 'Hatırlatma', body: 'Not', channelName: 'Hatırlatmalar'),
    );
    expect(
      calls.where((c) => c.method == 'deleteNotificationChannel').map((c) => c.arguments),
      containsAll(NotificationService.revealingChannelIds),
    );
    await NotificationService.schedulePillReminder(
      reminderTime: const TimeOfDay(hour: 8, minute: 0),
      isEnabled: true,
      title: 'Hap zamanı',
      body: 'Hapını al',
    );
    final args = scheduled().single;
    expect(args['title'], 'Hatırlatma');
    expect(args['body'], 'Not');
    final details = args['platformSpecifics'] as Map;
    expect(details['channelId'], NotificationService.discreteChannelId);
    expect(details['channelName'], 'Hatırlatmalar');
    expect(details['visibility'], NotificationVisibility.secret.index);
  });
}
