import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
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
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
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
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l.lgRecordTitle,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (_formError != null) AuthFormErrorBanner(message: _formError!),
              if (_metric == LearningGoalMetric.boolean)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.lgProgressDone),
                  value: _booleanDone,
                  activeThumbColor: AppColors.coral,
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
              const SizedBox(height: 14),
              AppTextField(
                label: l.lgProgressNote,
                controller: _note,
                prefixIcon: Icons.notes_rounded,
              ),
              AuthFieldError(messages: _fieldErrors['note']),
              const SizedBox(height: 14),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.event_outlined,
                        color: Color(0xFF8E98AC),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _recordedAt == null
                            ? l.lgProgressDate
                            : formatGoalDate(context, _recordedAt!),
                        style: const TextStyle(color: AppColors.navy),
                      ),
                      const Spacer(),
                      if (_recordedAt != null)
                        GestureDetector(
                          onTap: () => setState(() => _recordedAt = null),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              AuthFieldError(messages: _fieldErrors['recorded_at']),
              const SizedBox(height: 20),
              PrimaryButton(
                text: l.lgSave,
                onPressed: _submitting ? null : _submit,
              ),
              if (_submitting)
                const Padding(
                  padding: EdgeInsets.only(top: 14),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.coral),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
