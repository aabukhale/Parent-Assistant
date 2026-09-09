import 'package:flutter/foundation.dart';

/// Environment-aware configuration.
///
/// The API base URL is supplied at compile time so no developer machine's
/// address is ever hardcoded into the binary:
///
/// ```bash
/// flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1   # iOS sim
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1    # Android emu
/// flutter run --dart-define=API_BASE_URL=https://<ngrok-id>.ngrok.io/api/v1  # device
/// ```
///
/// See `docs/flutter-integration.md` (section "API base URL setup").
@immutable
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.connectTimeout,
    required this.receiveTimeout,
    required this.enableRequestLogging,
  });

  final String apiBaseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;

  /// Safe, redacted request/response logging. Debug builds only.
  final bool enableRequestLogging;

  static const String _rawBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // Sensible default for the most common local setup (iOS simulator / desktop).
    // Android emulators must override with http://10.0.2.2:8000/api/v1.
    defaultValue: 'http://127.0.0.1:8000/api/v1',
  );

  factory AppConfig.fromEnvironment() {
    var base = _rawBaseUrl.trim();
    // Tolerate a trailing slash so callers can always use relative paths.
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return AppConfig(
      apiBaseUrl: base,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      enableRequestLogging: kDebugMode,
    );
  }

  bool get isConfigured =>
      apiBaseUrl.isNotEmpty && Uri.tryParse(apiBaseUrl) != null;
}
