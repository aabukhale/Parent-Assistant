import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/design_system.dart';
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
      appBar: AppBar(title: Text(widget.isEdit ? l.lgEditTitle : l.lgNewTitle)),
      body: AppContentFrame(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xxxl,
          ),
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
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: l.lgFieldDescription,
                  controller: _description,
                  prefixIcon: Icons.notes_rounded,
                ),
                AuthFieldError(messages: _fieldErrors['description']),
                FormSectionLabel(l.lgFieldMetric),
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
                      style: context.type.bodySmall?.copyWith(
                        color: context.mamily.ink2,
                      ),
                    ),
                  ),
                AuthFieldError(messages: _fieldErrors['metric']),
                if (_metric.requiresTarget) ...[
                  const SizedBox(height: AppSpacing.lg),
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
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: l.lgFieldUnit,
                    hint: l.lgFieldUnitHint,
                    controller: _unit,
                  ),
                  AuthFieldError(messages: _fieldErrors['unit']),
                ],
                const SizedBox(height: AppSpacing.lg),
                if (!widget.isEdit) ...[
                  FormSectionLabel(l.lgFieldStartDate),
                  PickerField(
                    icon: Icons.event_outlined,
                    label: l.lgFieldStartDate,
                    value: formatGoalDate(context, _startDate),
                    onTap: () => _pickDate(isStart: true),
                  ),
                  AuthFieldError(messages: _fieldErrors['start_date']),
                  const SizedBox(height: AppSpacing.lg),
                ],
                FormSectionLabel(l.lgFieldTargetDate),
                PickerField(
                  icon: Icons.flag_outlined,
                  label: l.lgFieldTargetDate,
                  value: _targetDate == null
                      ? null
                      : formatGoalDate(context, _targetDate!),
                  onClear: _targetDate == null
                      ? null
                      : () => setState(() => _targetDate = null),
                  onTap: () => _pickDate(isStart: false),
                ),
                AuthFieldError(messages: _fieldErrors['target_date']),
                if (widget.isEdit) ...[
                  FormSectionLabel(l.lgFieldStatus),
                  _StatusPicker(
                    value: _status,
                    onChanged: (s) => setState(() => _status = s),
                  ),
                  AuthFieldError(messages: _fieldErrors['status']),
                ],
                const SizedBox(height: AppSpacing.xxl),
                PrimaryButton(
                  text: l.lgSave,
                  onPressed: _submitting ? null : _submit,
                ),
                if (_submitting)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
          RadioOptionCard<LearningGoalMetric>(
            value: m,
            groupValue: value,
            enabled: !locked,
            title: goalMetricLabel(l, m),
            subtitle: switch (m) {
              LearningGoalMetric.boolean => l.lgMetricBooleanHelp,
              LearningGoalMetric.numeric => l.lgMetricNumericHelp,
              LearningGoalMetric.percent => l.lgMetricPercentHelp,
            },
            onChanged: onChanged,
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
    return ChoiceChipBar<LearningGoalStatus>(
      options: {
        for (final s in LearningGoalStatus.editable) s: goalStatusLabel(l, s),
      },
      selected: value,
      onSelected: onChanged,
    );
  }
}
