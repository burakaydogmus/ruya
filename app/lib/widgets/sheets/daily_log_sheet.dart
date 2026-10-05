import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ruya/l10n/app_localizations.dart';
import 'package:ruya/models/flows/flow_enum.dart';
import 'package:ruya/models/period_logs/daily_log_enums.dart';
import 'package:ruya/models/period_logs/log_day.dart';
import 'package:ruya/models/period_logs/pain_level_enum.dart';
import 'package:ruya/models/period_logs/symptom.dart';
import 'package:ruya/services/symptom_service.dart';
import 'package:ruya/widgets/dialogs/custom_symptom_dialog.dart';

/// Result of [DailyLogSheet]: either a log to save or a delete request.
sealed class DailyLogSheetResult {
  const DailyLogSheetResult();
}

class DailyLogSaved extends DailyLogSheetResult {
  const DailyLogSaved(this.log);
  final LogDay log;
}

class DailyLogDeleted extends DailyLogSheetResult {
  const DailyLogDeleted(this.log);
  final LogDay log;
}

/// Full daily log editor: flow, pain, symptoms, mood, discharge, medication,
/// contraception, sex, libido and notes. Used for both new and existing logs.
class DailyLogSheet extends StatefulWidget {
  const DailyLogSheet({
    super.key,
    required this.date,
    required this.symptomService,
    this.existing,
    this.age,
    this.medicationSuggestions = const [],
    this.showIntimateFields = true,
  });

  final DateTime date;
  final LogDay? existing;
  final SymptomService symptomService;
  final int? age;
  final List<String> medicationSuggestions;

  /// False hides sex and libido (kid mode).
  final bool showIntimateFields;

  static Future<DailyLogSheetResult?> show(
    BuildContext context, {
    required DateTime date,
    required SymptomService symptomService,
    LogDay? existing,
    int? age,
    List<String> medicationSuggestions = const [],
    bool showIntimateFields = true,
  }) {
    return showModalBottomSheet<DailyLogSheetResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => DailyLogSheet(
        date: date,
        existing: existing,
        symptomService: symptomService,
        age: age,
        medicationSuggestions: medicationSuggestions,
        showIntimateFields: showIntimateFields,
      ),
    );
  }

  @override
  State<DailyLogSheet> createState() => _DailyLogSheetState();
}

class _DailyLogSheetState extends State<DailyLogSheet> {
  late DateTime _date;
  late FlowRate _flow;
  PainLevel? _pain;
  final Set<Symptom> _availableSymptoms = {};
  final Set<Symptom> _defaultSymptoms = {};
  final Set<Symptom> _symptoms = {};
  final List<Mood> _moods = [];
  Discharge? _discharge;
  Libido? _libido;
  SexActivity? _sex;
  final Set<ContraceptionMethod> _contraception = {};
  final List<String> _medications = [];
  late final TextEditingController _notes;
  final TextEditingController _medicationInput = TextEditingController();

  bool get _isEditing => widget.existing?.id != null;

  @override
  void initState() {
    super.initState();
    final log = widget.existing;
    _date = log?.date ?? widget.date;
    _flow = log?.flow ?? FlowRate.none;
    _pain = log?.painLevel == null ? null : PainLevel.values[log!.painLevel!];
    _symptoms.addAll(log?.symptoms ?? const []);
    _moods.addAll(log?.moods ?? const []);
    _discharge = log?.discharge;
    _libido = log?.libido;
    _sex = log?.sexActivity;
    _contraception.addAll(log?.contraception ?? const []);
    _medications.addAll(log?.medications ?? const []);
    _notes = TextEditingController(text: log?.notes ?? '');

    _defaultSymptoms.addAll(widget.symptomService.ageOrderedSymptoms(widget.age));
    _availableSymptoms
      ..addAll(_defaultSymptoms)
      ..addAll(_symptoms);
  }

  @override
  void dispose() {
    _notes.dispose();
    _medicationInput.dispose();
    super.dispose();
  }

