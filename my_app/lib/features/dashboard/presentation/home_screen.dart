import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/l10n.dart';
import '../../../core/design_system.dart';
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
      // Opened from Discover, so it needs a way back.
      appBar: AppBar(title: Text(l.discoverDashboard)),
      body: AppContentFrame(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(parentDashboardProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xxxl,
            ),
            children: [
              Text(
                l.homeGreeting(user?.firstName ?? ''),
                style: context.type.bodyLarge?.copyWith(
                  color: context.mamily.ink2,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                membership?.family.name ?? '',
                style: context.type.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xxl),
              async.when(
                skipLoadingOnReload: true,
                loading: () => const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.xxxl),
                  child: LoadingView(),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxl),
                  child: ErrorRetryView(
                    error: e,
                    onRetry: () async =>
                        ref.invalidate(parentDashboardProvider),
                  ),
                ),
                data: (dashboard) => dashboard.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxl),
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
                            style: context.type.bodyMedium?.copyWith(
                              color: context.mamily.ink2,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
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

    return AppCard(
      onTap: () {
        ref.read(selectedChildIdProvider.notifier).select(summary.childId);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChildDetailsScreen(childId: summary.childId),
          ),
        );
      },
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ChildAvatar(name: summary.name, seed: summary.childId, size: 44),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(summary.name, style: context.type.titleSmall),
                    if (summary.age != null)
                      Text(
                        l.childAgeYears(summary.age!),
                        style: context.type.bodySmall?.copyWith(
                          color: context.mamily.ink2,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: context.mamily.ink3),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _MiniStat(
                icon: Icons.stars_rounded,
                label: l.dashPoints,
                value: '${summary.pointsBalance}',
                tone: AppTone.warning,
              ),
              _MiniStat(
                icon: Icons.phone_android_rounded,
                label: l.dashScreenTimeToday,
                value: summary.screenTimeToday.measured
                    ? formatDurationMinutes(
                        context,
                        summary.screenTimeToday.usedMinutes,
                      )
                    : l.dashNotMeasured,
                sub: summary.screenTimeToday.hasLimit
                    ? l.dashScreenTimeOfLimit(
                        formatDurationMinutes(
                          context,
                          summary.screenTimeToday.effectiveLimitMinutes!,
                        ),
                      )
                    : l.dashScreenTimeNoLimit,
                tone: AppTone.brand,
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
                tone: AppTone.sleep,
              ),
              _MiniStat(
                icon: Icons.pending_actions_rounded,
                label: l.dashPendingApprovals,
                value: '${summary.tasks.pendingApproval}',
                tone: AppTone.accent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
    this.sub,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: AppCard(
        color: context.mamily.surfaceMuted,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: context.mamily.tone(tone).foreground,
                  size: AppSizes.iconSm,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.bodySmall?.copyWith(
                      color: context.mamily.ink2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(value, style: context.type.titleSmall),
            if (sub != null)
              Text(
                sub!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.type.bodySmall?.copyWith(
                  color: context.mamily.ink2,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
