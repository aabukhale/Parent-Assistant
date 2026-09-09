import 'package:flutter/foundation.dart';

/// The categories of failure a screen may need to react to differently.
enum ApiErrorKind {
  /// No usable connection / DNS / socket failure.
  network,

  /// Connect or receive timeout.
  timeout,

  /// 401 — token missing, invalid or expired. Triggers a session wipe.
  unauthorized,

  /// 403 — authenticated but not permitted (caregiver missing a grant).
  forbidden,

  /// 404 — resource does not exist or the caller is not a family member.
  notFound,

  /// 409 — domain/state conflict (already reviewed, overlap, duplicate pending…).
  conflict,

  /// 422 — Laravel validation error. [ApiException.fieldErrors] is populated.
  validation,

  /// 429 — rate limited.
  rateLimited,

  /// 503 — feature not configured / provider unavailable (e.g. AI generation).
  unavailable,

  /// 5xx (other) — unexpected server error.
  server,

  /// Anything we could not classify.
  unknown,
}

/// A typed, user-safe failure raised by the data layer.
///
/// Never surface [rawMessage] or [cause] directly to end users — screens map
/// [kind] (and [fieldErrors]) to localized copy. [rawMessage] is for logging
/// and for the debug error surface only.
@immutable
class ApiException implements Exception {
  const ApiException({
    required this.kind,
    this.statusCode,
    this.rawMessage,
    this.fieldErrors = const {},
    this.cause,
  });

  final ApiErrorKind kind;
  final int? statusCode;

  /// The `message` field from the backend envelope, if any. Logging/debug only.
  final String? rawMessage;

  /// Laravel `errors` map: field name -> list of messages. Only for [ApiErrorKind.validation].
  final Map<String, List<String>> fieldErrors;

  final Object? cause;

  bool get isUnauthorized => kind == ApiErrorKind.unauthorized;
  bool get isValidation => kind == ApiErrorKind.validation;
  bool get isConflict => kind == ApiErrorKind.conflict;

  /// First message for [field], if the backend reported one.
  String? fieldError(String field) {
    final messages = fieldErrors[field];
    if (messages == null || messages.isEmpty) return null;
    return messages.first;
  }

  @override
  String toString() =>
      'ApiException(kind: $kind, status: $statusCode, message: $rawMessage, fields: ${fieldErrors.keys.toList()})';
}
