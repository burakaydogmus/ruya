import 'package:flutter_test/flutter_test.dart';
import 'package:ruya/services/bag_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<BagService> ready() async {
  final bag = BagService();
  while (!bag.isReady) {
    await Future<void>.delayed(Duration.zero);
  }
  return bag;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the default list is written once and ticks are remembered', () async {
    final bag = await ready();
    expect(bag.items, isNull);
    await bag.ensureDefaults(['Ped', 'Su']);
    await bag.ensureDefaults(['Başka']);
    expect(bag.items, ['Ped', 'Su']);
    await bag.toggle('Ped');
    expect(bag.doneCount, 1);

    final again = await ready();
    expect(again.items, ['Ped', 'Su']);
    expect(again.isChecked('Ped'), isTrue);
  });

  test('ticks clear when the next cycle starts, the list stays', () async {
    final bag = await ready();
    await bag.ensureDefaults(['Ped', 'Su']);
    await bag.syncCycle('2026-10-20');
    await bag.toggle('Su');
    await bag.syncCycle('2026-10-20');
    expect(bag.doneCount, 1);
    await bag.syncCycle('2026-11-17');
    expect(bag.doneCount, 0);
    expect(bag.items, ['Ped', 'Su']);
  });

  test('own items can be added and removed; blanks, duplicates and long names are tamed', () async {
    final bag = await ready();
    await bag.ensureDefaults(['Ped']);
    await bag.add('  Çikolata ');
    await bag.add('Çikolata');
    await bag.add('   ');
    await bag.add('x' * 80);
    expect(bag.items, ['Ped', 'Çikolata', 'x' * BagService.maxLength]);
    await bag.toggle('Çikolata');
    await bag.remove('Çikolata');
    expect(bag.items, isNot(contains('Çikolata')));
    expect(bag.doneCount, 0);
  });
}
