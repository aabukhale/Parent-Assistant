import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system.dart';
import '../../../core/localization/l10n.dart';
import '../application/kid_providers.dart';
import '../data/kid_models.dart';
import 'kid_feedback.dart';
import 'kid_widgets.dart';

/// Bottom sheet for one task: what it is, where it stands, and the single
/// action the child can take ("I did it!"). Approval is always a parent's.
Future<void> showKidTaskSheet(BuildContext context, KidTaskSummary task) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _KidTaskSheet(task: task),
  );
}

/// Asks "Did you finish …?", sends the completion for a parent to check and
/// celebrates. Returns true when it was sent. Shared by the task sheet and the
/// "I did it!" button on My Day, so finishing a task is one confirm away.
Future<bool> submitKidTask(
  BuildContext context,
  WidgetRef ref,
  KidTaskSummary task, {
  ValueChanged<bool>? onBusy,
}) async {
  final l = context.l10n;
  final ok = await confirmAction(
    context,
    title: l.kidConfirmDoneTitle(task.title),
    body: l.kidConfirmDoneBody,
    confirmLabel: l.kidYesDone,
    cancelLabel: l.kidNotYet,
  );
  if (!ok || !context.mounted) return false;
  onBusy?.call(true);
  try {
    await ref.read(kidActionsProvider).completeTask(task.id);
    if (!context.mounted) return true;
    Celebration.show(
      context,
      message: '${l.kidTaskSentTitle} ${l.kidTaskSent}',
      icon: Icons.celebration_rounded,
    );
    return true;
  } catch (e) {
    if (context.mounted) showKidError(context, e);
    return false;
  } finally {
    onBusy?.call(false);
  }
}

class _KidTaskSheet extends ConsumerStatefulWidget {
  const _KidTaskSheet({required this.task});

  final KidTaskSummary task;

  @override
  ConsumerState<_KidTaskSheet> createState() => _KidTaskSheetState();
}

class _KidTaskSheetState extends ConsumerState<_KidTaskSheet> {
  bool _busy = false;

  Future<void> _submit() async {
    final done = await submitKidTask(
      context,
      ref,
      widget.task,
      onBusy: (busy) {
        if (mounted) setState(() => _busy = busy);
      },
    );
    if (done && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.mamily;
    final t = widget.task;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconTile(icon: taskIcon(t.iconKey ?? t.category), size: 64),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.title, style: context.type.titleLarge),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          if (t.points > 0) PointsPill(points: t.points),
                          KidStateBadge(state: t.state),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if ((t.description ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                t.description!,
                style: context.type.bodyLarge?.copyWith(color: c.ink2),
              ),
            ],
            if (t.state == 'rejected' && (t.reviewNote ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              NoticeBanner(
                tone: AppTone.warning,
                message: l.kidParentNote(t.reviewNote!),
              ),
            ],
            if (t.state == 'pending') ...[
              const SizedBox(height: AppSpacing.lg),
              NoticeBanner(tone: AppTone.info, message: l.explainTaskPending),
            ],
            const SizedBox(height: AppSpacing.xxl),
            if (t.canSubmit)
              FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  t.state == 'rejected' ? l.kidTryAgain : l.kidIDidIt,
                ),
              )
            else
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l.commonClose),
              ),
          ],
        ),
      ),
    );
  }
}
