import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
import '../../family/application/permissions_controller.dart';
import '../../family/data/models/family_permission.dart';
import '../../rewards/presentation/rewards_store_screen.dart';
import '../application/points_controller.dart';
import '../application/tasks_controller.dart';
import '../data/models/child_task.dart';
import 'points_history_screen.dart';
import 'task_detail_screen.dart';
import 'task_form_screen.dart';
import 'task_widgets.dart';

/// Tasks + points for the selected child. Rebuilt from Anwar's `RewardsScreen`
/// with real data. The rewards *store* button is kept visible but not wired —
/// reward endpoints land in Phase 6B.
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          l.tasksTitle,
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: l.rewardsStorePhase6b,
            icon: const Icon(
              Icons.card_giftcard_rounded,
              color: AppColors.coral,
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RewardsStoreScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: canManage && (tasks.valueOrNull?.isEmpty == false)
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              onPressed: () => _openForm(context),
              icon: const Icon(Icons.add_rounded),
              label: Text(l.tasksAdd),
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await tasksNotifier.refresh();
            ref.invalidate(pointsBalanceProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            children: [
              if (permissions.shouldSurfacePermissionError)
                _PermissionBanner(onRetry: () => refreshPermissions(ref)),
              const _BalanceCard(),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l.tasksListTitle,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _StatusFilter(
                current: tasks.valueOrNull?.statusFilter ?? 'active',
              ),
              const SizedBox(height: 12),
              tasks.when(
                skipLoadingOnReload: true,
                loading: () => const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.coral),
                  ),
                ),
                error: (e, _) =>
                    ErrorRetryView(error: e, onRetry: tasksNotifier.refresh),
                data: (state) => state.isEmpty
                    ? _EmptyTasks(
                        canManage: canManage,
                        onAdd: () => _openForm(context),
                      )
                    : Column(
                        children: [
                          for (final task in state.tasks)
                            _TaskCard(
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
                              padding: const EdgeInsets.only(top: 4),
                              child: state.loadingMore
                                  ? const CircularProgressIndicator(
                                      color: AppColors.coral,
                                    )
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

    return GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const PointsHistoryScreen())),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.coral,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          children: [
            const Icon(Icons.stars_rounded, color: Colors.white, size: 50),
            const SizedBox(height: 8),
            Text(
              l.tasksPointsBalance,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 4),
            balance.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: CircularProgressIndicator(color: Colors.white),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  e is ApiException ? e.localizedMessage(l) : l.errorUnknown,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              data: (b) => Column(
                children: [
                  Text(
                    numberFmt.format(b.balance),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    b.balance == 0 ? l.tasksPointsEmpty : l.tasksPointsUnit,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l.tasksPointsHistory,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusFilter extends ConsumerWidget {
  const _StatusFilter({required this.current});
  final String current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final options = {
      'active': l.taskStatusActive,
      'archived': l.taskStatusArchived,
      'all': l.taskFilterAll,
    };
    return Wrap(
      spacing: 8,
      children: [
        for (final entry in options.entries)
          ChoiceChip(
            label: Text(entry.value),
            selected: current == entry.key,
            onSelected: (_) => ref
                .read(tasksControllerProvider.notifier)
                .setStatusFilter(entry.key),
            selectedColor: AppColors.navy,
            labelStyle: TextStyle(
              color: current == entry.key ? Colors.white : AppColors.navy,
              fontSize: 12,
            ),
          ),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.onTap});
  final ChildTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.task_alt_rounded, color: AppColors.amber),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.bold,
                      decoration: task.isArchived
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${task.points} ${l.tasksPointsUnit} · ${recurrenceSummary(context, task)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF9AA3B5)),
          ],
        ),
      ),
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks({required this.canManage, required this.onAdd});
  final bool canManage;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(
        children: [
          const Icon(
            Icons.checklist_rounded,
            size: 56,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            l.tasksEmpty,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 15),
          ),
          const SizedBox(height: 16),
          if (canManage)
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.navy),
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: Text(l.tasksAdd),
            ),
        ],
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
