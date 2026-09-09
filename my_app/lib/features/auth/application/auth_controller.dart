import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/providers.dart';
import '../../../core/storage/secure_token_storage.dart';
import '../data/auth_repository.dart';
import '../data/auth_requests.dart';
import '../data/models/auth_session.dart';
import '../data/models/auth_user.dart';
import '../data/models/family_membership.dart';
import 'auth_state.dart';

/// Owns the session lifecycle:
///
/// * launch → read token → `/auth/me` → restore or clear
/// * login / register → hydrate session
/// * logout → revoke + wipe
/// * reacts to a backend 401 (via [unauthorizedSignalProvider]) by dropping to
///   the unauthenticated state
class AuthController extends Notifier<AuthState> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);
  SecureTokenStorage get _storage => ref.read(secureStorageProvider);

  @override
  AuthState build() {
    ref.listen<int>(
      unauthorizedSignalProvider,
      (_, _) => _onUnauthorizedSignal(),
    );
    Future.microtask(_restore);
    return const AuthState.restoring();
  }

  Future<void> _restore() async {
    if (!await _repo.hasStoredToken()) {
      state = const AuthState.unauthenticated();
      return;
    }
    try {
      await _applySession(await _repo.me(), syncLocale: true);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await _storage.clearSession();
        state = const AuthState.unauthenticated();
      } else {
        state = AuthState(phase: AuthPhase.restoreFailed, restoreError: e);
      }
    }
  }

  /// Retry a failed restore (offline / 5xx recovery screen).
  Future<void> retryRestore() async {
    state = const AuthState.restoring();
    await _restore();
  }

  Future<void> login(LoginInput input) async {
    await _applySession(await _repo.login(input), syncLocale: true);
  }

  Future<void> register(RegisterInput input) async {
    await _applySession(await _repo.register(input), syncLocale: true);
  }

  /// Re-fetch `/auth/me` without disturbing the active-family selection.
  Future<void> refreshSession() async {
    if (!state.isAuthenticated) return;
    await _applySession(await _repo.me(), keepActiveSelection: true);
  }

  /// Persist a profile change (`PATCH /me`) and merge the result into the live
  /// session so every screen reading [currentUserProvider] refreshes.
  Future<void> updateProfile(ProfileUpdateInput input) async {
    if (input.isEmpty) return;
    final user = await _repo.updateProfile(input);
    final session = state.session;
    if (session == null) return;
    state = state.copyWith(session: session.copyWith(user: user));
    final lang = input.preferredLanguage;
    if (lang != null) {
      await ref.read(localeControllerProvider.notifier).setLanguageCode(lang);
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState.unauthenticated();
  }

  Future<void> selectActiveFamily(String membershipId) async {
    final membership = _membershipById(membershipId);
    if (membership == null) return;
    await _storage.writeActiveFamilyId(membership.familyId);
    state = state.copyWith(activeMembershipId: membershipId);
  }

  FamilyMembership? _membershipById(String id) {
    for (final m in state.session?.memberships ?? const <FamilyMembership>[]) {
      if (m.id == id) return m;
    }
    return null;
  }

  Future<void> _applySession(
    AuthSession session, {
    bool syncLocale = false,
    bool keepActiveSelection = false,
  }) async {
    if (syncLocale) {
      final lang = session.user.preferredLanguage;
      if (lang != null) {
        await ref.read(localeControllerProvider.notifier).setLanguageCode(lang);
      }
    }

    String? activeId = keepActiveSelection ? state.activeMembershipId : null;
    final memberships = session.memberships;

    if (memberships.length == 1) {
      activeId = memberships.single.id;
      await _storage.writeActiveFamilyId(memberships.single.familyId);
    } else if (memberships.length > 1) {
      final storedFamilyId = await _storage.readActiveFamilyId();
      for (final m in memberships) {
        if (m.familyId == storedFamilyId) {
          activeId = m.id;
          break;
        }
      }
      // Verify a kept selection still exists.
      if (activeId != null && _indexOfMembership(memberships, activeId) == -1) {
        activeId = null;
      }
    } else {
      activeId = null;
    }

    state = AuthState(
      phase: AuthPhase.authenticated,
      session: session,
      activeMembershipId: activeId,
    );
  }

  int _indexOfMembership(List<FamilyMembership> list, String id) {
    for (var i = 0; i < list.length; i++) {
      if (list[i].id == id) return i;
    }
    return -1;
  }

  void _onUnauthorizedSignal() {
    if (state.phase == AuthPhase.authenticated) {
      state = const AuthState.unauthenticated();
    }
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

final currentUserProvider = Provider<AuthUser?>(
  (ref) => ref.watch(authControllerProvider).session?.user,
);

final activeMembershipProvider = Provider<FamilyMembership?>(
  (ref) => ref.watch(authControllerProvider).activeMembership,
);

/// The active family id, or null when unauthenticated / no family / unselected.
final activeFamilyIdProvider = Provider<String?>(
  (ref) => ref.watch(authControllerProvider).activeMembership?.familyId,
);
