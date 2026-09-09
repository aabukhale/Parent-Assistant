import 'package:dio/dio.dart';

import '../errors/api_exception.dart';
import 'api_envelope.dart';

/// Thin wrapper over [Dio] that every repository uses.
///
/// - Returns a parsed [ApiEnvelope] on success.
/// - Converts *all* failures ([DioException], parse errors) into a typed
///   [ApiException] — repositories and controllers never see a raw Dio error.
class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  Dio get raw => _dio;

  Future<ApiEnvelope> get(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) => _send(
    () => _dio.get<dynamic>(
      path,
      queryParameters: query,
      cancelToken: cancelToken,
    ),
  );

  Future<ApiEnvelope> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) => _send(
    () => _dio.post<dynamic>(
      path,
      data: body,
      queryParameters: query,
      cancelToken: cancelToken,
    ),
  );

  Future<ApiEnvelope> patch(String path, {Object? body}) =>
      _send(() => _dio.patch<dynamic>(path, data: body));

  Future<ApiEnvelope> put(String path, {Object? body}) =>
      _send(() => _dio.put<dynamic>(path, data: body));

  Future<ApiEnvelope> delete(String path, {Object? body}) =>
      _send(() => _dio.delete<dynamic>(path, data: body));

  Future<ApiEnvelope> _send(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      final response = await request();
      return ApiEnvelope.fromJson(response.data);
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(kind: ApiErrorKind.unknown, cause: e);
    }
  }

  ApiException _mapDioException(DioException e) {
    const timeouts = {
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
    };
    if (timeouts.contains(e.type)) {
      return ApiException(kind: ApiErrorKind.timeout, cause: e);
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.badCertificate) {
      return ApiException(kind: ApiErrorKind.network, cause: e);
    }
    if (e.type == DioExceptionType.cancel) {
      return ApiException(kind: ApiErrorKind.unknown, cause: e);
    }
    // badResponse / unknown / anything new — fall through to status mapping.

    final status = e.response?.statusCode;
    final body = e.response?.data;
    final message = body is Map && body['message'] is String
        ? body['message'] as String
        : null;
    final fieldErrors = _parseFieldErrors(body);

    final kind = switch (status) {
      401 => ApiErrorKind.unauthorized,
      403 => ApiErrorKind.forbidden,
      404 => ApiErrorKind.notFound,
      409 => ApiErrorKind.conflict,
      422 => ApiErrorKind.validation,
      429 => ApiErrorKind.rateLimited,
      503 => ApiErrorKind.unavailable,
      _ when status != null && status >= 500 => ApiErrorKind.server,
      _ when status != null && status >= 400 => ApiErrorKind.unknown,
      _ => ApiErrorKind.network,
    };

    return ApiException(
      kind: kind,
      statusCode: status,
      rawMessage: message,
      fieldErrors: fieldErrors,
      cause: e,
    );
  }

  Map<String, List<String>> _parseFieldErrors(Object? body) {
    if (body is! Map || body['errors'] is! Map) return const {};
    final raw = body['errors'] as Map;
    final result = <String, List<String>>{};
    raw.forEach((key, value) {
      if (value is List) {
        result['$key'] = value.map((v) => '$v').toList();
      } else if (value != null) {
        result['$key'] = ['$value'];
      }
    });
    return result;
  }
}
