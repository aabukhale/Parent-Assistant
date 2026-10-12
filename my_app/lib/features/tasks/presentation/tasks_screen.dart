import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../family/application/permissions_controller.dart';
import '../../family/data/models/family_permission.dart';
import '../../kid/presentation/kid_widgets.dart';
import '../../rewards/presentation/rewards_store_screen.dart';
import '../application/points_controller.dart';
import '../application/tasks_controller.dart';
import '../data/models/child_task.dart';
import 'points_history_screen.dart';
import 'task_detail_screen.dart';
import 'task_form_screen.dart';
import 'task_widgets.dart';

/// Tasks + points for the selected child.
class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final tasks = ref.watch(tasksControllerProvider);
    final tasksNotifier = ref.read(tasksControllerProvider.notifier);
    final permissions = ref.watch(permissionsProvider);
    final canManage = permissions.hasPermission(FamilyPermission.manageTasks);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.tasksTitle),
        actions: [
          IconButton(
            tooltip: l.rewardsStorePhase6b,
            icon: const Icon(Icons.card_giftcard_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RewardsStoreScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: canManage && (tasks.valueOrNull?.isEmpty == false)
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(context),
              icon: const Icon(Icons.add_rounded),
              label: Text(l.tasksAdd),
            )
          : null,
      body: AppContentFrame(
        child: RefreshIndicator(
          onRefresh: () async {
            await tasksNotifier.refresh();
            ref.invalidate(pointsBalanceProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              96,
            ),
            children: [
              if (permissions.shouldSurfacePermissionError)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: NoticeBanner(
                    tone: AppTone.warning,
                    message: l.permLoadFailed,
                    actionLabel: l.commonRetry,
                    onAction: () => refreshPermissions(ref),
                  ),
                ),
              const _BalanceCard(),
              const SizedBox(height: AppSpacing.xxl),
              SectionHeader(title: l.tasksListTitle),
              ChoiceChipBar<String>(
                options: {
                  'active': l.taskStatusActive,
                  'archived': l.taskStatusArchived,
                  'all': l.taskFilterAll,
                },
                selected: tasks.valueOrNull?.statusFilter ?? 'active',
                onSelected: tasksNotifier.setStatusFilter,
              ),
              const SizedBox(height: AppSpacing.md),
              tasks.when(
                skipLoadingOnReload: true,
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.xxl),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) =>
                    ErrorRetryView(error: e, onRetry: tasksNotifier.refresh),
                data: (state) => state.isEmpty
                    ? EmptyView(
                        emoji: '📋',
                        message: l.tasksEmpty,
                        action: canManage
                            ? FilledButton.icon(
                                onPressed: () => _openForm(context),
                                icon: const Icon(Icons.add_rounded),
                                label: Text(l.tasksAdd),
                              )
                            : null,
                      )
                    : Column(
                        children: [
                          for (final task in state.tasks)
                            _TaskTile(
                              task: task,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      TaskDetailScreen(taskId: task.id),
                                ),
                              ),
                            ),
                          if (state.hasMore)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.xs,
                              ),
                              child: state.loadingMore
                                  ? const CircularProgressIndicator()
                                  : OutlinedButton(
                                      onPressed: () => _loadMore(context, ref),
                                      child: Text(l.tasksLoadMore),
                                    ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const TaskFormScreen()));

  Future<void> _loadMore(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(tasksControllerProvider.notifier).loadMore();
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.localizedMessage(context.l10n))));
    }
  }
}

class _BalanceCard extends ConsumerWidget {
  const _BalanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final balance = ref.watch(pointsBalanceProvider);
    final numberFmt = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    );

    return HeroMetricCard(
      label: l.tasksPointsBalance,
      emoji: '⭐',
      tone: AppTone.warning,
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const PointsHistoryScreen())),
      actionLabel: l.tasksPointsHistory,
      valueWidget: balance.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
        error: (e, _) => Text(
          e is ApiException ? e.localizedMessage(l) : l.errorUnknown,
          style: context.type.bodyMedium,
        ),
        data: (b) => Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: AppSpacing.sm,
          children: [
            Text(
              numberFmt.format(b.balance),
              style: context.type.headlineMedium,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                b.balance == 0 ? l.tasksPointsEmpty : l.tasksPointsUnit,
                style: context.type.bodyLarge?.copyWith(
                  color: context.mamily.ink2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.onTap});
  final ChildTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppListTile(
      // The same icon the child sees for this task.
      leading: EmojiTile(
        emoji: iconEmoji(task.iconKey ?? task.category),
        size: 44,
      ),
      title: task.title,
      titleMaxLines: 1,
      strikeTitle: task.isArchived,
      subtitle:
          '${task.points} ${l.tasksPointsUnit} · ${recurrenceSummary(context, task)}',
      subtitleMaxLines: 1,
      onTap: onTap,
    );
  }
}
