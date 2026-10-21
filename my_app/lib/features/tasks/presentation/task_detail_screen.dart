import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../family/application/permissions_controller.dart';
import '../../family/data/models/family_permission.dart';
import '../application/completions_controller.dart';
import '../application/task_detail_controller.dart';
import '../application/tasks_controller.dart';
import '../data/models/child_task.dart';
import '../data/models/task_completion.dart';
import '../data/task_requests.dart';
import 'task_form_screen.dart';
import '../../kid/presentation/kid_widgets.dart';
import 'task_widgets.dart';
import 'request_completion_sheet.dart';

class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(taskDetailProvider(taskId));
    final canManageTasks = ref
        .watch(permissionsProvider)
        .hasPermission(FamilyPermission.manageTasks);

    return Scaffold(
      appBar: AppBar(
        title: Text(async.valueOrNull?.title ?? ''),
        actions: [
          if (canManageTasks &&
              async.hasValue &&
              !async.requireValue.isArchived) ...[
            IconButton(
              tooltip: l.commonEdit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TaskFormScreen(existing: async.requireValue),
                ),
              ),
            ),
            IconButton(
              tooltip: l.taskArchiveAction,
              icon: const Icon(Icons.archive_outlined),
              onPressed: () =>
                  _confirmArchive(context, ref, async.requireValue),
            ),
          ],
        ],
      ),
      body: AppContentFrame(
        child: async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorRetryView(
            error: e,
            onRetry: () async => ref.invalidate(taskDetailProvider(taskId)),
          ),
          data: (task) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(taskDetailProvider(taskId));
              await ref
                  .read(completionsControllerProvider(taskId).notifier)
                  .refresh();
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xxxl,
              ),
              children: [
                _TaskHeader(task: task),
                const SizedBox(height: AppSpacing.lg),
                if (!task.isArchived)
                  FilledButton.icon(
                    onPressed: () =>
                        showRequestCompletionSheet(context, taskId),
                    icon: const Icon(Icons.add_task_rounded),
                    label: Text(l.completionRequest),
                  ),
                const SizedBox(height: AppSpacing.xxl),
                SectionHeader(title: l.completionHistoryTitle),
                _CompletionsSection(taskId: taskId),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmArchive(
    BuildContext context,
    WidgetRef ref,
    ChildTask task,
  ) async {
    final l = context.l10n;
    final ok = await confirmAction(
      context,
      title: l.taskArchiveConfirmTitle,
      body: l.taskArchiveConfirmBody(task.title),
      confirmLabel: l.taskArchiveAction,
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(tasksControllerProvider.notifier).archiveTask(task.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.taskArchived)));
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.localizedMessage(l))));
    }
  }
}

class _TaskHeader extends StatelessWidget {
  const _TaskHeader({required this.task});
  final ChildTask task;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.mamily;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(icon: taskIcon(task.iconKey ?? task.category), size: 52),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(task.title, style: context.type.titleLarge)),
              const SizedBox(width: AppSpacing.sm),
              StatusPill(
                label: task.isArchived
                    ? l.taskStatusArchived
                    : l.taskStatusActive,
                tone: task.isArchived ? AppTone.neutral : AppTone.accent,
                icon: task.isArchived
                    ? Icons.archive_outlined
                    : Icons.play_circle_outline_rounded,
              ),
            ],
          ),
          if ((task.description ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              task.description!,
              style: context.type.bodyLarge?.copyWith(color: c.ink2),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _row(
            context,
            Icons.stars_rounded,
            '${l.taskDetailPointsLabel}: ${task.points}',
          ),
          _row(context, Icons.repeat_rounded, recurrenceSummary(context, task)),
          if (task.deadlineAt != null)
            _row(
              context,
              Icons.flag_outlined,
              '${l.taskFieldDeadline}: ${formatTaskDate(context, task.deadlineAt!.toLocal())}',
            ),
          if ((task.category ?? '').isNotEmpty)
            _row(context, Icons.label_outline_rounded, task.category!),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xs),
    child: Row(
      children: [
        Icon(icon, size: AppSizes.iconSm, color: context.mamily.ink3),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text, style: context.type.bodyMedium)),
      ],
    ),
  );
}

class _CompletionsSection extends ConsumerStatefulWidget {
  const _CompletionsSection({required this.taskId});
  final String taskId;

  @override
  ConsumerState<_CompletionsSection> createState() =>
      _CompletionsSectionState();
}

