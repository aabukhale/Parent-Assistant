import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
import '../../family/application/permissions_controller.dart';
import '../../family/data/models/family_permission.dart';
import '../../tasks/application/points_controller.dart';
import '../../tasks/data/task_requests.dart';
import '../application/redemptions_controller.dart';
import '../application/rewards_controller.dart';
import '../data/models/reward.dart';
import '../data/models/reward_redemption.dart';
import 'reward_form_screen.dart';
import 'reward_widgets.dart';

/// The reward catalog + redemption history for the selected child. Replaces
/// Anwar's hardcoded `RewardsStoreScreen`. Reached from the rewards-store icon
/// on `TasksScreen`.
class RewardsStoreScreen extends ConsumerStatefulWidget {
  const RewardsStoreScreen({super.key});

  @override
  ConsumerState<RewardsStoreScreen> createState() => _RewardsStoreScreenState();
}

class _RewardsStoreScreenState extends ConsumerState<RewardsStoreScreen> {
  int _tab = 0; // 0 = catalog, 1 = redemptions
  final Set<String> _busy = {};

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final permissions = ref.watch(permissionsProvider);
    final canManage = permissions.hasPermission(FamilyPermission.manageRewards);
    final canReview = permissions.hasPermission(
      FamilyPermission.approveRedemptions,
    );
    final rewards = ref.watch(rewardsControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          l.rewardsStoreTitle,
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButton: _tab == 0 && canManage
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.coral,
              foregroundColor: Colors.white,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RewardFormScreen()),
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text(l.rewardsAdd),
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(rewardsControllerProvider.notifier).refresh();
            await ref.read(redemptionsControllerProvider.notifier).refresh();
            ref.invalidate(pointsBalanceProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            children: [
              if (permissions.shouldSurfacePermissionError)
                _PermissionBanner(onRetry: () => refreshPermissions(ref)),
              const _BalanceStrip(),
              const SizedBox(height: 16),
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: 0, label: Text(l.rewardsTabCatalog)),
                  ButtonSegment(value: 1, label: Text(l.rewardsTabHistory)),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
              const SizedBox(height: 14),
              if (_tab == 0 && canManage && rewards.hasValue)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilterChip(
                    label: Text(l.rewardsShowInactive),
                    selected: rewards.requireValue.includeInactive,
                    showCheckmark: true,
                    onSelected: (v) => ref
                        .read(rewardsControllerProvider.notifier)
                        .setIncludeInactive(v),
                  ),
                ),
              if (_tab == 0 && canManage && rewards.hasValue)
                const SizedBox(height: 10),
              if (_tab == 0)
                _CatalogSection(canManage: canManage)
              else
                _RedemptionsSection(
                  canReview: canReview,
                  busy: _busy,
                  run: _run,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _run(String id, Future<String?> Function() action) async {
    if (_busy.contains(id)) return;
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    setState(() => _busy.add(id));
    try {
      final ok = await action();
      if (ok != null) messenger.showSnackBar(SnackBar(content: Text(ok)));
    } on ApiException catch (e) {
      final msg = switch (e.kind) {
        ApiErrorKind.conflict => l.redemptionConflict,
        ApiErrorKind.validation => l.redemptionInsufficient,
        _ => e.localizedMessage(l),
      };
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }
}

class _BalanceStrip extends ConsumerWidget {
  const _BalanceStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final balance = ref.watch(pointsBalanceProvider);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.coral,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.stars_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Text(
            l.tasksPointsBalance,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          const Spacer(),
          balance.when(
            loading: () => const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
            error: (e, _) => Text(
              e is ApiException ? e.localizedMessage(l) : l.errorUnknown,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
            data: (b) => Text(
              formatPoints(context, b.balance),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogSection extends ConsumerWidget {
  const _CatalogSection({required this.canManage});
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(rewardsControllerProvider);
    final notifier = ref.read(rewardsControllerProvider.notifier);
    final balance = ref.watch(pointsBalanceProvider).valueOrNull?.balance;

    return async.when(
      skipLoadingOnReload: true,
      loading: () => const Padding(
        padding: EdgeInsets.all(28),
        child: Center(child: CircularProgressIndicator(color: AppColors.coral)),
      ),
      error: (e, _) => ErrorRetryView(error: e, onRetry: notifier.refresh),
      data: (state) => state.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text(
                  l.rewardsCatalogEmpty,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ),
            )
          : Column(
              children: [
                for (final reward in state.rewards)
                  _RewardCard(
                    reward: reward,
                    balance: balance,
                    canManage: canManage,
                    onRequest: () => _request(context, ref, reward),
                    onEdit: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RewardFormScreen(existing: reward),
                      ),
                    ),
                    onDelete: () => _confirmDelete(context, ref, reward),
                  ),
                if (state.hasMore)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: state.loadingMore
                        ? const CircularProgressIndicator(
                            color: AppColors.coral,
                          )
                        : OutlinedButton(
                            onPressed: () => _loadMore(context, ref),
                            child: Text(l.rewardsLoadMore),
                          ),
                  ),
              ],
            ),
    );
  }

  Future<void> _loadMore(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(rewardsControllerProvider.notifier).loadMore();
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.localizedMessage(context.l10n))));
    }
  }

  Future<void> _request(
    BuildContext context,
    WidgetRef ref,
    Reward reward,
  ) async {
    final l = context.l10n;
    final balance = ref.read(pointsBalanceProvider).valueOrNull?.balance;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.rewardRequestTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.rewardRequestConfirm(reward.title, reward.pointsCost)),
            const SizedBox(height: 8),
            AffordabilityHint(cost: reward.pointsCost, balance: balance),
            const SizedBox(height: 8),
            Text(
              l.rewardOnBehalfNote,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.rewardRequest),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(redemptionsControllerProvider.notifier)
          .requestRedemption(reward.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.rewardRequested)));
    } on ApiException catch (e) {
      if (!context.mounted) return;
      final msg = switch (e.kind) {
        ApiErrorKind.conflict => l.redemptionConflict,
        ApiErrorKind.validation => l.redemptionRewardUnavailable,
        _ => e.localizedMessage(l),
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Reward reward,
  ) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.rewardDeleteConfirmTitle),
        content: Text(l.rewardDeleteConfirmBody(reward.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              l.rewardDeleteAction,
              style: const TextStyle(color: AppColors.coral),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(rewardsControllerProvider.notifier)
          .deleteReward(reward.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.rewardDeleted)));
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.localizedMessage(l))));
    }
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.reward,
    required this.balance,
    required this.canManage,
    required this.onRequest,
    required this.onEdit,
    required this.onDelete,
  });

  final Reward reward;
  final int? balance;
  final bool canManage;
  final VoidCallback onRequest;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  rewardTypeIcon(reward.type),
                  color: AppColors.amber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reward.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          l.rewardCost(reward.pointsCost),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        Text('·', style: TextStyle(color: AppColors.textMuted)),
                        Text(
                          rewardTypeLabel(l, reward.type),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        ScopeBadge(isGlobal: reward.isGlobal),
                        if (!reward.isActive)
                          StatusPill(
                            text: l.rewardInactiveBadge,
                            color: AppColors.textMuted,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (canManage && !reward.isGlobal)
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.textMuted,
                  ),
                  onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(l.rewardsEditTitle),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(l.rewardDeleteAction),
                    ),
                  ],
                ),
            ],
          ),
          if ((reward.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              reward.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AffordabilityHint(
                  cost: reward.pointsCost,
                  balance: balance,
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.coral,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: reward.isActive ? onRequest : null,
                child: Text(l.rewardRequest),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RedemptionsSection extends ConsumerWidget {
  const _RedemptionsSection({
    required this.canReview,
    required this.busy,
    required this.run,
  });

  final bool canReview;
  final Set<String> busy;
  final Future<void> Function(String id, Future<String?> Function()) run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(redemptionsControllerProvider);
    final notifier = ref.read(redemptionsControllerProvider.notifier);

    return async.when(
      skipLoadingOnReload: true,
      loading: () => const Padding(
        padding: EdgeInsets.all(28),
        child: Center(child: CircularProgressIndicator(color: AppColors.coral)),
      ),
      error: (e, _) => ErrorRetryView(error: e, onRetry: notifier.refresh),
      data: (state) => state.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text(
                  l.rewardsHistoryEmpty,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ),
            )
          : Column(
              children: [
                for (final r in state.redemptions)
                  _RedemptionCard(
                    redemption: r,
                    canReview: canReview,
                    busy: busy.contains(r.id),
                    onApprove: () => run(r.id, () async {
                      final note = await _note(context, l.redemptionApprove);
                      if (note == null) return null;
                      await notifier.approve(r.id, ReviewInput(note: note));
                      return l.redemptionApproved;
                    }),
                    onReject: () => run(r.id, () async {
                      final note = await _note(context, l.redemptionReject);
                      if (note == null) return null;
                      await notifier.reject(r.id, ReviewInput(note: note));
                      return l.redemptionRejected;
                    }),
                    onCancel: () => run(r.id, () async {
                      final note = await _note(context, l.redemptionCancel);
                      if (note == null) return null;
                      await notifier.cancel(r.id, ReviewInput(note: note));
                      return l.redemptionCancelled;
                    }),
                  ),
                if (state.hasMore)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: state.loadingMore
                        ? const CircularProgressIndicator(
                            color: AppColors.coral,
                          )
                        : OutlinedButton(
                            onPressed: notifier.loadMore,
                            child: Text(l.rewardsLoadMore),
                          ),
                  ),
              ],
            ),
    );
  }

  Future<String?> _note(BuildContext context, String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: context.l10n.redemptionReviewNote,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(context.l10n.commonSave),
          ),
        ],
      ),
    );
  }
}

