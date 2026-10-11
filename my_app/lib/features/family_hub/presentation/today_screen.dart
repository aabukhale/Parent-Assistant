import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/design_system.dart';
import '../../../core/localization/l10n.dart';
import '../../auth/application/auth_controller.dart';
import '../../children/presentation/child_form_screen.dart';
import '../../kid/data/kid_models.dart';
import '../../kid/presentation/kid_widgets.dart';
import '../../notifications/application/notifications_controller.dart';
import '../../notifications/presentation/inbox_screen.dart';
import '../../tasks/presentation/task_form_screen.dart';
import '../application/hub_providers.dart';
import '../data/hub_models.dart';
import 'challenges_screen.dart';
import 'child_hub_screen.dart';
import 'child_picker.dart';
import 'hub_widgets.dart';
import 'pairing_sheet.dart';
import 'planner_screen.dart';
import 'praise_sheet.dart';
import 'recap_screen.dart';
import 'requests_inbox_screen.dart';

/// Parent home: what needs attention now, how each child's day is going,
/// what's planned, and the shortest path to the common actions.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.mamily;
    final user = ref.watch(currentUserProvider);
    final pulse = ref.watch(pulseProvider);
    final inbox = ref.watch(familyInboxProvider(null));
    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? l.todayGreetingMorning(user?.firstName ?? '')
        : hour < 17
        ? l.todayGreetingAfternoon(user?.firstName ?? '')
        : l.todayGreetingEvening(user?.firstName ?? '');
    final dateLine = DateFormat.yMMMMEEEEd(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(DateTime.now());

    Future<void> refresh() async {
      ref
        ..invalidate(pulseProvider)
        ..invalidate(familyInboxProvider)
        ..invalidate(challengesProvider)
        ..invalidate(unreadCountProvider)
        ..invalidate(plannerProvider);
    }

    return SafeArea(
      bottom: false,
      child: AppContentFrame(
        maxWidth: 860,
        child: RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xxxl,
            ),
            children: [
              PageTitle(
                title: greeting,
                subtitle: dateLine,
                trailing: IconButton(
                  tooltip: l.notifInboxTitle,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NotificationInboxScreen(),
                    ),
                  ),
                  icon: Badge(
                    isLabelVisible: unread > 0,
                    label: Text('$unread'),
                    child: const Icon(Icons.notifications_none_rounded),
                  ),
                ),
              ),
              // ---- Needs you -------------------------------------------------
              inbox.when(
                loading: () =>
                    const SizedBox(height: 120, child: LoadingView()),
                error: (e, _) => ErrorRetryView(error: e, onRetry: refresh),
                data: (fresh) => _NeedsYou(inbox: fresh.value),
              ),
              // ---- Family pulse --------------------------------------------------
              SectionHeader(
                title: l.todayFamilyPulse,
                padding: const EdgeInsets.only(
                  top: AppSpacing.xl,
                  bottom: AppSpacing.md,
                ),
              ),
              pulse.when(
                skipLoadingOnRefresh: true,
                loading: () =>
                    const SizedBox(height: 160, child: LoadingView()),
                error: (e, _) => ErrorRetryView(error: e, onRetry: refresh),
                data: (fresh) {
                  if (fresh.value.children.isEmpty) {
                    return EmptyView(
                      emoji: '👶',
                      message: l.todayNoChildren,
                      action: FilledButton.icon(
                        icon: const Icon(Icons.add_rounded),
                        label: Text(l.todayAddChild),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ChildFormScreen(),
                          ),
                        ),
                      ),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LayoutBuilder(
                        builder: (context, box) {
                          final columns = box.maxWidth >= 640 ? 2 : 1;
                          final width = columns == 1
                              ? box.maxWidth
                              : (box.maxWidth - AppSpacing.md) / 2;
                          return Wrap(
                            spacing: AppSpacing.md,
                            runSpacing: AppSpacing.md,
                            children: [
                              for (final child in fresh.value.children)
                                SizedBox(
                                  width: width,
                                  child: _PulseCard(child: child),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      FreshnessLine(
                        fetchedAt: fresh.fetchedAt,
                        fromCache: fresh.fromCache,
                      ),
                      SectionHeader(
                        title: l.todayPlan,
                        actionLabel: l.commonSeeAll,
                        onAction: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const PlannerScreen(),
                          ),
                        ),
                        padding: const EdgeInsets.only(
                          top: AppSpacing.xl,
                          bottom: AppSpacing.md,
                        ),
                      ),
                      _TodayPlan(date: fresh.value.localDate),
                    ],
                  );
                },
              ),
              // ---- Challenges + recap --------------------------------------------
              const _ActiveChallenges(),
              const SizedBox(height: AppSpacing.md),
              NavTile(
                icon: Icons.auto_graph_rounded,
                emoji: '📊',
                tone: AppTone.info,
                title: l.recapTitle,
                subtitle: l.discoverRecapBody,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const RecapScreen()),
                ),
              ),
              // ---- Quick actions -------------------------------------------------
              SectionHeader(
                title: l.todayQuickActions,
                padding: const EdgeInsets.only(
                  top: AppSpacing.xl,
                  bottom: AppSpacing.md,
                ),
              ),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _QuickAction(
                    icon: Icons.add_task_rounded,
                    label: l.quickAddTask,
                    onTap: () async {
                      final child = await pickChild(
                        context,
                        ref,
                        title: l.quickAddTask,
                      );
                      if (child != null && context.mounted) {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const TaskFormScreen(),
                          ),
                        );
                      }
                    },
                  ),
                  _QuickAction(
                    icon: Icons.favorite_rounded,
                    label: l.quickSendPraise,
                    onTap: () async {
                      final child = await pickChild(
                        context,
                        ref,
                        title: l.quickSendPraise,
                      );
                      if (child != null && context.mounted) {
                        await showPraiseSheet(
                          context,
                          childId: child.id,
                          childName: child.name,
                        );
                      }
                    },
                  ),
                  _QuickAction(
                    icon: Icons.event_rounded,
                    label: l.quickNewEvent,
                    onTap: () => showEventSheet(context),
                  ),
                  _QuickAction(
                    icon: Icons.groups_rounded,
                    label: l.quickNewChallenge,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ChallengeFormScreen(),
                      ),
                    ),
                  ),
                  _QuickAction(
                    icon: Icons.qr_code_2_rounded,
                    label: l.quickPairDevice,
                    onTap: () async {
                      final child = await pickChild(
                        context,
                        ref,
                        title: l.quickPairDevice,
                      );
                      if (child != null && context.mounted) {
                        await showPairingSheet(
                          context,
                          childId: child.id,
                          childName: child.name,
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l.pulseDeviceExplain,
                style: context.type.bodySmall?.copyWith(color: c.ink3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NeedsYou extends StatelessWidget {
  const _NeedsYou({required this.inbox});

  final FamilyInbox inbox;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.mamily;
    final count = inbox.items.length;
    if (count == 0) {
      return AppCard(
        color: c.success.background,
        child: Row(
          children: [
            const Text('🌤️', style: TextStyle(fontSize: 30)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(l.todayAllClear, style: context.type.titleSmall),
            ),
          ],
        ),
      );
    }
    final top = inbox.items.take(2).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          color: c.brand.background,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const RequestsInboxScreen(),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.action,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$count',
                  style: context.type.titleMedium?.copyWith(color: c.onAction),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.todayNeedsYou,
                      style: context.type.labelLarge?.copyWith(
                        color: c.brand.foreground,
                      ),
                    ),
                    Text(
                      l.todayNeedsYouCount(count),
                      style: context.type.titleMedium,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.brand.foreground),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final item in top) ...[
          InboxItemCard(item: item, compact: true),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _PulseCard extends StatelessWidget {
  const _PulseCard({required this.child});

  final PulseChild child;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.mamily;
    final routine = child.routine;
    final checkin = child.lastCheckin;
    final st = child.screenTime;

    String? routineLine;
    if (routine != null) {
      final title = routine['title'] as String? ?? '';
      routineLine = routine['state'] == 'in_progress'
          ? l.pulseRoutineNow(title)
          : routine['start_time'] != null
          ? l.pulseRoutineNext(title, routine['start_time'] as String)
          : l.pulseRoutineNextNoTime(title);
    }

    String screenLine;
    switch (st['state']) {
      case 'measured':
        final used = (st['used_minutes'] as num?)?.toInt() ?? 0;
        final limit = (st['limit_minutes'] as num?)?.toInt();
        screenLine = limit == null
            ? l.pulseScreenMeasuredNoLimit(used)
            : l.pulseScreenMeasured(used, limit);
      case 'not_reported':
        screenLine = l.pulseScreenNotReported;
      default:
        screenLine = '';
    }

    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChildHubScreen(childId: child.childId),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ChildAvatar(
                name: child.name,
                avatarKey: child.avatarKey,
                colorHex: child.avatarColor,
                seed: child.childId,
                size: 52,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(child.name, style: context.type.titleMedium),
                    Text(
                      child.tasksTotal == 0
                          ? l.pulseNoTasksToday
                          : l.pulseTasks(child.tasksDone, child.tasksTotal),
                      style: context.type.bodyMedium?.copyWith(color: c.ink2),
                    ),
                  ],
                ),
              ),
              ProgressRing(
                value: child.tasksTotal == 0
                    ? 0
                    : child.tasksDone / child.tasksTotal,
                size: 48,
                stroke: 6,
                color: c.success.foreground,
                semanticsLabel: child.name,
                center: Text(
                  '⭐${child.pointsBalance}',
                  style: context.type.labelSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (child.pendingApprovals > 0)
                StatusPill(
                  label: l.pulseToReview(child.pendingApprovals),
                  tone: AppTone.brand,
                  icon: Icons.how_to_reg_rounded,
                ),
              FreshnessBadge(
                state: child.deviceState,
                lastContactAt: child.lastContactAt,
              ),
            ],
          ),
          if (routineLine != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _Line(icon: Icons.wb_sunny_outlined, text: routineLine),
          ],
          const SizedBox(height: AppSpacing.xs),
          _Line(
            icon: Icons.chat_bubble_outline_rounded,
            text: checkin == null
                ? l.pulseNoCheckin
                : l.pulseCheckin(
                    '${moodEmoji(checkin['mood'] as String)} ${moodLabel(l, checkin['mood'] as String)}',
                    checkin['created_at'] == null
                        ? ''
                        : relativeTime(
                            context,
                            DateTime.parse(
                              checkin['created_at'] as String,
                            ).toLocal(),
                          ),
                  ),
          ),
          if (screenLine.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            _Line(icon: Icons.timer_outlined, text: screenLine),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: AppSizes.iconSm, color: context.mamily.ink2),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: Text(
          text,
          style: context.type.bodySmall?.copyWith(color: context.mamily.ink2),
        ),
      ),
    ],
  );
}

