import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The little "pack your bag" checklist for the days before a period. The
/// ticks clear themselves when a new cycle starts.
class BagService extends ChangeNotifier {
  BagService() {
    _load();
  }

  Future<void> _load() async {
    final prefs = _prefs = await SharedPreferences.getInstance();
    _items = prefs.getStringList(_itemsKey);
    _checked = (prefs.getStringList(_checkedKey) ?? const []).toSet();
    _cycle = prefs.getString(_cycleKey);
    _ready = true;
    notifyListeners();
  }

  static const _itemsKey = 'bag_items';
  static const _checkedKey = 'bag_checked';
  static const _cycleKey = 'bag_cycle';
  static const int maxItems = 20;
  static const int maxLength = 40;

  SharedPreferences? _prefs;
  bool _ready = false;

  bool get isReady => _ready;
  List<String>? _items;
  Set<String> _checked = {};
  String? _cycle;

  /// Null until the default list was written (needs localized names).
  List<String>? get items => _items;
  int get doneCount => (_items ?? const []).where(_checked.contains).length;
  bool isChecked(String item) => _checked.contains(item);

  Future<void> ensureDefaults(List<String> defaults) async {
    if (!_ready || _items != null) return;
    _items = List.of(defaults);
    await _prefs?.setStringList(_itemsKey, _items!);
    notifyListeners();
  }

  /// Clears the ticks when [cycleKey] (the expected start date) changes.
  Future<void> syncCycle(String? cycleKey) async {
    if (!_ready || cycleKey == null || cycleKey == _cycle) return;
    _cycle = cycleKey;
    _checked = {};
    await _prefs?.setString(_cycleKey, cycleKey);
    await _prefs?.setStringList(_checkedKey, const []);
    notifyListeners();
  }

  Future<void> toggle(String item) async {
    if (!_checked.remove(item)) _checked.add(item);
    await _prefs?.setStringList(_checkedKey, _checked.toList());
    notifyListeners();
  }

  Future<void> add(String item) async {
    final name = item.trim();
    final list = _items ?? [];
    if (name.isEmpty || list.contains(name) || list.length >= maxItems) return;
    list.add(name.length > maxLength ? name.substring(0, maxLength) : name);
    _items = list;
    await _prefs?.setStringList(_itemsKey, list);
    notifyListeners();
  }

  Future<void> remove(String item) async {
    _items?.remove(item);
    _checked.remove(item);
    await _prefs?.setStringList(_itemsKey, _items ?? const []);
    await _prefs?.setStringList(_checkedKey, _checked.toList());
    notifyListeners();
  }
}
