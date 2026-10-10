import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system.dart';
import '../../../core/localization/l10n.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/login_screen.dart';
import '../../notifications/application/notifications_controller.dart';
import '../../notifications/presentation/inbox_screen.dart';
import '../application/kid_providers.dart';
import '../data/kid_models.dart';
import 'kid_feedback.dart';
import 'kid_widgets.dart';
import 'mood_sheet.dart';

/// "Me": my requests and their answers, asking for screen time, how I feel,
/// my activities, notifications, and the grown-ups area.
class KidMeScreen extends ConsumerWidget {
  const KidMeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.mamily;
    final session = ref.watch(childSessionProvider);
    final requests = ref.watch(kidRequestsProvider);
    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;
    Future<void> refresh() async {
      ref
        ..invalidate(kidRequestsProvider)
        ..invalidate(kidScreenTimeProvider)
        ..invalidate(kidCheckinsProvider)
        ..invalidate(kidActivitiesProvider)
        ..invalidate(unreadCountProvider);
    }

    return SafeArea(
      bottom: false,
      child: AppContentFrame(
        maxWidth: 720,
        child: RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxxl,
            ),
            children: [
              if (session != null)
                Row(
                  children: [
                    ChildAvatar(
                      name: session.name,
                      avatarKey: session.avatarKey,
                      colorHex: session.avatarColor,
                      seed: session.childId,
                      size: 72,
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(session.name, style: context.type.headlineSmall),
                          Text(
                            session.familyName,
                            style: context.type.bodyLarge?.copyWith(
                              color: c.ink2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              KidSectionTitle(l.kidMyRequests),
              ...requests.when(
                loading: () => [
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: LoadingView(),
                  ),
                ],
                error: (e, _) => [ErrorRetryView(error: e, onRetry: refresh)],
                data: (fresh) {
                  final r = fresh.value;
                  if (r.pending.isEmpty && r.decided.isEmpty)
                    return [EmptyView(emoji: '📮', message: l.kidNoRequests)];
                  return [
                    for (final item in r.pending.take(5))
                      _RequestTile(item: item),
                    for (final item in r.decided.take(5))
                      _RequestTile(item: item),
                    if (r.pending.length + r.decided.length > 10)
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const KidRequestsScreen(),
                          ),
                        ),
                        child: Text(l.commonSeeAll),
                      ),
                  ];
                },
              ),
              KidSectionTitle(l.kidMoreTime),
              const _ScreenTimeCard(),
              KidSectionTitle(l.kidHowFeel),
              const _RecentMoods(),
              KidSectionTitle(l.kidMyActivities),
              const _ActivitiesList(),
              const SizedBox(height: AppSpacing.lg),
              KidCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const NotificationInboxScreen(),
                  ),
                ),
                child: Row(
                  children: [
                    const EmojiTile(emoji: '🔔', size: 44),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        l.kidNotifications,
                        style: context.type.titleSmall,
                      ),
                    ),
                    if (unread > 0)
                      Badge(label: Text('$unread'), largeSize: 24),
                  ],
                ),
              ),
              KidSectionTitle(l.kidGrownUps),
              KidCard(
                color: c.surfaceMuted,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l.kidGrownUpsBody,
                      style: context.type.bodyMedium?.copyWith(color: c.ink2),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.lock_person_rounded),
                      label: Text(l.kidParentSignIn),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LoginScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: () async {
                        final ok = await confirmAction(
                          context,
                          title: l.kidSignOutDevice,
                          body: l.kidSignOutConfirm,
                          confirmLabel: l.commonSignOut,
                          destructive: true,
                        );
                        if (ok)
                          await ref
                              .read(authControllerProvider.notifier)
                              .logout();
                      },
                      child: Text(l.kidSignOutDevice),
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
}

