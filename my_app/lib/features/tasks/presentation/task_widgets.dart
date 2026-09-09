import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../data/models/child_task.dart';
import '../data/models/task_completion.dart';
import '../data/models/task_enums.dart';

String _tag(BuildContext c) => Localizations.localeOf(c).toLanguageTag();

String formatTaskDate(BuildContext context, DateTime d) =>
    DateFormat.yMMMd(_tag(context)).format(d);

String formatTaskDateTime(BuildContext context, DateTime d) =>
    DateFormat.yMMMd(_tag(context)).add_jm().format(d.toLocal());

/// Localized full weekday name for an ISO weekday (1 = Mon … 7 = Sun).
String isoWeekdayName(BuildContext context, int isoDay) {
  // 2024-01-01 was a Monday → offset to the requested ISO weekday.
  final ref = DateTime(2024, 1, isoDay);
  return DateFormat.EEEE(_tag(context)).format(ref);
}

String isoWeekdayShort(BuildContext context, int isoDay) {
  final ref = DateTime(2024, 1, isoDay);
  return DateFormat.E(_tag(context)).format(ref);
}

/// Human recurrence summary, from the real `recurrence_type` + `recurrence_config`.
String recurrenceSummary(BuildContext context, ChildTask task) {
  final l = context.l10n;
  switch (task.recurrenceType) {
    case TaskRecurrence.daily:
      return l.recurrenceSummaryDaily;
    case TaskRecurrence.oneTime:
      final by = task.deadlineAt;
      return by == null
          ? l.recurrenceSummaryOneTime
          : l.recurrenceSummaryOneTimeBy(formatTaskDate(context, by.toLocal()));
    case TaskRecurrence.weekly:
      final days = (task.recurrenceConfig?.daysOfWeek ?? const <int>[])..sort();
      final names = days.map((d) => isoWeekdayShort(context, d)).join(', ');
      return l.recurrenceSummaryWeekly(names);
    case TaskRecurrence.custom:
      final c = task.recurrenceConfig;
      if (c != null && c.dates.isNotEmpty) {
        return l.recurrenceSummaryCustomDates(c.dates.length);
      }
      if (c != null && c.intervalDays != null) {
        return l.recurrenceSummaryCustomInterval(c.intervalDays!);
      }
      return l.recurrenceCustom;
  }
}

String txnTypeLabel(AppLocalizations l, PointTransactionType type) =>
    switch (type) {
      PointTransactionType.taskAward => l.txnTypeTaskAward,
      PointTransactionType.taskReversal => l.txnTypeTaskReversal,
      PointTransactionType.activityAward => l.txnTypeActivityAward,
      PointTransactionType.activityReversal => l.txnTypeActivityReversal,
      PointTransactionType.redemption => l.txnTypeRedemption,
      PointTransactionType.redemptionRefund => l.txnTypeRedemptionRefund,
      PointTransactionType.adjustment => l.txnTypeAdjustment,
    };

Color completionStatusColor(TaskCompletion c) {
  if (c.isReversed) return AppColors.textMuted;
  return switch (c.status) {
    CompletionStatus.pending => AppColors.amber,
    CompletionStatus.approved => const Color(0xFF57C77A),
    CompletionStatus.rejected => AppColors.coral,
  };
}

String completionStatusLabel(AppLocalizations l, TaskCompletion c) =>
    switch (c.status) {
      CompletionStatus.pending => l.completionStatusPending,
      CompletionStatus.approved => l.completionStatusApproved,
      CompletionStatus.rejected => l.completionStatusRejected,
    };

class CompletionStatusChip extends StatelessWidget {
  const CompletionStatusChip({super.key, required this.completion});
  final TaskCompletion completion;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final color = completionStatusColor(completion);
    return Wrap(
      spacing: 6,
      children: [
        _pill(completionStatusLabel(l, completion), color),
        if (completion.isReversed)
          _pill(l.completionReversedBadge, AppColors.textMuted),
      ],
    );
  }

  Widget _pill(String text, Color color) => Container(
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
