import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
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
      appBar: AppBar(title: Text(l.rewardsStoreTitle)),
      floatingActionButton: _tab == 0 && canManage
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RewardFormScreen()),
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text(l.rewardsAdd),
            )
          : null,
      body: AppContentFrame(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(rewardsControllerProvider.notifier).refresh();
            await ref.read(redemptionsControllerProvider.notifier).refresh();
            ref.invalidate(pointsBalanceProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              96,
            ),
            children: [
              if (permissions.shouldSurfacePermissionError)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: NoticeBanner(
                    tone: AppTone.warning,
                    message: l.permLoadFailed,
                    actionLabel: l.commonRetry,
                    onAction: () => refreshPermissions(ref),
                  ),
                ),
              const _BalanceStrip(),
              const SizedBox(height: AppSpacing.lg),
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: 0, label: Text(l.rewardsTabCatalog)),
                  ButtonSegment(value: 1, label: Text(l.rewardsTabHistory)),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
              const SizedBox(height: AppSpacing.md),
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
                const SizedBox(height: AppSpacing.sm),
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
    return AppCard(
      tone: AppTone.warning,
      child: Row(
        children: [
          const IconBadge(emoji: '⭐', tone: AppTone.warning, size: 40),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(l.tasksPointsBalance, style: context.type.labelLarge),
          ),
          balance.when(
            loading: () => const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (e, _) => Flexible(
              child: Text(
                e is ApiException ? e.localizedMessage(l) : l.errorUnknown,
                style: context.type.bodySmall,
              ),
            ),
            data: (b) => Text(
              formatPoints(context, b.balance),
              style: context.type.headlineSmall,
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
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => ErrorRetryView(error: e, onRetry: notifier.refresh),
      data: (state) => state.isEmpty
          ? EmptyView(emoji: '🎁', message: l.rewardsCatalogEmpty)
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
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: state.loadingMore
                        ? const CircularProgressIndicator()
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
    final confirmed = await confirmAction(
      context,
      title: l.rewardRequestTitle,
      body: l.rewardRequestConfirm(reward.title, reward.pointsCost),
      confirmLabel: l.rewardRequest,
      extra: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AffordabilityHint(cost: reward.pointsCost, balance: balance),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l.rewardOnBehalfNote,
            style: context.type.bodySmall?.copyWith(color: context.mamily.ink2),
          ),
        ],
      ),
    );
    if (!confirmed) return;
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
    final ok = await confirmAction(
      context,
      title: l.rewardDeleteConfirmTitle,
      body: l.rewardDeleteConfirmBody(reward.title),
      confirmLabel: l.rewardDeleteAction,
      destructive: true,
    );
    if (!ok) return;
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
    final c = context.mamily;
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(
                icon: rewardTypeIcon(reward.type),
                tone: AppTone.warning,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reward.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.titleSmall?.copyWith(
                        color: reward.isActive ? null : c.ink2,
                      ),
                    ),
                    Text(
                      '${l.rewardCost(reward.pointsCost)} · ${rewardTypeLabel(l, reward.type)}',
                      style: context.type.bodySmall?.copyWith(color: c.ink2),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        ScopeBadge(isGlobal: reward.isGlobal),
                        if (!reward.isActive)
                          StatusPill(
                            label: l.rewardInactiveBadge,
                            icon: Icons.pause_circle_outline_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (canManage && !reward.isGlobal)
                PopupMenuButton<String>(
                  tooltip: l.commonEdit,
                  icon: Icon(Icons.more_vert_rounded, color: c.ink2),
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
            const SizedBox(height: AppSpacing.sm),
            Text(
              reward.description!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: context.type.bodyMedium?.copyWith(color: c.ink2),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AffordabilityHint(cost: reward.pointsCost, balance: balance),
              FilledButton(
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
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => ErrorRetryView(error: e, onRetry: notifier.refresh),
      data: (state) => state.isEmpty
          ? EmptyView(emoji: '🧾', message: l.rewardsHistoryEmpty)
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
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: state.loadingMore
                        ? const CircularProgressIndicator()
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

    final c = context.mamily;
    final meta = [
      '${l.redemptionCostLabel(r.pointsCost)} · ${rewardTypeLabel(l, r.rewardType)}',
      if (r.createdAt != null) formatRewardDate(context, r.createdAt!),
    ].join('\n');
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(
                icon: rewardTypeIcon(r.rewardType),
                tone: AppTone.warning,
                size: 40,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.rewardTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.titleSmall,
                    ),
                    Text(
                      meta,
                      style: context.type.bodySmall?.copyWith(color: c.ink2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusPill(
                label: redemptionStatusLabel(l, r.status),
                tone: redemptionStatusTone(r.status),
                icon: redemptionStatusIcon(r.status),
              ),
            ],
          ),
          if ((r.reviewNote ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              r.reviewNote!,
              style: context.type.bodyMedium?.copyWith(color: c.ink2),
            ),
          ],
          if (r.screenTimeOverride != null)
            ScreenTimeOverrideCard(data: r.screenTimeOverride!),
          if (busy)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.sm),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (showApproveReject || showCancel) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (showApproveReject)
                  FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(l.redemptionApprove),
                  ),
                if (showApproveReject)
                  OutlinedButton(
                    onPressed: onReject,
                    child: Text(l.redemptionReject),
                  ),
                if (showCancel)
                  TextButton(
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
