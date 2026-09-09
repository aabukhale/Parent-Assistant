import 'package:flutter/material.dart';

import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../tasks/data/models/task_enums.dart';
import '../data/models/activity.dart';
import '../data/models/activity_assignment.dart';

IconData activitySourceIcon(ActivitySource s) => switch (s) {
  ActivitySource.ai => Icons.auto_awesome_rounded,
  ActivitySource.family => Icons.home_rounded,
  ActivitySource.global => Icons.public_rounded,
};

String activitySourceLabel(AppLocalizations l, ActivitySource s) => switch (s) {
  ActivitySource.ai => l.activitySourceAi,
  ActivitySource.family => l.activitySourceFamily,
  ActivitySource.global => l.activitySourceGlobal,
};

String assignmentStatusLabel(AppLocalizations l, AssignmentStatus s) =>
    switch (s) {
      AssignmentStatus.assigned => l.activityStatusAssigned,
      AssignmentStatus.completed => l.activityStatusCompleted,
      AssignmentStatus.cancelled => l.activityStatusCancelled,
    };

Color assignmentStatusColor(AssignmentStatus s) => switch (s) {
  AssignmentStatus.assigned => AppColors.amber,
  AssignmentStatus.completed => const Color(0xFF57C77A),
  AssignmentStatus.cancelled => AppColors.textMuted,
};

String completionStatusLabel(AppLocalizations l, CompletionStatus s) =>
    switch (s) {
      CompletionStatus.pending => l.redemptionStatusPending,
      CompletionStatus.approved => l.redemptionStatusApproved,
      CompletionStatus.rejected => l.redemptionStatusRejected,
    };

/// "3–8 yrs" / "من 3 سنوات" style age range, or null when the activity sets none.
String? activityAgeLabel(AppLocalizations l, Activity a) {
  if (a.minAge == null && a.maxAge == null) return null;
  if (a.minAge != null && a.maxAge != null) {
    return l.activityAgeRange(a.minAge!, a.maxAge!);
  }
  if (a.minAge != null) return l.activityAgeMin(a.minAge!);
  return l.activityAgeMax(a.maxAge!);
}

class ActivityPill extends StatelessWidget {
  const ActivityPill({super.key, required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
    ),
  );
}
