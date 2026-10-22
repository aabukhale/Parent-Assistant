import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/cache/offline_cache.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/util/client_id.dart';
import '../../auth/application/auth_controller.dart';
import '../../kid/application/kid_providers.dart';
import 'native_enforcement.dart';

/// Child device: keeps the phone's enforcement in step with the parent's
/// rules, and tells the parent the truth about it.
///
///   1. fetch the compiled policy (or use the cached one when offline)
///   2. ignore anything older than what is already applied (out-of-order)
///   3. report "received"
///   4. hand it to the native mechanism; report its own verdict ("applied",
///      "unsupported", "permission_needed" …) plus capabilities
///   5. re-verify on later syncs ("observed")
///
/// A push only *triggers* a sync; nothing is considered applied until the
/// native layer says so. The cached policy lets enforcement keep working
/// (and expiring exceptions keep expiring) without connectivity.
class DeviceRulesSync {
  DeviceRulesSync(
    this._client,
    this._cache,
    this._scope,
    this._native, {
    this.onUsageUploaded,
  });

  /// Lets the child's screen-time view refresh once fresh usage is on the
  /// server (otherwise "minutes left" lags behind what the phone enforces).
  final void Function()? onUsageUploaded;

  final ApiClient _client;
  final OfflineCache _cache;
  final String _scope;
  final NativeEnforcement _native;

  Timer? _timer;
  bool _running = false;
  DateTime? _lastAppsUpload;

  void startPeriodic() {
    _timer ??= Timer.periodic(const Duration(minutes: 15), (_) => sync());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<int> _appliedVersion() async {
    final v = await _cache.read(_scope, 'applied_policy_version');
    return (v?.data as num?)?.toInt() ?? -1;
  }

  Future<Map<String, dynamic>?> _fetchPolicy() async {
    try {
      final p = (await _client.get('/child/device-policy')).dataMap;
      await _cache.write(_scope, 'device_policy', p);
      return p;
    } on ApiException catch (e) {
      if (e.kind != ApiErrorKind.network && e.kind != ApiErrorKind.timeout) {
        rethrow;
      }
      final cached = await _cache.read(_scope, 'device_policy');
      return (cached?.data as Map?)?.cast<String, dynamic>();
    }
  }

  Future<void> sync() async {
    if (_running) return;
    _running = true;
    try {
      final caps = await _native.capabilities();
      final policy = await _fetchPolicy();
      if (policy == null) return;
      final version = (policy['version'] as num?)?.toInt() ?? 0;
      final applied = await _appliedVersion();

      Future<void> report(Map<String, Object?> body) async {
        try {
          await _client.post('/child/device-policy/status', body: body);
        } catch (_) {}
      }

      if (version < applied) {
        // Stale (out-of-order) policy: keep what is applied, just re-verify.
        final ok = await _native.verify(applied);
        await report({
          'received_version': applied,
          'observed': ok,
          'capabilities': caps,
        });
        return;
      }

      await report({'received_version': version, 'capabilities': caps});

      final result = await _native.apply(policy);
      final ok = result.status == 'applied' || result.status == 'partial'
          ? await _native.verify(version)
          : false;
      if (result.status == 'applied' || result.status == 'partial') {
        await _cache.write(_scope, 'applied_policy_version', version);
      }
      await report({
        'received_version': version,
        'applied_version': version,
        'apply_status': result.status,
        'observed': ok,
        'capabilities': caps,
        'results': [
          for (final r in result.results)
            {'rule': r['rule'] ?? '', 'state': r['state'] ?? ''},
        ],
        'error': ?result.error,
      });

      await _ackCommands(version);
      if (caps['usage_reporting'] == 'available') await _uploadUsage();
      await _uploadApps();
    } catch (e) {
      debugPrint('Device rules sync failed: ${e.runtimeType}');
    } finally {
      _running = false;
    }
  }

  Future<void> _ackCommands(int appliedVersion) async {
    try {
      final list = (await _client.get('/child/device-commands')).dataList;
      for (final c in list.whereType<Map>()) {
        final id = c['id'] as String;
        final type = c['type'] as String?;
        final status = switch (type) {
          'sync_rules' =>
            ((c['policy_version'] as num?)?.toInt() ?? 0) <= appliedVersion
                ? 'applied'
                : 'failed',
          _ => 'applied',
        };
        await _client.post(
          '/child/device-commands/$id/ack',
          body: {'status': status},
        );
      }
    } catch (_) {}
  }

  Future<void> _uploadUsage() async {
    final last = await _cache.read(_scope, 'usage_uploaded_until');
    final from =
        DateTime.tryParse((last?.data as String?) ?? '') ??
        DateTime.now().subtract(const Duration(days: 1));
    final until = DateTime.now();
    final events = await _native.usageSince(from);
    if (events.isEmpty) return;
    try {
      for (var i = 0; i < events.length; i += 200) {
        await _client.post(
          '/child/usage',
          body: {
            'batch_id': newClientId(),
            'events': events.sublist(i, (i + 200).clamp(0, events.length)),
          },
        );
      }
      await _cache.write(
        _scope,
        'usage_uploaded_until',
        until.toIso8601String(),
      );
    } catch (_) {}
  }

  Future<void> _uploadApps() async {
    final now = DateTime.now();
    if (_lastAppsUpload != null &&
        now.difference(_lastAppsUpload!) < const Duration(hours: 6)) {
      return;
    }
    final apps = await _native.installedApps();
    if (apps.isEmpty) return;
    try {
      await _client.put(
        '/child/device-apps',
        body: {'apps': apps.take(500).toList()},
      );
      _lastAppsUpload = now;
    } catch (_) {}
  }
}

final nativeEnforcementProvider = Provider<NativeEnforcement>(
  (_) => const NativeEnforcement(),
);

final deviceRulesSyncProvider = Provider<DeviceRulesSync>((ref) {
  final childId = ref.watch(childSessionProvider)?.childId ?? 'none';
  final sync = DeviceRulesSync(
    ref.watch(apiClientProvider),
    ref.watch(offlineCacheProvider),
    'child_$childId',
    ref.watch(nativeEnforcementProvider),
    onUsageUploaded: () => ref.invalidate(kidScreenTimeProvider),
  );
  ref.onDispose(sync.stop);
  return sync;
});

/// Whether OS-level rules are in force on this phone right now.
final deviceEnforcementActiveProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(nativeEnforcementProvider).enforcementActive(),
);

/// What this phone can enforce right now (for setup prompts on the child's
/// phone). Refreshed after a setup step.
final deviceCapabilitiesProvider =
    FutureProvider.autoDispose<Map<String, String>>(
      (ref) => ref.watch(nativeEnforcementProvider).capabilities(),
    );
