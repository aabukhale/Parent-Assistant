import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system.dart';
import '../../../core/localization/l10n.dart';
import '../application/kid_providers.dart';
import 'kid_feedback.dart';
import 'kid_widgets.dart';

/// "How are you feeling?" — pick a mood, optionally add a short note. This is
/// a message to the family, not an assessment.
Future<void> showMoodSheet(BuildContext context, {String? initialMood}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _MoodSheet(initialMood: initialMood),
  );
}

class _MoodSheet extends ConsumerStatefulWidget {
  const _MoodSheet({this.initialMood});

  final String? initialMood;

  @override
  ConsumerState<_MoodSheet> createState() => _MoodSheetState();
}

class _MoodSheetState extends ConsumerState<_MoodSheet> {
  late String? _mood = widget.initialMood;
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    final mood = _mood;
    if (mood == null) return;
    setState(() => _busy = true);
    try {
      final note = _note.text.trim();
      await ref
          .read(kidActionsProvider)
          .checkIn(mood, note: note.isEmpty ? null : note);
      if (!mounted) return;
      final l = context.l10n;
      Navigator.of(context).pop();
      showResultSnack(context, l.kidFeelThanks);
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
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.kidHowFeel,
                style: context.type.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              MoodPicker(
                selected: _mood,
                onSelected: (m) => setState(() => _mood = m),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _note,
                maxLength: 140,
                maxLines: 2,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(labelText: l.kidFeelNote),
              ),
              Text(
                l.kidFeelPrivacy,
                style: context.type.bodySmall?.copyWith(color: c.ink2),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _mood == null || _busy ? null : _share,
                child: Text(l.kidFeelShare),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row/wrap of large mood buttons (emoji + word, selectable).
class MoodPicker extends StatelessWidget {
  const MoodPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.mamily;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final m in moods)
          Semantics(
            button: true,
            selected: selected == m,
            label: moodLabel(l, m),
            excludeSemantics: true,
            child: InkWell(
              borderRadius: AppRadii.largeAll,
              onTap: () => onSelected(m),
              child: AnimatedContainer(
                duration: AppMotion.resolve(context, AppMotion.fast),
                width: 84,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  color: selected == m ? c.accent.background : c.surfaceMuted,
                  borderRadius: AppRadii.largeAll,
                  border: Border.all(
                    color: selected == m
                        ? c.accent.foreground
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(moodIcon(m), size: 34, color: c.accent.foreground),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      moodLabel(l, m),
                      style: context.type.labelMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
