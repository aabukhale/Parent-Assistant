import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system.dart';
import '../../../core/localization/l10n.dart';
import '../../surfaces/live_activity.dart';
import '../application/kid_providers.dart';
import '../data/kid_models.dart';
import 'kid_feedback.dart';
import 'kid_widgets.dart';

/// Full-screen routine checklist: big steps, clear progress, gentle cheers,
/// and a celebration when the last step is done.
class RoutineRunScreen extends ConsumerStatefulWidget {
  const RoutineRunScreen({super.key, required this.routineId});

  final String routineId;

  @override
  ConsumerState<RoutineRunScreen> createState() => _RoutineRunScreenState();
}

class _RoutineRunScreenState extends ConsumerState<RoutineRunScreen> {
  Routine? _local;
  final Set<String> _busySteps = {};

  Future<void> _toggle(Routine routine, RoutineStep step) async {
    if (_busySteps.contains(step.id)) return;
    final l = context.l10n;
    setState(() => _busySteps.add(step.id));
    HapticFeedback.selectionClick();
    try {
      final actions = ref.read(kidActionsProvider);
      final updated = step.checked
          ? await actions.uncheckStep(routine.id, step.id)
          : await actions.checkStep(routine.id, step.id);
      if (!mounted) return;
      setState(() => _local = updated);
      await RoutineLiveActivity.update(updated);
      if (!mounted) return;
      final run = updated.todayRun;
      if (run != null && run.isFinished && !step.checked) {
        HapticFeedback.mediumImpact();
        Celebration.show(context, message: l.kidRoutineDone, emoji: '🏆');
        await RoutineLiveActivity.end(updated);
      }
    } catch (e) {
      if (mounted) showKidError(context, e);
    } finally {
      if (mounted) setState(() => _busySteps.remove(step.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(kidRoutineProvider(widget.routineId));
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: AppContentFrame(
          child: async.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorRetryView(
              error: e,
              onRetry: () async =>
                  ref.invalidate(kidRoutineProvider(widget.routineId)),
            ),
            data: (fetched) => _body(_local ?? fetched),
          ),
        ),
      ),
    );
  }

  Widget _body(Routine r) {
    final l = context.l10n;
    final c = context.mamily;
    final done = r.doneCount;
    final total = r.steps.length;
    final left = total - done;
    final run = r.todayRun;
    final finished = run?.isFinished ?? false;
    final cheer = switch (done) {
      0 => null,
      _ when left == 0 => l.kidRoutineDone,
      _ when left == 1 => l.kidRoutineCheer3,
      1 => l.kidRoutineCheer1,
      _ => l.kidRoutineCheer2,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xxxl,
      ),
      children: [
        Row(
          children: [
            ProgressRing(
              value: total == 0 ? 0 : done / total,
              size: 88,
              stroke: 10,
              color: c.success.foreground,
              semanticsLabel: r.title,
              center: Text('$done/$total', style: context.type.titleMedium),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.title, style: context.type.headlineSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l.kidRoutineStepsLeft(left),
                    style: context.type.bodyLarge?.copyWith(color: c.ink2),
                  ),
                  if (cheer != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        cheer,
                        style: context.type.titleSmall?.copyWith(
                          color: c.success.foreground,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (finished && run?.status == 'pending_review') ...[
          const SizedBox(height: AppSpacing.lg),
          NoticeBanner(tone: AppTone.info, message: l.kidRoutineBonusPending),
        ] else if (finished) ...[
          const SizedBox(height: AppSpacing.lg),
          NoticeBanner(
            tone: AppTone.success,
            message: l.kidRoutineFinishedToday,
          ),
        ],
        if (r.scheduledToday == false) ...[
          const SizedBox(height: AppSpacing.lg),
          NoticeBanner(tone: AppTone.neutral, message: l.kidRoutineNotToday),
        ],
        const SizedBox(height: AppSpacing.xl),
        for (final step in r.steps) ...[
          _StepTile(
            step: step,
            busy: _busySteps.contains(step.id),
            locked: finished,
            onTap: () => _toggle(r, step),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.step,
    required this.busy,
    required this.locked,
    required this.onTap,
  });

  final RoutineStep step;
  final bool busy;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mamily;
    final l = context.l10n;
    return Semantics(
      button: !locked,
      checked: step.checked,
      label: step.title,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppMotion.resolve(context, AppMotion.normal),
        decoration: BoxDecoration(
          color: step.checked ? c.success.background : c.surface,
          borderRadius: AppRadii.xlAll,
          border: Border.all(
            color: step.checked ? c.success.border : c.border,
            width: 1.5,
          ),
        ),
        child: InkWell(
          borderRadius: AppRadii.xlAll,
          onTap: locked || busy ? null : onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 76),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  EmojiTile(
                    emoji: iconEmoji(step.iconKey),
                    size: 52,
                    fill: step.checked ? c.surface : null,
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.title,
                          style: context.type.titleMedium?.copyWith(
                            decoration: step.checked
                                ? TextDecoration.lineThrough
                                : null,
                            color: step.checked ? c.ink2 : c.ink,
                          ),
                        ),
                        if (step.durationMinutes != null)
                          Text(
                            l.kidMinutes(step.durationMinutes!),
                            style: context.type.bodySmall?.copyWith(
                              color: c.ink2,
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox.square(
                    dimension: 44,
                    child: busy
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : AnimatedSwitcher(
                            duration: AppMotion.resolve(
                              context,
                              AppMotion.fast,
                            ),
                            child: Icon(
                              step.checked
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              key: ValueKey(step.checked),
                              size: 40,
                              color: step.checked
                                  ? c.success.foreground
                                  : c.borderStrong,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
