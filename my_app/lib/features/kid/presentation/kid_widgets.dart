import 'package:flutter/material.dart';

import '../../../core/design_system.dart';
import '../../../core/localization/l10n.dart';

/// Emoji for task/step icon keys and categories. Unknown keys fall back to a star.
String iconEmoji(String? key) => switch (key) {
  'bed' => '🛏️',
  'tooth' || 'teeth' => '🪥',
  'shirt' || 'clothes' => '👕',
  'breakfast' || 'food' || 'meal' => '🥣',
  'snack' => '🍎',
  'backpack' || 'school' => '🎒',
  'hands' => '🧼',
  'book' || 'reading' || 'homework' => '📚',
  'ball' || 'sport' || 'play' => '⚽',
  'toys' || 'tidy' => '🧸',
  'bath' => '🛁',
  'pajamas' => '🌙',
  'music' => '🎵',
  'art' => '🎨',
  'pet' => '🐾',
  'plant' || 'garden' => '🪴',
  'kitchen' || 'chores' => '🍽️',
  'water' => '💧',
  'kindness' || 'heart' => '💛',
  _ => '⭐',
};

/// One key per icon in [iconEmoji], in picker order.
const pickableIconKeys = [
  'bed',
  'tooth',
  'shirt',
  'breakfast',
  'snack',
  'backpack',
  'hands',
  'book',
  'ball',
  'toys',
  'bath',
  'pajamas',
  'music',
  'art',
  'pet',
  'plant',
  'kitchen',
  'water',
  'kindness',
];

/// Spoken name of a [pickableIconKeys] icon, in the UI language.
String iconLabel(AppLocalizations l, String key) => switch (key) {
  'bed' => l.iconBed,
  'tooth' => l.iconTooth,
  'shirt' => l.iconShirt,
  'breakfast' => l.iconBreakfast,
  'snack' => l.iconSnack,
  'backpack' => l.iconBackpack,
  'hands' => l.iconHands,
  'book' => l.iconBook,
  'ball' => l.iconBall,
  'toys' => l.iconToys,
  'bath' => l.iconBath,
  'pajamas' => l.iconPajamas,
  'music' => l.iconMusic,
  'art' => l.iconArt,
  'pet' => l.iconPet,
  'plant' => l.iconPlant,
  'kitchen' => l.iconKitchen,
  'water' => l.iconWater,
  'kindness' => l.iconKindness,
  _ => key,
};

/// Bottom sheet to choose a task or routine-step icon. Returns the key, or
/// null if dismissed.
Future<String?> pickIconKey(BuildContext context, {String? current}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final key in pickableIconKeys)
              Semantics(
                button: true,
                selected: key == current,
                label: iconLabel(sheetContext.l10n, key),
                child: InkWell(
                  borderRadius: AppRadii.mediumAll,
                  onTap: () => Navigator.of(sheetContext).pop(key),
                  child: EmojiTile(
                    emoji: iconEmoji(key),
                    size: 52,
                    fill: key == current
                        ? sheetContext.mamily.accent.background
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

String moodEmoji(String mood) => switch (mood) {
  'great' => '🤩',
  'happy' => '😊',
  'okay' => '🙂',
  'tired' => '🥱',
  'sad' => '😢',
  'worried' => '😟',
  'angry' => '😠',
  _ => '🙂',
};

String moodLabel(AppLocalizations l, String mood) => switch (mood) {
  'great' => l.moodGreat,
  'happy' => l.moodHappy,
  'okay' => l.moodOkay,
  'tired' => l.moodTired,
  'sad' => l.moodSad,
  'worried' => l.moodWorried,
  'angry' => l.moodAngry,
  _ => mood,
};

const moods = ['great', 'happy', 'okay', 'tired', 'sad', 'worried', 'angry'];

String badgeEmoji(String? badge) => switch (badge) {
  'star' => '⭐',
  'heart' => '💖',
  'rocket' => '🚀',
  'trophy' => '🏆',
  'rainbow' => '🌈',
  'sun' => '☀️',
  'muscle' => '💪',
  'brain' => '🧠',
  'kindness' => '🤝',
  'helper' => '🦸',
  _ => '💌',
};

/// Coloured points chip ("⭐ 120").
class PointsPill extends StatelessWidget {
  const PointsPill({super.key, required this.points, this.large = false});

  final int points;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = context.mamily;
    return Semantics(
      label: context.l10n.kidPoints(points),
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: large ? AppSpacing.lg : AppSpacing.md,
          vertical: large ? AppSpacing.sm : AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: c.warning.background,
          borderRadius: AppRadii.pillAll,
          border: Border.all(color: c.warning.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('⭐', style: TextStyle(fontSize: large ? 20 : 16)),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '$points',
              style:
                  (large ? context.type.titleMedium : context.type.labelLarge)
                      ?.copyWith(
                        color: c.warning.foreground,
                        fontWeight: FontWeight.w700,
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A task/routine state as icon + word (never colour alone).
class KidStateBadge extends StatelessWidget {
  const KidStateBadge({super.key, required this.state});

  final String state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (label, tone, icon) = switch (state) {
      'pending' || 'pending_review' => (
        l.kidStatePending,
        AppTone.info,
        Icons.hourglass_top_rounded,
      ),
      'approved' || 'done' || 'completed' => (
        l.kidStateApproved,
        AppTone.success,
        Icons.check_circle_rounded,
      ),
      'rejected' => (l.kidStateRejected, AppTone.warning, Icons.replay_rounded),
      'in_progress' => (
        l.kidStateInProgress,
        AppTone.accent,
        Icons.directions_run_rounded,
      ),
      'upcoming' => (
        l.kidStateUpcoming,
        AppTone.neutral,
        Icons.schedule_rounded,
      ),
      'past' => (l.kidStatePast, AppTone.neutral, Icons.history_rounded),
      _ => (
        l.kidStateTodo,
        AppTone.brand,
        Icons.radio_button_unchecked_rounded,
      ),
    };
    return StatusPill(label: label, tone: tone, icon: icon);
  }
}

/// Big, rounded kid card.
class KidCard extends StatelessWidget {
  const KidCard({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.padding,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    color: color,
    semanticLabel: semanticLabel,
    borderRadius: AppRadii.xlAll,
    padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
    child: child,
  );
}

/// Section title used across child screens.
class KidSectionTitle extends StatelessWidget {
  const KidSectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.xs,
      AppSpacing.xl,
      AppSpacing.xs,
      AppSpacing.sm,
    ),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(text, style: context.type.titleMedium),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Emoji in a soft rounded square (task / step icon).
class EmojiTile extends StatelessWidget {
  const EmojiTile({super.key, required this.emoji, this.size = 48, this.fill});

  final String emoji;
  final double size;
  final Color? fill;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill ?? context.mamily.surfaceMuted,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text(
        emoji,
        style: TextStyle(fontSize: size * 0.5),
        textScaler: TextScaler.noScaling,
      ),
    ),
  );
}
