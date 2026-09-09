import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../children/application/selected_child_controller.dart';
import '../../family/application/permissions_controller.dart';
import '../../family/data/models/family_permission.dart';
import '../../learning_goals/presentation/learning_goals_screen.dart';
import '../../sleep/presentation/sleep_screen.dart';
import '../../tasks/presentation/tasks_screen.dart';
import '../application/dashboard_controllers.dart';
import 'dashboard_widgets.dart';
import 'development_report_screen.dart';

/// The child-development digest on the child details screen — replaces the old
/// "stats pending" placeholder. Data is `GET …/children/{child}/summary`
/// (`view_reports` on the backend); a caregiver without the grant sees an honest
/// "not available to you" state rather than a blank or a fake number.
class ChildSummarySection extends ConsumerWidget {
  const ChildSummarySection({super.key, required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final permissions = ref.watch(permissionsProvider);
    final canView = permissions.hasPermission(FamilyPermission.viewReports);

    if (permissions.isReady && !canView) {
      return _card(
        context,
        Text(
          l.dashReportsRestricted,
          style: const TextStyle(color: AppColors.textMuted, height: 1.5),
        ),
      );
    }

    final async = ref.watch(childSummaryProvider(childId));

    return Column(
      children: [
        if (permissions.shouldSurfacePermissionError)
          DashboardNoticeBanner(
            message: l.permLoadFailed,
            onRetry: () => refreshPermissions(ref),
          ),
        async.when(
          skipLoadingOnReload: true,
          loading: () => _card(
            context,
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(color: AppColors.coral),
              ),
            ),
          ),
          error: (e, _) {
            final kind = e is ApiException ? e.kind : null;
            final message = kind == ApiErrorKind.forbidden
                ? l.dashReportsRestricted
                : (e is ApiException ? e.localizedMessage(l) : l.errorUnknown);
            return _card(
              context,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      height: 1.5,
                    ),
                  ),
                  if (kind != ApiErrorKind.forbidden)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: () =>
                            ref.invalidate(childSummaryProvider(childId)),
                        child: Text(l.commonRetry),
                      ),
                    ),
                ],
              ),
            );
          },
          data: (s) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  l.dashTodayTitle,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.55,
                children: [
                  DashboardStatTile(
                    label: l.dashPoints,
                    value: '${s.pointsBalance}',
                    icon: Icons.stars_rounded,
                    color: AppColors.amber,
                    onTap: () => _go(context, ref, const TasksScreen()),
                  ),
                  DashboardStatTile(
                    label: s.screenTimeToday.hasLimit
                        ? l.dashScreenTimeUsedOfLimit(
                            formatDurationMinutes(
                              context,
                              s.screenTimeToday.effectiveLimitMinutes!,
                            ),
                          )
                        : l.dashScreenTimeToday,
                    value: formatDurationMinutes(
                      context,
                      s.screenTimeToday.usedMinutes,
                    ),
                    icon: Icons.phone_android_rounded,
                    color: AppColors.coral,
                  ),
                  DashboardStatTile(
                    label: l.dashLastSleep,
                    value: s.lastSleep == null
                        ? null
                        : formatDurationMinutes(
                            context,
                            s.lastSleep!.durationMinutes,
                          ),
                    icon: Icons.bedtime_rounded,
                    color: const Color(0xFF9B8CC2),
                    onTap: () => _go(context, ref, const SleepScreen()),
                  ),
                  DashboardStatTile(
                    label: l.dashActiveTasks,
                    value: '${s.tasks.active}',
                    icon: Icons.checklist_rounded,
                    color: AppColors.teal,
                    onTap: () => _go(context, ref, const TasksScreen()),
                  ),
                  DashboardStatTile(
                    label: l.dashPendingApprovals,
                    value: '${s.tasks.pendingApproval}',
                    icon: Icons.pending_actions_rounded,
                    color: AppColors.coral,
                    onTap: () => _go(context, ref, const TasksScreen()),
                  ),
                  DashboardStatTile(
                    label: l.dashGoals,
                    value: l.dashGoalsValue(
                      s.learningGoals.active,
                      s.learningGoals.achieved,
                    ),
                    icon: Icons.flag_rounded,
                    color: const Color(0xFF57C77A),
                    onTap: () => _go(context, ref, const LearningGoalsScreen()),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  ref.read(selectedChildIdProvider.notifier).select(childId);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DevelopmentReportScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.bar_chart_rounded),
                label: Text(l.dashOpenReport),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.navy,
                  minimumSize: const Size.fromHeight(46),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _go(BuildContext context, WidgetRef ref, Widget screen) {
    ref.read(selectedChildIdProvider.notifier).select(childId);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Widget _card(BuildContext context, Widget child) => Container(
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
          context.l10n.dashTodayTitle,
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
