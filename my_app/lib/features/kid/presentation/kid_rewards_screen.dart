import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system.dart';
import '../../../core/localization/l10n.dart';
import '../application/kid_providers.dart';
import '../data/kid_models.dart';
import 'kid_feedback.dart';
import 'kid_widgets.dart';

/// Rewards: my points, what I'm saving for, what I can ask for, my ideas.
class KidRewardsScreen extends ConsumerWidget {
  const KidRewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final rewards = ref.watch(kidRewardsProvider);
    final wishes = ref.watch(kidWishesProvider);
    Future<void> refresh() async {
      ref
        ..invalidate(kidRewardsProvider)
        ..invalidate(kidWishesProvider);
    }

    return SafeArea(
      bottom: false,
      child: AppContentFrame(
        maxWidth: 720,
        child: rewards.when(
          skipLoadingOnRefresh: true,
          loading: () => const LoadingView(),
          error: (e, _) => ErrorRetryView(error: e, onRetry: refresh),
          data: (fresh) {
            final catalog = fresh.value;
            final saving = catalog.rewards
                .where((r) => r.isSavingFor)
                .firstOrNull;
            return RefreshIndicator(
              onRefresh: refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xxxl,
                ),
                children: [
                  _BalanceHero(balance: catalog.balance),
                  if (fresh.fromCache) ...[
                    const SizedBox(height: AppSpacing.sm),
                    FreshnessLine(fetchedAt: fresh.fetchedAt, fromCache: true),
                  ],
                  if (saving != null) ...[
                    KidSectionTitle(l.kidSavingFor),
                    _RewardCard(reward: saving, highlight: true),
                  ],
                  KidSectionTitle(l.kidTabRewards),
                  if (catalog.rewards.isEmpty)
                    EmptyView(emoji: '🎁', message: l.kidNoRewards)
                  else
                    LayoutBuilder(
                      builder: (context, box) {
                        final columns = box.maxWidth > 560 ? 2 : 1;
                        final items = catalog.rewards
                            .where((r) => !r.isSavingFor)
                            .toList();
                        return Wrap(
                          spacing: AppSpacing.md,
                          runSpacing: AppSpacing.md,
                          children: [
                            for (final r in items)
                              SizedBox(
                                width: columns == 1
                                    ? box.maxWidth
                                    : (box.maxWidth - AppSpacing.md) / 2,
                                child: _RewardCard(reward: r),
                              ),
                          ],
                        );
                      },
                    ),
                  KidSectionTitle(
                    l.kidMyIdeas,
                    trailing: TextButton.icon(
                      onPressed: () => _suggest(context, ref),
                      icon: const Icon(Icons.lightbulb_outline_rounded),
                      label: Text(l.kidSuggestReward),
                    ),
                  ),
                  ...wishes.maybeWhen(
                    data: (w) => w.value.isEmpty
                        ? [
                            KidCard(
                              onTap: () => _suggest(context, ref),
                              child: Row(
                                children: [
                                  const Text(
                                    '💡',
                                    style: TextStyle(fontSize: 32),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Text(
                                      l.kidSuggestTitle,
                                      style: context.type.titleSmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ]
                        : [for (final wish in w.value) _WishRow(wish: wish)],
                    orElse: () => const [SizedBox.shrink()],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const KidPointsHistoryScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.receipt_long_rounded),
                    label: Text(l.kidPointsHistory),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _suggest(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _SuggestSheet(),
    );
  }
}

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    final c = context.mamily;
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: AppRadii.xlAll,
        gradient: LinearGradient(colors: [c.warning.background, c.surface]),
        border: Border.all(color: c.warning.border),
      ),
      child: Row(
        children: [
          const Text('⭐', style: TextStyle(fontSize: 52)),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.kidMyBalance,
                  style: context.type.labelLarge?.copyWith(
                    color: c.warning.foreground,
                  ),
                ),
                Semantics(
                  label: l.kidPoints(balance),
                  excludeSemantics: true,
                  child: Text('$balance', style: context.type.displaySmall),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardCard extends ConsumerStatefulWidget {
  const _RewardCard({required this.reward, this.highlight = false});

  final KidReward reward;
  final bool highlight;

  @override
  ConsumerState<_RewardCard> createState() => _RewardCardState();
}

class _RewardCardState extends ConsumerState<_RewardCard> {
  bool _busy = false;

  String get _emoji => switch (widget.reward.type) {
    'screen_time' => '📺',
    'physical' => '🧸',
    'family_activity' => '🎡',
    _ => '🎟️',
  };

  Future<void> _ask() async {
    final l = context.l10n;
    final r = widget.reward;
    final ok = await confirmAction(
      context,
      title: l.kidRewardAskTitle(r.title),
      body: l.kidRewardAskBody(r.pointsCost),
      confirmLabel: l.kidAskForReward,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(kidActionsProvider).requestReward(r.id);
      if (mounted)
        Celebration.show(context, message: l.kidRewardAsked, emoji: '🎁');
    } catch (e) {
      if (mounted) showKidError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(kidActionsProvider)
          .setSavingFor(widget.reward.isSavingFor ? null : widget.reward.id);
    } catch (e) {
      if (mounted) showKidError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mamily;
    final l = context.l10n;
    final r = widget.reward;
    return KidCard(
      color: widget.highlight ? c.warning.background : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EmojiTile(
                emoji: _emoji,
                size: 52,
                fill: widget.highlight ? c.surface : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.title, style: context.type.titleSmall),
                    Text(
                      '${r.pointsCost} ⭐',
                      style: context.type.labelLarge?.copyWith(
                        color: c.warning.foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ProgressBar(
            value: r.progress,
            color: r.affordable ? c.success.foreground : c.warning.foreground,
            semanticsLabel: r.title,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l.kidPointsToGo(r.pointsNeeded),
            style: context.type.bodySmall?.copyWith(
              color: r.affordable ? c.success.foreground : c.ink2,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: r.hasPendingRequest
                    ? StatusPill(
                        label: l.kidRequested,
                        tone: AppTone.info,
                        icon: Icons.hourglass_top_rounded,
                      )
                    : FilledButton(
                        onPressed: r.affordable && !_busy ? _ask : null,
                        child: Text(l.kidAskForReward),
                      ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                tooltip: r.isSavingFor ? l.kidGoalChosen : l.kidChooseGoal,
                onPressed: _busy ? null : _save,
                icon: Icon(
                  r.isSavingFor
                      ? Icons.flag_rounded
                      : Icons.outlined_flag_rounded,
                  color: r.isSavingFor ? c.brand.foreground : c.ink2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WishRow extends ConsumerWidget {
  const _WishRow({required this.wish});

  final RewardWish wish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.mamily;
    final (label, tone) = switch (wish.status) {
      'approved' => (l.explainWishApproved, AppTone.success),
      'declined' => (l.explainWishDeclined, AppTone.neutral),
      'withdrawn' => (l.explainWishWithdrawn, AppTone.neutral),
      _ => (l.explainWishPending, AppTone.info),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: KidCard(
        child: Row(
          children: [
            const Text('💡', style: TextStyle(fontSize: 28)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(wish.title, style: context.type.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
                  StatusPill(label: label, tone: tone),
                  if ((wish.decisionNote ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        l.kidParentNote(wish.decisionNote!),
                        style: context.type.bodySmall?.copyWith(color: c.ink2),
                      ),
                    ),
                ],
              ),
            ),
            if (wish.status == 'pending')
              TextButton(
                onPressed: () async {
                  try {
                    await ref.read(kidActionsProvider).withdrawWish(wish.id);
                  } catch (e) {
                    if (context.mounted) showKidError(context, e);
                  }
                },
                child: Text(l.kidWithdraw),
              ),
          ],
        ),
      ),
    );
  }
}

class _SuggestSheet extends ConsumerStatefulWidget {
  const _SuggestSheet();

  @override
  ConsumerState<_SuggestSheet> createState() => _SuggestSheetState();
}

class _SuggestSheetState extends ConsumerState<_SuggestSheet> {
  final _title = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _title.text.trim();
    if (title.length < 2) return;
    setState(() => _busy = true);
    try {
      final note = _note.text.trim();
      await ref
          .read(kidActionsProvider)
          .suggestWish(title, note: note.isEmpty ? null : note);
      if (!mounted) return;
      final l = context.l10n;
      Navigator.of(context).pop();
      Celebration.show(context, message: l.kidSuggestSent, emoji: '💡');
    } catch (e) {
      if (mounted) showKidError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.kidSuggestTitle, style: context.type.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _title,
                autofocus: true,
                maxLength: 120,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: l.kidSuggestField),
              ),
              TextField(
                controller: _note,
                maxLength: 300,
                maxLines: 2,
                decoration: InputDecoration(labelText: l.kidSuggestNote),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: _busy || _title.text.trim().length < 2
                    ? null
                    : _send,
                child: Text(l.kidSuggestSend),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Points history: every earn and spend, from the server ledger.
class KidPointsHistoryScreen extends ConsumerWidget {
  const KidPointsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.mamily;
    final async = ref.watch(kidPointsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.kidPointsHistory)),
      body: AppContentFrame(
        child: async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorRetryView(
            error: e,
            onRetry: () async => ref.invalidate(kidPointsProvider),
          ),
          data: (fresh) => fresh.value.entries.isEmpty
              ? EmptyView(emoji: '⭐', message: l.kidPoints(0))
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: fresh.value.entries.length + 1,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    if (i == 0)
                      return _BalanceHero(balance: fresh.value.balance);
                    final e = fresh.value.entries[i - 1];
                    final earn = e.amount >= 0;
                    return KidCard(
                      child: Row(
                        children: [
                          Text(
                            earn ? '⬆️' : '🎁',
                            style: const TextStyle(fontSize: 26),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.reference ?? e.type,
                                  style: context.type.titleSmall,
                                ),
                                if (e.createdAt != null)
                                  Text(
                                    relativeTime(context, e.createdAt!),
                                    style: context.type.bodySmall?.copyWith(
                                      color: c.ink2,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '${earn ? '+' : ''}${e.amount}',
                            style: context.type.titleMedium?.copyWith(
                              color: earn
                                  ? c.success.foreground
                                  : c.danger.foreground,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
