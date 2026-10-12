import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/l10n.dart';
import '../../../core/design_system.dart';
import '../data/models/learning_goal.dart';

String goalStatusLabel(AppLocalizations l, LearningGoalStatus s) => switch (s) {
  LearningGoalStatus.active => l.lgStatusActive,
  LearningGoalStatus.paused => l.lgStatusPaused,
  LearningGoalStatus.achieved => l.lgStatusAchieved,
  LearningGoalStatus.archived => l.lgStatusArchived,
};

String goalMetricLabel(AppLocalizations l, LearningGoalMetric m) => switch (m) {
  LearningGoalMetric.boolean => l.lgMetricBoolean,
  LearningGoalMetric.numeric => l.lgMetricNumeric,
  LearningGoalMetric.percent => l.lgMetricPercent,
};

AppTone goalStatusTone(LearningGoalStatus s) => switch (s) {
  LearningGoalStatus.active => AppTone.accent,
  LearningGoalStatus.paused => AppTone.warning,
  LearningGoalStatus.achieved => AppTone.success,
  LearningGoalStatus.archived => AppTone.neutral,
};

IconData goalStatusIcon(LearningGoalStatus s) => switch (s) {
  LearningGoalStatus.active => Icons.play_circle_outline_rounded,
  LearningGoalStatus.paused => Icons.pause_circle_outline_rounded,
  LearningGoalStatus.achieved => Icons.emoji_events_outlined,
  LearningGoalStatus.archived => Icons.archive_outlined,
};

/// `12` for whole numbers, `12.5` otherwise — matches the backend `decimal:2`
/// without trailing zeros.
String formatGoalNumber(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String formatGoalDate(BuildContext context, DateTime date) => DateFormat.yMMMd(
  Localizations.localeOf(context).toLanguageTag(),
).format(date);

/// The human "current standing" line, entirely from backend values.
String goalStandingText(AppLocalizations l, LearningGoal goal) {
  switch (goal.metric) {
    case LearningGoalMetric.boolean:
      return goal.isBooleanDone ? l.lgDone : l.lgNotDone;
    case LearningGoalMetric.percent:
      final target = goal.targetValue;
      final current = formatGoalNumber(goal.currentValue);
      return target != null
          ? '$current% / ${formatGoalNumber(target)}%'
          : '$current%';
    case LearningGoalMetric.numeric:
      final unit = (goal.unit ?? '').trim();
      final current = formatGoalNumber(goal.currentValue);
      final target = goal.targetValue;
      final base = target != null
          ? '$current / ${formatGoalNumber(target)}'
          : current;
      return unit.isEmpty ? base : '$base $unit';
  }
}

class GoalStatusChip extends StatelessWidget {
  const GoalStatusChip({super.key, required this.status});
  final LearningGoalStatus status;

  @override
  Widget build(BuildContext context) => StatusPill(
    label: goalStatusLabel(context.l10n, status),
    tone: goalStatusTone(status),
    icon: goalStatusIcon(status),
  );
}

/// Progress driven only by [LearningGoal.progressFraction].
class GoalProgressBar extends StatelessWidget {
  const GoalProgressBar({super.key, required this.goal});
  final LearningGoal goal;

  @override
  Widget build(BuildContext context) {
    final c = context.mamily;
    final pct = goal.progressPercentage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProgressBar(
          value: goal.progressFraction,
          color: c.tone(goalStatusTone(goal.status)).foreground,
          semanticsLabel: goal.title,
        ),
        if (pct != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${formatGoalNumber(pct)}%',
            style: context.type.bodySmall?.copyWith(color: c.ink2),
          ),
        ],
      ],
    );
  }
}
