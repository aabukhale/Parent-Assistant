import 'package:flutter/foundation.dart';

/// Tolerant parsing of the backend's standard response envelope:
///
/// ```json
/// { "success": true, "message": "OK", "data": <any>, "meta": { ... }? , "errors": { ... }? }
/// ```
///
/// Small fixed catalogs (`interests`, `screen-time-rules`, `content-policy`,
/// `game-progress`) return a plain `data` array with **no** `meta`.
@immutable
class ApiEnvelope {
  const ApiEnvelope({
    required this.success,
    required this.message,
    required this.data,
    this.meta,
  });

  final bool success;
  final String message;
  final Object? data;
  final Map<String, dynamic>? meta;

  factory ApiEnvelope.fromJson(Object? body) {
    if (body is Map<String, dynamic>) {
      return ApiEnvelope(
        success: body['success'] as bool? ?? true,
        message: body['message'] as String? ?? 'OK',
        data: body.containsKey('data') ? body['data'] : body,
        meta: body['meta'] is Map<String, dynamic>
            ? body['meta'] as Map<String, dynamic>
            : null,
      );
    }
    // A bare array or primitive — treat the whole payload as `data`.
    return ApiEnvelope(success: true, message: 'OK', data: body);
  }

  Map<String, dynamic> get dataMap {
    final d = data;
    if (d is Map<String, dynamic>) return d;
    throw StateError('Expected a JSON object in "data", got ${d.runtimeType}');
  }

  List<dynamic> get dataList {
    final d = data;
    if (d is List) return d;
    if (d is Map<String, dynamic> && d['data'] is List) {
      return d['data'] as List;
    }
    throw StateError('Expected a JSON array in "data", got ${d.runtimeType}');
  }
}

/// Pagination block from `meta`.
@immutable
class PageMeta {
  const PageMeta({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  bool get hasMore => currentPage < lastPage;
  int get nextPage => currentPage + 1;

  factory PageMeta.fromJson(Map<String, dynamic> json) => PageMeta(
    currentPage: (json['current_page'] as num?)?.toInt() ?? 1,
    lastPage: (json['last_page'] as num?)?.toInt() ?? 1,
    perPage: (json['per_page'] as num?)?.toInt() ?? 0,
    total: (json['total'] as num?)?.toInt() ?? 0,
  );

  /// Single-page fallback for endpoints that return a plain array with no meta.
  factory PageMeta.single(int count) =>
      PageMeta(currentPage: 1, lastPage: 1, perPage: count, total: count);
}

/// A page of [T] plus its pagination cursor.
@immutable
class Paginated<T> {
  const Paginated({required this.items, required this.meta});

  final List<T> items;
  final PageMeta meta;

  bool get hasMore => meta.hasMore;
  bool get isEmpty => items.isEmpty;

  Paginated<T> append(Paginated<T> next) =>
      Paginated(items: [...items, ...next.items], meta: next.meta);

  static Paginated<T> from<T>(
    ApiEnvelope envelope,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final list = envelope.dataList
        .whereType<Map<String, dynamic>>()
        .map(fromJson)
        .toList(growable: false);
    final meta = envelope.meta != null
        ? PageMeta.fromJson(envelope.meta!)
        : PageMeta.single(list.length);
    return Paginated(items: list, meta: meta);
  }
}
