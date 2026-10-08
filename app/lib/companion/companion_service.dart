import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:ruya/companion/companion.dart';
import 'package:ruya/database/app_database.dart';

/// Companion state in the encrypted database (table `companion`), so it is part
/// of the encrypted backup and of "delete all data".
class CompanionRepository {
  CompanionRepository({AppDatabase? database}) : _db = database ?? AppDatabase.instance;

  final AppDatabase _db;

  Future<Map<String, String>> readAll() async {
    final db = await _db.database;
    final rows = await db.query('companion');
    return {for (final r in rows) r['key'] as String: r['value'] as String};
  }

  Future<void> write(Map<String, String> values) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      for (final e in values.entries) {
        await txn.rawInsert('INSERT OR REPLACE INTO companion (key, value) VALUES (?, ?)', [e.key, e.value]);
      }
    });
  }

  Future<void> clear() async {
    final db = await _db.database;
    await db.delete('companion');
  }
}

int _epochDay(DateTime d) => DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

class CompanionService extends ChangeNotifier {
  CompanionService(this._repo, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const _firstSeenKey = 'first_seen_day';
  static const _maxSeenKey = 'max_seen_day';
  static const _selectedKey = 'selected';
  static const _hiddenKey = 'hidden';
  static const _announcedKey = 'announced';
  static const _namesKey = 'names';

  final CompanionRepository _repo;
  final DateTime Function() _clock;

  bool _loaded = false;
  int _firstSeen = 0;
  int _maxSeen = 0;
  Companion _selected = Companion.pamuk;
  bool _hidden = false;
  Set<Companion> _announced = {Companion.pamuk};
  Map<Companion, String> _names = {};

  bool get isLoaded => _loaded;

  /// Calendar days since RUYA was first opened. Moving the clock back never
  /// takes a companion away: the furthest day seen is kept.
  int get daysTogether => _maxSeen - _firstSeen;

  Companion get selected => _selected;
  bool get isHidden => _hidden;

  bool isUnlocked(Companion c) => daysTogether >= c.unlockDay;
  int daysUntil(Companion c) => (c.unlockDay - daysTogether).clamp(0, c.unlockDay);
  List<Companion> get unlocked => Companion.values.where(isUnlocked).toList();

  /// Companions that arrived but were not introduced yet.
  List<Companion> get newArrivals => unlocked.where((c) => !_announced.contains(c)).toList();

  String? nickname(Companion c) => _names[c];

  Future<void> load() async {
    final values = await _repo.readAll();
    final today = _epochDay(_clock());
    _firstSeen = int.tryParse(values[_firstSeenKey] ?? '') ?? today;
    final storedMax = int.tryParse(values[_maxSeenKey] ?? '') ?? today;
    _maxSeen = storedMax > today ? storedMax : today;
    _selected = Companion.byName(values[_selectedKey]) ?? Companion.pamuk;
    _hidden = values[_hiddenKey] == 'true';
    final announced = (values[_announcedKey] ?? Companion.pamuk.name).split(',');
    _announced = {for (final n in announced) ?Companion.byName(n)};
    _announced.add(Companion.pamuk);
    _names = {};
    if (values[_namesKey] != null) {
      final decoded = (jsonDecode(values[_namesKey]!) as Map).cast<String, dynamic>();
      for (final e in decoded.entries) {
        final c = Companion.byName(e.key);
        if (c != null && e.value is String) _names[c] = e.value as String;
      }
    }
    if (!isUnlocked(_selected)) _selected = Companion.pamuk;
    if (!values.containsKey(_firstSeenKey) || storedMax != _maxSeen) {
      await _repo.write({_firstSeenKey: '$_firstSeen', _maxSeenKey: '$_maxSeen'});
    }
    _loaded = true;
    notifyListeners();
  }

  /// Re-reads the day, e.g. when the app returns to the foreground after midnight.
  Future<void> refreshDay() async {
    final today = _epochDay(_clock());
    if (today > _maxSeen) {
      _maxSeen = today;
      await _repo.write({_maxSeenKey: '$_maxSeen'});
      notifyListeners();
    }
  }

  Future<void> select(Companion c) async {
    if (!isUnlocked(c)) return;
    _selected = c;
    await _repo.write({_selectedKey: c.name});
    notifyListeners();
  }

  Future<void> setHidden(bool hidden) async {
    _hidden = hidden;
    await _repo.write({_hiddenKey: '$hidden'});
    notifyListeners();
  }

  Future<void> markAnnounced(Iterable<Companion> companions) async {
    _announced.addAll(companions);
    await _repo.write({_announcedKey: _announced.map((c) => c.name).join(',')});
    notifyListeners();
  }

  static const int maxNameLength = 20;

  Future<void> rename(Companion c, String? name) async {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) {
      _names.remove(c);
    } else {
      _names[c] = trimmed.length > maxNameLength ? trimmed.substring(0, maxNameLength) : trimmed;
    }
    await _repo.write({_namesKey: jsonEncode({for (final e in _names.entries) e.key.name: e.value})});
    notifyListeners();
  }

  /// Called after "delete all data": companions start over from today.
  Future<void> reset() async {
    await _repo.clear();
    await load();
  }
}
