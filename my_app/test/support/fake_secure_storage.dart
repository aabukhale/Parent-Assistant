import 'package:my_app/core/storage/secure_token_storage.dart';

/// In-memory [SecureTokenStorage] for tests — never touches the platform
/// Keychain/Keystore.
class FakeSecureTokenStorage implements SecureTokenStorage {
  FakeSecureTokenStorage({
    String? token,
    String? locale,
    String? activeFamilyId,
  }) : _token = token,
       _locale = locale,
       _activeFamilyId = activeFamilyId;

  String? _token;
  String? _locale;
  String? _activeFamilyId;

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> writeToken(String token) async => _token = token;

  @override
  Future<void> deleteToken() async => _token = null;

  @override
  Future<bool> hasToken() async => (_token ?? '').isNotEmpty;

  @override
  Future<String?> readLocale() async => _locale;

  @override
  Future<void> writeLocale(String languageCode) async => _locale = languageCode;

  @override
  Future<String?> readActiveFamilyId() async => _activeFamilyId;

  @override
  Future<void> writeActiveFamilyId(String familyId) async =>
      _activeFamilyId = familyId;

  @override
  Future<void> deleteActiveFamilyId() async => _activeFamilyId = null;

  String? _installId;

  @override
  Future<String> readOrCreateInstallId() async =>
      _installId ??= 'install_test_fixed';

  @override
  Future<void> clearSession() async {
    _token = null;
    _activeFamilyId = null;
  }
}
