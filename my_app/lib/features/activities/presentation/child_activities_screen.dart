import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          l.activitiesAssignedTitle,
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
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
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
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
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.coral,
                                  ),
                                )
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  a.activity?.title ?? l.activitiesTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              ActivityPill(
                text: assignmentStatusLabel(l, a.status),
                color: assignmentStatusColor(a.status),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            a.pointsReward > 0
                ? l.activityRewardPoints(a.pointsReward)
                : l.activityNoPoints,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          if (a.dueDate != null)
            Text(
              l.activityDueOn(
                '${a.dueDate!.year}-${a.dueDate!.month.toString().padLeft(2, '0')}-${a.dueDate!.day.toString().padLeft(2, '0')}',
              ),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          if (last != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  completionStatusLabel(l, last.status),
                  style: TextStyle(
                    color: switch (last.status) {
                      CompletionStatus.approved => const Color(0xFF57C77A),
                      CompletionStatus.rejected => AppColors.coral,
                      CompletionStatus.pending => AppColors.amber,
                    },
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (last.isReversed) ...[
                  const SizedBox(width: 8),
                  Text(
                    l.completionReversedBadge,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
                if (last.pointsAwarded != null && last.pointsAwarded! > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    l.activityAwarded(last.pointsAwarded!),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
            if ((last.reviewNote ?? '').isNotEmpty)
              Text(
                last.reviewNote!,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
          ],
          const SizedBox(height: 10),
          if (busy)
            const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.coral,
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (a.canComplete)
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.coral,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: onComplete,
                    child: Text(l.activityMarkDone),
                  ),
                if (last != null && last.canApproveOrReject && canReview) ...[
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF57C77A),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => onApprove(last.id),
                    child: Text(l.redemptionApprove),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.coral,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => onReject(last.id),
                    child: Text(l.redemptionReject),
                  ),
                ],
                if (last != null && last.canReverse && canReverse)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => onReverse(last.id),
                    child: Text(l.completionReverse),
                  ),
              ],
            ),
          Text(
            l.activityOnBehalfNote,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
