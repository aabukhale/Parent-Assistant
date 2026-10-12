import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/design_system.dart';
import '../../children/application/selected_child_controller.dart';
import '../application/activities_controller.dart';
import '../data/models/activity.dart';
import 'activity_details_screen.dart';
import 'activity_widgets.dart';
import 'generate_activity_screen.dart';

/// The family activity catalog (Activities tab). Replaces Anwar's hardcoded
/// `activities` list. Global + AI + this family's own activities, from
/// `GET /activities?family_id=`. Tap a card → real details + "assign to the
/// selected child" flow.
class ActivitiesScreen extends ConsumerWidget {
  const ActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(activitiesCatalogControllerProvider);
    final controller = ref.read(activitiesCatalogControllerProvider.notifier);
    final selectedChild = ref.watch(selectedChildProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.activitiesTitle)),
      body: AppContentFrame(
        child: RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xxxl,
            ),
            children: [
              AppListTile(
                margin: EdgeInsets.zero,
                tone: AppTone.accent,
                leading: const IconBadge(
                  icon: Icons.auto_awesome_rounded,
                  tone: AppTone.accent,
                  size: 52,
                ),
                title: l.activityGenerateCta,
                subtitle: l.activityGenerateCtaSub,
                subtitleMaxLines: 3,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const GenerateActivityScreen(),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SectionHeader(title: l.activitiesCatalogTitle),
              async.when(
                skipLoadingOnReload: true,
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.xxl),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) =>
                    ErrorRetryView(error: e, onRetry: controller.refresh),
                data: (state) => state.isEmpty
                    ? EmptyView(emoji: '🧩', message: l.activitiesCatalogEmpty)
                    : Column(
                        children: [
                          for (final activity in state.activities)
                            _ActivityCard(
                              activity: activity,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ActivityDetailsScreen(
                                    activityId: activity.id,
                                    childId: selectedChild?.id,
                                  ),
                                ),
                              ),
                            ),
                          if (state.hasMore)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: state.loadingMore
                                  ? const CircularProgressIndicator()
                                  : OutlinedButton(
                                      onPressed: () => _loadMore(context, ref),
                                      child: Text(l.rewardsLoadMore),
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

  Future<void> _loadMore(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(activitiesCatalogControllerProvider.notifier).loadMore();
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.localizedMessage(context.l10n))));
    }
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity, required this.onTap});

  final Activity activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final age = activityAgeLabel(l, activity);
    return AppCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          IconBadge(
            icon: activitySourceIcon(activity.source),
            tone: AppTone.accent,
            size: 52,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ActivityPill(
                      text: activitySourceLabel(l, activity.source),
                      icon: activitySourceIcon(activity.source),
                    ),
                    if (activity.durationMinutes != null)
                      Text(
                        l.activityDurationMin(activity.durationMinutes!),
                        style: context.type.bodySmall?.copyWith(
                          color: context.mamily.ink2,
                        ),
                      ),
                    if (age != null)
                      Text(
                        age,
                        style: context.type.bodySmall?.copyWith(
                          color: context.mamily.ink2,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: context.mamily.ink3,
          ),
        ],
      ),
    );
  }
}
