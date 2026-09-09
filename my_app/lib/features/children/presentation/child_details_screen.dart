import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          async.valueOrNull?.name ?? '',
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (canManage && async.hasValue) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.navy),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChildFormScreen(existing: async.requireValue),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.coral,
              ),
              onPressed: () => _confirmDelete(context, ref, async.requireValue),
            ),
          ],
        ],
      ),
      body: SafeArea(
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.childDeleteConfirmTitle),
        content: Text(l.childDeleteConfirmBody(child.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              l.childDeleteAction,
              style: const TextStyle(color: AppColors.coral),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
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
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: _avatarColor(child.avatarColor),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.face_rounded,
                    size: 50,
                    color: AppColors.coral,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  child.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.childAgeYears(child.age),
                  style: const TextStyle(
                    color: Color(0xFFD8DDEC),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _Section(
            title: l.childFieldInterests,
            child: child.interests.isEmpty
                ? Text(
                    l.childDetailsInterestsEmpty,
                    style: const TextStyle(color: AppColors.textMuted),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final i in child.interests)
                        Chip(
                          label: Text(i.name),
                          backgroundColor: const Color(0xFFE4F4F3),
                          side: BorderSide.none,
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          ChildSummarySection(childId: child.id),
          const SizedBox(height: 20),
          // Learning goals — connected (Phase 4). Selecting the child first
          // keeps the goal providers scoped to this child.
          _FeatureTile(
            icon: Icons.flag_rounded,
            title: l.lgTitle,
            color: const Color(0xFF57C77A),
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
            color: const Color(0xFF9B8CC2),
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
            color: AppColors.coral,
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
            color: AppColors.teal,
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
            color: const Color(0xFF7C89B8),
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
            color: AppColors.teal,
            builder: () => const NutritionScreen(),
          ),
          // Tasks & points — connected (Phase 6A); the rewards store (Phase 6B)
          // is reached from the tasks screen's app-bar icon. Select the child
          // first so the task / points providers stay scoped to this child.
          _FeatureTile(
            icon: Icons.stars_rounded,
            title: l.tasksTitle,
            color: AppColors.amber,
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
            color: const Color(0xFF57C77A),
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
            color: const Color(0xFF7C89B8),
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
            color: AppColors.coral,
            builder: () => const AiParentingScreen(),
          ),
          _FeatureTile(
            icon: Icons.menu_book_rounded,
            title: l.libraryTitle,
            color: AppColors.teal,
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
    required this.color,
    this.builder,
    this.onTap,
  }) : assert(builder != null || onTap != null);

  final IconData icon;
  final String title;
  final Color color;
  final Widget Function()? builder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:
          onTap ??
          () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => builder!())),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 15,
              color: Color(0xFF9AA3B5),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
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
          Text(
            title,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

Color _avatarColor(String? hex) {
  if (hex == null || hex.isEmpty) return const Color(0xFFFFE4DF);
  final cleaned = hex.replaceAll('#', '');
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return const Color(0xFFFFE4DF);
  return Color(cleaned.length <= 6 ? 0xFF000000 | value : value);
}
