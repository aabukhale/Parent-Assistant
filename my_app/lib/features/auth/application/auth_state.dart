import 'package:flutter/foundation.dart';

import '../../../core/errors/api_exception.dart';
import '../data/models/auth_session.dart';
import '../data/models/child_session.dart';
import '../data/models/family_membership.dart';

enum AuthPhase {
  /// Reading the stored token / calling `/auth/me`. The gate shows a splash.
  restoring,

  /// No token, or restore hit a 401. The gate shows Welcome/Login.
  unauthenticated,

  /// Restore failed for a *recoverable* reason (offline, 5xx). The gate shows a
  /// retry screen — the token is kept.
  restoreFailed,

  /// Authenticated. The gate shows the app shell.
  authenticated,
}

@immutable
class AuthState {
  const AuthState({
    required this.phase,
    this.session,
    this.childSession,
    this.activeMembershipId,
    this.restoreError,
    this.hasParkedChild = false,
  });

  final AuthPhase phase;

  /// Parent / caregiver session (`/auth/me`). Null for a child device.
  final AuthSession? session;

  /// Paired child session (`/child/me`). Null for a parent session.
  final ChildSession? childSession;

  /// A child session is parked on this install while a grown-up is signed in.
  final bool hasParkedChild;

  /// Which `family_members` row is currently active. Null while a
  /// multi-family user has not chosen one yet.
  final String? activeMembershipId;

  final ApiException? restoreError;

  const AuthState.restoring() : this(phase: AuthPhase.restoring);
  const AuthState.unauthenticated() : this(phase: AuthPhase.unauthenticated);

  /// A parent/caregiver is signed in.
  bool get isAuthenticated =>
      phase == AuthPhase.authenticated && session != null;

  /// A paired child is signed in on this device.
  bool get isChild => phase == AuthPhase.authenticated && childSession != null;

  FamilyMembership? get activeMembership {
    final list = session?.memberships ?? const [];
    for (final m in list) {
      if (m.id == activeMembershipId) return m;
    }
    return null;
  }

  bool get needsFamilySelection =>
      isAuthenticated &&
      (session?.hasFamily ?? false) &&
      activeMembership == null;

  bool get hasNoFamily => isAuthenticated && !(session?.hasFamily ?? false);

  AuthState copyWith({
    AuthPhase? phase,
    AuthSession? session,
    String? activeMembershipId,
    ApiException? restoreError,
    bool? hasParkedChild,
    bool clearActive = false,
    bool clearError = false,
  }) => AuthState(
    phase: phase ?? this.phase,
    session: session ?? this.session,
    childSession: childSession,
    hasParkedChild: hasParkedChild ?? this.hasParkedChild,
    activeMembershipId: clearActive
        ? null
        : (activeMembershipId ?? this.activeMembershipId),
    restoreError: clearError ? null : (restoreError ?? this.restoreError),
  );
}
