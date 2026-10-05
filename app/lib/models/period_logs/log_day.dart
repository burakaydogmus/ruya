import 'dart:convert';

import 'package:ruya/models/flows/flow_enum.dart';
import 'package:ruya/models/period_logs/daily_log_enums.dart';
import 'package:ruya/models/period_logs/symptom.dart';

/// Represents a single day's log.
///
/// This class stores daily observations such as flow, pain, symptoms, mood,
/// discharge, medication, notes, libido, sex and contraception.
/// Each [LogDay] object can be associated with a parent [Period] via the [periodId].
///
/// [notes] and [medications] are stored encrypted by the repository; this model
/// always holds the plaintext values.
class LogDay {
	int? id;
	DateTime date;
	List<Symptom> symptoms;
	FlowRate flow;
  int? painLevel;
	int? periodId;
  List<Mood> moods;
  Discharge? discharge;
  Libido? libido;
  SexActivity? sexActivity;
  List<ContraceptionMethod> contraception;
  List<String> medications;
  String? notes;

	LogDay({
		this.id,
		required this.date,
		this.symptoms = const [],
		required this.flow,
    this.painLevel,
		this.periodId,
    this.moods = const [],
    this.discharge,
    this.libido,
    this.sexActivity,
    this.contraception = const [],
    this.medications = const [],
    this.notes,
	});

  /// Whether this log contains anything worth keeping.
  bool get hasContent =>
      flow != FlowRate.none ||
      painLevel != null ||
      symptoms.isNotEmpty ||
      moods.isNotEmpty ||
      discharge != null ||
      libido != null ||
      sexActivity != null ||
      contraception.isNotEmpty ||
      medications.isNotEmpty ||
      (notes != null && notes!.trim().isNotEmpty);

  /// Row for the `period_logs` table. `notes` and `medications` are plaintext here;
  /// the repository encrypts them before writing.
	Map<String, dynamic> toMap() {
		return {
			'id': id,
			'date': date.toIso8601String(),
			'flow': flow.intValue,
      'painLevel': painLevel,
			'period_id': periodId,
      'discharge': discharge?.dbValue,
      'libido': libido?.dbValue,
      'sex_activity': sexActivity?.dbValue,
      'contraception': contraception.isEmpty
          ? null
          : jsonEncode(contraception.map((c) => c.dbValue).toList()),
      'medications': medications.isEmpty ? null : jsonEncode(medications),
      'notes': (notes == null || notes!.trim().isEmpty) ? null : notes,
		};
	}

  /// Builds a log from a `period_logs` row whose encrypted fields were already decrypted.
	factory LogDay.fromMap(
    Map<String, dynamic> map, {
    List<Symptom>? symptoms,
    List<Mood>? moods,
  }) {
		return LogDay(
			id: map['id'] as int?,
			date: DateTime.parse(map['date'] as String),
			symptoms: symptoms ?? [],
			flow: FlowRate.values[map['flow'] as int],
      painLevel: map['painLevel'] as int?,
			periodId: map['period_id'] as int?,
      moods: moods ?? [],
      discharge: Discharge.fromDb(map['discharge'] as String?),
      libido: Libido.fromDb(map['libido'] as String?),
      sexActivity: SexActivity.fromDb(map['sex_activity'] as String?),
      contraception: decodeStringList(map['contraception'])
          .map(ContraceptionMethod.fromDb)
          .whereType<ContraceptionMethod>()
          .toList(),
      medications: decodeStringList(map['medications']),
      notes: map['notes'] as String?,
		);
	}

  /// Decodes a JSON string list column, tolerating null and malformed values.
  static List<String> decodeStringList(Object? raw) {
    if (raw is! String || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.whereType<String>().toList();
    } catch (_) {}
    return [];
  }

  /// Copies the log. Nullable optional fields are cleared with the `clear*` flags.
	LogDay copyWith({
		int? id,
		DateTime? date,
		List<Symptom>? symptoms,
		FlowRate? flow,
    int? painLevel,
		int? periodId,
    List<Mood>? moods,
    Discharge? discharge,
    Libido? libido,
    SexActivity? sexActivity,
    List<ContraceptionMethod>? contraception,
    List<String>? medications,
    String? notes,
    bool clearPainLevel = false,
    bool clearDischarge = false,
    bool clearLibido = false,
    bool clearSexActivity = false,
    bool clearNotes = false,
	}) {
		return LogDay(
			id: id ?? this.id,
			date: date ?? this.date,
			symptoms: symptoms ?? this.symptoms,
			flow: flow ?? this.flow,
      painLevel: clearPainLevel ? null : (painLevel ?? this.painLevel),
			periodId: periodId ?? this.periodId,
      moods: moods ?? this.moods,
      discharge: clearDischarge ? null : (discharge ?? this.discharge),
      libido: clearLibido ? null : (libido ?? this.libido),
      sexActivity: clearSexActivity ? null : (sexActivity ?? this.sexActivity),
      contraception: contraception ?? this.contraception,
      medications: medications ?? this.medications,
      notes: clearNotes ? null : (notes ?? this.notes),
		);
	}
}
