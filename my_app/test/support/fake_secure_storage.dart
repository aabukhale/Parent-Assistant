import 'package:my_app/core/storage/secure_token_storage.dart';

/// In-memory [SecureTokenStorage] for tests — never touches the platform
/// Keychain/Keystore.
class FakeSecureTokenStorage implements SecureTokenStorage {
  FakeSecureTokenStorage({
    String? token,
    String? locale,
    String? activeFamilyId,
    String? sessionKind,
    String? parkedChildToken,
  }) : _token = token,
       _locale = locale,
       _activeFamilyId = activeFamilyId,
       _sessionKind = sessionKind,
       _parkedChild = parkedChildToken;

  String? _token;
  String? _locale;
  String? _activeFamilyId;
  String? _sessionKind;
  String? _parkedChild;

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> writeToken(String token) async => _token = token;

  @override
  Future<void> deleteToken() async => _token = null;

  @override
  Future<bool> hasToken() async => (_token ?? '').isNotEmpty;

  bool _celebrations = true;
  String? _childDevice;
  String? _childSessionCache;

  @override
  Future<String?> readChildSessionCache() async => _childSessionCache;

  @override
  Future<void> writeChildSessionCache(String json) async =>
      _childSessionCache = json;

  @override
  Future<String?> readChildDeviceId() async => _childDevice;

  @override
  Future<void> writeChildDeviceId(String id) async => _childDevice = id;

  @override
  Future<void> deleteChildDeviceId() async => _childDevice = null;

  @override
  Future<bool> readCelebrations() async => _celebrations;

  @override
  Future<void> writeCelebrations(bool on) async => _celebrations = on;

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
  Future<String?> readSessionKind() async => _sessionKind;

  @override
  Future<void> writeSessionKind(String kind) async => _sessionKind = kind;

  @override
  Future<String?> readParkedChildToken() async => _parkedChild;

  @override
  Future<void> writeParkedChildToken(String token) async =>
      _parkedChild = token;

  @override
  Future<void> deleteParkedChildToken() async => _parkedChild = null;

  @override
  Future<void> clearSession() async {
    _token = null;
    _sessionKind = null;
    _activeFamilyId = null;
  }

  @override
  Future<void> clearEverything() async {
    await clearSession();
    _parkedChild = null;
  }
}
