import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system.dart';
import '../../../core/localization/l10n.dart';
import '../../children/application/children_controller.dart';
import '../../children/data/models/child.dart';

/// Children of the active family keyed by id (for avatars and names).
final childLookupProvider = Provider<Map<String, Child>>((ref) {
  final list =
      ref.watch(childrenControllerProvider).valueOrNull?.children ??
      const <Child>[];
  return {for (final c in list) c.id: c};
});

/// Avatar for a child id, falling back to a neutral initial.
class ChildAvatarById extends ConsumerWidget {
  const ChildAvatarById({
    super.key,
    required this.childId,
    this.name,
    this.size = 40,
  });

  final String childId;
  final String? name;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(childLookupProvider)[childId];
    return ChildAvatar(
      name: child?.name ?? name ?? '?',
      avatarKey: child?.avatarKey,
      colorHex: child?.avatarColor,
      seed: childId,
      size: size,
    );
  }
}

/// Large page title used at the top of parent tabs.
class PageTitle extends StatelessWidget {
  const PageTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: context.type.headlineMedium),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle!,
                    style: context.type.bodyLarge?.copyWith(
                      color: context.mamily.ink2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A tappable navigation tile: icon disc, title, subtitle, chevron.
class NavTile extends StatelessWidget {
  const NavTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.tone = AppTone.neutral,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final AppTone tone;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.mamily;
    final t = c.tone(tone);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.background,
              borderRadius: AppRadii.mediumAll,
            ),
            child: Icon(icon, color: t.foreground),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.type.titleSmall),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: context.type.bodySmall?.copyWith(color: c.ink2),
                  ),
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (onTap != null)
            Icon(Icons.chevron_right_rounded, color: c.ink3),
        ],
      ),
    );
  }
}

/// Device freshness as icon + words (never colour alone).
class FreshnessBadge extends StatelessWidget {
  const FreshnessBadge({super.key, required this.state, this.lastContactAt});

  /// fresh | stale | offline | unknown
  final String state;
  final DateTime? lastContactAt;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final when = lastContactAt == null
        ? ''
        : relativeTime(context, lastContactAt!);
    final (label, tone, icon) = switch (state) {
      'fresh' => (
        l.pulseDeviceFresh(when),
        AppTone.success,
        Icons.wifi_rounded,
      ),
      'stale' => (
        l.pulseDeviceStale(when),
        AppTone.warning,
        Icons.schedule_rounded,
      ),
      'offline' => (
        l.pulseDeviceOffline(when),
        AppTone.neutral,
        Icons.wifi_off_rounded,
      ),
      _ => (l.pulseDeviceUnknown, AppTone.neutral, Icons.phonelink_off_rounded),
    };
    return Tooltip(
      message: l.pulseDeviceExplain,
      child: StatusPill(label: label, tone: tone, icon: icon),
    );
  }
}

String weekdayShort(AppLocalizations l, int iso) => switch (iso) {
  1 => l.weekdayShort1,
  2 => l.weekdayShort2,
  3 => l.weekdayShort3,
  4 => l.weekdayShort4,
  5 => l.weekdayShort5,
  6 => l.weekdayShort6,
  _ => l.weekdayShort7,
};
