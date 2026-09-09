import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          l.lgTitle,
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButton: canManage && (state.valueOrNull?.isEmpty == false)
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.coral,
              foregroundColor: Colors.white,
              onPressed: () => _openForm(context),
              icon: const Icon(Icons.add_rounded),
              label: Text(l.lgAddGoal),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            if (permissions.shouldSurfacePermissionError)
              _PermissionErrorBanner(onRetry: () => refreshPermissions(ref)),
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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          if ((childName ?? '').isNotEmpty)
            Text(
              l.lgSubtitle(childName!),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 15),
            ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in _filters) ...[
                  _FilterChip(value: f, current: list.statusFilter),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final goal in list.goals)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _GoalCard(goal: goal, onTap: () => onTap(goal)),
            ),
          if (list.hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: list.loadingMore
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.coral),
                    )
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
    final selected = current == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => ref
          .read(learningGoalsControllerProvider.notifier)
          .setStatusFilter(value),
      selectedColor: AppColors.navy,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.navy,
        fontSize: 12,
      ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
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
                    goal.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GoalStatusChip(status: goal.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${goalMetricLabel(l, goal.metric)} · ${goalStandingText(l, goal)}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            GoalProgressBar(goal: goal),
          ],
        ),
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
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        children: [
          const SizedBox(height: 110),
          const Icon(Icons.flag_outlined, size: 60, color: AppColors.textMuted),
          const SizedBox(height: 14),
          Text(
            l.lgEmpty,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 15),
          ),
          const SizedBox(height: 18),
          if (canManage)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: Text(l.lgAddGoal),
              ),
            ),
        ],
      ),
    );
  }
}

/// Shown when the caregiver's effective-permissions could not be loaded — the
/// management actions are hidden (denied by default) until it succeeds.
class _PermissionErrorBanner extends StatelessWidget {
  const _PermissionErrorBanner({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.amber,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l.permLoadFailed,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: Text(l.commonRetry)),
        ],
      ),
    );
  }
}
