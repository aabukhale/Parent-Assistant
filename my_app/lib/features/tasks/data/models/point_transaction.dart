import 'package:flutter/foundation.dart';

import 'task_enums.dart';

/// One immutable ledger entry (`PointTransactionResource`). The ledger is
/// append-only — history is never deleted or mutated client-side.
@immutable
class PointTransaction {
  const PointTransaction({
    required this.id,
    required this.childId,
    required this.amount,
    required this.type,
    this.sourceType,
    this.sourceId,
    this.actorId,
    this.reference,
    this.createdAt,
  });

  final String id;
  final String childId;

  /// Signed (positive award, negative reversal/redemption).
  final int amount;
  final PointTransactionType type;
  final PointSourceType? sourceType;
  final String? sourceId;
  final String? actorId;
  final String? reference;
  final DateTime? createdAt;

  bool get isCredit => amount >= 0;

  factory PointTransaction.fromJson(Map<String, dynamic> json) =>
      PointTransaction(
        id: '${json['id']}',
        childId: '${json['child_id']}',
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        type: PointTransactionType.fromWire(json['type'] as String?),
        sourceType: PointSourceType.fromWire(json['source_type'] as String?),
        sourceId: json['source_id'] as String?,
        actorId: json['actor_id'] as String?,
        reference: json['reference'] as String?,
        createdAt: DateTime.tryParse('${json['created_at']}'),
      );
}

/// `GET …/points-balance` → `{ child_id, balance }`. The single source of truth
/// for the balance — never computed locally.
@immutable
class PointsBalance {
  const PointsBalance({required this.childId, required this.balance});

  final String childId;
  final int balance;

  factory PointsBalance.fromJson(Map<String, dynamic> json) => PointsBalance(
    childId: '${json['child_id']}',
    balance: (json['balance'] as num?)?.toInt() ?? 0,
  );
}
