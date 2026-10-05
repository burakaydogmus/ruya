import 'package:ruya/import/import_models.dart';
import 'package:ruya/models/flows/flow_enum.dart';
import 'package:ruya/models/period_logs/daily_log_enums.dart';

/// drip CSV export (first column `date`, contains `bleeding.value`).
///
/// * `bleeding.value` 0..3 → spotting, light, medium, heavy
/// * `pain.*`, `mood.*` booleans → symptoms / moods
/// * `desire.value` 0..2 → libido
/// * `sex.solo|partner` with any contraceptive column → protected, otherwise unprotected;
///   contraceptive columns are also kept as contraception methods
/// * `mucus.texture` 1/2 → creamy / egg white, `mucus.feeling` 0 → dry
/// * notes and temperature (BBT) → notes
class DripImporter extends ExternalImporter {
  const DripImporter();

  static const List<FlowRate> _flow = [FlowRate.spotting, FlowRate.light, FlowRate.medium, FlowRate.heavy];
  static const List<Libido> _desire = [Libido.low, Libido.medium, Libido.high];
  static const Map<String, String> _pain = {
    'pain.cramps': 'cramps',
    'pain.headache': 'headache',
    'pain.migraine': 'headache',
    'pain.backache': 'back pain',
    'pain.nausea': 'nausea',
    'pain.tenderBreasts': 'tender breasts',
  };
  static const Map<String, Mood> _mood = {
    'mood.happy': Mood.happy,
    'mood.sad': Mood.sad,
    'mood.stressed': Mood.anxious,
    'mood.balanced': Mood.calm,
    'mood.fine': Mood.calm,
    'mood.anxious': Mood.anxious,
    'mood.energetic': Mood.energetic,
    'mood.fatigue': Mood.tired,
    'mood.angry': Mood.irritable,
    'mood.moodSwings': Mood.moodSwings,
    'mood.mood_swing': Mood.moodSwings,
    'mood.sensitive': Mood.sensitive,
  };
  static const Map<String, ContraceptionMethod> _contraception = {
    'sex.condom': ContraceptionMethod.condom,
    'sex.pill': ContraceptionMethod.pill,
    'sex.iud': ContraceptionMethod.iud,
    'sex.patch': ContraceptionMethod.patch,
    'sex.ring': ContraceptionMethod.ring,
    'sex.implant': ContraceptionMethod.implant,
    'sex.diaphragm': ContraceptionMethod.other,
  };

  @override
  ImportSource get source => ImportSource.drip;

  /// RFC 4180-style CSV: quotes, escaped quotes (`""`), CRLF/LF, newlines inside quotes.
  static List<List<String>> parseCsv(String text) {
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;
    void endField() {
      row.add(field.toString());
      field.clear();
    }

    void endRow() {
      endField();
      if (row.any((f) => f.isNotEmpty)) rows.add(row);
      row = <String>[];
    }

    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (inQuotes) {
        if (c == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(c);
        }
      } else if (c == '"') {
        inQuotes = true;
      } else if (c == ',') {
        endField();
      } else if (c == '\n' || c == '\r') {
        if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        endRow();
      } else {
        field.write(c);
      }
    }
    endRow();
    return rows;
  }

  @override
  ImportResult? tryParse(String content, {DateTime? today}) {
    final text = content.startsWith('﻿') ? content.substring(1) : content;
    final rows = parseCsv(text);
    if (rows.length < 2) return null;
    final headers = rows.first.map((h) => h.trim()).toList();
    if (headers.first != 'date' || !headers.contains('bleeding.value')) return null;
    final index = {for (var i = 0; i < headers.length; i++) headers[i]: i};

    final now = dateOnly(today ?? DateTime.now());
    final days = <DateTime, ImportedDay>{};
    var skipped = 0;
    for (final cells in rows.skip(1)) {
      String get(String col) {
        final i = index[col];
        return i == null || i >= cells.length ? '' : cells[i].trim();
      }

      bool isTrue(String col) => get(col).toLowerCase() == 'true';

      final date = parseImportDate(get('date'));
      if (date == null || date.isAfter(now)) {
        skipped++;
        continue;
      }
      final day = ImportedDay(date);

      final bleeding = int.tryParse(get('bleeding.value'));
      if (bleeding != null && bleeding >= 0 && bleeding < _flow.length) day.flow = _flow[bleeding];

      _pain.forEach((col, symptom) {
        if (isTrue(col)) day.symptoms.add(symptom);
      });
      _mood.forEach((col, mood) {
        if (isTrue(col)) day.addMood(mood);
      });

      final desire = int.tryParse(get('desire.value'));
      if (desire != null && desire >= 0 && desire < _desire.length) day.libido = _desire[desire];

      _contraception.forEach((col, method) {
        if (isTrue(col)) day.contraception.add(method);
      });
      if (isTrue('sex.partner') || isTrue('sex.solo')) {
        day.sexActivity = day.contraception.isEmpty ? SexActivity.unprotected : SexActivity.protected;
      }

      switch (get('mucus.texture')) {
        case '1':
          day.discharge = Discharge.creamy;
        case '2':
          day.discharge = Discharge.eggWhite;
        default:
          if (get('mucus.feeling') == '0') day.discharge = Discharge.dry;
      }

      day.addNote(get('note.value'));
      final temperature = get('temperature.value');
      if (temperature.isNotEmpty) {
        final time = get('temperature.time');
        day.addNote('BBT $temperature°C${time.isEmpty ? '' : ' @ $time'}');
      }
      for (final col in const ['pain.note', 'mood.note', 'sex.note', 'temperature.note']) {
        day.addNote(get(col));
      }
      if (isTrue('pain.ovulationPain')) day.addNote('ovulation pain');

      if (!day.isEmpty) days[date] = day;
    }
    if (days.isEmpty) return null;
    return ImportResult(source, days, skippedEntries: skipped);
  }
}
