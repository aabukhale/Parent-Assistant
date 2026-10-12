import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/design_system.dart';
import '../../auth/presentation/auth_form_widgets.dart';
import '../../family/application/permissions_controller.dart';
import '../../family/data/models/family_permission.dart';
import '../application/sleep_log_detail_controller.dart';
import '../application/sleep_logs_controller.dart';
import '../data/models/sleep_log.dart';
import '../data/sleep_requests.dart';
import 'sleep_widgets.dart';

/// Create (when [logId] is null) or edit a sleep record. In edit mode the log
/// is re-fetched (`GET …/sleep-logs/{id}`) so a concurrently deleted record
/// shows an honest error instead of a stale form.
class SleepFormScreen extends ConsumerWidget {
  const SleepFormScreen({super.key, this.logId});

  final String? logId;

  bool get isEdit => logId != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final canManage = ref
        .watch(permissionsProvider)
        .hasPermission(FamilyPermission.manageSleep);

    final async = isEdit ? ref.watch(sleepLogDetailProvider(logId!)) : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? l.sleepEditTitle : l.sleepAddTitle),
        actions: [
          if (isEdit && canManage && (async?.hasValue ?? false))
            IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                color: context.mamily.actionText,
              ),
              onPressed: () =>
                  _confirmDelete(context, ref, async!.requireValue),
            ),
        ],
      ),
      body: AppContentFrame(
        child: async == null
            ? const _SleepFormBody()
            : async.when(
                loading: () => const LoadingView(),
                error: (e, _) => ErrorRetryView(
                  error: e,
                  onRetry: () async =>
                      ref.invalidate(sleepLogDetailProvider(logId!)),
                ),
                data: (log) =>
                    _SleepFormBody(existing: log, key: ValueKey(log.id)),
              ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    SleepLog log,
  ) async {
    final l = context.l10n;
    final ok = await confirmAction(
      context,
      title: l.sleepDeleteConfirmTitle,
      body: l.sleepDeleteConfirmBody,
      confirmLabel: l.sleepDeleteAction,
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(sleepLogsControllerProvider.notifier).deleteLog(log.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.sleepDeleted)));
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.localizedMessage(l))));
    }
  }
}

class _SleepFormBody extends ConsumerStatefulWidget {
  const _SleepFormBody({this.existing, super.key});
  final SleepLog? existing;

  bool get isEdit => existing != null;

  @override
  ConsumerState<_SleepFormBody> createState() => _SleepFormBodyState();
}

class _SleepFormBodyState extends ConsumerState<_SleepFormBody> {
  late DateTime _bedtime;
  late DateTime _wake;

  bool _submitting = false;
  Map<String, List<String>> _fieldErrors = const {};
  String? _formError;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _bedtime = e.startedAtLocal;
      _wake = e.endedAtLocal;
    } else {
      final now = DateTime.now();
      // Default to "last night": 21:00 today → 07:00 next day (crosses midnight).
      _bedtime = DateTime(now.year, now.month, now.day, 21);
      _wake = _bedtime.add(const Duration(hours: 10));
    }
  }

  Future<void> _pick({required bool bedtime}) async {
    final initial = bedtime ? _bedtime : _wake;
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: now.add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (bedtime) {
        _bedtime = picked;
      } else {
        _wake = picked;
      }
    });
  }

  bool get _crossesMidnight =>
      _bedtime.year != _wake.year ||
      _bedtime.month != _wake.month ||
      _bedtime.day != _wake.day;

  Future<void> _submit() async {
    setState(() {
      _fieldErrors = const {};
      _formError = null;
    });
    final l = context.l10n;

    if (!_wake.isAfter(_bedtime)) {
      setState(
        () => _fieldErrors = {
          'started_at': [l.sleepValidationRange],
        },
      );
      return;
    }

    final input = SleepLogInput(
      startedAt: _bedtime,
      endedAt: _wake,
      source: widget.isEdit ? null : SleepSource.manual,
    );

    setState(() => _submitting = true);
    try {
      final controller = ref.read(sleepLogsControllerProvider.notifier);
      if (widget.isEdit) {
        await controller.updateLog(widget.existing!.id, input);
      } else {
        await controller.createLog(input);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEdit ? l.sleepUpdated : l.sleepCreated),
        ),
      );
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.isConflict) {
          _formError = l.sleepOverlap;
        } else if (e.isValidation) {
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: IconBadge(emoji: '🌙', tone: AppTone.sleep, size: 72),
          ),
          const SizedBox(height: AppSpacing.xxl),
          if (_formError != null) AuthFormErrorBanner(message: _formError!),
          _DateTimeCard(
            title: l.sleepFieldBedtime,
            icon: Icons.nightlight_rounded,
            dateText: formatSleepDate(context, _bedtime),
            timeText: formatSleepTime(context, _bedtime),
            onTap: () => _pick(bedtime: true),
          ),
          AuthFieldError(messages: _fieldErrors['started_at']),
          const SizedBox(height: AppSpacing.xs),
          _DateTimeCard(
            title: l.sleepFieldWake,
            icon: Icons.wb_sunny_rounded,
            dateText: formatSleepDate(context, _wake),
            timeText: formatSleepTime(context, _wake),
            badge: _crossesMidnight ? l.sleepNextDay : null,
            onTap: () => _pick(bedtime: false),
          ),
          AuthFieldError(messages: _fieldErrors['ended_at']),
          const SizedBox(height: AppSpacing.xxl),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(l.sleepSave),
          ),
          if (_submitting)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _DateTimeCard extends StatelessWidget {
  const _DateTimeCard({
    required this.title,
    required this.icon,
    required this.dateText,
    required this.timeText,
    required this.onTap,
    this.badge,
  });

  final String title;
  final IconData icon;
  final String dateText;
  final String timeText;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mamily;
    return Semantics(
      button: true,
      label: '$title, $dateText, $timeText${badge == null ? '' : ', $badge'}',
      excludeSemantics: true,
      child: AppCard(
        onTap: onTap,
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            IconBadge(icon: icon, tone: AppTone.sleep),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.type.titleSmall),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        dateText,
                        style: context.type.bodySmall?.copyWith(color: c.ink2),
                      ),
                      if (badge != null)
                        StatusPill(label: badge!, tone: AppTone.info),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              timeText,
              style: context.type.titleMedium?.copyWith(
                color: c.sleep.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
