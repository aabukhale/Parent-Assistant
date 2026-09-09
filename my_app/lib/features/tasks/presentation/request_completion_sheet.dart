import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
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
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
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
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
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
              l.completionRequestTitle,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l.completionOnBehalfNote,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            if (_formError != null) AuthFormErrorBanner(message: _formError!),
            Text(
              l.completionFieldDate,
              style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_available_outlined,
                      color: Color(0xFF8E98AC),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      formatTaskDate(context, _date),
                      style: const TextStyle(color: AppColors.navy),
                    ),
                  ],
                ),
              ),
            ),
            AuthFieldError(messages: _fieldErrors['occurrence_date']),
            const SizedBox(height: 20),
            PrimaryButton(
              text: l.completionRequest,
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
    );
  }
}