String explainRequest(AppLocalizations l, KidRequest r) =>
    switch (r.explanation) {
      'task_pending' => l.explainTaskPending,
      'task_approved' => l.explainTaskApproved,
      'task_rejected' => l.explainTaskRejected,
      'task_reversed' => l.explainTaskReversed,
      'reward_pending' => l.explainRewardPending,
      'reward_approved' => l.explainRewardApproved,
      'reward_rejected' => l.explainRewardRejected,
      'reward_cancelled' => l.explainRewardCancelled,
      'wish_pending' => l.explainWishPending,
      'wish_approved' => l.explainWishApproved,
      'wish_declined' => l.explainWishDeclined,
      'wish_withdrawn' => l.explainWishWithdrawn,
      'screen_time_pending' => l.explainScreenPending,
      'screen_time_approved' => l.explainScreenApproved,
      'screen_time_declined' => l.explainScreenDeclined,
      'screen_time_cancelled' => l.explainScreenCancelled,
      'routine_pending' => l.explainRoutinePending,
      'routine_approved' => l.explainRoutineApproved,
      'routine_rejected' => l.explainRoutineRejected,
      _ => r.status,
    };

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.item});

  final KidRequest item;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.mamily;
    final emoji = switch (item.kind) {
      'task' => '✅',
      'reward' => '🎁',
      'wish' => '💡',
      'screen_time' => '⏱️',
      'routine' => '🧩',
      _ => '📮',
    };
    final title = item.kind == 'screen_time'
        ? l.kidMinutes(item.minutes ?? int.tryParse(item.title) ?? 0)
        : item.title;
    final tone = switch (item.status) {
      'pending' => AppTone.info,
      'approved' => AppTone.success,
      'rejected' || 'declined' || 'reversed' => AppTone.warning,
      _ => AppTone.neutral,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: KidCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.type.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
                  StatusPill(label: explainRequest(l, item), tone: tone),
                  if ((item.note ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        l.kidParentNote(item.note!),
                        style: context.type.bodySmall?.copyWith(color: c.ink2),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full list of my requests.
class KidRequestsScreen extends ConsumerWidget {
  const KidRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(kidRequestsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.kidMyRequests)),
      body: AppContentFrame(
        child: async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorRetryView(
            error: e,
            onRetry: () async => ref.invalidate(kidRequestsProvider),
          ),
          data: (fresh) => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              if (fresh.value.pending.isNotEmpty) KidSectionTitle(l.kidWaiting),
              for (final r in fresh.value.pending) _RequestTile(item: r),
              if (fresh.value.decided.isNotEmpty)
                KidSectionTitle(l.kidAnswered),
              for (final r in fresh.value.decided) _RequestTile(item: r),
              if (fresh.value.pending.isEmpty && fresh.value.decided.isEmpty)
                EmptyView(emoji: '📮', message: l.kidNoRequests),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScreenTimeCard extends ConsumerStatefulWidget {
  const _ScreenTimeCard();

  @override
  ConsumerState<_ScreenTimeCard> createState() => _ScreenTimeCardState();
}

class _ScreenTimeCardState extends ConsumerState<_ScreenTimeCard> {
  bool _busy = false;

  Future<void> _ask() async {
    final l = context.l10n;
    int minutes = 15;
    final reason = TextEditingController();
    final ok = await confirmAction(
      context,
      title: l.kidMoreTime,
      confirmLabel: l.kidMoreTimeSend,
      extra: StatefulBuilder(
        builder: (context, set) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.kidMoreTimeHow, style: context.type.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final m in const [10, 15, 20, 30, 45, 60])
                  ChoiceChip(
                    label: Text(l.kidMinutes(m)),
                    selected: minutes == m,
                    onSelected: (_) => set(() => minutes = m),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: reason,
              maxLength: 200,
              decoration: InputDecoration(labelText: l.kidMoreTimeWhy),
            ),
          ],
        ),
      ),
    );
    final why = reason.text.trim();
    reason.dispose();
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(kidActionsProvider)
          .askForScreenTime(minutes, reason: why.isEmpty ? null : why);
      if (mounted) showResultSnack(context, l.kidRewardAsked);
    } catch (e) {
      if (mounted) showKidError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.mamily;
    final async = ref.watch(kidScreenTimeProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorRetryView(
        error: e,
        onRetry: () async => ref.invalidate(kidScreenTimeProvider),
      ),
      data: (fresh) {
        final st = fresh.value;
        final pending = st.pending;
        return KidCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const EmojiTile(emoji: '⏱️', size: 48),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      st.limitMinutes == null
                          ? l.kidScreenNoLimit
                          : l.kidScreenTodayLimit(st.limitMinutes!),
                      style: context.type.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l.kidScreenNotMeasured,
                style: context.type.bodySmall?.copyWith(color: c.ink2),
              ),
              const SizedBox(height: AppSpacing.md),
              if (pending != null) ...[
                NoticeBanner(
                  tone: AppTone.info,
                  message: l.kidMoreTimeWaiting(pending.minutes),
                ),
                TextButton(
                  onPressed: () =>
                      ref.read(kidActionsProvider).cancelScreenTime(pending.id),
                  child: Text(l.kidWithdraw),
                ),
              ] else
                FilledButton.icon(
                  onPressed: _busy ? null : _ask,
                  icon: const Icon(Icons.more_time_rounded),
                  label: Text(l.kidMoreTime),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RecentMoods extends ConsumerWidget {
  const _RecentMoods();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.mamily;
    final async = ref.watch(kidCheckinsProvider);
    final recent =
        async.valueOrNull?.value.take(5).toList() ?? const <MoodCheckin>[];
    return KidCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (recent.isNotEmpty)
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final m in recent)
                  Tooltip(
                    message: moodLabel(l, m.mood),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: c.surfaceMuted,
                        borderRadius: AppRadii.mediumAll,
                      ),
                      child: Text(
                        moodEmoji(m.mood),
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
                  ),
              ],
            ),
          if (recent.isNotEmpty) const SizedBox(height: AppSpacing.md),
          FilledButton.tonalIcon(
            onPressed: () => showMoodSheet(context),
            icon: const Icon(Icons.emoji_emotions_rounded),
            label: Text(l.kidFeelShare),
          ),
        ],
      ),
    );
  }
}