class _RedemptionCard extends StatelessWidget {
  const _RedemptionCard({
    required this.redemption,
    required this.canReview,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    required this.onCancel,
  });

  final RewardRedemption redemption;
  final bool canReview;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final r = redemption;
    final showApproveReject = canReview && r.canApproveOrReject;
    final showCancel = canReview && r.canCancel;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                rewardTypeIcon(r.rewardType),
                size: 18,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  r.rewardTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              StatusPill(
                text: redemptionStatusLabel(l, r.status),
                color: redemptionStatusColor(r.status),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${l.redemptionCostLabel(r.pointsCost)} · ${rewardTypeLabel(l, r.rewardType)}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          if ((r.reviewNote ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              r.reviewNote!,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
          if (r.createdAt != null) ...[
            const SizedBox(height: 2),
            Text(
              formatRewardDate(context, r.createdAt!),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
          if (r.screenTimeOverride != null)
            ScreenTimeOverrideCard(data: r.screenTimeOverride!),
          if (busy)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.coral,
                ),
              ),
            )
          else if (showApproveReject || showCancel) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (showApproveReject)
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF57C77A),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: onApprove,
                    child: Text(l.redemptionApprove),
                  ),
                if (showApproveReject)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.coral,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: onReject,
                    child: Text(l.redemptionReject),
                  ),
                if (showCancel)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: onCancel,
                    child: Text(l.redemptionCancel),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.amber,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l.permLoadFailed,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: Text(l.commonRetry)),
        ],
      ),
    );
  }
}
