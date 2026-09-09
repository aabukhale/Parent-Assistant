import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
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
          if (canManage &&
              async.hasValue &&
              !async.requireValue.isArchived) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.navy),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      LearningGoalFormScreen(existing: async.requireValue),
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.lgArchiveConfirmTitle),
        content: Text(l.lgArchiveConfirmBody(goal.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              l.lgArchive,
              style: const TextStyle(color: AppColors.coral),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      goal.title,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  GoalStatusChip(status: goal.status),
                ],
              ),
              if ((goal.description ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  goal.description!,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                goalMetricLabel(l, goal.metric),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.lgStanding,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                goalStandingText(l, goal),
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              GoalProgressBar(goal: goal),
              const SizedBox(height: 14),
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
                  color: const Color(0xFF57C77A),
                ),
            ],
          ),
        ),
        if (canManage && !goal.isArchived) ...[
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.coral,
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: () => showRecordProgressSheet(context, goal),
            icon: const Icon(Icons.add_chart_rounded),
            label: Text(l.lgRecord),
          ),
        ],
        const SizedBox(height: 22),
        Text(
          l.lgHistoryTitle,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        progress.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.coral),
            ),
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
                  style: const TextStyle(color: AppColors.textMuted),
                )
              : Column(
                  children: [
                    for (final entry in state.entries)
                      _ProgressTile(goal: goal, entry: entry),
                    if (state.hasMore)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: state.loadingMore
                            ? const CircularProgressIndicator(
                                color: AppColors.coral,
                              )
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
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
    ),
    child: child,
  );
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text, this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Icon(icon, size: 16, color: color ?? AppColors.textMuted),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(color: color ?? AppColors.textMuted, fontSize: 13),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  valueText,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if ((entry.note ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    entry.note!,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (entry.recordedAt != null)
            Text(
              formatGoalDate(context, entry.recordedAt!),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
        ],
      ),
    );
  }
}
