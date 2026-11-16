import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// A small read-through cache of the last successful JSON payloads, so a
/// screen can still show *something honest* while offline ("last updated …").
///
/// Safety rules:
/// * Entries are namespaced by a session scope (family / child id), so one
///   family's data can never be read under another session.
/// * The whole cache directory is deleted on logout / revoke / 401
///   (registered with SessionCleanup in `main.dart`).
/// * Only GET payloads are cached; nothing is replayed to the server.
class OfflineCache {
  OfflineCache({Future<Directory> Function()? baseDir})
    : _baseDir = baseDir ?? _defaultDir;

  final Future<Directory> Function() _baseDir;

  static Future<Directory> _defaultDir() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/mamily_cache');
  }

  Future<File> _file(String scope, String key) async {
    final dir = await _baseDir();
    final safeScope = scope.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final safeKey = key.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return File('${dir.path}/$safeScope/$safeKey.json');
  }

  Future<void> write(String scope, String key, Object? data) async {
    try {
      final f = await _file(scope, key);
      await f.parent.create(recursive: true);
      await f.writeAsString(
        jsonEncode({
          'saved_at': DateTime.now().toUtc().toIso8601String(),
          'data': data,
        }),
      );
    } catch (_) {
      // Caching is best-effort; never fail the screen because of it.
    }
  }

  Future<CachedValue?> read(String scope, String key) async {
    try {
      final f = await _file(scope, key);
      if (!await f.exists()) return null;
      final json = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return CachedValue(
        data: json['data'],
        savedAt: DateTime.parse(json['saved_at'] as String).toLocal(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final dir = await _baseDir();
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }
}

class CachedValue {
  const CachedValue({required this.data, required this.savedAt});

  final Object? data;
  final DateTime savedAt;
}

final offlineCacheProvider = Provider<OfflineCache>((_) => OfflineCache());
