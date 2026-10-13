import 'package:flutter_test/flutter_test.dart';
import 'package:ruya/companion/companion.dart';
import 'package:ruya/companion/companion_service.dart';
import 'package:ruya/companion/room.dart';
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

    test('tea in the evening, and the log still comes first', () {
      expect(companionMoodFor(now: DateTime(2026, 10, 8, 19)), CompanionMood.tea);
      expect(
        companionMoodFor(now: DateTime(2026, 10, 8, 19), todayLog: LogDay(date: day, flow: FlowRate.medium)),
        CompanionMood.cozy,
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

    test('accessories arrive with the calendar and the choice is remembered per companion', () async {
      final s = service();
      await s.load();
      expect(s.isAccessoryUnlocked(Accessory.bow), isFalse);
      await s.setWearing(Companion.pamuk, Accessory.bow);
      expect(s.wearing(Companion.pamuk), isNull);

      now = now.add(const Duration(days: 21));
      final later = service();
      await later.load();
      expect(later.isAccessoryUnlocked(Accessory.daisy), isTrue);
      expect(later.daysUntilAccessory(Accessory.beanie), 24);
      await later.setWearing(Companion.pamuk, Accessory.daisy);
      final again = service();
      await again.load();
      expect(again.wearing(Companion.pamuk), Accessory.daisy);
      expect(again.wearing(Companion.fistik), isNull);
      await again.setWearing(Companion.pamuk, null);
      expect(again.wearing(Companion.pamuk), isNull);
    });

    test('room items go into their own slot only, once they have arrived', () async {
      final s = service();
      await s.load();
      expect(s.roomItem(RoomSlot.window)?.id, kDefaultRoom[RoomSlot.window]);
      final locked = kRoomItems.values.firstWhere((i) => i.unlockDay > 0);
      await s.setRoomItem(locked.slot, locked);
      expect(s.roomItem(locked.slot)?.id, isNot(locked.id));

      now = now.add(Duration(days: locked.unlockDay));
      final later = service();
      await later.load();
      await later.setRoomItem(locked.slot, locked);
      final wrongSlot = RoomSlot.values.firstWhere((x) => x != locked.slot);
      final before = later.roomItem(wrongSlot)?.id;
      await later.setRoomItem(wrongSlot, locked);
      expect(later.roomItem(wrongSlot)?.id, before);
      await later.setShowTogether(true);

      final again = service();
      await again.load();
      expect(again.roomItem(locked.slot)?.id, locked.id);
      expect(again.showTogether, isTrue);
      await again.setRoomItem(locked.slot, null);
      expect(again.roomItem(locked.slot), isNull);
    });

    test('birthday: everyone wears the party hat, the greeting shows once and the hat stays', () async {
      final s = service()..birthDate = DateTime(2010, 10, 8);
      await s.load();
      expect(s.isBirthday, isTrue);
      expect(s.hasUnseenSpecialDay, isTrue);
      expect(s.wearing(Companion.pamuk), Accessory.party);
      expect(s.isSpecialDate(DateTime(2027, 10, 8)), isTrue);
      expect(s.isSpecialDate(DateTime(2026, 10, 9)), isFalse);
      await s.markSpecialDaySeen();
      expect(s.hasUnseenSpecialDay, isFalse);

      now = now.add(const Duration(days: 1));
      final next = service()..birthDate = DateTime(2010, 10, 8);
      await next.load();
      expect(next.isSpecialDay, isFalse);
      expect(next.wearing(Companion.pamuk), isNull);
      expect(next.isAccessoryUnlocked(Accessory.party), isTrue);
    });

    test('the anniversary comes a year after the first day, not before', () async {
      await service().load();
      now = DateTime(2027, 10, 7, 9);
      final eve = service();
      await eve.load();
      expect(eve.anniversaryYears, isNull);
      now = DateTime(2027, 10, 8, 9);
      final day = service();
      await day.load();
      expect(day.anniversaryYears, 1);
      expect(day.isSpecialDate(DateTime(2028, 10, 8)), isTrue);
      expect(day.isSpecialDate(DateTime(2026, 10, 8)), isFalse);
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