class _TodayPlan extends ConsumerWidget {
  const _TodayPlan({required this.date});

  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    if (date.isEmpty) return const SizedBox.shrink();
    final async = ref.watch(
      plannerProvider((from: date, to: date, childId: null)),
    );
    return async.when(
      loading: () => const SizedBox(height: 80, child: LoadingView()),
      error: (e, _) => ErrorRetryView(
        error: e,
        onRetry: () async => ref.invalidate(plannerProvider),
      ),
      data: (fresh) => fresh.value.isEmpty
          ? AppCard(child: Text(l.todayNoPlan, style: context.type.bodyMedium))
          : Column(
              children: [
                for (final item in fresh.value.take(6)) PlannerRow(item: item),
              ],
            ),
    );
  }
}

class _ActiveChallenges extends ConsumerWidget {
  const _ActiveChallenges();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.mamily;
    final async = ref.watch(challengesProvider);
    final active =
        async.valueOrNull
            ?.where((ch) => ch.status == 'active' || ch.status == 'achieved')
            .toList() ??
        const <FamilyChallenge>[];
    if (active.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l.challengesTitle,
          actionLabel: l.commonSeeAll,
          onAction: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ChallengesScreen()),
          ),
          padding: const EdgeInsets.only(
            top: AppSpacing.xl,
            bottom: AppSpacing.md,
          ),
        ),
        for (final ch in active.take(2))
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: AppCard(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ChallengeDetailScreen(challengeId: ch.id),
                ),
              ),
              child: Row(
                children: [
                  ProgressRing(
                    value: ch.progress,
                    size: 52,
                    stroke: 6,
                    color: c.accent.foreground,
                    semanticsLabel: ch.title,
                    center: const Text('🤝'),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ch.title, style: context.type.titleSmall),
                        Text(
                          '${ch.progressValue}/${ch.targetValue}${ch.unitLabel == null ? '' : ' ${ch.unitLabel}'}',
                          style: context.type.bodySmall?.copyWith(
                            color: c.ink2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (ch.status == 'achieved')
                    StatusPill(
                      label: l.challengeStatusAchieved,
                      tone: AppTone.success,
                      icon: Icons.emoji_events_rounded,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: Icon(icon, size: 20, color: context.mamily.accent.foreground),
    label: Text(label),
    onPressed: onTap,
  );
}
