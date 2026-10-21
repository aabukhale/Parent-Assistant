import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system.dart';
import '../../../core/localization/l10n.dart';
import '../application/parent_safety_providers.dart';
import '../data/safety_models.dart';

/// Who looked at locations, changed rules, linked phones or ran help
/// sessions. No coordinates or screen content are ever stored here.
class AccessHistoryScreen extends ConsumerWidget {
  const AccessHistoryScreen({super.key, this.childId});

  final String? childId;

  static String describe(AppLocalizations l, AccessLogEntry e) {
    final who = e.actorType == 'system' ? l.accessSystem : (e.actorName ?? '—');
    final child = e.childName ?? '';
    return switch (e.action) {
      'location.viewed' => l.accessViewedLocation(who, child),
      'location.history_viewed' => l.accessViewedHistory(who, child),
      'rules.changed' => l.accessRulesChanged(who, child),
      'remote.requested' => l.accessRemoteRequested(who, child),
      'remote.started' => l.accessRemoteStarted(child),
      'remote.ended' => l.accessRemoteEnded(child),
      'location.sharing_on' => l.accessSharingOn(who, child),
      'location.sharing_off' => l.accessSharingOff(who, child),
      'caregiver.access_changed' => l.accessCaregiver(who),
      _ => l.accessOther(who, e.action),
    };
  }

  static IconData icon(String action) => switch (action.split('.').first) {
    'location' => Icons.location_on_rounded,
    'rules' => Icons.tune_rounded,
    'remote' => Icons.support_agent_rounded,
    'caregiver' => Icons.manage_accounts_rounded,
    'safe_place' => Icons.home_rounded,
    _ => Icons.history_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(accessLogProvider(childId));
    return Scaffold(
      appBar: AppBar(title: Text(l.accessHistory)),
      body: AppContentFrame(
        child: async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorRetryView(
            error: e,
            onRetry: () async => ref.invalidate(accessLogProvider(childId)),
          ),
          data: (items) => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(l.accessHistoryBody, style: context.type.bodyMedium),
              const SizedBox(height: AppSpacing.lg),
              if (items.isEmpty)
                EmptyView(icon: Icons.history_rounded, message: l.commonEmpty),
              for (final e in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppListTile(
                    leading: IconBadge(icon: icon(e.action)),
                    title: describe(l, e),
                    subtitle: e.createdAt == null
                        ? null
                        : relativeTime(context, e.createdAt!),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