class _ActivitiesList extends ConsumerWidget {
  const _ActivitiesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(kidActivitiesProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorRetryView(
        error: e,
        onRetry: () async => ref.invalidate(kidActivitiesProvider),
      ),
      data: (fresh) {
        final open = fresh.value
            .where((a) => a['status'] == 'assigned')
            .toList();
        if (open.isEmpty) return EmptyView(emoji: '🧪', message: l.commonEmpty);
        return Column(
          children: [
            for (final a in open)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: KidCard(
                  child: Row(
                    children: [
                      const EmojiTile(emoji: '🧪', size: 44),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          ((a['activity'] as Map?)?['title'] as String?) ?? '',
                          style: context.type.titleSmall,
                        ),
                      ),
                      _ActivityDoneButton(assignment: a),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ActivityDoneButton extends ConsumerStatefulWidget {
  const _ActivityDoneButton({required this.assignment});

  final Map<String, dynamic> assignment;

  @override
  ConsumerState<_ActivityDoneButton> createState() =>
      _ActivityDoneButtonState();
}

class _ActivityDoneButtonState extends ConsumerState<_ActivityDoneButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final completions = (widget.assignment['completions'] as List?) ?? const [];
    final pending = completions.whereType<Map>().any(
      (c) => c['status'] == 'pending',
    );
    if (pending) return KidStateBadge(state: 'pending');
    return FilledButton(
      onPressed: _busy
          ? null
          : () async {
              setState(() => _busy = true);
              try {
                await ref
                    .read(kidActionsProvider)
                    .completeActivity(widget.assignment['id'] as String);
                if (context.mounted)
                  Celebration.show(
                    context,
                    message: l.celebrateGreat,
                    emoji: '🌟',
                  );
              } catch (e) {
                if (context.mounted) showKidError(context, e);
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
      child: Text(l.kidActivityDone),
    );
  }
}
