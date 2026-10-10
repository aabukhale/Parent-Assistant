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

class _KidTaskSheet extends ConsumerStatefulWidget {
  const _KidTaskSheet({required this.task});

  final KidTaskSummary task;

  @override
  ConsumerState<_KidTaskSheet> createState() => _KidTaskSheetState();
}

class _KidTaskSheetState extends ConsumerState<_KidTaskSheet> {
  bool _busy = false;

  Future<void> _submit() async {
    final l = context.l10n;
    final ok = await confirmAction(
      context,
      title: l.kidConfirmDoneTitle(widget.task.title),
      body: l.kidConfirmDoneBody,
      confirmLabel: l.kidYesDone,
      cancelLabel: l.kidNotYet,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(kidActionsProvider).completeTask(widget.task.id);
      if (!mounted) return;
      Celebration.show(
        context,
        message: '${l.kidTaskSentTitle} ${l.kidTaskSent}',
        emoji: '🙌',
      );
      Navigator.of(context).pop();
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
                EmojiTile(emoji: iconEmoji(t.iconKey ?? t.category), size: 64),
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
