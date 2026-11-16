import 'package:flutter/material.dart';

import '../../../core/localization/l10n.dart';
import '../../../core/design_system.dart';
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

AppTone assignmentStatusTone(AssignmentStatus s) => switch (s) {
  AssignmentStatus.assigned => AppTone.warning,
  AssignmentStatus.completed => AppTone.success,
  AssignmentStatus.cancelled => AppTone.neutral,
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

/// A labelled pill: tone + word (and the tone's default icon), never colour
/// alone.
class ActivityPill extends StatelessWidget {
  const ActivityPill({
    super.key,
    required this.text,
    this.tone = AppTone.info,
    this.icon,
  });
  final String text;
  final AppTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) =>
      StatusPill(label: text, tone: tone, icon: icon);
}
