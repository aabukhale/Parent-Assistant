import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/design_system.dart';
import '../../children/application/selected_child_controller.dart';
import '../../family/application/permissions_controller.dart';
import '../../family/data/models/family_permission.dart';
import '../application/learning_goals_controller.dart';
import '../data/models/learning_goal.dart';
import 'goal_widgets.dart';
import 'learning_goal_detail_screen.dart';
import 'learning_goal_form_screen.dart';

/// Learning goals for the selected child. Reached from the child details screen.
class LearningGoalsScreen extends ConsumerWidget {
  const LearningGoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final state = ref.watch(learningGoalsControllerProvider);
    final controller = ref.read(learningGoalsControllerProvider.notifier);
    final childName = ref.watch(selectedChildProvider)?.name;
    final permissions = ref.watch(permissionsProvider);
    final canManage = permissions.hasPermission(
      FamilyPermission.manageLearningGoals,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.lgTitle)),
      floatingActionButton: canManage && (state.valueOrNull?.isEmpty == false)
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(context),
              icon: const Icon(Icons.add_rounded),
              label: Text(l.lgAddGoal),
            )
          : null,
      body: AppContentFrame(
        child: Column(
          children: [
            if (permissions.shouldSurfacePermissionError)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  0,
                ),
                child: NoticeBanner(
                  tone: AppTone.warning,
                  message: l.permLoadFailed,
                  actionLabel: l.commonRetry,
                  onAction: () => refreshPermissions(ref),
                ),
              ),
            Expanded(
              child: state.when(
                skipLoadingOnReload: true,
                loading: () => const LoadingView(),
                error: (e, _) =>
                    ErrorRetryView(error: e, onRetry: controller.refresh),
                data: (list) => list.isEmpty
                    ? _Empty(
                        canManage: canManage,
                        onAdd: () => _openForm(context),
                        onRefresh: controller.refresh,
                      )
                    : _List(
                        list: list,
                        childName: childName,
                        onRefresh: controller.refresh,
                        onLoadMore: () => _loadMore(context, ref),
                        onTap: (g) => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                LearningGoalDetailScreen(goalId: g.id),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const LearningGoalFormScreen()));

  Future<void> _loadMore(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(learningGoalsControllerProvider.notifier).loadMore();
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.localizedMessage(context.l10n))));
    }
  }
}

class _List extends StatelessWidget {
  const _List({
    required this.list,
    required this.childName,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onTap,
  });

  final LearningGoalsListState list;
  final String? childName;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;
  final void Function(LearningGoal) onTap;

  static const _filters = ['active', 'paused', 'achieved', 'archived', 'all'];

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          96,
        ),
        children: [
          if ((childName ?? '').isNotEmpty)
            Text(
              l.lgSubtitle(childName!),
              style: context.type.bodyLarge?.copyWith(
                color: context.mamily.ink2,
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final f in _filters)
                _FilterChip(value: f, current: list.statusFilter),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final goal in list.goals)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _GoalCard(goal: goal, onTap: () => onTap(goal)),
            ),
          if (list.hasMore)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: list.loadingMore
                  ? const Center(child: CircularProgressIndicator())
                  : OutlinedButton(
                      onPressed: onLoadMore,
                      child: Text(l.lgLoadMore),
                    ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends ConsumerWidget {
  const _FilterChip({required this.value, required this.current});
  final String value;
  final String current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final label = switch (value) {
      'active' => l.lgStatusActive,
      'paused' => l.lgStatusPaused,
      'achieved' => l.lgStatusAchieved,
      'archived' => l.lgStatusArchived,
      _ => l.lgFilterAll,
    };
    return ChoiceChip(
      label: Text(label),
      selected: current == value,
      onSelected: (_) => ref
          .read(learningGoalsControllerProvider.notifier)
          .setStatusFilter(value),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.onTap});
  final LearningGoal goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  goal.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.titleSmall,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              GoalStatusChip(status: goal.status),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${goalMetricLabel(l, goal.metric)} · ${goalStandingText(l, goal)}',
            style: context.type.bodySmall?.copyWith(color: context.mamily.ink2),
          ),
          const SizedBox(height: AppSpacing.md),
          GoalProgressBar(goal: goal),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.canManage,
    required this.onAdd,
    required this.onRefresh,
  });
  final bool canManage;
  final VoidCallback onAdd;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return EmptyView(
      emoji: '🎯',
      message: l.lgEmpty,
      onRefresh: onRefresh,
      action: canManage
          ? FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: Text(l.lgAddGoal),
            )
          : null,
    );
  }
}
