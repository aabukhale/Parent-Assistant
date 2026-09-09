import 'package:flutter/foundation.dart';

import '../../../tasks/data/models/task_enums.dart';

/// One activity-assignment completion (`ActivityCompletionResource`). Same shape
/// and status machine as a task completion: the **backend status drives every
/// UI action**; a reversed completion keeps `status == approved` with a non-null
/// [reversedAt].
@immutable
class ActivityCompletion {
  const ActivityCompletion({
    required this.id,
    required this.activityAssignmentId,
    required this.childId,
    required this.status,
    this.completedAt,
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
  });

  final String id;
  final String activityAssignmentId;
  final String childId;
  final CompletionStatus status;
  final DateTime? completedAt;
  final String? requestedBy;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewNote;
  final int? pointsAwarded;
  final String? awardTransactionId;
  final DateTime? reversedAt;
  final String? reversedBy;
  final String? reversalNote;
  final DateTime? createdAt;

  bool get isPending => status == CompletionStatus.pending;
  bool get isApproved => status == CompletionStatus.approved;
  bool get isRejected => status == CompletionStatus.rejected;
  bool get isReversed => reversedAt != null;

  /// pending → approve / reject; approved & not reversed → reverse.
  bool get canApproveOrReject => isPending;
  bool get canReverse => isApproved && !isReversed;

  factory ActivityCompletion.fromJson(Map<String, dynamic> json) =>
      ActivityCompletion(
        id: '${json['id']}',
        activityAssignmentId: '${json['activity_assignment_id']}',
        childId: '${json['child_id']}',
        status: CompletionStatus.fromWire(json['status'] as String?),
        completedAt: DateTime.tryParse('${json['completed_at']}'),
        requestedBy: json['requested_by'] as String?,
        reviewedBy: json['reviewed_by'] as String?,
        reviewedAt: DateTime.tryParse('${json['reviewed_at']}'),
        reviewNote: json['review_note'] as String?,
        pointsAwarded: (json['points_awarded'] as num?)?.round(),
        awardTransactionId: json['award_transaction_id'] as String?,
        reversedAt: DateTime.tryParse('${json['reversed_at']}'),
        reversedBy: json['reversed_by'] as String?,
        reversalNote: json['reversal_note'] as String?,
        createdAt: DateTime.tryParse('${json['created_at']}'),
      );
}
