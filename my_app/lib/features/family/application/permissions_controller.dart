import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/data/models/family_membership.dart' show FamilyRole;
import '../data/family_members_repository.dart';
import '../data/models/family_member.dart';
import '../data/models/family_permission.dart';

/// Members of the **active** family, with backend `effective_permissions`.
///
/// * `build()` watches [activeFamilyIdProvider], so a family switch clears this
///   and reloads — the old family's permissions are never reused (req. 10).
/// * Cached until the family changes or it is invalidated (req. 12).
/// * Null family (unauthenticated / no family) → empty list, no request.
final familyMembersProvider = FutureProvider<List<FamilyMember>>((ref) async {
  final familyId = ref.watch(activeFamilyIdProvider);
  if (familyId == null) return const [];
  return ref.watch(familyMembersRepositoryProvider).listAll(familyId);
});

enum PermissionsStatus { loading, ready, error }

/// The authenticated user's effective capabilities in the active family.
///
/// Resolution rules:
/// * **ready** (members loaded, own row found) → use the row's
///   `effective_permissions` verbatim — owner/parent naturally carry all keys,
///   caregivers carry exactly what was granted.
/// * **loading / error** → fall back to the role invariant: owner/parent hold
///   everything (a hard backend guarantee, independent of this endpoint);
///   everyone else holds nothing → management actions default to **denied**
///   (req. 11).
/// * [canManageChildren] is always role-based (Sprint 1 invariant) and does not
///   depend on the members fetch (req. 7).
@immutable
class Permissions {
  const Permissions._({
    required this.status,
    required this.role,
    required Set<FamilyPermission> effective,
    this.error,
  }) : _effective = effective;

  final PermissionsStatus status;
  final FamilyRole? role;
  final Set<FamilyPermission> _effective;
  final Object? error;

  const Permissions.loading(FamilyRole? role)
    : this._(
        status: PermissionsStatus.loading,
        role: role,
        effective: const {},
      );

  const Permissions.error(FamilyRole? role, Object? error)
    : this._(
        status: PermissionsStatus.error,
        role: role,
        effective: const {},
        error: error,
      );

  const Permissions.ready({
    required FamilyRole? role,
    required Set<FamilyPermission> effective,
  }) : this._(
         status: PermissionsStatus.ready,
         role: role,
         effective: effective,
       );

  bool get isReady => status == PermissionsStatus.ready;
  bool get isLoading => status == PermissionsStatus.loading;
  bool get hasError => status == PermissionsStatus.error;

  bool get _roleHoldsAll =>
      role == FamilyRole.owner || role == FamilyRole.parent;

  bool hasPermission(FamilyPermission permission) {
    if (isReady) return _effective.contains(permission);
    return _roleHoldsAll; // loading / error → role invariant (caregiver = denied)
  }

  /// Child *profile* create / update / delete — role-gated to owner/parent,
  /// independent of the members endpoint.
  bool get canManageChildren => _roleHoldsAll;

  Set<FamilyPermission> get effectivePermissions {
    if (isReady) return _effective;
    return _roleHoldsAll ? FamilyPermission.all : const {};
  }

  /// The members fetch failed *and it changes what the user can see* — i.e. a
  /// caregiver (owner/parent are unaffected by their invariant). Screens use
  /// this to offer a retry.
  bool get shouldSurfacePermissionError => hasError && !_roleHoldsAll;
}

/// Central permission API. Screens read this instead of inspecting role names.
final permissionsProvider = Provider<Permissions>((ref) {
  final membership = ref.watch(activeMembershipProvider);
  final role = membership?.role;
  final myMembershipId = membership?.id;
  final myUserId = ref.watch(currentUserProvider)?.id;

  return ref
      .watch(familyMembersProvider)
      .when(
        loading: () => Permissions.loading(role),
        error: (e, _) => Permissions.error(role, e),
        data: (members) {
          FamilyMember? mine;
          for (final m in members) {
            if ((myMembershipId != null && m.id == myMembershipId) ||
                (myUserId != null && m.userId == myUserId)) {
              mine = m;
              break;
            }
          }
          if (mine == null) {
            // Own row missing from the listing — treat like a failed load
            // (role invariant still protects owner/parent).
            return Permissions.error(
              role,
              StateError('own membership not in members list'),
            );
          }
          return Permissions.ready(
            role: mine.role,
            effective: mine.effectivePermissions,
          );
        },
      );
});

/// Re-fetch the active family's members (after a permission-load failure).
void refreshPermissions(WidgetRef ref) => ref.invalidate(familyMembersProvider);
