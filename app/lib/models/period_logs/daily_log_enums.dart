import 'package:flutter/material.dart';
import 'package:ruya/l10n/app_localizations.dart';

/// Shared helper for enums that are persisted by a stable string value.
T? _fromDb<T extends Enum>(List<T> values, String? value, String Function(T) dbValue) {
  if (value == null || value.isEmpty) return null;
  for (final v in values) {
    if (dbValue(v) == value) return v;
  }
  return null;
}

/// Mood options (multi-select, max [maxSelected] per day).
enum Mood {
  energetic('energetic', '⚡'),
  calm('calm', '😌'),
  happy('happy', '😊'),
  confident('confident', '💪'),
  focused('focused', '🎯'),
  tired('tired', '😴'),
  foggy('foggy', '🌫️'),
  sad('sad', '😔'),
  anxious('anxious', '😰'),
  irritable('irritable', '😠'),
  moodSwings('mood_swings', '🎭'),
  sensitive('sensitive', '🫶');

  const Mood(this.dbValue, this.emoji);

  final String dbValue;
  final String emoji;

  static const int maxSelected = 5;

  static Mood? fromDb(String? value) => _fromDb(values, value, (m) => m.dbValue);

  String getDisplayName(AppLocalizations l10n) => switch (this) {
        Mood.energetic => l10n.mood_energetic,
        Mood.calm => l10n.mood_calm,
        Mood.happy => l10n.mood_happy,
        Mood.confident => l10n.mood_confident,
        Mood.focused => l10n.mood_focused,
        Mood.tired => l10n.mood_tired,
        Mood.foggy => l10n.mood_foggy,
        Mood.sad => l10n.mood_sad,
        Mood.anxious => l10n.mood_anxious,
        Mood.irritable => l10n.mood_irritable,
        Mood.moodSwings => l10n.mood_moodSwings,
        Mood.sensitive => l10n.mood_sensitive,
      };

  /// Whether the mood is generally considered positive (used for trends).
  bool get isPositive => switch (this) {
        Mood.energetic || Mood.calm || Mood.happy || Mood.confident || Mood.focused => true,
        _ => false,
      };
}

/// Vaginal discharge / cervical mucus.
enum Discharge {
  dry('dry'),
  sticky('sticky'),
  creamy('creamy'),
  watery('watery'),
  eggWhite('egg_white'),
  unusual('unusual');

  const Discharge(this.dbValue);

  final String dbValue;

  static Discharge? fromDb(String? value) => _fromDb(values, value, (d) => d.dbValue);

  String getDisplayName(AppLocalizations l10n) => switch (this) {
        Discharge.dry => l10n.discharge_dry,
        Discharge.sticky => l10n.discharge_sticky,
        Discharge.creamy => l10n.discharge_creamy,
        Discharge.watery => l10n.discharge_watery,
        Discharge.eggWhite => l10n.discharge_eggWhite,
        Discharge.unusual => l10n.discharge_unusual,
      };
}

enum Libido {
  low('low'),
  medium('medium'),
  high('high');

  const Libido(this.dbValue);

  final String dbValue;

  static Libido? fromDb(String? value) => _fromDb(values, value, (l) => l.dbValue);

  String getDisplayName(AppLocalizations l10n) => switch (this) {
        Libido.low => l10n.libido_low,
        Libido.medium => l10n.libido_medium,
        Libido.high => l10n.libido_high,
      };
}

/// Quick sex entry on the daily log. Detailed entries live in `sexual_activity_logs`.
enum SexActivity {
  none('none'),
  protected('protected'),
  unprotected('unprotected');

  const SexActivity(this.dbValue);

  final String dbValue;

  static SexActivity? fromDb(String? value) => _fromDb(values, value, (s) => s.dbValue);

  bool get hadSex => this != SexActivity.none;

  String getDisplayName(AppLocalizations l10n) => switch (this) {
        SexActivity.none => l10n.sexActivity_none,
        SexActivity.protected => l10n.sexActivity_protected,
        SexActivity.unprotected => l10n.sexActivity_unprotected,
      };
}

/// Contraception used or taken on a given day (multi-select).
enum ContraceptionMethod {
  pill('pill', Icons.medication_outlined),
  condom('condom', Icons.shield_outlined),
  iud('iud', Icons.verified_user_outlined),
  implant('implant', Icons.verified_user_outlined),
  injection('injection', Icons.vaccines_outlined),
  patch('patch', Icons.healing_outlined),
  ring('ring', Icons.radio_button_unchecked),
  emergency('emergency', Icons.emergency_outlined),
  withdrawal('withdrawal', Icons.do_not_disturb_on_outlined),
  other('other', Icons.more_horiz);

  const ContraceptionMethod(this.dbValue, this.icon);

  final String dbValue;
  final IconData icon;

  static ContraceptionMethod? fromDb(String? value) => _fromDb(values, value, (c) => c.dbValue);

  String getDisplayName(AppLocalizations l10n) => switch (this) {
        ContraceptionMethod.pill => l10n.contraception_pill,
        ContraceptionMethod.condom => l10n.contraception_condom,
        ContraceptionMethod.iud => l10n.contraception_iud,
        ContraceptionMethod.implant => l10n.contraception_implant,
        ContraceptionMethod.injection => l10n.contraception_injection,
        ContraceptionMethod.patch => l10n.contraception_patch,
        ContraceptionMethod.ring => l10n.contraception_ring,
        ContraceptionMethod.emergency => l10n.contraception_emergency,
        ContraceptionMethod.withdrawal => l10n.contraception_withdrawal,
        ContraceptionMethod.other => l10n.contraception_other,
      };
}
