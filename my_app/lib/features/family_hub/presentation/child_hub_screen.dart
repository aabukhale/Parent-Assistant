import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../activities/presentation/child_activities_screen.dart';
import '../../children/application/child_detail_controller.dart';
import '../../children/application/children_controller.dart';
import '../../children/application/selected_child_controller.dart';
import '../../children/data/models/child.dart';
import '../../children/presentation/child_form_screen.dart';
import '../../content_control/presentation/content_control_screen.dart';
import '../../dashboard/presentation/child_summary_section.dart';
import '../../dashboard/presentation/development_report_screen.dart';
import '../../family/application/permissions_controller.dart';
import '../../learning_goals/presentation/learning_goals_screen.dart';
import '../../rewards/presentation/rewards_store_screen.dart';
import '../../screen_time/presentation/screen_time_screen.dart';
import '../../sleep/presentation/sleep_screen.dart';
import '../../tasks/presentation/tasks_screen.dart';
import '../application/hub_providers.dart';
import 'child_sections.dart';
import 'hub_widgets.dart';
import 'praise_sheet.dart';
import 'requests_inbox_screen.dart';

/// Everything about one child in one place. Opening it selects the child, so
/// every existing per-child screen (tasks, rewards, goals…) works unchanged.
class ChildHubScreen extends ConsumerStatefulWidget {
  const ChildHubScreen({super.key, required this.childId});

  final String childId;

  @override
  ConsumerState<ChildHubScreen> createState() => _ChildHubScreenState();
}

