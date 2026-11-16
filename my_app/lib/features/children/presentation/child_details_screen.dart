import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/design_system.dart';
import '../../activities/presentation/child_activities_screen.dart';
import '../../ai_parenting/ai_parenting_screen.dart';
import '../../games/presentation/games_screen.dart';
import '../../content_control/presentation/content_control_screen.dart';
import '../../dashboard/presentation/child_summary_section.dart';
import '../../dashboard/presentation/development_report_screen.dart';
import '../../family/application/permissions_controller.dart';
import '../../learning_goals/presentation/learning_goals_screen.dart';
import '../../library/presentation/library_screen.dart';
import '../../nutrition/nutrition_screen.dart';
import '../../screen_time/presentation/screen_time_screen.dart';
import '../../sleep/presentation/sleep_screen.dart';
import '../../tasks/presentation/tasks_screen.dart';
import '../application/child_detail_controller.dart';
import '../application/children_controller.dart';
import '../application/selected_child_controller.dart';
import '../data/models/child.dart';
import 'child_form_screen.dart';

/// One child's profile, from `GET /families/{family}/children/{child}`.
/// Edit / delete are shown only to owner/parent (backend also enforces 403).
class ChildDetailsScreen extends ConsumerWidget {
  const ChildDetailsScreen({super.key, required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(childDetailProvider(childId));
    final canManage = ref.watch(permissionsProvider).canManageChildren;

    return Scaffold(
      appBar: AppBar(
        title: Text(async.valueOrNull?.name ?? ''),
        actions: [
          if (canManage && async.hasValue) ...[
            IconButton(
              icon: Icon(Icons.edit_outlined, color: context.mamily.ink),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChildFormScreen(existing: async.requireValue),
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                color: context.mamily.actionText,
              ),
              onPressed: () => _confirmDelete(context, ref, async.requireValue),
            ),
          ],
        ],
      ),
      body: AppContentFrame(
        child: async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorRetryView(
            error: e,
            onRetry: () async => ref.invalidate(childDetailProvider(childId)),
          ),
          data: (child) => _Body(child: child),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Child child,
  ) async {
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
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.childDeleted)));
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
  const _Body({required this.child});
  final Child child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxxl,
      ),
      child: Column(
        children: [
          AppCard(
            tone: AppTone.brand,
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Row(
              children: [
                ChildAvatar(
                  name: child.name,
                  avatarKey: child.avatarKey,
                  colorHex: child.avatarColor,
                  seed: child.id,
                  size: 72,
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(child.name, style: context.type.headlineMedium),
                      Text(
                        l.childAgeYears(child.age),
                        style: context.type.bodyLarge?.copyWith(
                          color: context.mamily.ink2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _Section(
            title: l.childFieldInterests,
            child: child.interests.isEmpty
                ? Text(
                    l.childDetailsInterestsEmpty,
                    style: context.type.bodyMedium?.copyWith(
                      color: context.mamily.ink2,
                    ),
                  )
                : Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final i in child.interests)
                        StatusPill(label: i.name, tone: AppTone.accent),
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ChildSummarySection(childId: child.id),
          const SizedBox(height: AppSpacing.xl),
          // Learning goals — connected (Phase 4). Selecting the child first
          // keeps the goal providers scoped to this child.
          _FeatureTile(
            icon: Icons.flag_rounded,
            title: l.lgTitle,
            tone: AppTone.success,
            onTap: () {
              ref.read(selectedChildIdProvider.notifier).select(child.id);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LearningGoalsScreen()),
              );
            },
          ),
          // Sleep — connected (Phase 5). Select the child first so the sleep
          // providers stay scoped to this child.
          _FeatureTile(
            icon: Icons.bedtime_rounded,
            title: l.sleepTitle,
            tone: AppTone.sleep,
            onTap: () {
              ref.read(selectedChildIdProvider.notifier).select(child.id);
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SleepScreen()));
            },
          ),
          // Screen time — connected (Phase 11). Child-scoped, so select first.
          _FeatureTile(
            icon: Icons.smartphone_rounded,
            title: l.stTitle,
            tone: AppTone.brand,
            onTap: () {
              ref.read(selectedChildIdProvider.notifier).select(child.id);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ScreenTimeScreen()),
              );
            },
          ),
          // Content controls — connected (Phase 10). Child-scoped.
          _FeatureTile(
            icon: Icons.lock_outline_rounded,
            title: l.contentTitle,
            tone: AppTone.accent,
            onTap: () {
              ref.read(selectedChildIdProvider.notifier).select(child.id);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ContentControlScreen()),
              );
            },
          ),
          // Development report — connected (Phase 7). Select the child first so
          // the report provider stays scoped to this child.
          _FeatureTile(
            icon: Icons.bar_chart_rounded,
            title: l.dashReportTitle,
            tone: AppTone.info,
            onTap: () {
              ref.read(selectedChildIdProvider.notifier).select(child.id);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DevelopmentReportScreen(),
                ),
              );
            },
          ),
          _FeatureTile(
            icon: Icons.restaurant_rounded,
            title: l.nutritionTitle,
            tone: AppTone.accent,
            builder: () => const NutritionScreen(),
          ),
          // Tasks & points — connected (Phase 6A); the rewards store (Phase 6B)
          // is reached from the tasks screen's app-bar icon. Select the child
          // first so the task / points providers stay scoped to this child.
          _FeatureTile(
            icon: Icons.stars_rounded,
            title: l.tasksTitle,
            tone: AppTone.warning,
            onTap: () {
              ref.read(selectedChildIdProvider.notifier).select(child.id);
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const TasksScreen()));
            },
          ),
          // Assigned activities + completion workflow — connected (Phase 8).
          _FeatureTile(
            icon: Icons.directions_run_rounded,
            title: l.activitiesAssignedTitle,
            tone: AppTone.success,
            onTap: () {
              ref.read(selectedChildIdProvider.notifier).select(child.id);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ChildActivitiesScreen(),
                ),
              );
            },
          ),
          // Games — parent preview + progress (Phase 12). Child-scoped progress.
          _FeatureTile(
            icon: Icons.sports_esports_rounded,
            title: l.gamesTitle,
            tone: AppTone.info,
            onTap: () {
              ref.read(selectedChildIdProvider.notifier).select(child.id);
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const GamesScreen()));
            },
          ),
          _FeatureTile(
            icon: Icons.auto_awesome_rounded,
            title: l.aiCoachTitle,
            tone: AppTone.brand,
            builder: () => const AiParentingScreen(),
          ),
          _FeatureTile(
            icon: Icons.menu_book_rounded,
            title: l.libraryTitle,
            tone: AppTone.accent,
            onTap: () {
              ref.read(selectedChildIdProvider.notifier).select(child.id);
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const LibraryScreen()));
            },
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.tone,
    this.builder,
    this.onTap,
  }) : assert(builder != null || onTap != null);

  final IconData icon;
  final String title;
  final AppTone tone;
  final Widget Function()? builder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppListTile(
      leading: IconBadge(icon: icon, tone: tone),
      title: title,
      onTap:
          onTap ??
          () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => builder!())),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.type.titleSmall),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}
