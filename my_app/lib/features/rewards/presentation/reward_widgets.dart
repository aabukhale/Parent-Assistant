import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/l10n.dart';
import '../../../core/design_system.dart';
import '../data/models/reward.dart';
import '../data/models/reward_enums.dart';
import '../data/models/screen_time_override.dart';

String _tag(BuildContext c) => Localizations.localeOf(c).toLanguageTag();

String formatRewardDate(BuildContext context, DateTime d) =>
    DateFormat.yMMMd(_tag(context)).add_jm().format(d.toLocal());

String formatPoints(BuildContext context, int n) =>
    NumberFormat.decimalPattern(_tag(context)).format(n);

IconData rewardTypeIcon(RewardType t) => switch (t) {
  RewardType.screenTime => Icons.phone_android_rounded,
  RewardType.physical => Icons.card_giftcard_rounded,
  RewardType.familyActivity => Icons.family_restroom_rounded,
  RewardType.privilege => Icons.workspace_premium_rounded,
};

String rewardTypeLabel(AppLocalizations l, RewardType t) => switch (t) {
  RewardType.screenTime => l.rewardTypeScreenTime,
  RewardType.physical => l.rewardTypePhysical,
  RewardType.familyActivity => l.rewardTypeFamilyActivity,
  RewardType.privilege => l.rewardTypePrivilege,
};

String redemptionStatusLabel(AppLocalizations l, RedemptionStatus s) =>
    switch (s) {
      RedemptionStatus.pending => l.redemptionStatusPending,
      RedemptionStatus.approved => l.redemptionStatusApproved,
      RedemptionStatus.rejected => l.redemptionStatusRejected,
      RedemptionStatus.cancelled => l.redemptionStatusCancelled,
    };

AppTone redemptionStatusTone(RedemptionStatus s) => switch (s) {
  RedemptionStatus.pending => AppTone.warning,
  RedemptionStatus.approved => AppTone.success,
  RedemptionStatus.rejected => AppTone.danger,
  RedemptionStatus.cancelled => AppTone.neutral,
};

IconData redemptionStatusIcon(RedemptionStatus s) => switch (s) {
  RedemptionStatus.pending => Icons.hourglass_top_rounded,
  RedemptionStatus.approved => Icons.check_circle_rounded,
  RedemptionStatus.rejected => Icons.cancel_rounded,
  RedemptionStatus.cancelled => Icons.block_rounded,
};

/// Whether a reward belongs to this family or is offered by Mamily to all.
class ScopeBadge extends StatelessWidget {
  const ScopeBadge({super.key, required this.isGlobal});
  final bool isGlobal;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return StatusPill(
      label: isGlobal ? l.rewardScopeGlobal : l.rewardScopeFamily,
      tone: isGlobal ? AppTone.info : AppTone.accent,
      icon: isGlobal ? Icons.public_rounded : Icons.home_rounded,
    );
  }
}

/// Informational affordability hint from the **cached** balance — the backend
/// approval response stays authoritative (422 on insufficient points).
class AffordabilityHint extends StatelessWidget {
  const AffordabilityHint({
    super.key,
    required this.cost,
    required this.balance,
  });
  final int cost;
  final int? balance;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.mamily;
    if (balance == null) return const SizedBox.shrink();
    final canAfford = balance! >= cost;
    final tone = canAfford ? c.success : c.warning;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          canAfford ? Icons.check_circle_outline_rounded : Icons.timelapse,
          size: AppSizes.iconSm,
          color: tone.foreground,
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            canAfford ? l.rewardAffordCan : l.rewardAffordNeed(cost - balance!),
            style: context.type.bodySmall?.copyWith(color: tone.foreground),
          ),
        ),
      ],
    );
  }
}

/// Backend policy data for an approved screen-time reward — never a device
/// restriction. Rendered from the `screen_time_override` embedded in the
/// redemption response.
class ScreenTimeOverrideCard extends StatelessWidget {
  const ScreenTimeOverrideCard({super.key, required this.data});
  final ScreenTimeOverride data;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.mamily;
    final revoked = data.isRevoked;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: AppCard(
        tone: revoked ? AppTone.neutral : AppTone.info,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  revoked ? Icons.timer_off_outlined : Icons.timelapse_rounded,
                  size: AppSizes.iconSm,
                  color: revoked ? c.ink2 : c.info.foreground,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    revoked
                        ? l.screenTimeRevoked
                        : l.screenTimeGranted(data.additionalMinutes),
                    style: context.type.labelLarge,
                  ),
                ),
              ],
            ),
            if (!revoked && data.expiresAt != null)
              Text(
                l.screenTimeExpires(formatRewardDate(context, data.expiresAt!)),
                style: context.type.bodySmall?.copyWith(color: c.ink2),
              ),
            Text(
              l.screenTimePolicyNote,
              style: context.type.bodySmall?.copyWith(color: c.ink2),
            ),
          ],
        ),
      ),
    );
  }
}

extension RewardX on Reward {
  IconData get icon => rewardTypeIcon(type);
}
