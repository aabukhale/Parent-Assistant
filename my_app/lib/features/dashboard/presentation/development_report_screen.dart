import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/l10n.dart';
import '../../../core/design_system.dart';
import '../../children/application/selected_child_controller.dart';
import '../../family/application/permissions_controller.dart';
import '../../family/data/models/family_permission.dart';
import '../application/dashboard_controllers.dart';
import '../data/models/development_report.dart';
import 'dashboard_widgets.dart';

/// Weekly / monthly development report for the selected child
/// (`GET …/children/{child}/reports/{period}`). Replaces Anwar's mock
/// `DevelopmentScreen` (fabricated percentages, a "+12% vs last week" score, and
/// fixed summary counts). The backend returns **period aggregates only** — no
/// per-day series and no composite score — so this screen shows section cards,
/// not trend charts (see docs/flutter-integration.md).
class DevelopmentReportScreen extends ConsumerWidget {
  const DevelopmentReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final scope = ref.watch(childScopeProvider);
    final child = ref.watch(selectedChildProvider);
    final permissions = ref.watch(permissionsProvider);
    final canView = permissions.hasPermission(FamilyPermission.viewReports);
    final period = ref.watch(reportPeriodProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.dashReportTitle)),
      body: AppContentFrame(
        child: _body(
          context,
          ref,
          scope,
          child?.name,
          permissions,
          canView,
          period,
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    ChildScope scope,
    String? childName,
    Permissions permissions,
    bool canView,
    String period,
  ) {
    final l = context.l10n;

    if (scope.familyId == null || scope.childId == null) {
      return EmptyView(
        icon: Icons.child_care_rounded,
        message: l.dashNoChildSelected,
      );
    }

    if (permissions.isReady && !canView) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            l.dashReportsRestricted,
            textAlign: TextAlign.center,
            style: context.type.bodyMedium?.copyWith(
              color: context.mamily.ink2,
            ),
          ),
        ),
      );
    }

    final async = ref.watch(developmentReportProvider(period));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(developmentReportProvider(period)),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        children: [
          if (permissions.shouldSurfacePermissionError)
            DashboardNoticeBanner(
              message: l.permLoadFailed,
              onRetry: () => refreshPermissions(ref),
            ),
          if (childName != null && childName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                l.dashReportFor(childName),
                style: context.type.bodyMedium?.copyWith(
                  color: context.mamily.ink2,
                ),
              ),
            ),
          _PeriodToggle(current: period),
          const SizedBox(height: AppSpacing.lg),
          async.when(
            skipLoadingOnReload: true,
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 50),
              child: LoadingView(),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.only(top: 40),
              child: ErrorRetryView(
                error: e,
                onRetry: () async =>
                    ref.invalidate(developmentReportProvider(period)),
              ),
            ),
            data: (report) => _ReportBody(report: report),
          ),
        ],
      ),
    );
  }
}

class _PeriodToggle extends ConsumerWidget {
  const _PeriodToggle({required this.current});
  final String current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(value: 'weekly', label: Text(l.dashPeriodWeekly)),
        ButtonSegment(value: 'monthly', label: Text(l.dashPeriodMonthly)),
      ],
      selected: {current},
      onSelectionChanged: (s) =>
          ref.read(reportPeriodProvider.notifier).state = s.first,
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report});
  final DevelopmentReport report;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final range = formatDateRange(
      context,
      report.periodStart,
      report.periodEnd,
    );
    final st = report.sections;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (range.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(range, style: context.type.titleSmall),
          ),
        Text(
          l.dashReportTimezone(report.timezone),
          style: context.type.bodySmall?.copyWith(color: context.mamily.ink2),
        ),
        const SizedBox(height: AppSpacing.md),
        if (!report.hasSufficientData)
          NoticeBanner(tone: AppTone.info, message: l.dashReportNoData),
        DashboardSectionCard(
          title: l.dashSectionScreenTime,
          icon: Icons.phone_android_rounded,
          tone: AppTone.brand,
          hasData: st.screenTime.hasData,
          child: Column(
            children: [
              DashboardMetricRow(
                label: l.dashScreenTimeTotal,
                value: formatDurationMinutes(
                  context,
                  st.screenTime.metric('total_minutes'),
                ),
              ),
              DashboardMetricRow(
                label: l.dashScreenTimeDailyAverage,
                value: formatDurationMinutes(
                  context,
                  st.screenTime.metric('daily_average_minutes'),
                ),
              ),
              DashboardMetricRow(
                label: l.dashDaysWithUsage,
                value: '${st.screenTime.metric('days_with_usage')}',
              ),
            ],
          ),
        ),
        DashboardSectionCard(
          title: l.dashSectionSleep,
          icon: Icons.bedtime_rounded,
          tone: AppTone.sleep,
          hasData: st.sleep.hasData,
          child: Column(
            children: [
              DashboardMetricRow(
                label: l.dashSleepNights,
                value: '${st.sleep.metric('nights_logged')}',
              ),
              DashboardMetricRow(
                label: l.dashSleepTotal,
                value: formatDurationMinutes(
                  context,
                  st.sleep.metric('total_minutes'),
                ),
              ),
              DashboardMetricRow(
                label: l.dashSleepAverage,
                value: formatDurationMinutes(
                  context,
                  st.sleep.metric('average_minutes'),
                ),
              ),
            ],
          ),
        ),
        DashboardSectionCard(
          title: l.dashSectionActivities,
          icon: Icons.directions_run_rounded,
          tone: AppTone.warning,
          hasData: st.activities.hasData,
          child: Column(
            children: [
              DashboardMetricRow(
                label: l.dashActivitiesCompleted,
                value: '${st.activities.metric('completed')}',
              ),
              DashboardMetricRow(
                label: l.dashActivitiesApproved,
                value: '${st.activities.metric('approved')}',
              ),
            ],
          ),
        ),
        DashboardSectionCard(
          title: l.dashSectionGames,
          icon: Icons.sports_esports_rounded,
          tone: AppTone.info,
          hasData: st.games.hasData,
          child: Column(
            children: [
              DashboardMetricRow(
                label: l.dashGamesSessions,
                value: '${st.games.metric('sessions')}',
              ),
              DashboardMetricRow(
                label: l.dashGamesDistinct,
                value: '${st.games.metric('distinct_games')}',
              ),
              DashboardMetricRow(
                label: l.dashGamesPlayTime,
                value: formatDurationMinutes(
                  context,
                  st.games.metric('total_play_minutes'),
                ),
              ),
            ],
          ),
        ),
        DashboardSectionCard(
          title: l.dashSectionTasks,
          icon: Icons.checklist_rounded,
          tone: AppTone.accent,
          hasData: st.tasks.hasData,
          child: Column(
            children: [
              DashboardMetricRow(
                label: l.dashTasksApproved,
                value: '${st.tasks.metric('approved_completions')}',
              ),
              DashboardMetricRow(
                label: l.dashTasksPoints,
                value: '${st.tasks.metric('points_from_tasks')}',
              ),
            ],
          ),
        ),
        DashboardSectionCard(
          title: l.dashSectionPoints,
          icon: Icons.stars_rounded,
          tone: AppTone.warning,
          hasData: st.points.hasData,
          child: Column(
            children: [
              DashboardMetricRow(
                label: l.dashPointsNet,
                value: _signed(st.points.metric('net_change')),
              ),
              DashboardMetricRow(
                label: l.dashPointsTransactions,
                value: '${st.points.metric('transaction_count')}',
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _signed(int v) => v > 0 ? '+$v' : '$v';
}
