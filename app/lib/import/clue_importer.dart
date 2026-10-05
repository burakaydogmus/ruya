import 'dart:convert';

import 'package:ruya/import/import_models.dart';
import 'package:ruya/models/flows/flow_enum.dart';
import 'package:ruya/models/period_logs/daily_log_enums.dart';

/// Clue `measurements.json`: a flat array of `{date, type, value}` where value
/// is `{option}` or a list of `{option}`. Unknown categories are ignored; unknown
/// pain/feeling options are kept as notes so nothing the user logged is lost.
class ClueImporter extends ExternalImporter {
  const ClueImporter();

  static const Map<String, FlowRate> _flow = {
    'light': FlowRate.light,
    'medium': FlowRate.medium,
    'heavy': FlowRate.heavy,
    'very_heavy': FlowRate.heavy,
  };
  static const Map<String, String> _pain = {
    'period_cramps': 'cramps',
    'lower_back': 'back pain',
    'breast_tenderness': 'tender breasts',
    'headache': 'headache',
    'migraine': 'headache',
    'migraine_with_aura': 'headache',
  };
  static const Map<String, Mood> _feelings = {
    'happy': Mood.happy,
    'sad': Mood.sad,
    'angry': Mood.irritable,
    'anxious': Mood.anxious,
    'indifferent': Mood.calm,
    'mood_swings': Mood.moodSwings,
    'mood_swing': Mood.moodSwings,
    'sensitive': Mood.sensitive,
    'sensitivity': Mood.sensitive,
  };
  static const Map<String, Mood> _energy = {
    'energetic': Mood.energetic,
    'fully_energized': Mood.energetic,
    'tired': Mood.tired,
    'exhausted': Mood.tired,
  };
  static const Map<String, Discharge> _discharge = {
    'none': Discharge.dry,
    'sticky': Discharge.sticky,
    'creamy': Discharge.creamy,
    'egg_white': Discharge.eggWhite,
    'watery': Discharge.watery,
    'atypical': Discharge.unusual,
  };

  @override
  ImportSource get source => ImportSource.clue;

  static List<String> _options(Object? value) {
    if (value is List) {
      return value
          .map((v) => v is Map ? v['option'] : null)
          .whereType<String>()
          .where((o) => o.isNotEmpty)
          .toList();
    }
    if (value is Map && value['option'] is String) return [value['option'] as String];
    return const [];
  }

  @override
  ImportResult? tryParse(String content, {DateTime? today}) {
    final Object? json;
    try {
      json = jsonDecode(content);
    } catch (_) {
      return null;
    }
    if (json is! List) return null;
    if (!json.any((e) => e is Map && e['date'] is String && e['type'] is String)) return null;

    final now = dateOnly(today ?? DateTime.now());
    final days = <DateTime, ImportedDay>{};
    var skipped = 0;
    for (final entry in json) {
      if (entry is! Map || entry['type'] is! String) {
        skipped++;
        continue;
      }
      final date = parseImportDate(entry['date']);
      if (date == null || date.isAfter(now)) {
        skipped++;
        continue;
      }
      final day = days.putIfAbsent(date, () => ImportedDay(date));
      final options = _options(entry['value']);

      switch (entry['type'] as String) {
        case 'period':
          // `none` means "not bleeding": never invent a flow the user did not log.
          final flow = options.isEmpty ? null : _flow[options.first];
          if (flow != null) day.flow = flow;
        case 'spotting':
          if (day.flow == FlowRate.none) day.flow = FlowRate.spotting;
        case 'pain':
          for (final o in options) {
            if (o == 'pain_free') continue;
            final symptom = _pain[o];
            symptom != null ? day.symptoms.add(symptom) : day.addNote(o.replaceAll('_', ' '));
          }
        case 'feelings':
          for (final o in options) {
            final mood = _feelings[o];
            mood != null ? day.addMood(mood) : day.addNote(o.replaceAll('_', ' '));
          }
        case 'energy':
          for (final o in options) {
            final mood = _energy[o];
            if (mood != null) day.addMood(mood);
          }
        case 'sex_life':
          for (final o in options) {
            switch (o) {
              case 'protected_sex':
                day.sexActivity = SexActivity.protected;
              case 'unprotected_sex' || 'withdrawal':
                day.sexActivity = SexActivity.unprotected;
                if (o == 'withdrawal') day.contraception.add(ContraceptionMethod.withdrawal);
              case 'high_sex_drive':
                day.libido = Libido.high;
              case 'low_sex_drive':
                day.libido = Libido.low;
            }
          }
        case 'digestion':
          for (final o in options) {
            day.symptoms.add(o == 'nauseous' ? 'nausea' : 'digestion');
          }
        case 'discharge':
          if (options.isNotEmpty) day.discharge = _discharge[options.first] ?? day.discharge;
        case 'bbt':
          final value = entry['value'];
          final t = value is Map ? value['temperature'] : null;
          if (t is num) day.addNote('BBT $t°C');
      }
    }
    days.removeWhere((_, d) => d.isEmpty);
    if (days.isEmpty) return null;
    return ImportResult(source, days, skippedEntries: skipped);
  }
}
