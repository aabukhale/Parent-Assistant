import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../kid/presentation/kid_widgets.dart';
import '../application/hub_actions.dart';

/// Send a short praise message (optionally with a badge, optionally linked to
/// a real accomplishment such as an approved task).
Future<void> showPraiseSheet(
  BuildContext context, {
  required String childId,
  required String childName,
  String? subjectType,
  String? subjectId,
  String? subjectTitle,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PraiseSheet(
      childId: childId,
      childName: childName,
      subjectType: subjectType,
      subjectId: subjectId,
      subjectTitle: subjectTitle,
    ),
  );
}

class _PraiseSheet extends ConsumerStatefulWidget {
  const _PraiseSheet({
    required this.childId,
    required this.childName,
    this.subjectType,
    this.subjectId,
    this.subjectTitle,
  });

  final String childId;
  final String childName;
  final String? subjectType;
  final String? subjectId;
  final String? subjectTitle;

  @override
  ConsumerState<_PraiseSheet> createState() => _PraiseSheetState();
}

class _PraiseSheetState extends ConsumerState<_PraiseSheet> {
  final _message = TextEditingController();
  String? _badge = 'star';
  bool _busy = false;

  static const _badges = [
    'star',
    'heart',
    'rocket',
    'trophy',
    'rainbow',
    'sun',
    'muscle',
    'brain',
    'kindness',
    'helper',
  ];

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(hubActionsProvider)
          .sendPraise(
            widget.childId,
            message: text,
            badgeKey: _badge,
            subjectType: widget.subjectType,
            subjectId: widget.subjectId,
          );
      if (!mounted) return;
      final l = context.l10n;
      Navigator.of(context).pop();
      showResultSnack(context, l.praiseSent);
    } on ApiException catch (e) {
      if (mounted) showResultSnack(context, e.localizedMessage(context.l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.mamily;
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.praiseTitle(widget.childName),
                style: context.type.titleLarge,
              ),
              if (widget.subjectTitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${l.praiseFor}: ${widget.subjectTitle}',
                  style: context.type.bodyMedium?.copyWith(color: c.ink2),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final s in [
                    l.praiseSuggestion1,
                    l.praiseSuggestion2,
                    l.praiseSuggestion3,
                  ])
                    ActionChip(
                      label: Text(s),
                      onPressed: () => setState(() => _message.text = s),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _message,
                maxLength: 200,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: l.praiseMessage),
              ),
              Text(l.praiseBadge, style: context.type.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final b in _badges)
                    Semantics(
                      button: true,
                      selected: _badge == b,
                      label: b,
                      child: InkWell(
                        borderRadius: AppRadii.mediumAll,
                        onTap: () =>
                            setState(() => _badge = _badge == b ? null : b),
                        child: Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _badge == b
                                ? c.sleep.background
                                : c.surfaceMuted,
                            borderRadius: AppRadii.mediumAll,
                            border: Border.all(
                              color: _badge == b
                                  ? c.sleep.foreground
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            badgeEmoji(b),
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: _busy || _message.text.trim().isEmpty ? null : _send,
                icon: const Icon(Icons.send_rounded),
                label: Text(l.commonSend),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
