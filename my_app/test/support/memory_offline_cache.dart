import 'package:my_app/core/cache/offline_cache.dart';

/// In-memory [OfflineCache] for widget tests: real file I/O never completes
/// inside the fake-async zone `testWidgets` runs in.
class MemoryOfflineCache extends OfflineCache {
  final Map<String, CachedValue> _entries = {};

  @override
  Future<void> write(String scope, String key, Object? data) async =>
      _entries['$scope/$key'] = CachedValue(
        data: data,
        savedAt: DateTime.now(),
      );

  @override
  Future<CachedValue?> read(String scope, String key) async =>
      _entries['$scope/$key'];

  @override
  Future<void> clear() async => _entries.clear();
}
