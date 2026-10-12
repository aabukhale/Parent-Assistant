import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/design_system.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/primary_button.dart';
import '../../auth/presentation/auth_form_widgets.dart';
import '../../kid/presentation/kid_widgets.dart';
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
  String? _iconKey;

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
    _iconKey = e?.iconKey;
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
    iconKey: _iconKey,
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
      iconKey: _iconKey,
      status: _status,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? l.tasksEditTitle : l.tasksNewTitle),
      ),
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
                  label: l.taskFieldTitle,
                  hint: l.taskFieldTitleHint,
                  controller: _title,
                  prefixIcon: Icons.task_alt_rounded,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l.validationRequired
                      : null,
                ),
                AuthFieldError(messages: _fieldErrors['title']),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: l.taskFieldDescription,
                  controller: _description,
                  prefixIcon: Icons.notes_rounded,
                ),
                AuthFieldError(messages: _fieldErrors['description']),
                const SizedBox(height: AppSpacing.lg),
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
                FormSectionLabel(l.taskFieldRecurrence),
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
                FormSectionLabel(l.taskFieldDeadline),
                PickerField(
                  icon: Icons.flag_outlined,
                  label: l.taskFieldDeadline,
                  value: _deadline == null
                      ? null
                      : formatTaskDate(context, _deadline!),
                  onClear: _deadline == null
                      ? null
                      : () => setState(() => _deadline = null),
                  onTap: _pickDeadline,
                ),
                AuthFieldError(messages: _fieldErrors['deadline_at']),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: l.taskFieldCategory,
                  controller: _category,
                  prefixIcon: Icons.label_outline_rounded,
                ),
                AuthFieldError(messages: _fieldErrors['category']),
                const SizedBox(height: AppSpacing.lg),
                AppListTile(
                  margin: EdgeInsets.zero,
                  leading: EmojiTile(
                    emoji: iconEmoji(_iconKey ?? _category.text),
                    size: 44,
                  ),
                  title: l.taskFieldIcon,
                  subtitle: l.taskFieldIconHint,
                  onTap: () async {
                    final key = await pickIconKey(context, current: _iconKey);
                    if (key != null && mounted) setState(() => _iconKey = key);
                  },
                ),
                if (widget.isEdit) ...[
                  FormSectionLabel(l.taskStatusActive),
                  ChoiceChipBar<TaskStatus>(
                    options: {
                      for (final s in TaskStatus.values)
                        s: s == TaskStatus.active
                            ? l.taskStatusActive
                            : l.taskStatusArchived,
                    },
                    selected: _status,
                    onSelected: (s) => setState(() => _status = s),
                  ),
                  AuthFieldError(messages: _fieldErrors['status']),
                ],
                const SizedBox(height: AppSpacing.xxl),
                PrimaryButton(
                  text: l.taskSave,
                  onPressed: _submitting ? null : _submit,
                ),
                if (_submitting)
                  const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.lg),
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
          RadioOptionCard<TaskRecurrence>(
            value: r,
            groupValue: value,
            title: label(r),
            subtitle: help(r),
            onChanged: onChanged,
          ),
      ],
    );
  }
}

class _ReadOnlyRecurrence extends StatelessWidget {
  const _ReadOnlyRecurrence({required this.task});
  final ChildTask task;

  @override
  Widget build(BuildContext context) =>
      ReadOnlyField(text: recurrenceSummary(context, task));
}
