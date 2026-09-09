import 'package:flutter/foundation.dart';

import 'reward_enums.dart';

/// A reward (`RewardResource`).
///
/// `scope` is `global` (a read-only Mamily template, `family_id == null`) or
/// `family` (this family's own, editable/deletable with `manage_rewards`).
///
/// `metadata` is an opaque map on the wire; the only key the backend documents
/// and validates is `metadata.minutes` (1–600) for `screen_time` rewards — no
/// other metadata fields are surfaced or invented.
@immutable
class Reward {
  const Reward({
    required this.id,
    this.familyId,
    required this.scope,
    required this.title,
    this.description,
    required this.type,
    required this.pointsCost,
    this.metadata,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? familyId;

  /// `global` | `family`
  final String scope;
  final String title;
  final String? description;
  final RewardType type;
  final int pointsCost;
  final Map<String, dynamic>? metadata;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isGlobal => scope == 'global' || familyId == null;

  /// Documented screen-time payload; null for non-screen-time rewards or when
  /// unset.
  int? get screenTimeMinutes {
    if (type != RewardType.screenTime) return null;
    final m = metadata?['minutes'];
    return m is num ? m.toInt() : null;
  }

  factory Reward.fromJson(Map<String, dynamic> json) => Reward(
    id: '${json['id']}',
    familyId: json['family_id'] as String?,
    scope:
        json['scope'] as String? ??
        (json['family_id'] == null ? 'global' : 'family'),
    title: json['title'] as String? ?? '',
    description: json['description'] as String?,
    type: RewardType.fromWire(json['type'] as String?),
    pointsCost: (json['points_cost'] as num?)?.toInt() ?? 0,
    metadata: json['metadata'] is Map<String, dynamic>
        ? json['metadata'] as Map<String, dynamic>
        : null,
    isActive: json['is_active'] as bool? ?? true,
    createdAt: DateTime.tryParse('${json['created_at']}'),
    updatedAt: DateTime.tryParse('${json['updated_at']}'),
  );
}
