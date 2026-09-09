import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../data/models/reward.dart';
import '../data/models/reward_enums.dart';
import '../data/models/reward_redemption.dart';
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

Color redemptionStatusColor(RedemptionStatus s) => switch (s) {
  RedemptionStatus.pending => AppColors.amber,
  RedemptionStatus.approved => const Color(0xFF57C77A),
  RedemptionStatus.rejected => AppColors.coral,
  RedemptionStatus.cancelled => AppColors.textMuted,
};

class ScopeBadge extends StatelessWidget {
  const ScopeBadge({super.key, required this.isGlobal});
  final bool isGlobal;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final color = isGlobal ? const Color(0xFF7C89B8) : AppColors.teal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isGlobal ? l.rewardScopeGlobal : l.rewardScopeFamily,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
    ),
  );
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
    if (balance == null) return const SizedBox.shrink();
    final canAfford = balance! >= cost;
    return Text(
      canAfford ? l.rewardAffordCan : l.rewardAffordNeed(cost - balance!),
      style: TextStyle(
        color: canAfford ? const Color(0xFF57C77A) : AppColors.coral,
        fontSize: 11,
      ),
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
    final revoked = data.isRevoked;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF1F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                revoked ? Icons.timer_off_outlined : Icons.timelapse_rounded,
                size: 16,
                color: revoked ? AppColors.textMuted : const Color(0xFF7C89B8),
              ),
              const SizedBox(width: 6),
              Text(
                revoked
                    ? l.screenTimeRevoked
                    : l.screenTimeGranted(data.additionalMinutes),
                style: TextStyle(
                  color: revoked ? AppColors.textMuted : AppColors.navy,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (!revoked && data.expiresAt != null) ...[
            const SizedBox(height: 2),
            Text(
              l.screenTimeExpires(formatRewardDate(context, data.expiresAt!)),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
          const SizedBox(height: 2),
          Text(
            l.screenTimePolicyNote,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

extension RewardX on Reward {
  IconData get icon => rewardTypeIcon(type);
}

extension RedemptionX on RewardRedemption {
  Color get statusColor => redemptionStatusColor(status);
}