  LogDay _buildLog() {
    final base = widget.existing ?? LogDay(date: _date, flow: FlowRate.none);
    return LogDay(
      id: base.id,
      date: _date,
      periodId: base.periodId,
      flow: _flow,
      painLevel: _pain?.intValue,
      symptoms: _symptoms.toList(),
      moods: List.of(_moods),
      discharge: _discharge,
      // Hidden fields keep their stored value instead of being wiped.
      libido: widget.showIntimateFields ? _libido : base.libido,
      sexActivity: widget.showIntimateFields ? _sex : base.sexActivity,
      contraception: _contraception.toList(),
      medications: List.of(_medications),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _addCustomSymptom() async {
    final result = await showDialog<(String, bool)>(
      context: context,
      builder: (_) => const CustomSymptomDialog(),
    );
    if (result == null || !mounted || result.$1.isEmpty) return;
    final symptom = Symptom.fromDbString(result.$1);
    if (!result.$2 && !_defaultSymptoms.contains(symptom)) {
      _defaultSymptoms.add(symptom);
      await widget.symptomService.addSymptom(symptom);
    }
    setState(() {
      _availableSymptoms.add(symptom);
      _symptoms.add(symptom);
    });
  }

  void _addMedication(String raw) {
    final name = raw.trim();
    if (name.isEmpty) return;
    final exists = _medications.any((m) => m.toLowerCase() == name.toLowerCase());
    setState(() {
      if (!exists) _medications.add(name);
      _medicationInput.clear();
    });
  }

  void _toggleMood(Mood mood) {
    setState(() {
      if (_moods.contains(mood)) {
        _moods.remove(mood);
      } else if (_moods.length < Mood.maxSelected) {
        _moods.add(mood);
      }
    });
  }

  Future<void> _confirmDelete() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.dailyLog_deleteTitle),
        content: Text(l10n.dailyLog_deleteBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.delete)),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.pop(context, DailyLogDeleted(widget.existing!));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final suggestions = widget.medicationSuggestions
        .where((s) => !_medications.any((m) => m.toLowerCase() == s.toLowerCase()))
        .take(6)
        .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEditing ? l10n.dailyLog_editTitle : l10n.symptomEntrySheet_logYourDay,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  if (_isEditing)
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: l10n.delete,
                      onPressed: _confirmDelete,
                    ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                children: [
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(DateFormat.yMMMMEEEEd(l10n.localeName).format(_date)),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      alignment: Alignment.centerLeft,
                    ),
                    onPressed: _isEditing ? null : _pickDate,
                  ),
                  _Section(
                    title: l10n.flow,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: FlowRate.periodFlows.map((flow) {
                        return ChoiceChip(
                          label: Text(flow.getDisplayName(l10n)),
                          selected: _flow == flow,
                          onSelected: (selected) =>
                              setState(() => _flow = selected ? flow : FlowRate.none),
                        );
                      }).toList(),
                    ),
                  ),
                  _Section(
                    title: '${l10n.painLevel_title}: ${_pain == null ? l10n.notSet : _pain!.getDisplayName(l10n)}',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: PainLevel.values.map((level) {
                        final selected = _pain == level;
                        return IconButton(
                          icon: Icon(level.icon),
                          iconSize: 34,
                          tooltip: level.getDisplayName(l10n),
                          color: selected ? level.color : theme.colorScheme.onSurfaceVariant,
                          onPressed: () => setState(() => _pain = selected ? null : level),
                        );
                      }).toList(),
                    ),
                  ),
                  _Section(
                    title: l10n.dailyLog_symptoms,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        ..._availableSymptoms.map((s) => FilterChip(
                              label: Text(s.getDisplayName(l10n)),
                              selected: _symptoms.contains(s),
                              onSelected: (v) => setState(() => v ? _symptoms.add(s) : _symptoms.remove(s)),
                            )),
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 18),
                          label: Text(l10n.add),
                          onPressed: _addCustomSymptom,
                        ),
                      ],
                    ),
                  ),
                  _Section(
                    title: l10n.dailyLog_moodTitle(_moods.length, Mood.maxSelected),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: Mood.values.map((mood) {
                        return FilterChip(
                          avatar: Text(mood.emoji),
                          showCheckmark: false,
                          label: Text(mood.getDisplayName(l10n)),
                          selected: _moods.contains(mood),
                          onSelected: (_) => _toggleMood(mood),
                        );
                      }).toList(),
                    ),
                  ),
                  _Section(
                    title: l10n.dailyLog_discharge,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: Discharge.values.map((d) {
                        return ChoiceChip(
                          label: Text(d.getDisplayName(l10n)),
                          selected: _discharge == d,
                          onSelected: (v) => setState(() => _discharge = v ? d : null),
                        );
                      }).toList(),
                    ),
                  ),
                  _Section(
                    title: l10n.dailyLog_medication,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_medications.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: _medications
                                .map((m) => InputChip(
                                      label: Text(m),
                                      onDeleted: () => setState(() => _medications.remove(m)),
                                    ))
                                .toList(),
                          ),
                        TextField(
                          controller: _medicationInput,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            hintText: l10n.dailyLog_medicationHint,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.add),
                              tooltip: l10n.add,
                              onPressed: () => _addMedication(_medicationInput.text),
                            ),
                          ),
                          onSubmitted: _addMedication,
                        ),
                        if (suggestions.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            children: suggestions
                                .map((s) => ActionChip(
                                      avatar: const Icon(Icons.history, size: 16),
                                      label: Text(s),
                                      onPressed: () => _addMedication(s),
                                    ))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _Section(
                    title: l10n.dailyLog_contraception,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: ContraceptionMethod.values.map((c) {
                        return FilterChip(
                          avatar: Icon(c.icon, size: 16),
                          label: Text(c.getDisplayName(l10n)),
                          selected: _contraception.contains(c),
                          onSelected: (v) => setState(() => v ? _contraception.add(c) : _contraception.remove(c)),
                        );
                      }).toList(),
                    ),
                  ),
                  if (widget.showIntimateFields) ...[
                    _Section(
                      title: l10n.dailyLog_sex,
                      child: Wrap(
                        spacing: 8,
                        children: SexActivity.values.map((s) {
                          return ChoiceChip(
                            label: Text(s.getDisplayName(l10n)),
                            selected: _sex == s,
                            onSelected: (v) => setState(() => _sex = v ? s : null),
                          );
                        }).toList(),
                      ),
                    ),
                    _Section(
                      title: l10n.dailyLog_libido,
                      child: Wrap(
                        spacing: 8,
                        children: Libido.values.map((l) {
                          return ChoiceChip(
                            label: Text(l.getDisplayName(l10n)),
                            selected: _libido == l,
                            onSelected: (v) => setState(() => _libido = v ? l : null),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  _Section(
                    title: l10n.dailyLog_notes,
                    child: TextField(
                      controller: _notes,
                      minLines: 2,
                      maxLines: 6,
                      maxLength: 2000,
                      decoration: InputDecoration(
                        hintText: l10n.dailyLog_notesHint,
                        border: const OutlineInputBorder(),
                        helperText: l10n.dailyLog_notesEncrypted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonal(
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l10n.cancel),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        onPressed: () {
                          if (_medicationInput.text.trim().isNotEmpty) {
                            _addMedication(_medicationInput.text);
                          }
                          Navigator.of(context).pop(DailyLogSaved(_buildLog()));
                        },
                        child: Text(l10n.save),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
