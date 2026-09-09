import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/primary_button.dart';
import '../../auth/presentation/auth_form_widgets.dart';
import '../application/tasks_controller.dart';
import '../data/models/child_task.dart';
import '../data/models/task_enums.dart';
import '../data/task_requests.dart';
import 'recurrence_field.dart';
import 'task_widgets.dart';

/// Create (when [existing] is null) or edit a task. `recurrence_type` /
/// `recurrence_config` are immutable after creation (backend contract).
class TaskFormScreen extends ConsumerStatefulWidget {
  const TaskFormScreen({super.key, this.existing});

  final ChildTask? existing;

  bool get isEdit => existing != null;

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _points;
  late final TextEditingController _category;

  TaskRecurrence _recurrence = TaskRecurrence.daily;
  RecurrenceConfig _recurrenceConfig = const RecurrenceConfig();
  bool _recurrenceValid = true;
  DateTime? _deadline;
  TaskStatus _status = TaskStatus.active;

  bool _submitting = false;
  Map<String, List<String>> _fieldErrors = const {};
  String? _formError;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _points = TextEditingController(text: e != null ? '${e.points}' : '10');
    _category = TextEditingController(text: e?.category ?? '');
    _recurrence = e?.recurrenceType ?? TaskRecurrence.daily;
    _recurrenceConfig = e?.recurrenceConfig ?? const RecurrenceConfig();
    _deadline = e?.deadlineAt?.toLocal();
    _status = e?.status ?? TaskStatus.active;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _points.dispose();
    _category.dispose();
    super.dispose();
  }

  int? get _parsedPoints => int.tryParse(_points.text.trim());

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 7)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _submit() async {
    setState(() {
      _fieldErrors = const {};
      _formError = null;
    });
    final l = context.l10n;
    if (!_formKey.currentState!.validate()) return;

    final points = _parsedPoints;
    if (points == null || points < 0 || points > 100000) {
      setState(
        () => _fieldErrors = {
          'points': [l.taskValidationPointsRange],
        },
      );
      return;
    }
    if (!widget.isEdit && _recurrence.needsConfig && !_recurrenceValid) {
      setState(
        () => _fieldErrors = {
          'recurrence_config': [
            _recurrence == TaskRecurrence.weekly
                ? l.recurrenceWeeklyNeedsDay
                : l.recurrenceCustomNeedsConfig,
          ],
        },
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final controller = ref.read(tasksControllerProvider.notifier);
      if (widget.isEdit) {
        await controller.updateTask(widget.existing!.id, _buildUpdate(points));
      } else {
        await controller.createTask(_buildCreate(points));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.isEdit ? l.taskUpdated : l.taskCreated)),
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

  TaskCreateInput _buildCreate(int points) => TaskCreateInput(
    title: _title.text,
    description: _description.text,
    points: points,
    recurrenceType: _recurrence,
    recurrenceConfig: _recurrence.needsConfig ? _recurrenceConfig : null,
    deadlineAt: _deadline,
    category: _category.text,
  );

  TaskUpdateInput _buildUpdate(int points) {
    final desc = _description.text.trim();
    final cat = _category.text.trim();
    return TaskUpdateInput(
      title: _title.text,
      description: desc.isEmpty ? null : desc,
      clearDescription: desc.isEmpty,
      points: points,
      deadlineAt: _deadline,
      clearDeadline: _deadline == null,
      category: cat.isEmpty ? null : cat,
      clearCategory: cat.isEmpty,
      status: _status,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isEdit ? l.tasksEditTitle : l.tasksNewTitle),
      ),
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
                  label: l.taskFieldTitle,
                  hint: l.taskFieldTitleHint,
                  controller: _title,
                  prefixIcon: Icons.task_alt_rounded,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l.validationRequired
                      : null,
                ),
                AuthFieldError(messages: _fieldErrors['title']),
                const SizedBox(height: 16),
                AppTextField(
                  label: l.taskFieldDescription,
                  controller: _description,
                  prefixIcon: Icons.notes_rounded,
                ),
                AuthFieldError(messages: _fieldErrors['description']),
                const SizedBox(height: 16),
                AppTextField(
                  label: l.taskFieldPoints,
                  controller: _points,
                  prefixIcon: Icons.stars_rounded,
                  keyboardType: TextInputType.number,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l.validationRequired
                      : null,
                ),
                AuthFieldError(messages: _fieldErrors['points']),
                const SizedBox(height: 18),
                _sectionLabel(l.taskFieldRecurrence),
                const SizedBox(height: 8),
                if (widget.isEdit)
                  _ReadOnlyRecurrence(task: widget.existing!)
                else ...[
                  _RecurrencePicker(
                    value: _recurrence,
                    onChanged: (r) => setState(() {
                      _recurrence = r;
                      _recurrenceConfig = const RecurrenceConfig();
                      _recurrenceValid = !r.needsConfig;
                    }),
                  ),
                  AuthFieldError(messages: _fieldErrors['recurrence_type']),
                  if (_recurrence.needsConfig) ...[
                    const SizedBox(height: 12),
                    RecurrenceField(
                      type: _recurrence,
                      initial: _recurrenceConfig,
                      onChanged: (config, valid) {
                        _recurrenceConfig = config;
                        _recurrenceValid = valid;
                      },
                    ),
                    AuthFieldError(
                      messages:
                          _fieldErrors['recurrence_config'] ??
                          _fieldErrors['recurrence_config.days_of_week'],
                    ),
                  ],
                ],
                const SizedBox(height: 18),
                _sectionLabel(l.taskFieldDeadline),
                const SizedBox(height: 8),
                _DeadlineTile(
                  label: _deadline == null
                      ? l.taskFieldDeadline
                      : formatTaskDate(context, _deadline!),
                  onClear: _deadline == null
                      ? null
                      : () => setState(() => _deadline = null),
                  onTap: _pickDeadline,
                ),
                AuthFieldError(messages: _fieldErrors['deadline_at']),
                const SizedBox(height: 16),
                AppTextField(
                  label: l.taskFieldCategory,
                  controller: _category,
                  prefixIcon: Icons.label_outline_rounded,
                ),
                AuthFieldError(messages: _fieldErrors['category']),
                if (widget.isEdit) ...[
                  const SizedBox(height: 18),
                  _sectionLabel(l.taskStatusActive),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final s in TaskStatus.values)
                        ChoiceChip(
                          label: Text(
                            s == TaskStatus.active
                                ? l.taskStatusActive
                                : l.taskStatusArchived,
                          ),
                          selected: _status == s,
                          onSelected: (_) => setState(() => _status = s),
                          selectedColor: AppColors.teal,
                        ),
                    ],
                  ),
                  AuthFieldError(messages: _fieldErrors['status']),
                ],
                const SizedBox(height: 28),
                PrimaryButton(
                  text: l.taskSave,
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

  Widget _sectionLabel(String text) => Align(
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

class _RecurrencePicker extends StatelessWidget {
  const _RecurrencePicker({required this.value, required this.onChanged});
  final TaskRecurrence value;
  final ValueChanged<TaskRecurrence> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    String label(TaskRecurrence r) => switch (r) {
      TaskRecurrence.oneTime => l.recurrenceOneTime,
      TaskRecurrence.daily => l.recurrenceDaily,
      TaskRecurrence.weekly => l.recurrenceWeekly,
      TaskRecurrence.custom => l.recurrenceCustom,
    };
    String help(TaskRecurrence r) => switch (r) {
      TaskRecurrence.oneTime => l.recurrenceOneTimeHelp,
      TaskRecurrence.daily => l.recurrenceDailyHelp,
      TaskRecurrence.weekly => l.recurrenceWeeklyHelp,
      TaskRecurrence.custom => l.recurrenceCustomHelp,
    };
    return Column(
      children: [
        for (final r in TaskRecurrence.values)
          GestureDetector(
            onTap: () => onChanged(r),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: value == r ? AppColors.coral : AppColors.border,
                  width: value == r ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    value == r
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: value == r ? AppColors.coral : AppColors.textMuted,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label(r),
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          help(r),
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
      ],
    );
  }
}

class _ReadOnlyRecurrence extends StatelessWidget {
  const _ReadOnlyRecurrence({required this.task});
  final ChildTask task;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 18,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              recurrenceSummary(context, task),
              style: const TextStyle(color: AppColors.navy),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeadlineTile extends StatelessWidget {
  const _DeadlineTile({required this.label, required this.onTap, this.onClear});
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.flag_outlined, color: Color(0xFF8E98AC), size: 20),
            const SizedBox(width: 10),
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
