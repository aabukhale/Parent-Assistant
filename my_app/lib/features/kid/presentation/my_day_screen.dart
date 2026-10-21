import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system.dart';
import '../../../core/localization/l10n.dart';
import '../../auth/application/auth_controller.dart';
import '../../safety/application/kid_safety_providers.dart';
import '../../safety/presentation/kid_help_screen.dart';
import '../../safety/presentation/kid_safety_widgets.dart';
import '../application/kid_providers.dart';
import '../data/kid_models.dart';
import 'kid_requests_screen.dart';
import 'kid_widgets.dart';
import 'mood_sheet.dart';
import 'routine_run_screen.dart';
import 'task_sheet.dart';

/// "Today": one obvious next step, what is paused and why, today's plan, and
/// what the child is working towards. Every item is real data for this child.
class MyDayScreen extends ConsumerWidget {
  const MyDayScreen({super.key, this.onOpenRewards, this.onOpenTogether});

  final VoidCallback? onOpenRewards;
  final VoidCallback? onOpenTogether;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(kidMyDayProvider);
    final session = ref.watch(childSessionProvider);
    final journey = ref.watch(kidJourneyProvider).valueOrNull;
    Future<void> refresh() async {
      ref
        ..invalidate(kidMyDayProvider)
        ..invalidate(kidScreenTimeProvider)
        ..invalidate(kidJourneyProvider)
        ..invalidate(kidActivitiesProvider);
    }

    return SafeArea(
      bottom: false,
      child: AppContentFrame(
        maxWidth: 720,
        child: async.when(
          skipLoadingOnRefresh: true,
          loading: () => const LoadingView(),
          error: (e, _) => ErrorRetryView(error: e, onRetry: refresh),
          data: (fresh) => RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xxxl,
              ),
              children: [
                _Header(
                  day: fresh.value,
                  name: session?.name ?? '',
                  avatarKey: session?.avatarKey,
                  avatarColor: session?.avatarColor,
                  seed: session?.childId,
                ),
                if (fresh.fromCache) ...[
                  const SizedBox(height: AppSpacing.sm),
                  FreshnessLine(fetchedAt: fresh.fetchedAt, fromCache: true),
                ],
                const SizedBox(height: AppSpacing.lg),
                const _ScreenTimeStatus(),
                if (journey != null && journey.isLive) ...[
                  JourneyBanner(journey: journey),
                  const SizedBox(height: AppSpacing.lg),
                ],
                _NextStepCard(day: fresh.value),
                if (fresh.value.newEncouragements.isNotEmpty) ...[
                  KidSectionTitle(context.l10n.kidMessages),
                  for (final e in fresh.value.newEncouragements)
                    _MessageCard(e: e, onOpen: onOpenTogether),
                ],
                if (!fresh.value.checkedInToday) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const _MoodPrompt(),
                ],
                if (fresh.value.timeline.isNotEmpty) ...[
                  KidSectionTitle(context.l10n.kidTodayPlan),
                  for (final item in fresh.value.timeline) ...[
                    _TimelineTile(item: item),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
                if (fresh.value.rewardGoal != null) ...[
                  KidSectionTitle(context.l10n.kidSavingFor),
                  _GoalCard(
                    goal: fresh.value.rewardGoal!,
                    balance: fresh.value.pointsBalance,
                    onTap: onOpenRewards,
                  ),
                ],
                if (fresh.value.goals.isNotEmpty) ...[
                  KidSectionTitle(context.l10n.kidMyGoals),
                  for (final g in fresh.value.goals) _LearningGoalRow(goal: g),
                ],
                KidSectionTitle(context.l10n.kidActivitiesTitle),
                const KidActivitiesSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.day,
    required this.name,
    this.avatarKey,
    this.avatarColor,
    this.seed,
  });

  final MyDay day;
  final String name;
  final String? avatarKey;
  final String? avatarColor;
  final String? seed;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final greeting = switch (day.greeting) {
      'afternoon' => l.kidGreetingAfternoon(name),
      'evening' => l.kidGreetingEvening(name),
      _ => l.kidGreetingMorning(name),
    };
    final avatar = ChildAvatar(
      name: name,
      avatarKey: avatarKey,
      colorHex: avatarColor,
      seed: seed,
      size: 60,
    );
    final title = Semantics(
      header: true,
      child: Text(greeting, style: context.type.headlineSmall),
    );
    final points = PointsPill(points: day.pointsBalance, large: true);
    final help = _HelpButton();

    // With large text the greeting gets its own full-width line.
    if (MediaQuery.textScalerOf(context).scale(1) > 1.3) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [avatar, const Spacer(), help]),
          const SizedBox(height: AppSpacing.md),
          title,
          const SizedBox(height: AppSpacing.sm),
          points,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            avatar,
            const SizedBox(width: AppSpacing.md),
            Expanded(child: title),
            const SizedBox(width: AppSpacing.sm),
            help,
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        points,
      ],
    );
  }
}

class _NextStepCard extends ConsumerWidget {
  const _NextStepCard({required this.day});

  final MyDay day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.mamily;
    final next = day.nextItem;

