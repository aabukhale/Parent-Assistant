import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/design_system.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/primary_button.dart';
import '../../auth/presentation/auth_form_widgets.dart';
import '../application/learning_goal_progress_controller.dart';
import '../data/learning_goal_requests.dart';
import '../data/models/learning_goal.dart';
import 'goal_widgets.dart';

/// Opens the "record progress" modal for [goal]. Returns true if an entry was
/// saved.
Future<bool?> showRecordProgressSheet(BuildContext context, LearningGoal goal) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _RecordProgressForm(goal: goal),
    ),
  );
}

class _RecordProgressForm extends ConsumerStatefulWidget {
  const _RecordProgressForm({required this.goal});
  final LearningGoal goal;

  @override
  ConsumerState<_RecordProgressForm> createState() =>
      _RecordProgressFormState();
}

class _RecordProgressFormState extends ConsumerState<_RecordProgressForm> {
  final _formKey = GlobalKey<FormState>();
  final _value = TextEditingController();
  final _note = TextEditingController();
  bool _booleanDone = false;
  DateTime? _recordedAt;

  bool _submitting = false;
  Map<String, List<String>> _fieldErrors = const {};
  String? _formError;

  LearningGoalMetric get _metric => widget.goal.metric;

  @override
  void initState() {
    super.initState();
    _booleanDone = widget.goal.isBooleanDone;
  }

  @override
  void dispose() {
    _value.dispose();
    _note.dispose();
    super.dispose();
  }

  double? get _numericValue => double.tryParse(_value.text.trim());

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _recordedAt ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null) setState(() => _recordedAt = picked);
  }

  Future<void> _submit() async {
    setState(() {
      _fieldErrors = const {};
      _formError = null;
    });
    final l = context.l10n;

    double value;
    if (_metric == LearningGoalMetric.boolean) {
      value = _booleanDone ? 1 : 0;
    } else {
      if (!_formKey.currentState!.validate()) return;
      final parsed = _numericValue;
      if (parsed == null) {
        setState(
          () => _fieldErrors = {
            'value': [l.validationRequired],
          },
        );
        return;
      }
      if (_metric == LearningGoalMetric.percent &&
          (parsed < 0 || parsed > 100)) {
        setState(
          () => _fieldErrors = {
            'value': [l.lgValidationPercentRange],
          },
        );
        return;
      }
      value = parsed;
    }

    setState(() => _submitting = true);
    try {
      await ref
          .read(goalProgressControllerProvider(widget.goal.id).notifier)
          .record(
            LearningGoalProgressInput(
              value: value,
              note: _note.text,
              recordedAt: _recordedAt,
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.lgProgressRecorded)));
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.isValidation) {
          _fieldErrors = e.fieldErrors;
          if (_fieldErrors.isEmpty) _formError = e.localizedMessage(l);
        } else {
          _formError = e.localizedMessage(l);
        }
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.lgRecordTitle, style: context.type.titleMedium),
              const SizedBox(height: AppSpacing.lg),
              if (_formError != null) AuthFormErrorBanner(message: _formError!),
              if (_metric == LearningGoalMetric.boolean)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.lgProgressDone),
                  value: _booleanDone,
                  onChanged: (v) => setState(() => _booleanDone = v),
                )
              else
                AppTextField(
                  label: _metric == LearningGoalMetric.percent
                      ? '${l.lgProgressValue} (%)'
                      : l.lgProgressValue,
                  hint: widget.goal.unit,
                  controller: _value,
                  prefixIcon: Icons.trending_up_rounded,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l.validationRequired
                      : null,
                ),
              AuthFieldError(messages: _fieldErrors['value']),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: l.lgProgressNote,
                controller: _note,
                prefixIcon: Icons.notes_rounded,
              ),
              AuthFieldError(messages: _fieldErrors['note']),
              const SizedBox(height: AppSpacing.md),
              PickerField(
                icon: Icons.event_outlined,
                label: l.lgProgressDate,
                value: _recordedAt == null
                    ? null
                    : formatGoalDate(context, _recordedAt!),
                onClear: _recordedAt == null
                    ? null
                    : () => setState(() => _recordedAt = null),
                onTap: _pickDate,
              ),
              AuthFieldError(messages: _fieldErrors['recorded_at']),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                text: l.lgSave,
                onPressed: _submitting ? null : _submit,
              ),
              if (_submitting)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
