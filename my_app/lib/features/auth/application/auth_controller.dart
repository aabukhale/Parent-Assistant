import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/providers.dart';
import '../../../core/storage/secure_token_storage.dart';
import '../../../core/session/session_cleanup.dart';
import '../data/auth_repository.dart';
import '../data/child_auth_repository.dart';
import '../data/auth_requests.dart';
import '../data/models/auth_session.dart';
import '../data/models/auth_user.dart';
import '../data/models/child_session.dart';
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
  ChildAuthRepository get _childRepo => ref.read(childAuthRepositoryProvider);
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
    final parked = await _storage.readParkedChildToken() != null;
    if (!await _repo.hasStoredToken()) {
      state = AuthState(
        phase: AuthPhase.unauthenticated,
        hasParkedChild: parked,
      );
      return;
    }

    final kind = await _storage.readSessionKind();
    try {
      if (kind == ChildAuthRepository.sessionKind) {
        _applyChildSession(await _childRepo.me(), hasParkedChild: false);
      } else {
        await _applySession(await _repo.me(), syncLocale: true);
        state = state.copyWith(hasParkedChild: parked);
      }
    } on ApiException catch (e) {
      // 401: token gone. 403: the token is the wrong kind for the endpoint
      // (e.g. a tampered session-kind flag) — never trust it, wipe it.
      if (e.isUnauthorized || e.kind == ApiErrorKind.forbidden) {
        await _storage.clearSession();
        await ref.read(sessionCleanupProvider).run();
        state = AuthState(
          phase: AuthPhase.unauthenticated,
          hasParkedChild: parked,
        );
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

  /// Parent sign-in. On a device where a child is signed in, the child
  /// session is parked first, so a grown-up can step in with real credentials
  /// and later hand the device back without re-pairing.
  Future<void> login(LoginInput input) async {
    await _parkChildIfActive();
    await _applySession(await _repo.login(input), syncLocale: true);
    state = state.copyWith(
      hasParkedChild: await _storage.readParkedChildToken() != null,
    );
  }

  Future<void> register(RegisterInput input) async {
    await _parkChildIfActive();
    await _applySession(await _repo.register(input), syncLocale: true);
  }

  /// Pair this install with a child profile using a parent-issued code.
  Future<void> pairChild(String code, {required String deviceName}) async {
    final session = await _childRepo.pair(code, deviceName: deviceName);
    await _storage.deleteParkedChildToken();
    _applyChildSession(session, hasParkedChild: false);
  }

  /// Re-fetch the active session without disturbing the family selection.
  Future<void> refreshSession() async {
    if (state.isChild) {
      _applyChildSession(await _childRepo.me(), hasParkedChild: false);
      return;
    }
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

  /// Sign the current session out (server revoke + local wipe + private data
  /// cleanup). A parked child session survives a parent's logout; a child
  /// signing out forgets nothing else.
  Future<void> logout() async {
    if (state.isChild) {
      await _childRepo.logout();
    } else {
      await _repo.logout();
    }
    await ref.read(sessionCleanupProvider).run();
    state = AuthState(
      phase: AuthPhase.unauthenticated,
      hasParkedChild: await _storage.readParkedChildToken() != null,
    );
  }

  /// Parent finished on a shared device: end the parent session and resume
  /// the parked child session.
  Future<void> handBackToChild() async {
    if (state.isAuthenticated) {
      await _repo.logout();
      await ref.read(sessionCleanupProvider).run();
    }
    await resumeParkedChild();
  }

  Future<void> resumeParkedChild() async {
    final parked = await _storage.readParkedChildToken();
    if (parked == null) return;
    await _storage.writeToken(parked);
    await _storage.writeSessionKind(ChildAuthRepository.sessionKind);
    await _storage.deleteParkedChildToken();
    state = const AuthState.restoring();
    await _restore();
  }

  Future<void> selectActiveFamily(String membershipId) async {
    final membership = _membershipById(membershipId);
    if (membership == null) return;
    await _storage.writeActiveFamilyId(membership.familyId);
    state = state.copyWith(activeMembershipId: membershipId);
  }

  Future<void> _parkChildIfActive() async {
    if (!state.isChild) return;
    final token = await _storage.readToken();
    if (token != null && token.isNotEmpty) {
      await _storage.writeParkedChildToken(token);
    }
    await _storage.clearSession();
    await ref.read(sessionCleanupProvider).run();
  }

  FamilyMembership? _membershipById(String id) {
    for (final m in state.session?.memberships ?? const <FamilyMembership>[]) {
      if (m.id == id) return m;
    }
    return null;
  }

  void _applyChildSession(
    ChildSession session, {
    required bool hasParkedChild,
  }) {
    final lang = session.preferredLanguage;
    if (lang != null) {
      ref.read(localeControllerProvider.notifier).setLanguageCode(lang);
    }
    state = AuthState(
      phase: AuthPhase.authenticated,
      childSession: session,
      hasParkedChild: hasParkedChild,
    );
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
      hasParkedChild: state.hasParkedChild,
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
      ref.read(sessionCleanupProvider).run();
      state = AuthState(
        phase: AuthPhase.unauthenticated,
        hasParkedChild: state.hasParkedChild,
      );
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

/// The paired child session on this device, or null for a parent session.
final childSessionProvider = Provider<ChildSession?>(
  (ref) => ref.watch(authControllerProvider).childSession,
);
