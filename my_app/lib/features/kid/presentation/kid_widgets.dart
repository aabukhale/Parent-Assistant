import 'package:flutter/material.dart';

import '../../../core/design_system.dart';
import '../../../core/localization/l10n.dart';

/// Icon for task/step icon keys and categories. Unknown keys fall back to a
/// star. Always shown with a text label (title or [iconLabel]) — children are
/// never asked to guess what a symbol means.
IconData taskIcon(String? key) => switch (key) {
  'bed' => Icons.bed_rounded,
  'tooth' || 'teeth' => Icons.brush_rounded,
  'shirt' || 'clothes' => Icons.checkroom_rounded,
  'breakfast' || 'food' || 'meal' => Icons.breakfast_dining_rounded,
  'snack' => Icons.cookie_rounded,
  'backpack' || 'school' => Icons.backpack_rounded,
  'hands' => Icons.wash_rounded,
  'book' || 'reading' || 'homework' => Icons.menu_book_rounded,
  'ball' || 'sport' || 'play' => Icons.sports_soccer_rounded,
  'toys' || 'tidy' => Icons.toys_rounded,
  'bath' => Icons.bathtub_rounded,
  'pajamas' => Icons.nightlight_round,
  'music' => Icons.music_note_rounded,
  'art' => Icons.palette_rounded,
  'pet' => Icons.pets_rounded,
  'plant' || 'garden' => Icons.local_florist_rounded,
  'kitchen' || 'chores' => Icons.dinner_dining_rounded,
  'water' => Icons.water_drop_rounded,
  'kindness' || 'heart' => Icons.favorite_rounded,
  _ => Icons.star_rounded,
};

/// Icon for a routine kind.
IconData routineIcon(String? kind) => switch (kind) {
  'morning' => Icons.wb_sunny_rounded,
  'after_school' => Icons.backpack_rounded,
  'bedtime' => Icons.bedtime_rounded,
  _ => Icons.checklist_rounded,
};

/// One key per icon in [taskIcon], in picker order.
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
                  child: IconTile(
                    icon: taskIcon(key),
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

IconData moodIcon(String mood) => switch (mood) {
  'great' => Icons.sentiment_very_satisfied_rounded,
  'happy' => Icons.sentiment_satisfied_alt_rounded,
  'okay' => Icons.sentiment_neutral_rounded,
  'tired' => Icons.bedtime_rounded,
  'sad' => Icons.sentiment_dissatisfied_rounded,
  'worried' => Icons.mood_bad_rounded,
  'angry' => Icons.sentiment_very_dissatisfied_rounded,
  _ => Icons.sentiment_neutral_rounded,
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

IconData badgeIcon(String? badge) => switch (badge) {
  'star' => Icons.star_rounded,
  'heart' => Icons.favorite_rounded,
  'rocket' => Icons.rocket_launch_rounded,
  'trophy' => Icons.emoji_events_rounded,
  'rainbow' => Icons.looks_rounded,
  'sun' => Icons.wb_sunny_rounded,
  'muscle' => Icons.fitness_center_rounded,
  'brain' => Icons.psychology_rounded,
  'kindness' => Icons.volunteer_activism_rounded,
  'helper' => Icons.handshake_rounded,
  _ => Icons.mail_rounded,
};

/// Icon for a parent's reply sticker on a check-in.
IconData stickerIcon(String key) => switch (key) {
  'hug' => Icons.volunteer_activism_rounded,
  'heart' => Icons.favorite_rounded,
  'high_five' => Icons.front_hand_rounded,
  'proud' => Icons.emoji_events_rounded,
  'thinking_of_you' => Icons.cloud_rounded,
  'lets_talk' => Icons.chat_rounded,
  _ => Icons.mail_rounded,
};

/// Coloured points chip (star icon + number; announced as "120 points").
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
            Icon(
              Icons.star_rounded,
              size: large ? 22 : 18,
              color: c.warning.foreground,
            ),
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

/// An icon in a soft rounded square (task / step / section visual). Pair it
/// with visible text; pass [semanticLabel] only when it stands alone.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.size = 48,
    this.fill,
    this.color,
    this.semanticLabel,
  });

  final IconData icon;
  final double size;
  final Color? fill;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill ?? context.mamily.surfaceMuted,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(
        icon,
        size: size * 0.55,
        color: color ?? context.mamily.brand.foreground,
      ),
    );
    return semanticLabel == null
        ? ExcludeSemantics(child: tile)
        : Semantics(label: semanticLabel, image: true, child: tile);
  }
}
