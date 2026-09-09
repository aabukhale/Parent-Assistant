import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/application/auth_controller.dart';
import '../../children/application/selected_child_controller.dart';
import '../../children/presentation/child_details_screen.dart';
import '../application/dashboard_controllers.dart';
import '../data/models/child_summary.dart';
import 'dashboard_widgets.dart';

/// Home tab — the mother dashboard. The greeting is the real session user; every
/// statistic comes from `GET /families/{family}/dashboard` (one request returns
/// the family roll-up and a digest per active child). Nothing is fabricated
/// while loading.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final user = ref.watch(currentUserProvider);
    final membership = ref.watch(activeMembershipProvider);
    final async = ref.watch(parentDashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(parentDashboardProvider),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 8),
              Text(
                l.homeGreeting(user?.firstName ?? ''),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                membership?.family.name ?? '',
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              async.when(
                skipLoadingOnReload: true,
                loading: () => const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: LoadingView(),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: ErrorRetryView(
                    error: e,
                    onRetry: () async =>
                        ref.invalidate(parentDashboardProvider),
                  ),
                ),
                data: (dashboard) => dashboard.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: EmptyView(
                          icon: Icons.family_restroom_rounded,
                          message: l.homeNoChildren,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.homeChildrenCount(dashboard.childrenCount),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),
                          for (final child in dashboard.children)
                            _ChildDashboardCard(summary: child),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChildDashboardCard extends ConsumerWidget {
  const _ChildDashboardCard({required this.summary});

  final ChildSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;

    return GestureDetector(
      onTap: () {
        ref.read(selectedChildIdProvider.notifier).select(summary.childId);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChildDetailsScreen(childId: summary.childId),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFFFFE4DF),
                  child: Icon(
                    Icons.face_rounded,
                    color: AppColors.coral,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.name,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (summary.age != null)
                        Text(
                          l.childAgeYears(summary.age!),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF9AA3B5),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MiniStat(
                  icon: Icons.stars_rounded,
                  label: l.dashPoints,
                  value: '${summary.pointsBalance}',
                  color: AppColors.amber,
                ),
                _MiniStat(
                  icon: Icons.phone_android_rounded,
                  label: l.dashScreenTimeToday,
                  value: formatDurationMinutes(
                    context,
                    summary.screenTimeToday.usedMinutes,
                  ),
                  sub: summary.screenTimeToday.hasLimit
                      ? l.dashScreenTimeOfLimit(
                          formatDurationMinutes(
                            context,
                            summary.screenTimeToday.effectiveLimitMinutes!,
                          ),
                        )
                      : l.dashScreenTimeNoLimit,
                  color: AppColors.coral,
                ),
                _MiniStat(
                  icon: Icons.bedtime_rounded,
                  label: l.dashLastSleep,
                  value: summary.lastSleep == null
                      ? l.dashNone
                      : formatDurationMinutes(
                          context,
                          summary.lastSleep!.durationMinutes,
                        ),
                  color: const Color(0xFF9B8CC2),
                ),
                _MiniStat(
                  icon: Icons.pending_actions_rounded,
                  label: l.dashPendingApprovals,
                  value: '${summary.tasks.pendingApproval}',
                  color: AppColors.teal,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.sub,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (sub != null)
            Text(
              sub!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
            ),
        ],
      ),
    );
  }
}
