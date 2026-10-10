import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/util/client_id.dart';
import '../application/kid_providers.dart';
import '../data/kid_models.dart';
import 'kid_feedback.dart';
import 'kid_widgets.dart';

/// Family challenges (cooperative — one shared total, no rankings) and
/// messages from the family (praise and replies to check-ins).
class TogetherScreen extends ConsumerWidget {
  const TogetherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final challenges = ref.watch(kidChallengesProvider);
    final messages = ref.watch(kidEncouragementsProvider);
    final checkins = ref.watch(kidCheckinsProvider);
    Future<void> refresh() async {
      ref
        ..invalidate(kidChallengesProvider)
        ..invalidate(kidEncouragementsProvider)
        ..invalidate(kidCheckinsProvider);
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
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xxxl,
            ),
            children: [
              KidSectionTitle(l.kidChallenges),
              ...challenges.when(
                loading: () => [
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: LoadingView(),
                  ),
                ],
                error: (e, _) => [ErrorRetryView(error: e, onRetry: refresh)],
                data: (fresh) => fresh.value.isEmpty
                    ? [EmptyView(emoji: '🤝', message: l.kidNoChallenges)]
                    : [
                        for (final ch in fresh.value)
                          _ChallengeCard(challenge: ch),
                      ],
              ),
              KidSectionTitle(l.kidMessages),
              ..._messageList(context, ref, messages, checkins),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _messageList(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<Fresh<List<Encouragement>>> messages,
    AsyncValue<Fresh<List<MoodCheckin>>> checkins,
  ) {
    final l = context.l10n;
    final c = context.mamily;
    final praise = messages.valueOrNull?.value ?? const <Encouragement>[];
    final replies = (checkins.valueOrNull?.value ?? const <MoodCheckin>[])
        .where((m) => m.hasReply)
        .toList();
    if (messages.isLoading && praise.isEmpty) return const [LoadingView()];
    if (praise.isEmpty && replies.isEmpty) {
      return [EmptyView(emoji: '💌', message: l.kidNoMessages)];
    }

    final items = <(DateTime, Widget)>[
      for (final e in praise)
        (
          e.createdAt ?? DateTime(2000),
          KidCard(
            color: e.seenAt == null ? c.sleep.background : null,
            onTap: e.seenAt == null
                ? () => ref.read(kidActionsProvider).markSeen(e.id)
                : null,
            child: Row(
              children: [
                Text(
                  badgeEmoji(e.badgeKey),
                  style: const TextStyle(fontSize: 36),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (e.senderName != null)
                            Expanded(
                              child: Text(
                                e.senderName!,
                                style: context.type.labelLarge?.copyWith(
                                  color: c.sleep.foreground,
                                ),
                              ),
                            ),
                          if (e.seenAt == null)
                            StatusPill(label: l.commonNew, tone: AppTone.sleep),
                        ],
                      ),
                      Text(e.message, style: context.type.bodyLarge),
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
              ],
            ),
          ),
        ),
      for (final m in replies)
        (
          m.repliedAt ?? DateTime(2000),
          KidCard(
            child: Row(
              children: [
                Text(
                  m.replySticker != null
                      ? _sticker(m.replySticker!)
                      : moodEmoji(m.mood),
                  style: const TextStyle(fontSize: 34),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.kidReplyFrom(m.repliedByName ?? ''),
                        style: context.type.labelLarge?.copyWith(
                          color: c.accent.foreground,
                        ),
                      ),
                      if ((m.reply ?? '').isNotEmpty)
                        Text(m.reply!, style: context.type.bodyLarge),
                      Text(
                        '${moodEmoji(m.mood)} ${moodLabel(l, m.mood)}${m.note == null ? '' : ' · ${m.note}'}',
                        style: context.type.bodySmall?.copyWith(color: c.ink2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    ]..sort((a, b) => b.$1.compareTo(a.$1));

    return [
      for (final (_, w) in items)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: w,
        ),
    ];
  }

  static String _sticker(String key) => switch (key) {
    'hug' => '🤗',
    'heart' => '❤️',
    'high_five' => '🙌',
    'proud' => '🥹',
    'thinking_of_you' => '💭',
    'lets_talk' => '💬',
    _ => '💌',
  };
}

class _ChallengeCard extends ConsumerStatefulWidget {
  const _ChallengeCard({required this.challenge});

  final FamilyChallenge challenge;

  @override
  ConsumerState<_ChallengeCard> createState() => _ChallengeCardState();
}

class _ChallengeCardState extends ConsumerState<_ChallengeCard> {
  bool _busy = false;
  // Reused if the same contribution is retried after a network error.
  String? _pendingClientId;

  Future<void> _add() async {
    final l = context.l10n;
    final amount = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.kidAddProgressAmount, style: sheet.type.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.center,
                children: [
                  for (final n in const [1, 5, 10, 15, 20, 30])
                    ActionChip(
                      label: Text(
                        widget.challenge.unitLabel == null
                            ? '$n'
                            : '$n ${widget.challenge.unitLabel}',
                      ),
                      onPressed: () => Navigator.of(sheet).pop(n),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (amount == null || !mounted) return;
    setState(() => _busy = true);
    _pendingClientId ??= newClientId();
    try {
      await ref
          .read(kidActionsProvider)
          .contribute(widget.challenge.id, amount, clientId: _pendingClientId!);
      _pendingClientId = null;
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
    final ch = widget.challenge;
    final achieved = ch.status == 'achieved' || ch.status == 'rewarded';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: KidCard(
        color: achieved ? c.success.background : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProgressRing(
                  value: ch.progress,
                  size: 76,
                  color: achieved ? c.success.foreground : c.accent.foreground,
                  semanticsLabel: ch.title,
                  center: Text(
                    achieved ? '🏆' : '🤝',
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ch.title, style: context.type.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${l.kidTogetherProgress(ch.progressValue, ch.targetValue)}${ch.unitLabel == null ? '' : ' ${ch.unitLabel}'}',
                        style: context.type.bodyLarge?.copyWith(color: c.ink2),
                      ),
                      if (ch.myContribution != null && ch.myContribution! > 0)
                        Text(
                          l.kidMyPart(ch.myContribution!),
                          style: context.type.bodySmall?.copyWith(
                            color: c.accent.foreground,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // Everyone on the same team — avatars, never a scoreboard.
            Row(
              children: [
                for (final p in ch.participants.take(6))
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: AppSpacing.xs,
                    ),
                    child: ChildAvatar(
                      name: p.name,
                      avatarKey: p.avatarKey,
                      colorHex: p.avatarColor,
                      seed: p.id,
                      size: 32,
                    ),
                  ),
                const Spacer(),
                if (ch.rewardPoints > 0) PointsPill(points: ch.rewardPoints),
              ],
            ),
            if (achieved) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                l.kidChallengeAchieved,
                style: context.type.titleSmall?.copyWith(
                  color: c.success.foreground,
                ),
              ),
            ] else if (ch.isManual && ch.isActive) ...[
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: _busy ? null : _add,
                icon: const Icon(Icons.add_rounded),
                label: Text(l.kidAddProgress),
              ),
            ] else if (ch.isActive) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l.kidChallengeCountsAuto,
                style: context.type.bodySmall?.copyWith(color: c.ink2),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
