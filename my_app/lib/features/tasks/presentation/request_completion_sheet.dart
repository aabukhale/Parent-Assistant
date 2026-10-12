import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/design_system.dart';
import '../../../widgets/primary_button.dart';
import '../../auth/presentation/auth_form_widgets.dart';
import '../application/completions_controller.dart';
import '../data/task_requests.dart';
import 'task_widgets.dart';

/// Log a task-occurrence completion. **Parent-managed / on-behalf-of-child** —
/// there is no secure Child Mode session yet (see docs/child-mode-security.md),
/// so this is not presented as an authenticated child action.
Future<bool?> showRequestCompletionSheet(BuildContext context, String taskId) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _RequestForm(taskId: taskId),
    ),
  );
}

class _RequestForm extends ConsumerStatefulWidget {
  const _RequestForm({required this.taskId});
  final String taskId;

  @override
  ConsumerState<_RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends ConsumerState<_RequestForm> {
  DateTime _date = DateTime.now();
  bool _submitting = false;
  Map<String, List<String>> _fieldErrors = const {};
  String? _formError;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (picked != null) setState(() => _date = picked);
  }

  bool get _isToday {
    final now = DateTime.now();
    return _date.year == now.year &&
        _date.month == now.month &&
        _date.day == now.day;
  }

  Future<void> _submit() async {
    setState(() {
      _fieldErrors = const {};
      _formError = null;
    });
    final l = context.l10n;
    setState(() => _submitting = true);
    try {
      await ref
          .read(completionsControllerProvider(widget.taskId).notifier)
          .requestCompletion(
            CompletionRequestInput(occurrenceDate: _isToday ? null : _date),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.completionRequested)));
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.isConflict) {
          _formError = l.completionConflict;
        } else if (e.isValidation) {
          _fieldErrors = e.fieldErrors;
          if (_fieldErrors.containsKey('occurrence_date') ||
              _fieldErrors.containsKey('task')) {
            _formError = l.completionInvalidOccurrence;
          } else if (_fieldErrors.isEmpty) {
            _formError = e.localizedMessage(l);
          }
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.completionRequestTitle, style: context.type.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l.completionOnBehalfNote,
              style: context.type.bodyMedium?.copyWith(
                color: context.mamily.ink2,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_formError != null) AuthFormErrorBanner(message: _formError!),
            FormSectionLabel(l.completionFieldDate),
            PickerField(
              icon: Icons.event_available_outlined,
              label: l.completionFieldDate,
              value: formatTaskDate(context, _date),
              onTap: _pickDate,
            ),
            AuthFieldError(messages: _fieldErrors['occurrence_date']),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              text: l.completionRequest,
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
    );
  }
}
