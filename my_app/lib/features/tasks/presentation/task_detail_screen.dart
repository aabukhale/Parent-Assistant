import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
import '../../family/application/permissions_controller.dart';
import '../../family/data/models/family_permission.dart';
import '../application/completions_controller.dart';
import '../application/task_detail_controller.dart';
import '../application/tasks_controller.dart';
import '../data/models/child_task.dart';
import '../data/models/task_completion.dart';
import '../data/task_requests.dart';
import 'task_form_screen.dart';
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          async.valueOrNull?.title ?? '',
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (canManageTasks &&
              async.hasValue &&
              !async.requireValue.isArchived) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.navy),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TaskFormScreen(existing: async.requireValue),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.archive_outlined, color: AppColors.coral),
              onPressed: () =>
                  _confirmArchive(context, ref, async.requireValue),
            ),
          ],
        ],
      ),
      body: SafeArea(
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                _TaskHeader(task: task),
                const SizedBox(height: 16),
                if (!task.isArchived)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.coral,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: () =>
                        showRequestCompletionSheet(context, taskId),
                    icon: const Icon(Icons.add_task_rounded),
                    label: Text(l.completionRequest),
                  ),
                const SizedBox(height: 22),
                Text(
                  l.completionHistoryTitle,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.taskArchiveConfirmTitle),
        content: Text(l.taskArchiveConfirmBody(task.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              l.taskArchiveAction,
              style: const TextStyle(color: AppColors.coral),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color:
                      (task.isArchived ? AppColors.textMuted : AppColors.teal)
                          .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  task.isArchived ? l.taskStatusArchived : l.taskStatusActive,
                  style: TextStyle(
                    color: task.isArchived
                        ? AppColors.textMuted
                        : AppColors.teal,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if ((task.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              task.description!,
              style: const TextStyle(color: AppColors.textMuted, height: 1.5),
            ),
          ],
          const SizedBox(height: 12),
          _row(
            Icons.stars_rounded,
            '${l.taskDetailPointsLabel}: ${task.points}',
          ),
          _row(Icons.repeat_rounded, recurrenceSummary(context, task)),
          if (task.deadlineAt != null)
            _row(
              Icons.flag_outlined,
              '${l.taskFieldDeadline}: ${formatTaskDate(context, task.deadlineAt!.toLocal())}',
            ),
          if ((task.category ?? '').isNotEmpty)
            _row(Icons.label_outline_rounded, task.category!),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppColors.navy, fontSize: 13),
          ),
        ),
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
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(color: AppColors.coral)),
      ),
      error: (e, _) => ErrorRetryView(error: e, onRetry: notifier.refresh),
      data: (state) => state.isEmpty
          ? Text(
              l.completionHistoryEmpty,
              style: const TextStyle(color: AppColors.textMuted),
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
                    padding: const EdgeInsets.only(top: 6),
                    child: state.loadingMore
                        ? const CircularProgressIndicator(
                            color: AppColors.coral,
                          )
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
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
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              CompletionStatusChip(completion: c),
            ],
          ),
          if (c.isApproved && (c.pointsAwarded ?? 0) > 0 && !c.isReversed) ...[
            const SizedBox(height: 4),
            Text(
              l.completionPointsAwarded(c.pointsAwarded!),
              style: const TextStyle(
                color: Color(0xFF57C77A),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          if ((c.reviewNote ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              c.reviewNote!,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
          if ((c.reversalNote ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              '${l.completionReversedBadge}: ${c.reversalNote!}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
          if (busy)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.coral,
                ),
              ),
            )
          else if (showApproveReject || showReverse) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (showApproveReject)
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF57C77A),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: onApprove,
                    child: Text(l.completionApprove),
                  ),
                if (showApproveReject)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.coral,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: onReject,
                    child: Text(l.completionReject),
                  ),
                if (showReverse)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: onReverse,
                    child: Text(l.completionReverse),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
