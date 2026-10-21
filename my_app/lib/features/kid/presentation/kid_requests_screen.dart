import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system.dart';
import '../../../core/localization/l10n.dart';
import '../application/kid_providers.dart';
import '../data/kid_models.dart';
import 'kid_feedback.dart';
import 'kid_widgets.dart';

/// "Ask for more time": the child picks how much and may say why. The
/// parent decides; nothing changes on the phone until they do.
Future<void> askForMoreTime(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  int minutes = 15;
  final reason = TextEditingController();
  final ok = await confirmAction(
    context,
    title: l.kidAskMoreTime,
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
  if (!ok || !context.mounted) return;
  try {
    await ref
        .read(kidActionsProvider)
        .askForScreenTime(minutes, reason: why.isEmpty ? null : why);
    if (context.mounted) showResultSnack(context, l.kidWaitingParent);
  } catch (e) {
    if (context.mounted) showKidError(context, e);
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
    final icon = switch (item.kind) {
      'task' => Icons.task_alt_rounded,
      'reward' => Icons.card_giftcard_rounded,
      'wish' => Icons.lightbulb_rounded,
      'screen_time' => Icons.timer_rounded,
      'routine' => Icons.checklist_rounded,
      _ => Icons.inbox_rounded,
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
            IconTile(icon: icon, size: 44),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.type.titleSmall),
                  // When, and what it earned, so repeated tasks (brushing
                  // teeth every day) can be told apart.
                  if (item.updatedAt != null)
                    Text(
                      [
                        if (item.status == 'approved' && (item.points ?? 0) > 0)
                          l.kidPoints(item.points!),
                        relativeTime(context, item.updatedAt!),
                      ].join(' · '),
                      style: context.type.bodySmall?.copyWith(color: c.ink2),
                    ),
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
                EmptyView(icon: Icons.inbox_rounded, message: l.kidNoRequests),
            ],
          ),
        ),
      ),
    );
  }
}

/// Activities a parent assigned, each with an "I did it" button.
class KidActivitiesSection extends ConsumerWidget {
  const KidActivitiesSection({super.key});

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
        if (open.isEmpty) {
          return KidCard(
            child: Row(
              children: [
                const IconTile(icon: Icons.eco_rounded, size: 44),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    l.kidNoActivities,
                    style: context.type.bodyMedium?.copyWith(
                      color: context.mamily.ink2,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            for (final a in open)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: KidCard(
                  child: Row(
                    children: [
                      const IconTile(icon: Icons.science_rounded, size: 44),
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
                if (context.mounted) {
                  Celebration.show(
                    context,
                    message: l.celebrateGreat,
                    icon: Icons.auto_awesome_rounded,
                  );
                }
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
