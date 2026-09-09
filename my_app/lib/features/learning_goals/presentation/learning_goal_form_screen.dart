import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/primary_button.dart';
import '../../auth/presentation/auth_form_widgets.dart';
import '../application/learning_goals_controller.dart';
import '../data/learning_goal_requests.dart';
import '../data/models/learning_goal.dart';
import 'goal_widgets.dart';

/// Create (when [existing] is null) or edit a learning goal.
/// `metric` and `start_date` are immutable after creation.
class LearningGoalFormScreen extends ConsumerStatefulWidget {
  const LearningGoalFormScreen({super.key, this.existing});

  final LearningGoal? existing;

  bool get isEdit => existing != null;

  @override
  ConsumerState<LearningGoalFormScreen> createState() =>
      _LearningGoalFormScreenState();
}

class _LearningGoalFormScreenState
    extends ConsumerState<LearningGoalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _target;
  late final TextEditingController _unit;

  LearningGoalMetric _metric = LearningGoalMetric.boolean;
  DateTime _startDate = DateTime.now();
  DateTime? _targetDate;
  LearningGoalStatus _status = LearningGoalStatus.active;

  bool _submitting = false;
  Map<String, List<String>> _fieldErrors = const {};
  String? _formError;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _target = TextEditingController(
      text: e?.targetValue != null ? formatGoalNumber(e!.targetValue!) : '',
    );
    _unit = TextEditingController(text: e?.unit ?? '');
    _metric = e?.metric ?? LearningGoalMetric.boolean;
    _startDate = e?.startDate ?? DateTime.now();
    _targetDate = e?.targetDate;
    _status =
        e?.status == null || !LearningGoalStatus.editable.contains(e!.status)
        ? LearningGoalStatus.active
        : e.status;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _target.dispose();
    _unit.dispose();
    super.dispose();
  }

  double? get _parsedTarget => double.tryParse(_target.text.trim());

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart ? _startDate : (_targetDate ?? _startDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: isStart ? DateTime(now.year - 5) : _startDate,
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _targetDate = picked;
      }
    });
  }

  String? _validate(AppLocalizations l) {
    if (_metric.requiresTarget) {
      final t = _parsedTarget;
      if (t == null) return l.lgValidationTarget;
      if (_metric == LearningGoalMetric.percent && (t < 0 || t > 100)) {
        return l.lgValidationPercentRange;
      }
    }
    return null;
  }

  Future<void> _submit() async {
    setState(() {
      _fieldErrors = const {};
      _formError = null;
    });
    final l = context.l10n;
    if (!_formKey.currentState!.validate()) return;
    final localError = _validate(l);
    if (localError != null) {
      setState(
        () => _fieldErrors = {
          'target_value': [localError],
        },
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final controller = ref.read(learningGoalsControllerProvider.notifier);
      if (widget.isEdit) {
        await controller.updateGoal(widget.existing!.id, _buildUpdate());
      } else {
        await controller.createGoal(_buildCreate());
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.isEdit ? l.lgUpdated : l.lgCreated)),
      );
      Navigator.of(context).pop();
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

  LearningGoalCreateInput _buildCreate() => LearningGoalCreateInput(
    title: _title.text,
    description: _description.text,
    metric: _metric,
    targetValue: _metric.requiresTarget ? _parsedTarget : null,
    unit: _metric == LearningGoalMetric.numeric ? _unit.text : null,
    startDate: _startDate,
    targetDate: _targetDate,
  );

  LearningGoalUpdateInput _buildUpdate() {
    final desc = _description.text.trim();
    final unit = _unit.text.trim();
    return LearningGoalUpdateInput(
      title: _title.text,
      description: desc.isEmpty ? null : desc,
      clearDescription: desc.isEmpty,
      targetValue: _metric.requiresTarget ? _parsedTarget : null,
      clearTargetValue: _metric.requiresTarget && _parsedTarget == null,
      unit: _metric == LearningGoalMetric.numeric && unit.isNotEmpty
          ? unit
          : null,
      clearUnit: _metric == LearningGoalMetric.numeric && unit.isEmpty,
      targetDate: _targetDate,
      clearTargetDate: _targetDate == null,
      status: _status,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.isEdit ? l.lgEditTitle : l.lgNewTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_formError != null)
                  AuthFormErrorBanner(message: _formError!),
                AppTextField(
                  label: l.lgFieldTitle,
                  hint: l.lgFieldTitleHint,
                  controller: _title,
                  prefixIcon: Icons.flag_outlined,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l.validationRequired
                      : null,
                ),
                AuthFieldError(messages: _fieldErrors['title']),
                const SizedBox(height: 16),
                AppTextField(
                  label: l.lgFieldDescription,
                  controller: _description,
                  prefixIcon: Icons.notes_rounded,
                ),
                AuthFieldError(messages: _fieldErrors['description']),
                const SizedBox(height: 18),
                _Label(l.lgFieldMetric),
                const SizedBox(height: 8),
                _MetricPicker(
                  value: _metric,
                  locked: widget.isEdit,
                  onChanged: (m) => setState(() => _metric = m),
                ),
                if (widget.isEdit)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      l.lgMetricLocked,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                AuthFieldError(messages: _fieldErrors['metric']),
                if (_metric.requiresTarget) ...[
                  const SizedBox(height: 16),
                  AppTextField(
                    label: _metric == LearningGoalMetric.percent
                        ? '${l.lgFieldTarget} (%)'
                        : l.lgFieldTarget,
                    controller: _target,
                    prefixIcon: Icons.track_changes_rounded,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  AuthFieldError(messages: _fieldErrors['target_value']),
                ],
                if (_metric == LearningGoalMetric.numeric) ...[
                  const SizedBox(height: 16),
                  AppTextField(
                    label: l.lgFieldUnit,
                    hint: l.lgFieldUnitHint,
                    controller: _unit,
                  ),
                  AuthFieldError(messages: _fieldErrors['unit']),
                ],
                const SizedBox(height: 18),
                if (!widget.isEdit) ...[
                  _Label(l.lgFieldStartDate),
                  const SizedBox(height: 8),
                  _DateRow(
                    label: formatGoalDate(context, _startDate),
                    onTap: () => _pickDate(isStart: true),
                  ),
                  AuthFieldError(messages: _fieldErrors['start_date']),
                  const SizedBox(height: 16),
                ],
                _Label(l.lgFieldTargetDate),
                const SizedBox(height: 8),
                _DateRow(
                  label: _targetDate == null
                      ? l.lgFieldTargetDate
                      : formatGoalDate(context, _targetDate!),
                  onClear: _targetDate == null
                      ? null
                      : () => setState(() => _targetDate = null),
                  onTap: () => _pickDate(isStart: false),
                ),
                AuthFieldError(messages: _fieldErrors['target_date']),
                if (widget.isEdit) ...[
                  const SizedBox(height: 18),
                  _Label(l.lgFieldStatus),
                  const SizedBox(height: 8),
                  _StatusPicker(
                    value: _status,
                    onChanged: (s) => setState(() => _status = s),
                  ),
                  AuthFieldError(messages: _fieldErrors['status']),
                ],
                const SizedBox(height: 28),
                PrimaryButton(
                  text: l.lgSave,
                  onPressed: _submitting ? null : _submit,
                ),
                if (_submitting)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.coral),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.navy,
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class _MetricPicker extends StatelessWidget {
  const _MetricPicker({
    required this.value,
    required this.locked,
    required this.onChanged,
  });
  final LearningGoalMetric value;
  final bool locked;
  final ValueChanged<LearningGoalMetric> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      children: [
        for (final m in LearningGoalMetric.values)
          Opacity(
            opacity: locked && m != value ? 0.5 : 1,
            child: GestureDetector(
              onTap: locked ? null : () => onChanged(m),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: value == m ? AppColors.coral : AppColors.border,
                    width: value == m ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      value == m
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: value == m ? AppColors.coral : AppColors.textMuted,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            goalMetricLabel(l, m),
                            style: const TextStyle(
                              color: AppColors.navy,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            switch (m) {
                              LearningGoalMetric.boolean =>
                                l.lgMetricBooleanHelp,
                              LearningGoalMetric.numeric =>
                                l.lgMetricNumericHelp,
                              LearningGoalMetric.percent =>
                                l.lgMetricPercentHelp,
                            },
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StatusPicker extends StatelessWidget {
  const _StatusPicker({required this.value, required this.onChanged});
  final LearningGoalStatus value;
  final ValueChanged<LearningGoalStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Wrap(
      spacing: 8,
      children: [
        for (final s in LearningGoalStatus.editable)
          ChoiceChip(
            label: Text(goalStatusLabel(l, s)),
            selected: value == s,
            onSelected: (_) => onChanged(s),
            selectedColor: AppColors.teal,
          ),
      ],
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.label, required this.onTap, this.onClear});
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_outlined, color: Color(0xFF8E98AC)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: const TextStyle(color: AppColors.navy)),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