class _ChildHubScreenState extends ConsumerState<ChildHubScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(selectedChildIdProvider.notifier).select(widget.childId);
      }
    });
  }

  void _open(Widget screen) {
    ref.read(selectedChildIdProvider.notifier).select(widget.childId);
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  Future<void> _delete(Child child) async {
    final l = context.l10n;
    final ok = await confirmAction(
      context,
      title: l.childDeleteConfirmTitle,
      body: l.childDeleteConfirmBody(child.name),
      confirmLabel: l.childDeleteAction,
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(childrenControllerProvider.notifier).deleteChild(child.id);
      if (!mounted) return;
      showResultSnack(context, l.childDeleted);
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) showResultSnack(context, e.localizedMessage(l));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.mamily;
    final async = ref.watch(childDetailProvider(widget.childId));
    final perms = ref.watch(permissionsProvider);
    final pulse = ref
        .watch(pulseProvider)
        .valueOrNull
        ?.value
        .children
        .where((p) => p.childId == widget.childId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (perms.canManageChildren && async.hasValue)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') _open(ChildFormScreen(existing: async.value));
                if (v == 'delete') _delete(async.value!);
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(l.hubEditChild)),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(l.childDeleteAction),
                ),
              ],
            ),
        ],
      ),
      body: AppContentFrame(
        maxWidth: 860,
        child: async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorRetryView(
            error: e,
            onRetry: () async =>
                ref.invalidate(childDetailProvider(widget.childId)),
          ),
          data: (child) => RefreshIndicator(
            onRefresh: () async {
              ref
                ..invalidate(childDetailProvider(widget.childId))
                ..invalidate(pulseProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.xxxl,
              ),
              children: [
                Row(
                  children: [
                    ChildAvatar(
                      name: child.name,
                      avatarKey: child.avatarKey,
                      colorHex: child.avatarColor,
                      seed: child.id,
                      size: 76,
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              child.name,
                              style: context.type.headlineMedium,
                            ),
                          ),
                          Text(
                            l.childAgeYears(child.age),
                            style: context.type.bodyLarge?.copyWith(
                              color: c.ink2,
                            ),
                          ),
                          if (pulse != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            FreshnessBadge(
                              state: pulse.deviceState,
                              lastContactAt: pulse.lastContactAt,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => showPraiseSheet(
                          context,
                          childId: child.id,
                          childName: child.name,
                        ),
                        icon: const Icon(Icons.favorite_rounded),
                        label: Text(l.quickSendPraise),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _open(RequestsInboxScreen(childId: child.id)),
                        icon: Badge(
                          isLabelVisible: (pulse?.pendingApprovals ?? 0) > 0,
                          label: Text('${pulse?.pendingApprovals ?? 0}'),
                          child: const Icon(Icons.inbox_rounded),
                        ),
                        label: Text(l.todayNeedsYou),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                ChildSummarySection(childId: child.id),
                SectionHeader(
                  title: l.hubSections(child.name),
                  padding: const EdgeInsets.only(
                    top: AppSpacing.xl,
                    bottom: AppSpacing.md,
                  ),
                ),
                LayoutBuilder(
                  builder: (context, box) {
                    final columns = box.maxWidth >= 640 ? 2 : 1;
                    final w = columns == 1
                        ? box.maxWidth
                        : (box.maxWidth - AppSpacing.md) / 2;
                    final tiles = <Widget>[
                      NavTile(
                        icon: Icons.task_alt_rounded,
                        emoji: '✅',
                        tone: AppTone.success,
                        title: l.hubTasks,
                        onTap: () => _open(const TasksScreen()),
                      ),
                      NavTile(
                        icon: Icons.wb_sunny_rounded,
                        emoji: '☀️',
                        tone: AppTone.warning,
                        title: l.hubRoutines,
                        onTap: () => _open(
                          ChildRoutinesScreen(
                            childId: child.id,
                            childName: child.name,
                          ),
                        ),
                      ),
                      NavTile(
                        icon: Icons.card_giftcard_rounded,
                        emoji: '🎁',
                        tone: AppTone.brand,
                        title: l.hubRewards,
                        onTap: () => _open(const RewardsStoreScreen()),
                      ),
                      NavTile(
                        icon: Icons.flag_rounded,
                        emoji: '🎯',
                        tone: AppTone.info,
                        title: l.hubGoals,
                        onTap: () => _open(const LearningGoalsScreen()),
                      ),
                      NavTile(
                        icon: Icons.extension_rounded,
                        emoji: '🧩',
                        tone: AppTone.accent,
                        title: l.hubActivities,
                        onTap: () => _open(const ChildActivitiesScreen()),
                      ),
                      NavTile(
                        icon: Icons.favorite_rounded,
                        emoji: '💬',
                        tone: AppTone.sleep,
                        title: l.hubCheckins,
                        onTap: () => _open(
                          ChildCheckinsScreen(
                            childId: child.id,
                            childName: child.name,
                          ),
                        ),
                      ),
                      NavTile(
                        icon: Icons.bedtime_rounded,
                        emoji: '🌙',
                        tone: AppTone.sleep,
                        title: l.hubSleep,
                        onTap: () => _open(const SleepScreen()),
                      ),
                      NavTile(
                        icon: Icons.restaurant_rounded,
                        emoji: '🥣',
                        tone: AppTone.warning,
                        title: l.hubMeals,
                        onTap: () => _open(
                          ChildMealsScreen(
                            childId: child.id,
                            childName: child.name,
                          ),
                        ),
                      ),
                      NavTile(
                        icon: Icons.timer_rounded,
                        emoji: '⏱️',
                        tone: AppTone.info,
                        title: l.hubScreenTime,
                        onTap: () => _open(const ScreenTimeScreen()),
                      ),
                      NavTile(
                        icon: Icons.shield_rounded,
                        emoji: '🛡️',
                        tone: AppTone.neutral,
                        title: l.hubContent,
                        onTap: () => _open(const ContentControlScreen()),
                      ),
                      NavTile(
                        icon: Icons.devices_rounded,
                        emoji: '📱',
                        tone: AppTone.neutral,
                        title: l.hubDevices,
                        onTap: () => _open(
                          ChildDevicesScreen(
                            childId: child.id,
                            childName: child.name,
                          ),
                        ),
                      ),
                      NavTile(
                        icon: Icons.insights_rounded,
                        emoji: '📈',
                        tone: AppTone.accent,
                        title: l.hubReport,
                        onTap: () => _open(const DevelopmentReportScreen()),
                      ),
                    ];
                    return Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: [
                        for (final t in tiles) SizedBox(width: w, child: t),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
