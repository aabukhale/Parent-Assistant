import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/storage/secure_token_storage.dart';
import 'auth_requests.dart';
import 'models/auth_session.dart';
import 'models/auth_user.dart';

/// All network calls for authentication and the current-user profile.
///
/// The token is written to secure storage here (and nowhere else). Login and
/// register responses carry the user but not the membership list, so both
/// hydrate the full [AuthSession] with a follow-up `/auth/me`.
class AuthRepository {
  AuthRepository(this._client, this._storage);

  final ApiClient _client;
  final SecureTokenStorage _storage;

  Future<AuthSession> register(RegisterInput input) async {
    final envelope = await _client.post('/auth/register', body: input.toJson());
    final token = envelope.dataMap['token'] as String?;
    if (token == null || token.isEmpty) {
      throw const ApiException(kind: ApiErrorKind.server);
    }
    await _storage.writeToken(token);
    return me();
  }

  Future<AuthSession> login(LoginInput input) async {
    final envelope = await _client.post('/auth/login', body: input.toJson());
    final token = envelope.dataMap['token'] as String?;
    if (token == null || token.isEmpty) {
      throw const ApiException(kind: ApiErrorKind.server);
    }
    await _storage.writeToken(token);
    return me();
  }

  Future<AuthSession> me() async {
    final envelope = await _client.get('/auth/me');
    return AuthSession.fromUserJson(envelope.dataMap);
  }

  Future<AuthUser> updateProfile(ProfileUpdateInput input) async {
    final envelope = await _client.patch('/me', body: input.toJson());
    return AuthUser.fromJson(envelope.dataMap);
  }

  /// Revoke the current token server-side, then always clear it locally — even
  /// if the network call fails, the device must not keep a usable token.
  Future<void> logout() async {
    try {
      await _client.post('/auth/logout');
    } on ApiException {
      // Swallow: local wipe below is the guarantee that matters.
    } finally {
      await _storage.clearSession();
    }
  }

  Future<bool> hasStoredToken() => _storage.hasToken();
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(secureStorageProvider),
  ),
);
