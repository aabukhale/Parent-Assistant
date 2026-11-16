import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/design_system.dart';
import '../../children/application/selected_child_controller.dart';
import '../../family/application/permissions_controller.dart';
import '../../family/data/models/family_permission.dart';
import '../application/activities_controller.dart';
import '../application/activity_assignments_controller.dart';
import '../data/activity_requests.dart';
import '../data/models/activity.dart';
import 'activity_widgets.dart';

/// Real activity details from `GET /activities/{activity}`. When a child is
/// selected and the caller has `manage_activities`, offers an "assign to this
/// child" flow that persists through `POST …/activity-assignments`.
class ActivityDetailsScreen extends ConsumerWidget {
  const ActivityDetailsScreen({
    super.key,
    required this.activityId,
    this.childId,
  });

  final String activityId;
  final String? childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(activityDetailProvider(activityId));

    return Scaffold(
      appBar: AppBar(
        title: Text(async.valueOrNull?.title ?? l.activitiesTitle),
      ),
      body: AppContentFrame(
        child: async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorRetryView(
            error: e,
            onRetry: () async =>
                ref.invalidate(activityDetailProvider(activityId)),
          ),
          data: (activity) => _Body(activity: activity, childId: childId),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.activity, required this.childId});

  final Activity activity;
  final String? childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final canManage = ref
        .watch(permissionsProvider)
        .hasPermission(FamilyPermission.manageActivities);
    final age = activityAgeLabel(l, activity);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxxl,
      ),
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ActivityPill(
              text: activitySourceLabel(l, activity.source),
              icon: activitySourceIcon(activity.source),
            ),
            if (activity.durationMinutes != null)
              Text(
                l.activityDurationMin(activity.durationMinutes!),
                style: context.type.bodySmall?.copyWith(
                  color: context.mamily.ink2,
                ),
              ),
            if (age != null)
              Text(
                age,
                style: context.type.bodySmall?.copyWith(
                  color: context.mamily.ink2,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if ((activity.description ?? '').isNotEmpty)
          Text(activity.description!, style: context.type.bodyMedium),
        if (activity.materials.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          _ListSection(title: l.activityMaterials, items: activity.materials),
        ],
        if (activity.steps.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          _ListSection(
            title: l.activitySteps,
            items: activity.steps,
            numbered: true,
          ),
        ],
        const SizedBox(height: AppSpacing.xxl),
        if (childId == null)
          Text(
            l.activityAssignNeedsChild,
            style: context.type.bodySmall?.copyWith(color: context.mamily.ink2),
          )
        else if (!canManage)
          Text(
            l.activityAssignNoPermission,
            style: context.type.bodySmall?.copyWith(color: context.mamily.ink2),
          )
        else
          FilledButton.icon(
            onPressed: () => _assign(context, ref),
            icon: const Icon(Icons.add_task_rounded),
            label: Text(l.activityAssignAction),
          ),
      ],
    );
  }

  Future<void> _assign(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final result = await showModalBottomSheet<_AssignResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AssignSheet(activityTitle: activity.title),
    );
    if (result == null) return;

    // Keep the assignment providers scoped to this child.
    ref.read(selectedChildIdProvider.notifier).select(childId!);
    try {
      await ref
          .read(activityAssignmentsControllerProvider.notifier)
          .assign(
            ActivityAssignInput(
              activityId: activity.id,
              pointsReward: result.points,
              dueDate: result.dueDate,
            ),
          );
      messenger.showSnackBar(SnackBar(content: Text(l.activityAssigned)));
    } on ApiException catch (e) {
      final msg = switch (e.kind) {
        ApiErrorKind.notFound => l.activityUnavailable,
        _ => e.localizedMessage(l),
      };
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}

class _ListSection extends StatelessWidget {
  const _ListSection({
    required this.title,
    required this.items,
    this.numbered = false,
  });

  final String title;
  final List<String> items;
  final bool numbered;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.type.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    numbered ? '${i + 1}. ' : '•  ',
                    style: context.type.bodyMedium?.copyWith(
                      color: context.mamily.ink2,
                    ),
                  ),
                  Expanded(
                    child: Text(items[i], style: context.type.bodyMedium),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AssignResult {
  const _AssignResult({this.points, this.dueDate});
  final int? points;
  final DateTime? dueDate;
}

class _AssignSheet extends StatefulWidget {
  const _AssignSheet({required this.activityTitle});
  final String activityTitle;

  @override
  State<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends State<_AssignSheet> {
  final _points = TextEditingController();
  DateTime? _dueDate;
  String? _error;

  @override
  void dispose() {
    _points.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.activityAssignAction, style: context.type.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.activityTitle,
            style: context.type.bodySmall?.copyWith(color: context.mamily.ink2),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _points,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l.activityFieldPoints,
              helperText: l.activityFieldPointsHelp,
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _dueDate == null
                  ? l.activityFieldDueDate
                  : l.activityDueOn(
                      '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}',
                    ),
            ),
            trailing: const Icon(Icons.calendar_today_rounded, size: 18),
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _dueDate ?? now,
                firstDate: now.subtract(const Duration(days: 1)),
                lastDate: now.add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => _dueDate = picked);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l.activityAssignOnBehalfNote,
            style: context.type.bodySmall?.copyWith(color: context.mamily.ink2),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submit,
              child: Text(l.activityAssignAction),
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final raw = _points.text.trim();
    int? points;
    if (raw.isNotEmpty) {
      points = int.tryParse(raw);
      if (points == null || points < 0 || points > 100000) {
        setState(() => _error = context.l10n.activityPointsInvalid);
        return;
      }
    }
    Navigator.of(context).pop(_AssignResult(points: points, dueDate: _dueDate));
  }
}
