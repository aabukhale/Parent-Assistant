import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/design_system.dart';
import '../../family/application/permissions_controller.dart';
import '../../family/data/models/family_permission.dart';
import '../application/learning_goal_detail_controller.dart';
import '../application/learning_goal_progress_controller.dart';
import '../application/learning_goals_controller.dart';
import '../data/models/learning_goal.dart';
import 'goal_widgets.dart';
import 'learning_goal_form_screen.dart';
import 'record_progress_sheet.dart';

class LearningGoalDetailScreen extends ConsumerWidget {
  const LearningGoalDetailScreen({super.key, required this.goalId});

  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(learningGoalDetailProvider(goalId));
    final canManage = ref
        .watch(permissionsProvider)
        .hasPermission(FamilyPermission.manageLearningGoals);

    return Scaffold(
      appBar: AppBar(
        title: Text(async.valueOrNull?.title ?? ''),
        actions: [
          if (canManage &&
              async.hasValue &&
              !async.requireValue.isArchived) ...[
            IconButton(
              tooltip: context.l10n.commonEdit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      LearningGoalFormScreen(existing: async.requireValue),
                ),
              ),
            ),
            IconButton(
              tooltip: context.l10n.lgArchive,
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
            onRetry: () async =>
                ref.invalidate(learningGoalDetailProvider(goalId)),
          ),
          data: (goal) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(learningGoalDetailProvider(goalId));
              await ref
                  .read(goalProgressControllerProvider(goalId).notifier)
                  .refresh();
            },
            child: _Body(goal: goal, canManage: canManage),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmArchive(
    BuildContext context,
    WidgetRef ref,
    LearningGoal goal,
  ) async {
    final l = context.l10n;
    final ok = await confirmAction(
      context,
      title: l.lgArchiveConfirmTitle,
      body: l.lgArchiveConfirmBody(goal.title),
      confirmLabel: l.lgArchive,
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref
          .read(learningGoalsControllerProvider.notifier)
          .archiveGoal(goal.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.lgArchived)));
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.localizedMessage(l))));
    }
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.goal, required this.canManage});
  final LearningGoal goal;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final progress = ref.watch(goalProgressControllerProvider(goal.id));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxxl,
      ),
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(goal.title, style: context.type.titleMedium),
                  ),
                  GoalStatusChip(status: goal.status),
                ],
              ),
              if ((goal.description ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  goal.description!,
                  style: context.type.bodyMedium?.copyWith(
                    color: context.mamily.ink2,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              Text(
                goalMetricLabel(l, goal.metric),
                style: context.type.bodySmall?.copyWith(
                  color: context.mamily.ink2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.lgStanding, style: context.type.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              Text(goalStandingText(l, goal), style: context.type.titleLarge),
              const SizedBox(height: AppSpacing.md),
              GoalProgressBar(goal: goal),
              const SizedBox(height: AppSpacing.md),
              if (goal.startDate != null)
                _MetaRow(
                  icon: Icons.play_arrow_rounded,
                  text: l.lgStartedOn(formatGoalDate(context, goal.startDate!)),
                ),
              if (goal.targetDate != null)
                _MetaRow(
                  icon: Icons.flag_outlined,
                  text: l.lgTargetOn(formatGoalDate(context, goal.targetDate!)),
                ),
              if (goal.achievedAt != null)
                _MetaRow(
                  icon: Icons.emoji_events_outlined,
                  text: l.lgAchievedOn(
                    formatGoalDate(context, goal.achievedAt!),
                  ),
                  color: context.mamily.success.foreground,
                ),
            ],
          ),
        ),
        if (canManage && !goal.isArchived) ...[
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: () => showRecordProgressSheet(context, goal),
            icon: const Icon(Icons.add_chart_rounded),
            label: Text(l.lgRecord),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(title: l.lgHistoryTitle),
        progress.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => ErrorRetryView(
            error: e,
            onRetry: () => ref
                .read(goalProgressControllerProvider(goal.id).notifier)
                .refresh(),
          ),
          data: (state) => state.isEmpty
              ? Text(
                  l.lgHistoryEmpty,
                  style: context.type.bodyMedium?.copyWith(
                    color: context.mamily.ink2,
                  ),
                )
              : Column(
                  children: [
                    for (final entry in state.entries)
                      _ProgressTile(goal: goal, entry: entry),
                    if (state.hasMore)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: state.loadingMore
                            ? const CircularProgressIndicator()
                            : OutlinedButton(
                                onPressed: () => ref
                                    .read(
                                      goalProgressControllerProvider(
                                        goal.id,
                                      ).notifier,
                                    )
                                    .loadMore(),
                                child: Text(l.lgLoadMore),
                              ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: AppCard(padding: const EdgeInsets.all(AppSpacing.xl), child: child),
  );
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text, this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Row(
      children: [
        Icon(icon, size: AppSizes.iconSm, color: color ?? context.mamily.ink2),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: context.type.bodyMedium?.copyWith(
              color: color ?? context.mamily.ink2,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ProgressTile extends StatelessWidget {
  const _ProgressTile({required this.goal, required this.entry});
  final LearningGoal goal;
  final LearningGoalProgressEntry entry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final valueText = switch (goal.metric) {
      LearningGoalMetric.boolean => entry.value >= 1 ? l.lgDone : l.lgNotDone,
      LearningGoalMetric.percent => '${formatGoalNumber(entry.value)}%',
      LearningGoalMetric.numeric =>
        (goal.unit ?? '').trim().isEmpty
            ? formatGoalNumber(entry.value)
            : '${formatGoalNumber(entry.value)} ${goal.unit!.trim()}',
    };
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(valueText, style: context.type.titleSmall),
                if ((entry.note ?? '').isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    entry.note!,
                    style: context.type.bodySmall?.copyWith(
                      color: context.mamily.ink2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (entry.recordedAt != null)
            Text(
              formatGoalDate(context, entry.recordedAt!),
              style: context.type.bodySmall?.copyWith(
                color: context.mamily.ink2,
              ),
            ),
        ],
      ),
    );
  }
}
