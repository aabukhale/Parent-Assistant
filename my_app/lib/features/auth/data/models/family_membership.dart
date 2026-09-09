import 'package:flutter/foundation.dart';

enum FamilyRole {
  owner,
  parent,
  caregiver;

  static FamilyRole fromString(String? value) => switch (value) {
    'owner' => FamilyRole.owner,
    'parent' => FamilyRole.parent,
    'caregiver' => FamilyRole.caregiver,
    _ => FamilyRole.caregiver,
  };

  /// Owner and parent implicitly hold every family permission (backend §5).
  bool get holdsAllPermissions =>
      this == FamilyRole.owner || this == FamilyRole.parent;

  /// Sprint 1 invariant: only owner/parent may manage child profiles.
  bool get canManageChildren =>
      this == FamilyRole.owner || this == FamilyRole.parent;
}

@immutable
class FamilySummary {
  const FamilySummary({
    required this.id,
    required this.name,
    this.ownerId,
    this.timezone,
    this.preferredLanguage,
  });

  final String id;
  final String name;
  final String? ownerId;
  final String? timezone;
  final String? preferredLanguage;

  factory FamilySummary.fromJson(Map<String, dynamic> json) => FamilySummary(
    id: '${json['id']}',
    name: json['name'] as String? ?? '',
    ownerId: json['owner_id'] as String?,
    timezone: json['timezone'] as String?,
    preferredLanguage: json['preferred_language'] as String?,
  );
}

/// One active `family_members` row for the authenticated user, from
/// `UserResource.memberships` (`FamilyMembershipResource`).
@immutable
class FamilyMembership {
  const FamilyMembership({
    required this.id,
    required this.role,
    required this.status,
    required this.family,
  });

  /// The `family_members` row id (membership id, distinct from the family id).
  final String id;
  final FamilyRole role;
  final String status;
  final FamilySummary family;

  String get familyId => family.id;

  factory FamilyMembership.fromJson(Map<String, dynamic> json) =>
      FamilyMembership(
        id: '${json['id']}',
        role: FamilyRole.fromString(json['role'] as String?),
        status: json['status'] as String? ?? 'active',
        family: FamilySummary.fromJson(
          (json['family'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
      );
}
