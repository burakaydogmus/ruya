import 'package:flutter_test/flutter_test.dart';
import 'package:ruya/companion/companion.dart';
import 'package:ruya/companion/companion_service.dart';
import 'package:ruya/models/flows/flow_enum.dart';
import 'package:ruya/models/period_logs/daily_log_enums.dart';
import 'package:ruya/models/period_logs/log_day.dart';
import 'package:ruya/models/period_logs/pain_level_enum.dart';

class _MemoryRepository extends CompanionRepository {
  final values = <String, String>{};

  @override
  Future<Map<String, String>> readAll() async => Map.of(values);

  @override
  Future<void> write(Map<String, String> v) async => values.addAll(v);

  @override
  Future<void> clear() async => values.clear();
}

void main() {
  group('companion mood', () {
    final noon = DateTime(2026, 10, 8, 12);
    final day = DateTime(2026, 10, 8);

    test('calm by day and sleepy at night, whatever the usage', () {
      expect(companionMoodFor(now: noon), CompanionMood.calm);
      expect(companionMoodFor(now: DateTime(2026, 10, 8, 23)), CompanionMood.sleepy);
      expect(companionMoodFor(now: DateTime(2026, 10, 8, 3)), CompanionMood.sleepy);
    });

    test('cozy on a logged period day, comfort for pain or a low mood', () {
      expect(companionMoodFor(now: noon, todayLog: LogDay(date: day, flow: FlowRate.medium)),
          CompanionMood.cozy);
      expect(
        companionMoodFor(
            now: noon, todayLog: LogDay(date: day, flow: FlowRate.light, painLevel: PainLevel.severe.index)),
        CompanionMood.comfort,
      );
      expect(companionMoodFor(now: noon, todayLog: LogDay(date: day, flow: FlowRate.none, moods: [Mood.sad])),
          CompanionMood.comfort);
      expect(companionMoodFor(now: noon, todayLog: LogDay(date: day, flow: FlowRate.none, moods: [Mood.happy])),
          CompanionMood.calm);
      expect(
        companionMoodFor(now: noon, todayLog: LogDay(date: day, flow: FlowRate.none, painLevel: PainLevel.mild.index)),
        CompanionMood.calm,
      );
    });

    test('every mood loop only uses frames that exist in the sheet', () {
      for (final mood in CompanionMood.values) {
        for (final (frame, ms) in CompanionFrames.loop(mood)) {
          expect(frame, inInclusiveRange(0, CompanionFrames.count - 1));
          expect(ms, greaterThan(0));
        }
      }
    });
  });

  group('CompanionService', () {
    late _MemoryRepository repo;
    late DateTime now;
    CompanionService service() => CompanionService(repo, clock: () => now);

    setUp(() {
      repo = _MemoryRepository();
      now = DateTime(2026, 10, 8, 9);
    });

    test('only Pamuk is there on the first day', () async {
      final s = service();
      await s.load();
      expect(s.daysTogether, 0);
      expect(s.unlocked, [Companion.pamuk]);
      expect(s.newArrivals, isEmpty);
      expect(s.daysUntil(Companion.fistik), 7);
    });

    test('friends arrive by calendar days, without opening the app in between', () async {
      await service().load();
      now = now.add(const Duration(days: 31));
      final s = service();
      await s.load();
      expect(s.daysTogether, 31);
      expect(s.unlocked, [Companion.pamuk, Companion.fistik, Companion.tarcin]);
      expect(s.newArrivals, [Companion.fistik, Companion.tarcin]);
      await s.markAnnounced(s.newArrivals);
      final again = service();
      await again.load();
      expect(again.newArrivals, isEmpty);
    });

    test('moving the clock back never takes a friend away', () async {
      await service().load();
      now = now.add(const Duration(days: 8));
      await service().load();
      now = now.subtract(const Duration(days: 8));
      final s = service();
      await s.load();
      expect(s.isUnlocked(Companion.fistik), isTrue);
    });

    test('choice, nickname and visibility are remembered; locked friends cannot be chosen', () async {
      final s = service();
      await s.load();
      await s.select(Companion.boncuk);
      expect(s.selected, Companion.pamuk);
      await s.rename(Companion.pamuk, '  Bulutçuk  ');
      await s.setHidden(true);
      final again = service();
      await again.load();
      expect(again.nickname(Companion.pamuk), 'Bulutçuk');
      expect(again.isHidden, isTrue);
      await again.rename(Companion.pamuk, '');
      expect(again.nickname(Companion.pamuk), isNull);
    });

    test('reset starts over from today', () async {
      await service().load();
      now = now.add(const Duration(days: 40));
      final s = service();
      await s.load();
      await s.reset();
      expect(s.daysTogether, 0);
      expect(s.unlocked, [Companion.pamuk]);
    });
  });
}
