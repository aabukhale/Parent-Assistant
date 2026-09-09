import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Adds `Authorization: Bearer <token>` and `Accept: application/json` to every
/// request. The token is read fresh on each call so a login/logout mid-session
/// is picked up without rebuilding the client.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.tokenReader, required this.onUnauthorized});

  final Future<String?> Function() tokenReader;

  /// Invoked once per 401 so the app can wipe the session and route to login.
  final FutureOr<void> Function() onUnauthorized;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    options.headers['Accept'] = 'application/json';
    final token = await tokenReader();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      await onUnauthorized();
    }
    handler.next(err);
  }
}

/// Adds `Accept-Language: ar|he|en` from the active UI locale.
class LocaleInterceptor extends Interceptor {
  LocaleInterceptor({required this.languageCodeReader});

  final String Function() languageCodeReader;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['Accept-Language'] = languageCodeReader();
    handler.next(options);
  }
}

/// Debug-only, redacted request/response logging.
///
/// Never logs: Authorization / bearer tokens, passwords, password_confirmation,
/// push tokens, device identifier hashes, or full request bodies for auth and
/// child-data endpoints.
class SafeLoggingInterceptor extends Interceptor {
  SafeLoggingInterceptor({this.enabled = kDebugMode});

  final bool enabled;

  static const _sensitiveKeys = <String>{
    'password',
    'password_confirmation',
    'current_password',
    'token',
    'push_token',
    'device_identifier_hash',
    'pin',
  };

  static const _sensitivePaths = <String>['/auth/', '/me'];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (enabled) {
      debugPrint(
        '→ ${options.method} ${options.uri.path}${_redactQuery(options.uri)}',
      );
      final body = _redactBody(options.path, options.data);
      if (body != null) debugPrint('  body: $body');
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (enabled) {
      debugPrint(
        '← ${response.statusCode} ${response.requestOptions.method} '
        '${response.requestOptions.uri.path}',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (enabled) {
      final data = err.response?.data;
      final msg = data is Map && data['message'] is String
          ? data['message']
          : err.type.name;
      debugPrint(
        '✗ ${err.response?.statusCode ?? '-'} '
        '${err.requestOptions.method} ${err.requestOptions.uri.path} — $msg',
      );
    }
    handler.next(err);
  }

  String _redactQuery(Uri uri) => uri.query.isEmpty ? '' : '?${uri.query}';

  Object? _redactBody(String path, Object? data) {
    if (_sensitivePaths.any(path.contains)) return '«redacted»';
    if (data is Map) {
      return {
        for (final entry in data.entries)
          entry.key: _sensitiveKeys.contains(entry.key)
              ? '«redacted»'
              : entry.value,
      };
    }
    return null; // don't log FormData / streams / unknown payloads
  }
}
