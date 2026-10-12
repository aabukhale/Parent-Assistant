import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/design_system.dart';
import '../../family/application/permissions_controller.dart';
import '../../family/data/models/family_permission.dart';
import '../../tasks/data/models/task_enums.dart';
import '../../tasks/data/task_requests.dart';
import '../application/activity_assignments_controller.dart';
import '../data/models/activity_assignment.dart';
import 'activity_widgets.dart';

/// A child's assigned activities + the completion workflow. Reached from the
/// child details screen. All completion actions are **parent-managed /
/// on-behalf-of-child** (no secure child session — see docs/child-mode-security.md).
class ChildActivitiesScreen extends ConsumerStatefulWidget {
  const ChildActivitiesScreen({super.key});

  @override
  ConsumerState<ChildActivitiesScreen> createState() =>
      _ChildActivitiesScreenState();
}

class _ChildActivitiesScreenState extends ConsumerState<ChildActivitiesScreen> {
  final Set<String> _busy = {};

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final async = ref.watch(activityAssignmentsControllerProvider);
    final controller = ref.read(activityAssignmentsControllerProvider.notifier);
    final permissions = ref.watch(permissionsProvider);
    final canReview = permissions.hasPermission(
      FamilyPermission.approveTaskCompletions,
    );
    final canReverse = permissions.hasPermission(
      FamilyPermission.reversePoints,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.activitiesAssignedTitle)),
      body: AppContentFrame(
        child: RefreshIndicator(
          onRefresh: controller.refresh,
          child: async.when(
            skipLoadingOnReload: true,
            loading: () => const LoadingView(),
            error: (e, _) => ListView(
              children: [
                const SizedBox(height: 120),
                ErrorRetryView(error: e, onRetry: controller.refresh),
              ],
            ),
            data: (state) => state.isEmpty
                ? EmptyView(
                    icon: Icons.directions_run_rounded,
                    message: l.activitiesAssignedEmpty,
                    onRefresh: controller.refresh,
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.xxxl,
                    ),
                    children: [
                      for (final a in state.assignments)
                        _AssignmentCard(
                          assignment: a,
                          canReview: canReview,
                          canReverse: canReverse,
                          busy: _busy.contains(a.id),
                          onComplete: () => _run(a.id, () async {
                            await controller.complete(
                              a.id,
                              const ReviewInput(),
                            );
                            return l.activityCompletionRequested;
                          }),
                          onApprove: (cId) => _run(a.id, () async {
                            final note = await _note(l.redemptionApprove);
                            if (note == null) return null;
                            await controller.approve(
                              a.id,
                              cId,
                              ReviewInput(note: note),
                            );
                            return l.redemptionApproved;
                          }),
                          onReject: (cId) => _run(a.id, () async {
                            final note = await _note(l.redemptionReject);
                            if (note == null) return null;
                            await controller.reject(
                              a.id,
                              cId,
                              ReviewInput(note: note),
                            );
                            return l.redemptionRejected;
                          }),
                          onReverse: (cId) => _run(a.id, () async {
                            final note = await _note(l.completionReverse);
                            if (note == null) return null;
                            await controller.reverse(
                              a.id,
                              cId,
                              ReviewInput(note: note),
                            );
                            return l.completionReversed;
                          }),
                        ),
                      if (state.hasMore)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: state.loadingMore
                              ? const Center(child: CircularProgressIndicator())
                              : OutlinedButton(
                                  onPressed: controller.loadMore,
                                  child: Text(l.rewardsLoadMore),
                                ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _run(String id, Future<String?> Function() action) async {
    if (_busy.contains(id)) return;
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    setState(() => _busy.add(id));
    try {
      final ok = await action();
      if (ok != null) {
        messenger.showSnackBar(SnackBar(content: Text(ok)));
      }
    } on ApiException catch (e) {
      final msg = switch (e.kind) {
        ApiErrorKind.conflict => l.activityConflict,
        _ => e.localizedMessage(l),
      };
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<String?> _note(String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: context.l10n.redemptionReviewNote,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(context.l10n.commonSave),
          ),
        ],
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    required this.assignment,
    required this.canReview,
    required this.canReverse,
    required this.busy,
    required this.onComplete,
    required this.onApprove,
    required this.onReject,
    required this.onReverse,
  });

  final ActivityAssignment assignment;
  final bool canReview;
  final bool canReverse;
  final bool busy;
  final VoidCallback onComplete;
  final void Function(String completionId) onApprove;
  final void Function(String completionId) onReject;
  final void Function(String completionId) onReverse;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final a = assignment;
    final last = a.latestCompletion;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  a.activity?.title ?? l.activitiesTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.titleSmall,
                ),
              ),
              ActivityPill(
                text: assignmentStatusLabel(l, a.status),
                tone: assignmentStatusTone(a.status),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            a.pointsReward > 0
                ? l.activityRewardPoints(a.pointsReward)
                : l.activityNoPoints,
            style: context.type.bodySmall?.copyWith(color: context.mamily.ink2),
          ),
          if (a.dueDate != null)
            Text(
              l.activityDueOn(
                '${a.dueDate!.year}-${a.dueDate!.month.toString().padLeft(2, '0')}-${a.dueDate!.day.toString().padLeft(2, '0')}',
              ),
              style: context.type.bodySmall?.copyWith(
                color: context.mamily.ink2,
              ),
            ),
          if (last != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusPill(
                  label: completionStatusLabel(l, last.status),
                  tone: switch (last.status) {
                    CompletionStatus.approved => AppTone.success,
                    CompletionStatus.rejected => AppTone.danger,
                    CompletionStatus.pending => AppTone.warning,
                  },
                ),
                if (last.isReversed)
                  StatusPill(
                    label: l.completionReversedBadge,
                    icon: Icons.undo_rounded,
                  ),
                if (last.pointsAwarded != null && last.pointsAwarded! > 0)
                  Text(
                    l.activityAwarded(last.pointsAwarded!),
                    style: context.type.bodySmall?.copyWith(
                      color: context.mamily.ink2,
                    ),
                  ),
              ],
            ),
            if ((last.reviewNote ?? '').isNotEmpty)
              Text(
                last.reviewNote!,
                style: context.type.bodySmall?.copyWith(
                  color: context.mamily.ink2,
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (busy)
            const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (a.canComplete)
                  FilledButton(
                    onPressed: onComplete,
                    child: Text(l.activityMarkDone),
                  ),
                if (last != null && last.canApproveOrReject && canReview) ...[
                  FilledButton(
                    onPressed: () => onApprove(last.id),
                    child: Text(l.redemptionApprove),
                  ),
                  OutlinedButton(
                    onPressed: () => onReject(last.id),
                    child: Text(l.redemptionReject),
                  ),
                ],
                if (last != null && last.canReverse && canReverse)
                  TextButton(
                    onPressed: () => onReverse(last.id),
                    child: Text(l.completionReverse),
                  ),
              ],
            ),
          Text(
            l.activityOnBehalfNote,
            style: context.type.bodySmall?.copyWith(color: context.mamily.ink2),
          ),
        ],
      ),
    );
  }
}
