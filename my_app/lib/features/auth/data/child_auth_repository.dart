import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/storage/secure_token_storage.dart';
import 'models/child_session.dart';

/// Normalizes what a child (or a parent reading it out) typed: uppercase,
/// no spaces or dashes. Returns null when it cannot be a pairing code.
String? normalizePairingCode(String input) {
  final cleaned = input.toUpperCase().replaceAll(RegExp(r'[\s\-_]'), '');
  if (cleaned.length != 8) return null;
  if (!RegExp(r'^[A-HJ-NP-Z2-9]{8}$').hasMatch(cleaned)) return null;
  return cleaned;
}

/// Extracts a pairing code from a scanned QR / tapped `mamily://pair?code=` link.
String? pairingCodeFromLink(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null) return normalizePairingCode(raw);
  if (uri.scheme == 'mamily' && uri.host == 'pair') {
    final code = uri.queryParameters['code'];
    return code == null ? null : normalizePairingCode(code);
  }
  return normalizePairingCode(raw);
}

/// Child-device session endpoints (`/child-auth/pair`, `/child/*`).
class ChildAuthRepository {
  ChildAuthRepository(this._client, this._storage);

  final ApiClient _client;
  final SecureTokenStorage _storage;

  static const sessionKind = 'child';

  /// Redeem a pairing code. On success the child token becomes the active
  /// session of this install.
  Future<ChildSession> pair(
    String code, {
    required String deviceName,
    String? appVersion,
  }) async {
    final normalized = normalizePairingCode(code);
    if (normalized == null) {
      throw const ApiException(
        kind: ApiErrorKind.validation,
        fieldErrors: {
          'code': ['invalid'],
        },
      );
    }
    final installId = await _storage.readOrCreateInstallId();
    final envelope = await _client.post(
      '/child-auth/pair',
      body: {
        'code': normalized,
        'device_name': deviceName,
        'platform': _platform(),
        // A child install has its own identity, separate from any parent
        // registration of the same phone (shared devices).
        'install_id_hash': 'child_$installId',
        'app_version': ?appVersion,
      },
    );
    final data = envelope.dataMap;
    final token = data['token'] as String?;
    if (token == null || token.isEmpty) {
      throw const ApiException(kind: ApiErrorKind.server);
    }
    await _storage.writeToken(token);
    await _storage.writeSessionKind(sessionKind);
    return ChildSession.fromJson(
      (data['session'] as Map).cast<String, dynamic>(),
    );
  }

  Future<ChildSession> me() async {
    final envelope = await _client.get('/child/me');
    return ChildSession.fromJson(envelope.dataMap);
  }

  Future<void> updatePushToken(String? pushToken) async {
    await _client.put('/child/device', body: {'push_token': pushToken});
  }

  /// End the child session on this install. Local wipe always happens.
  Future<void> logout() async {
    try {
      await _client.post('/child/logout');
    } on ApiException {
      // Local wipe below is what matters.
    } finally {
      await _storage.clearSession();
    }
  }

  static String _platform() => switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'ios',
    TargetPlatform.android => 'android',
    _ => 'web',
  };
}

final childAuthRepositoryProvider = Provider<ChildAuthRepository>(
  (ref) => ChildAuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(secureStorageProvider),
  ),
);