    if (next == null) {
      final allDone = day.timeline.isNotEmpty;
      return KidCard(
        color: allDone ? c.success.background : c.surfaceMuted,
        child: Row(
          children: [
            IconTile(
              icon: allDone
                  ? Icons.emoji_events_rounded
                  : Icons.wb_sunny_rounded,
              size: 56,
              fill: c.surface,
              color: allDone ? c.success.foreground : c.brand.foreground,
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Text(
                allDone ? l.kidAllDone : l.kidNothingToday,
                style: context.type.titleMedium,
              ),
            ),
          ],
        ),
      );
    }

    final routine = next.routine;
    final task = next.task;
    final icon = routine != null
        ? routineIcon(routine.kind)
        : taskIcon(task?.iconKey ?? task?.category);
    final subtitle = routine != null
        ? l.kidRoutineStepsLeft(routine.steps.length - routine.doneCount)
        : task != null && task.points > 0
        ? l.kidPoints(task.points)
        : null;
    final label = routine != null
        ? (next.state == 'in_progress'
              ? l.kidContinueRoutine
              : l.kidStartRoutine)
        : (next.state == 'rejected' ? l.kidTryAgain : l.kidIDidIt);

    void open() {
      if (routine != null) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => RoutineRunScreen(routineId: routine.id),
          ),
        );
      } else if (task != null && task.canSubmit) {
        submitKidTask(context, ref, task);
      } else if (task != null) {
        showKidTaskSheet(context, task);
      }
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadii.xlAll,
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [c.warning.background, c.brand.background],
        ),
        border: Border.all(color: c.warning.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.kidNextStep,
            style: context.type.labelLarge?.copyWith(color: c.brand.foreground),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              IconTile(icon: icon, size: 64, fill: c.surface),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(next.title, style: context.type.headlineSmall),
                    if (subtitle != null || next.time != null)
                      Text(
                        [?next.time, ?subtitle].join(' · '),
                        style: context.type.bodyLarge?.copyWith(color: c.ink2),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (routine != null && routine.doneCount > 0) ...[
            const SizedBox(height: AppSpacing.md),
            ProgressBar(
              value: routine.progress,
              color: c.success.foreground,
              semanticsLabel: routine.title,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: open,
              icon: Icon(
                routine != null
                    ? Icons.play_arrow_rounded
                    : Icons.check_rounded,
              ),
              label: Text(label),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.item});

  final TimelineItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.mamily;
    final l = context.l10n;
    final routine = item.routine;
    final task = item.task;
    final event = item.event;
    final icon = routine != null
        ? routineIcon(routine.kind)
        : event != null
        ? Icons.event_rounded
        : taskIcon(task?.iconKey ?? task?.category);

    VoidCallback? onTap;
    if (routine != null) {
      onTap = () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RoutineRunScreen(routineId: routine.id),
        ),
      );
    } else if (task != null) {
      onTap = () => showKidTaskSheet(context, task);
    }

    return KidCard(
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              item.time ?? '—',
              style: context.type.labelLarge?.copyWith(color: c.ink2),
              textAlign: TextAlign.center,
            ),
          ),
          IconTile(icon: icon, size: 48),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: context.type.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                if (routine != null && routine.steps.isNotEmpty) ...[
                  ProgressBar(
                    value: routine.progress,
                    height: 8,
                    color: c.success.foreground,
                    semanticsLabel: item.title,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    KidStateBadge(state: item.state),
                    if (task != null && task.points > 0)
                      Text(
                        l.kidPointsValue(task.points),
                        style: context.type.labelLarge?.copyWith(
                          color: c.warning.foreground,
                        ),
                      ),
                    if (event?['location'] case final String loc
                        when loc.isNotEmpty)
                      Text(
                        loc,
                        style: context.type.bodySmall?.copyWith(color: c.ink2),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (onTap != null) Icon(Icons.chevron_right_rounded, color: c.ink3),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.balance, this.onTap});

  final RewardGoal goal;
  final int balance;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mamily;
    final l = context.l10n;
    return KidCard(
      onTap: onTap,
      child: Row(
        children: [
          ProgressRing(
            value: goal.progress,
            size: 72,
            color: c.warning.foreground,
            semanticsLabel: goal.title,
            center: Icon(
              Icons.card_giftcard_rounded,
              size: 30,
              color: c.warning.foreground,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(goal.title, style: context.type.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l.kidPointsToGo(goal.pointsNeeded),
                  style: context.type.bodyLarge?.copyWith(
                    color: goal.pointsNeeded == 0
                        ? c.success.foreground
                        : c.ink2,
                  ),
                ),
                Text(
                  l.kidPointsOf(balance, goal.pointsCost),
                  style: context.type.bodySmall?.copyWith(color: c.ink2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodPrompt extends StatelessWidget {
  const _MoodPrompt();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return KidCard(
      color: context.mamily.info.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.kidHowFeel, style: context.type.titleMedium),
          const SizedBox(height: AppSpacing.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final m in moods)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: AppSpacing.sm,
                    ),
                    child: Semantics(
                      button: true,
                      label: moodLabel(l, m),
                      excludeSemantics: true,
                      child: InkWell(
                        borderRadius: AppRadii.largeAll,
                        onTap: () => showMoodSheet(context, initialMood: m),
                        child: Container(
                          width: 76,
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: context.mamily.surface,
                            borderRadius: AppRadii.largeAll,
                          ),
                          child: Column(
                            children: [
                              Icon(
                                moodIcon(m),
                                size: 32,
                                color: context.mamily.info.foreground,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                moodLabel(l, m),
                                style: context.type.labelMedium,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends ConsumerWidget {
  const _MessageCard({required this.e, this.onOpen});

  final Encouragement e;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mamily;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: KidCard(
        color: c.sleep.background,
        onTap: () {
          ref.read(kidActionsProvider).markSeen(e.id);
          onOpen?.call();
        },
        child: Row(
          children: [
            IconTile(
              icon: badgeIcon(e.badgeKey),
              size: 52,
              fill: c.surface,
              color: c.sleep.foreground,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (e.senderName != null)
                    Text(
                      e.senderName!,
                      style: context.type.labelLarge?.copyWith(
                        color: c.sleep.foreground,
                      ),
                    ),
                  Text(e.message, style: context.type.bodyLarge),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LearningGoalRow extends StatelessWidget {
  const _LearningGoalRow({required this.goal});

  final Map<String, dynamic> goal;

  @override
  Widget build(BuildContext context) {
    final progress = (goal['progress'] as num?)?.toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: KidCard(
        child: Row(
          children: [
            const IconTile(icon: Icons.flag_rounded, size: 44),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal['title'] as String? ?? '',
                    style: context.type.titleSmall,
                  ),
                  if (progress != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    ProgressBar(
                      value: progress,
                      height: 8,
                      semanticsLabel: goal['title'] as String?,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Labelled "Help" button in the Today header. Opens the help page; sending
/// an alert there needs a deliberate press-and-hold.
class _HelpButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.mamily;
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: c.danger.background,
        foregroundColor: c.danger.foreground,
        side: BorderSide(color: c.danger.border),
        minimumSize: const Size(0, 52),
      ),
      onPressed: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const KidHelpScreen())),
      icon: const Icon(Icons.sos_rounded),
      label: Text(context.l10n.kidHelp),
    );
  }
}

/// What screen-time situation the child is in, said calmly, with the one
/// thing they can do about it. Never claims enforcement this phone hasn't
/// confirmed: without it, the limit is described as the family's plan.
class _ScreenTimeStatus extends ConsumerWidget {
  const _ScreenTimeStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.mamily;
    final st = ref.watch(kidScreenTimeProvider).valueOrNull?.value;
    if (st == null) return const SizedBox.shrink();

    String hhmm(DateTime t) =>
        MaterialLocalizations.of(context).formatTimeOfDay(
          TimeOfDay.fromDateTime(t),
          alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
        );

    final pending = st.pending;
    final String? headline;
    final IconData icon;
    var tone = c.info;
    var paused = false;
    if (st.restrictionKind == 'restrict_now') {
      paused = true;
      headline = st.restrictionUntil == null
          ? l.kidPausedNow
          : l.kidPausedUntil(hhmm(st.restrictionUntil!));
      icon = Icons.pause_circle_rounded;
    } else if (st.restrictionKind == 'schedule' &&
        st.restrictionUntil != null) {
      paused = true;
      headline = l.kidPausedNamed(
        st.restrictionName ?? '',
        hhmm(st.restrictionUntil!),
      );
      icon = Icons.bedtime_rounded;
    } else if (st.remainingMinutes != null && st.limitMinutes != null) {
      final left = st.remainingMinutes!;
      headline = left > 0 ? l.kidTimeLeft(left) : l.kidTimeUsedUp;
      icon = Icons.timer_rounded;
      if (left == 0) tone = c.warning;
    } else if (st.limitMinutes != null) {
      headline = l.kidTimeAgreement(st.limitMinutes!);
      icon = Icons.timer_rounded;
    } else {
      headline = null;
      icon = Icons.timer_rounded;
    }
    if (headline == null && pending == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: KidCard(
        color: paused ? c.sleep.background : tone.background,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (headline != null)
              Row(
                children: [
                  Icon(
                    icon,
                    size: 32,
                    color: paused ? c.sleep.foreground : tone.foreground,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(headline, style: context.type.titleMedium),
                  ),
                ],
              ),
            if (paused) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(l.kidPausedStillOk, style: context.type.bodyMedium),
            ],
            const SizedBox(height: AppSpacing.md),
            if (pending != null)
              Row(
                children: [
                  Icon(Icons.hourglass_top_rounded, color: c.ink2),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${l.kidWaitingParent} ${l.kidMinutes(pending.minutes)}',
                      style: context.type.bodyLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref
                        .read(kidActionsProvider)
                        .cancelScreenTime(pending.id),
                    child: Text(l.kidWithdraw),
                  ),
                ],
              )
            else
              OutlinedButton.icon(
                onPressed: () => askForMoreTime(context, ref),
                icon: const Icon(Icons.more_time_rounded),
                label: Text(l.kidAskMoreTime),
              ),
          ],
        ),
      ),
    );
  }
}
