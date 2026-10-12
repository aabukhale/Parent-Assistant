import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/design_system.dart';
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
          style: context.type.bodyMedium?.copyWith(color: context.mamily.ink2),
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
                child: CircularProgressIndicator(),
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
                    style: context.type.bodyMedium?.copyWith(
                      color: context.mamily.ink2,
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
                child: Text(l.dashTodayTitle, style: context.type.titleSmall),
              ),
              const SizedBox(height: AppSpacing.md),
              // Rows sized to their content (a fixed aspect ratio overflowed
              // with longer values, Arabic text or large font sizes).
              DashboardTileGrid(
                tiles: [
                  DashboardStatTile(
                    label: l.dashPoints,
                    value: '${s.pointsBalance}',
                    icon: Icons.stars_rounded,
                    tone: AppTone.warning,
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
                    value: s.screenTimeToday.measured
                        ? formatDurationMinutes(
                            context,
                            s.screenTimeToday.usedMinutes,
                          )
                        : l.dashNotMeasured,
                    icon: Icons.phone_android_rounded,
                    tone: AppTone.brand,
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
                    tone: AppTone.sleep,
                    onTap: () => _go(context, ref, const SleepScreen()),
                  ),
                  DashboardStatTile(
                    label: l.dashActiveTasks,
                    value: '${s.tasks.active}',
                    icon: Icons.checklist_rounded,
                    tone: AppTone.accent,
                    onTap: () => _go(context, ref, const TasksScreen()),
                  ),
                  DashboardStatTile(
                    label: l.dashPendingApprovals,
                    value: '${s.tasks.pendingApproval}',
                    icon: Icons.pending_actions_rounded,
                    tone: AppTone.brand,
                    onTap: () => _go(context, ref, const TasksScreen()),
                  ),
                  DashboardStatTile(
                    label: l.dashGoals,
                    value: l.dashGoalsValue(
                      s.learningGoals.active,
                      s.learningGoals.achieved,
                    ),
                    icon: Icons.flag_rounded,
                    tone: AppTone.success,
                    onTap: () => _go(context, ref, const LearningGoalsScreen()),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
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

  Widget _card(BuildContext context, Widget child) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.dashTodayTitle, style: context.type.titleSmall),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    ),
  );
}
