import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The **only** place the Sanctum bearer token is persisted.
///
/// Backed by the iOS Keychain / Android Keystore-wrapped storage. Passwords are
/// never stored here (or anywhere on device). The user's preferred UI locale is
/// also kept here so it can be applied before the first frame and sent on the
/// very first API call.
class SecureTokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'mamily.auth.token';
  static const _localeKey = 'mamily.ui.locale';
  static const _activeFamilyKey = 'mamily.family.active';
  static const _installIdKey = 'mamily.device.install_id';

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> writeToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<void> deleteToken() => _storage.delete(key: _tokenKey);

  Future<bool> hasToken() async => (await readToken())?.isNotEmpty ?? false;

  Future<String?> readLocale() => _storage.read(key: _localeKey);

  Future<void> writeLocale(String languageCode) =>
      _storage.write(key: _localeKey, value: languageCode);

  /// Last family the user acted in — restored on next launch when the user
  /// belongs to more than one family.
  Future<String?> readActiveFamilyId() => _storage.read(key: _activeFamilyKey);

  Future<void> writeActiveFamilyId(String familyId) =>
      _storage.write(key: _activeFamilyKey, value: familyId);

  Future<void> deleteActiveFamilyId() => _storage.delete(key: _activeFamilyKey);

  /// A stable per-install identifier, created once and reused. It is an
  /// **app-generated random id**, not a hardware/advertising id — it is sent
  /// verbatim as `device_identifier_hash` when registering a device so a
  /// repeated registration from this install de-duplicates (the backend matches
  /// on the exact string) rather than creating a new device row. Survives logout
  /// (a device belongs to the install, not the session); cleared only if the app
  /// data is wiped.
  Future<String> readOrCreateInstallId() async {
    final existing = await _storage.read(key: _installIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final generated = 'install_$hex';
    await _storage.write(key: _installIdKey, value: generated);
    return generated;
  }

  /// Wipe the auth token and family selection. Called on logout and on a hard
  /// 401. The UI locale preference **and** the install id are intentionally kept.
  Future<void> clearSession() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _activeFamilyKey);
  }
}
