import 'package:flutter/foundation.dart';

import 'task_enums.dart';

/// One task-occurrence completion (`TaskCompletionResource`).
///
/// The **backend status drives every UI action** — never assume from local
/// state. A reversed completion keeps `status == approved` and has a non-null
/// [reversedAt].
@immutable
class TaskCompletion {
  const TaskCompletion({
    required this.id,
    required this.childTaskId,
    required this.childId,
    this.occurrenceDate,
    required this.status,
    this.requestedBy,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewNote,
    this.pointsAwarded,
    this.awardTransactionId,
    this.reversedAt,
    this.reversedBy,
    this.reversalNote,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String childTaskId;
  final String childId;

  /// Date-only (the occurrence being completed).
  final DateTime? occurrenceDate;

  final CompletionStatus status;
  final String? requestedBy;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewNote;

  /// Set when approved (0 for a 0-point task).
  final int? pointsAwarded;
  final String? awardTransactionId;

  final DateTime? reversedAt;
  final String? reversedBy;
  final String? reversalNote;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPending => status == CompletionStatus.pending;
  bool get isApproved => status == CompletionStatus.approved;
  bool get isRejected => status == CompletionStatus.rejected;
  bool get isReversed => reversedAt != null;

  /// Backend rules: pending → approve/reject; approved & not reversed → reverse.
  bool get canApproveOrReject => isPending;
  bool get canReverse => isApproved && !isReversed;

  factory TaskCompletion.fromJson(Map<String, dynamic> json) => TaskCompletion(
    id: '${json['id']}',
    childTaskId: '${json['child_task_id']}',
    childId: '${json['child_id']}',
    occurrenceDate: _date(json['occurrence_date']),
    status: CompletionStatus.fromWire(json['status'] as String?),
    requestedBy: json['requested_by'] as String?,
    reviewedBy: json['reviewed_by'] as String?,
    reviewedAt: DateTime.tryParse('${json['reviewed_at']}'),
    reviewNote: json['review_note'] as String?,
    pointsAwarded: (json['points_awarded'] as num?)?.toInt(),
    awardTransactionId: json['award_transaction_id'] as String?,
    reversedAt: DateTime.tryParse('${json['reversed_at']}'),
    reversedBy: json['reversed_by'] as String?,
    reversalNote: json['reversal_note'] as String?,
    createdAt: DateTime.tryParse('${json['created_at']}'),
    updatedAt: DateTime.tryParse('${json['updated_at']}'),
  );

  static DateTime? _date(Object? v) =>
      v == null ? null : DateTime.tryParse('$v');
}
