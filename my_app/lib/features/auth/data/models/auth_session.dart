import 'package:flutter/foundation.dart';

import 'auth_user.dart';
import 'family_membership.dart';

/// The hydrated result of `/auth/me` — the user plus their active memberships.
/// The bearer token itself lives only in secure storage, never here.
@immutable
class AuthSession {
  const AuthSession({required this.user, required this.memberships});

  final AuthUser user;
  final List<FamilyMembership> memberships;

  bool get hasFamily => memberships.isNotEmpty;
  bool get hasMultipleFamilies => memberships.length > 1;

  factory AuthSession.fromUserJson(Map<String, dynamic> userJson) {
    final rawMemberships = (userJson['memberships'] as List?) ?? const [];
    return AuthSession(
      user: AuthUser.fromJson(userJson),
      memberships: rawMemberships
          .whereType<Map>()
          .map((m) => FamilyMembership.fromJson(m.cast<String, dynamic>()))
          .toList(growable: false),
    );
  }

  AuthSession copyWith({AuthUser? user, List<FamilyMembership>? memberships}) =>
      AuthSession(
        user: user ?? this.user,
        memberships: memberships ?? this.memberships,
      );
}
