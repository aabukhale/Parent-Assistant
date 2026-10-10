import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/deep_links.dart';
import '../../../core/design_system.dart';
import '../../../core/localization/l10n.dart';
import '../application/notifications_controller.dart';
import '../data/notification_models.dart';

/// The durable notification inbox (read/unread), for parents and children.
class NotificationInboxScreen extends ConsumerWidget {
  const NotificationInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(inboxControllerProvider);
    final ctrl = ref.read(inboxControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.notifInboxTitle),
        actions: [
          if ((async.valueOrNull?.unread ?? 0) > 0)
            TextButton(
              onPressed: ctrl.markAllRead,
              child: Text(l.notifMarkAllRead),
            ),
        ],
      ),
      body: AppContentFrame(
        child: async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorRetryView(error: e, onRetry: ctrl.refresh),
          data: (state) => state.items.isEmpty
              ? EmptyView(
                  icon: Icons.notifications_none_rounded,
                  title: l.notifEmptyTitle,
                  message: l.notifEmptyBody,
                  onRefresh: ctrl.refresh,
                )
              : RefreshIndicator(
                  onRefresh: ctrl.refresh,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n.metrics.extentAfter < 300) ctrl.loadMore();
                      return false;
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: state.items.length + (state.hasMore ? 1 : 0),
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, i) {
                        if (i >= state.items.length) {
                          return const Padding(
                            padding: EdgeInsets.all(AppSpacing.lg),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return _NotificationTile(n: state.items[i]);
                      },
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.n});

  final AppNotification n;

  IconData get _icon => switch (n.category) {
    'tasks' => Icons.checklist_rounded,
    'approvals' => Icons.how_to_reg_rounded,
    'rewards' => Icons.card_giftcard_rounded,
    'routines' => Icons.wb_sunny_rounded,
    'challenges' => Icons.groups_rounded,
    'encouragement' => Icons.favorite_rounded,
    'checkins' => Icons.chat_bubble_rounded,
    'screen_time' => Icons.timer_rounded,
    'planner' => Icons.event_rounded,
    'devices' => Icons.devices_rounded,
    _ => Icons.notifications_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mamily;
    return AppCard(
      color: n.isRead ? null : c.info.background,
      onTap: () async {
        if (!n.isRead) {
          await ref.read(inboxControllerProvider.notifier).markRead(n.id);
        }
        final route = n.route;
        if (route != null && context.mounted) await DeepLinks.open(ref, route);
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.surface,
              shape: BoxShape.circle,
              border: Border.all(color: c.border),
            ),
            child: Icon(_icon, color: c.accent.foreground, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.title,
                  style: context.type.titleSmall?.copyWith(
                    fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  n.body,
                  style: context.type.bodyMedium?.copyWith(color: c.ink2),
                ),
                if (n.createdAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      relativeTime(context, n.createdAt!),
                      style: context.type.bodySmall?.copyWith(color: c.ink3),
                    ),
                  ),
              ],
            ),
          ),
          if (!n.isRead)
            Semantics(
              label: context.l10n.notifUnread,
              child: Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: c.action,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
