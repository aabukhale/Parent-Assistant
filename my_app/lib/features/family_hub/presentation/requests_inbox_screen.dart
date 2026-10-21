import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../kid/presentation/kid_widgets.dart';
import '../application/hub_actions.dart';
import '../application/hub_providers.dart';
import '../data/hub_models.dart';
import 'hub_widgets.dart';

/// One inbox for everything waiting on a parent: finished tasks and
/// activities, reward requests and ideas, extra screen time, routine bonuses
/// and unanswered check-ins.
class RequestsInboxScreen extends ConsumerStatefulWidget {
  const RequestsInboxScreen({super.key, this.childId});

  final String? childId;

  @override
  ConsumerState<RequestsInboxScreen> createState() =>
      _RequestsInboxScreenState();
}

class _RequestsInboxScreenState extends ConsumerState<RequestsInboxScreen> {
  late String? _child = widget.childId;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final async = ref.watch(familyInboxProvider(_child));
    final children = ref.watch(childLookupProvider).values.toList();

    return Scaffold(
      appBar: AppBar(title: Text(l.inboxTitle)),
      body: AppContentFrame(
        maxWidth: 760,
        child: Column(
          children: [
            if (children.length > 1)
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  children: [
                    ChoiceChip(
                      label: Text(l.inboxAll),
                      selected: _child == null,
                      onSelected: (_) => setState(() => _child = null),
                    ),
                    for (final c in children) ...[
                      const SizedBox(width: AppSpacing.sm),
                      ChoiceChip(
                        avatar: ChildAvatarById(childId: c.id, size: 24),
                        label: Text(c.name),
                        selected: _child == c.id,
                        onSelected: (_) => setState(() => _child = c.id),
                      ),
                    ],
                  ],
                ),
              ),
            Expanded(
              child: async.when(
                skipLoadingOnRefresh: true,
                loading: () => const LoadingView(),
                error: (e, _) => ErrorRetryView(
                  error: e,
                  onRetry: () async =>
                      ref.invalidate(familyInboxProvider(_child)),
                ),
                data: (fresh) => RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(familyInboxProvider(_child)),
                  child: fresh.value.items.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 80),
                            EmptyView(
                              icon: Icons.wb_sunny_rounded,
                              message: l.inboxEmpty,
                            ),
                          ],
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.sm,
                            AppSpacing.lg,
                            AppSpacing.xxxl,
                          ),
                          children: [
                            if (fresh.fromCache)
                              FreshnessLine(
                                fetchedAt: fresh.fetchedAt,
                                fromCache: true,
                              ),
                            for (final item in fresh.value.items) ...[
                              InboxItemCard(item: item),
                              const SizedBox(height: AppSpacing.md),
                            ],
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One request with its primary action. Used by the inbox and on Today.
class InboxItemCard extends ConsumerStatefulWidget {
  const InboxItemCard({super.key, required this.item, this.compact = false});

  final InboxItem item;
  final bool compact;

  @override
  ConsumerState<InboxItemCard> createState() => _InboxItemCardState();
}

class _InboxItemCardState extends ConsumerState<InboxItemCard> {
  bool _busy = false;

  InboxItem get item => widget.item;

  (String, IconData, AppTone) _kind(AppLocalizations l) => switch (item.kind) {
    'task_completion' => (
      l.inboxKindTask,
      Icons.task_alt_rounded,
      AppTone.success,
    ),
    'activity_completion' => (
      l.inboxKindActivity,
      Icons.extension_rounded,
      AppTone.accent,
    ),
    'reward_redemption' => (
      l.inboxKindReward,
      Icons.card_giftcard_rounded,
      AppTone.brand,
    ),
    'reward_wish' => (
      l.inboxKindWish,
      Icons.lightbulb_rounded,
      AppTone.warning,
    ),
    'screen_time_request' => (
      l.inboxKindScreenTime,
      Icons.more_time_rounded,
      AppTone.info,
    ),
    'routine_run' => (
      l.inboxKindRoutine,
      Icons.wb_sunny_rounded,
      AppTone.accent,
    ),
    _ => (l.inboxKindCheckin, Icons.favorite_rounded, AppTone.sleep),
  };

  String _title(AppLocalizations l) => switch (item.kind) {
    'screen_time_request' => l.inboxMinutesAsked(
      (item.detail['minutes'] as num?)?.toInt() ?? 0,
    ),
    'checkin' => moodLabel(l, item.title),
    _ => item.title,
  };

  String? _detail(AppLocalizations l) {
    final d = item.detail;
    return switch (item.kind) {
      'task_completion' || 'activity_completion'
          when ((d['points'] as num?)?.toInt() ?? 0) > 0 =>
        l.inboxPointsEarn((d['points'] as num).toInt()),
      'reward_redemption' => l.inboxPointsCost(
        (d['points_cost'] as num?)?.toInt() ?? 0,
      ),
      'routine_run' when ((d['bonus_points'] as num?)?.toInt() ?? 0) > 0 =>
        l.inboxPointsEarn((d['bonus_points'] as num).toInt()),
      'reward_wish' => d['note'] as String?,
      'screen_time_request' => d['reason'] as String?,
      'checkin' => d['note'] as String?,
      _ => null,
    };
  }

  Future<void> _run(
    Future<void> Function() action,
    String doneMessage, {
    Future<void> Function()? undo,
  }) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      final l = context.l10n;
      showResultSnack(
        context,
        doneMessage,
        onUndo: undo == null
            ? null
            : () async {
                try {
                  await undo();
                  if (mounted) showResultSnack(context, l.inboxUndone);
                } on ApiException catch (e) {
                  if (mounted) showResultSnack(context, e.localizedMessage(l));
                }
              },
      );
    } on ApiException catch (e) {
      if (mounted) showResultSnack(context, e.localizedMessage(context.l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approve() async {
    final l = context.l10n;
    final actions = ref.read(hubActionsProvider);
    switch (item.kind) {
      case 'reward_wish':
        final r = await _wishSheet();
        if (r == null) return;
        await _run(
          () async => actions.approve(item, points: r.$1, title: r.$2),
          l.inboxApproved,
        );
      case 'screen_time_request':
        final minutes = await _minutesSheet();
        if (minutes == null) return;
        await _run(
          () async => actions.approve(item, minutes: minutes),
          l.inboxApproved,
        );
      default:
        Future<void> Function()? undo;
        await _run(
          () async => undo = await actions.approve(item),
          l.inboxApproved,
          undo: () async => undo?.call(),
        );
    }
  }

  Future<void> _decline() async {
    final l = context.l10n;
    final note = TextEditingController();
    final ok = await confirmAction(
      context,
      title: l.inboxDeclineTitle,
      body: l.inboxDeclineBody,
      confirmLabel: l.inboxDecline,
      extra: TextField(
        controller: note,
        maxLength: 255,
        maxLines: 2,
        decoration: InputDecoration(labelText: l.inboxNoteOptional),
      ),
    );
    final text = note.text.trim();
    note.dispose();
    if (!ok) return;
    await _run(
      () => ref
          .read(hubActionsProvider)
          .decline(item, note: text.isEmpty ? null : text),
      l.inboxDeclined,
    );
  }

  Future<void> _reply() async {
    final l = context.l10n;
    final controller = TextEditingController();
    String? sticker;
    final ok = await confirmAction(
      context,
      title: l.inboxReplyTitle(item.childName ?? ''),
      body: l.inboxCheckinNote,
      confirmLabel: l.commonSend,
      extra: StatefulBuilder(
        builder: (context, set) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final (key, label) in [
                  ('hug', l.stickerHug),
                  ('heart', l.stickerHeart),
                  ('high_five', l.stickerHighFive),
                  ('proud', l.stickerProud),
                  ('thinking_of_you', l.stickerThinking),
                  ('lets_talk', l.stickerTalk),
                ])
                  ChoiceChip(
                    avatar: Icon(stickerIcon(key), size: 18),
                    label: Text(label),
                    selected: sticker == key,
                    onSelected: (s) => set(() => sticker = s ? key : null),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              maxLength: 200,
              maxLines: 2,
              decoration: InputDecoration(hintText: l.inboxReplyHint),
            ),
          ],
        ),
      ),
    );
    final text = controller.text.trim();
    controller.dispose();
    if (!ok || (text.isEmpty && sticker == null)) return;
    await _run(
      () => ref
          .read(hubActionsProvider)
          .replyCheckin(
            item.id,
            reply: text.isEmpty ? null : text,
            sticker: sticker,
          ),
      l.inboxReplySent,
    );
  }

  Future<(int, String)?> _wishSheet() async {
    final l = context.l10n;
    final name = TextEditingController(text: item.title);
    final points = TextEditingController(text: '50');
    final ok = await confirmAction(
      context,
      title: l.inboxWishTitle,
      confirmLabel: l.inboxWishAdd,
      extra: Column(
        children: [
          TextField(
            controller: name,
            maxLength: 120,
            decoration: InputDecoration(labelText: l.inboxWishName),
          ),
          TextField(
            controller: points,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l.inboxWishPoints),
          ),
        ],
      ),
    );
    final result = (int.tryParse(points.text.trim()) ?? 0, name.text.trim());
    name.dispose();
    points.dispose();
    if (!ok || result.$1 < 1 || result.$2.length < 2) return null;
    return result;
  }

  Future<int?> _minutesSheet() async {
    final l = context.l10n;
    var minutes = (item.detail['minutes'] as num?)?.toInt() ?? 15;
    final ok = await confirmAction(
      context,
      title: l.inboxGrantMinutes,
      body: l.inboxGrantNote,
      confirmLabel: l.inboxApprove,
      extra: StatefulBuilder(
        builder: (context, set) => Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final m in {10, 15, 20, 30, 45, 60, minutes}.toList()..sort())
              ChoiceChip(
                label: Text(l.kidMinutes(m)),
                selected: minutes == m,
                onSelected: (_) => set(() => minutes = m),
              ),
          ],
        ),
      ),
    );
    return ok ? minutes : null;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.mamily;
    final (kindLabel, icon, tone) = _kind(l);
    final detail = _detail(l);
    final isCheckin = item.kind == 'checkin';
    final byChild = item.detail['by_child'];

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ChildAvatarById(
                childId: item.childId,
                name: item.childName,
                size: 40,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.childName ?? '', style: context.type.titleSmall),
                    if (item.createdAt != null)
                      Text(
                        relativeTime(context, item.createdAt!),
                        style: context.type.bodySmall?.copyWith(color: c.ink2),
                      ),
                  ],
                ),
              ),
              StatusPill(label: kindLabel, tone: tone, icon: icon),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(_title(l), style: context.type.titleMedium),
          if (detail != null && detail.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              detail,
              style: context.type.bodyMedium?.copyWith(color: c.ink2),
            ),
          ],
          if (byChild is bool && !widget.compact) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              byChild
                  ? l.inboxByChild(item.childName ?? '')
                  : l.inboxLoggedByParent,
              style: context.type.bodySmall?.copyWith(color: c.ink3),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (!item.canAct)
            Text(
              l.inboxNoPermission,
              style: context.type.bodySmall?.copyWith(color: c.ink2),
            )
          else if (isCheckin)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.tonalIcon(
                onPressed: _busy ? null : _reply,
                icon: const Icon(Icons.reply_rounded),
                label: Text(l.inboxReply),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _decline,
                    child: Text(l.inboxDecline),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _approve,
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(l.inboxApprove),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