class _CompletionsSectionState extends ConsumerState<_CompletionsSection> {
  final Set<String> _busy = {};

  /// Runs a review action with a per-completion busy guard (prevents double
  /// taps). [action] returns the success message, or null if it was cancelled.
  Future<void> _run(
    String completionId,
    Future<String?> Function() action,
  ) async {
    if (_busy.contains(completionId)) return;
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    setState(() => _busy.add(completionId));
    try {
      final ok = await action();
      if (ok != null) messenger.showSnackBar(SnackBar(content: Text(ok)));
    } on ApiException catch (e) {
      final msg = e.isConflict ? l.completionConflict : e.localizedMessage(l);
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy.remove(completionId));
    }
  }

  Future<String?> _askNote(String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: context.l10n.completionReviewNote,
          ),
          maxLength: 500,
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

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final async = ref.watch(completionsControllerProvider(widget.taskId));
    final perms = ref.watch(permissionsProvider);
    final canReview = perms.hasPermission(
      FamilyPermission.approveTaskCompletions,
    );
    final canReverse = perms.hasPermission(FamilyPermission.reversePoints);
    final notifier = ref.read(
      completionsControllerProvider(widget.taskId).notifier,
    );

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => ErrorRetryView(error: e, onRetry: notifier.refresh),
      data: (state) => state.isEmpty
          ? Text(
              l.completionHistoryEmpty,
              style: context.type.bodyMedium?.copyWith(
                color: context.mamily.ink2,
              ),
            )
          : Column(
              children: [
                for (final c in state.completions)
                  _CompletionCard(
                    completion: c,
                    busy: _busy.contains(c.id),
                    canReview: canReview,
                    canReverse: canReverse,
                    onApprove: () => _run(c.id, () async {
                      final note = await _askNote(l.completionApprove);
                      if (note == null) return null;
                      await notifier.approve(c.id, ReviewInput(note: note));
                      return l.completionApproved;
                    }),
                    onReject: () => _run(c.id, () async {
                      final note = await _askNote(l.completionReject);
                      if (note == null) return null;
                      await notifier.reject(c.id, ReviewInput(note: note));
                      return l.completionRejected;
                    }),
                    onReverse: () => _run(c.id, () async {
                      final note = await _askNote(l.completionReverse);
                      if (note == null) return null;
                      await notifier.reverse(c.id, ReviewInput(note: note));
                      return l.completionReversed;
                    }),
                  ),
                if (state.hasMore)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: state.loadingMore
                        ? const CircularProgressIndicator()
                        : OutlinedButton(
                            onPressed: notifier.loadMore,
                            child: Text(l.tasksLoadMore),
                          ),
                  ),
              ],
            ),
    );
  }
}

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({
    required this.completion,
    required this.busy,
    required this.canReview,
    required this.canReverse,
    required this.onApprove,
    required this.onReject,
    required this.onReverse,
  });

  final TaskCompletion completion;
  final bool busy;
  final bool canReview;
  final bool canReverse;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onReverse;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = completion;
    final showApproveReject = canReview && c.canApproveOrReject;
    final showReverse = canReverse && c.canReverse;

    final colors = context.mamily;
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c.occurrenceDate == null
                      ? '—'
                      : l.completionOccurrence(
                          formatTaskDate(context, c.occurrenceDate!),
                        ),
                  style: context.type.titleSmall,
                ),
              ),
              CompletionStatusChip(completion: c),
            ],
          ),
          if (c.isApproved && (c.pointsAwarded ?? 0) > 0 && !c.isReversed) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              l.completionPointsAwarded(c.pointsAwarded!),
              style: context.type.labelLarge?.copyWith(
                color: colors.success.foreground,
              ),
            ),
          ],
          if ((c.reviewNote ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              c.reviewNote!,
              style: context.type.bodySmall?.copyWith(color: colors.ink2),
            ),
          ],
          if ((c.reversalNote ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              '${l.completionReversedBadge}: ${c.reversalNote!}',
              style: context.type.bodySmall?.copyWith(color: colors.ink2),
            ),
          ],
          if (busy)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.sm),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (showApproveReject || showReverse) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (showApproveReject)
                  FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(l.completionApprove),
                  ),
                if (showApproveReject)
                  OutlinedButton(
                    onPressed: onReject,
                    child: Text(l.completionReject),
                  ),
                if (showReverse)
                  TextButton.icon(
                    onPressed: onReverse,
                    icon: const Icon(Icons.undo_rounded),
                    label: Text(l.completionReverse),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
