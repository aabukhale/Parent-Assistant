import 'package:flutter/foundation.dart';

import '../../../auth/data/models/family_membership.dart' show FamilyRole;
import 'family_permission.dart';

/// Minimal public view of another family member (`UserSummaryResource`).
@immutable
class MemberUser {
  const MemberUser({
    required this.id,
    required this.firstName,
    this.lastName,
    this.email,
    this.phone,
  });

  final String id;
  final String firstName;
  final String? lastName;
  final String? email;
  final String? phone;

  String get displayName => [
    firstName,
    lastName,
  ].where((p) => (p ?? '').trim().isNotEmpty).join(' ').trim();

  factory MemberUser.fromJson(Map<String, dynamic> json) => MemberUser(
    id: '${json['id']}',
    firstName: json['first_name'] as String? ?? '',
    lastName: json['last_name'] as String?,
    email: json['email'] as String?,
    phone: json['phone'] as String?,
  );
}

/// One `family_members` row (`FamilyMemberResource`), including the
/// backend-computed `effective_permissions`.
@immutable
class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.role,
    required this.status,
    this.joinedAt,
    this.user,
    this.effectivePermissions = const {},
  });

  /// The membership row id (matches `FamilyMembership.id` from `/auth/me`).
  final String id;
  final String familyId;
  final String userId;
  final FamilyRole role;

  /// `pending` | `active` | `revoked`
  final String status;
  final DateTime? joinedAt;
  final MemberUser? user;
  final Set<FamilyPermission> effectivePermissions;

  bool get isActive => status == 'active';

  factory FamilyMember.fromJson(Map<String, dynamic> json) => FamilyMember(
    id: '${json['id']}',
    familyId: '${json['family_id']}',
    userId: '${json['user_id']}',
    role: FamilyRole.fromString(json['role'] as String?),
    status: json['status'] as String? ?? 'active',
    joinedAt: DateTime.tryParse('${json['joined_at']}'),
    user: json['user'] is Map
        ? MemberUser.fromJson((json['user'] as Map).cast<String, dynamic>())
        : null,
    effectivePermissions: FamilyPermission.parseAll(
      json['effective_permissions'],
    ),
  );
}
