import 'package:flutter/foundation.dart';

import 'child_summary.dart';

/// `GET /families/{family}/dashboard` — a family-level roll-up plus one
/// [ChildSummary] per **active** child (archived children are excluded by the
/// backend). One request returns everything; there is no per-child follow-up.
@immutable
class ParentDashboard {
  const ParentDashboard({
    required this.familyId,
    required this.childrenCount,
    required this.children,
  });

  final String familyId;
  final int childrenCount;
  final List<ChildSummary> children;

  bool get isEmpty => children.isEmpty;

  factory ParentDashboard.fromJson(Map<String, dynamic> json) {
    final rawChildren = (json['children'] as List?) ?? const [];
    return ParentDashboard(
      familyId: '${json['family_id']}',
      childrenCount: (json['children_count'] as num?)?.round() ?? 0,
      children: rawChildren
          .whereType<Map>()
          .map((m) => ChildSummary.fromJson(m.cast<String, dynamic>()))
          .toList(growable: false),
    );
  }
}
