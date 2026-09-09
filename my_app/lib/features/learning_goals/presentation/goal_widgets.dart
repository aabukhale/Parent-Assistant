import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
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

Color goalStatusColor(LearningGoalStatus s) => switch (s) {
  LearningGoalStatus.active => AppColors.teal,
  LearningGoalStatus.paused => AppColors.amber,
  LearningGoalStatus.achieved => const Color(0xFF57C77A),
  LearningGoalStatus.archived => AppColors.textMuted,
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
  Widget build(BuildContext context) {
    final color = goalStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        goalStatusLabel(context.l10n, status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// A thin progress bar driven only by [LearningGoal.progressFraction].
class GoalProgressBar extends StatelessWidget {
  const GoalProgressBar({super.key, required this.goal});
  final LearningGoal goal;

  @override
  Widget build(BuildContext context) {
    final pct = goal.progressPercentage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: goal.progressFraction,
            minHeight: 8,
            backgroundColor: const Color(0xFFECEEF4),
            valueColor: AlwaysStoppedAnimation(goalStatusColor(goal.status)),
          ),
        ),
        if (pct != null) ...[
          const SizedBox(height: 6),
          Text(
            '${formatGoalNumber(pct)}%',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ],
    );
  }
}
