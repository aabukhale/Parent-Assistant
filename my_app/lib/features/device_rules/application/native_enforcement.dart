import 'package:flutter/services.dart';

/// Bridge to the platform's *real* enforcement mechanisms:
///
/// * Android — only when Mamily is the device owner (provisioned at setup):
///   `DevicePolicyManager.setPackagesSuspended`, Chrome managed
///   configuration for websites, UsageStatsManager for usage (needs the
///   "Usage access" permission). An ordinary install reports app blocking
///   as `setup_needed`, never pretends.
/// * iOS — Family Controls / Managed Settings / Device Activity (iOS 16+,
///   entitlement + authorization required). Usage data cannot leave the
///   device on iOS, so `usage_reporting` is always `unsupported` there.
///
/// Missing native code (tests, desktop) answers "unsupported" for
/// everything.
class NativeEnforcement {
  const NativeEnforcement();

  static const _ch = MethodChannel('mamily/device_rules');

  static const capabilityKeys = [
    'app_blocking',
    'app_limits',
    'schedules',
    'web_filter',
    'restrict_now',
    'usage_reporting',
    'device_lock',
  ];

  Future<Map<String, String>> capabilities() async {
    try {
      final m = await _ch.invokeMapMethod<String, String>('capabilities');
      if (m != null) return m;
    } on MissingPluginException {
      // fall through
    } on PlatformException {
      // fall through
    }
    return {for (final k in capabilityKeys) k: 'unsupported'};
  }

  /// Applies [policy] (the compiled policy from the server). Returns the
  /// mechanism's own verdict: applied | partial | permission_needed |
  /// unsupported | failed, with per-rule results.
  Future<({String status, List<Map<String, String>> results, String? error})>
  apply(Map<String, dynamic> policy) async {
    try {
      final r = await _ch.invokeMapMethod<String, Object?>('apply', policy);
      return (
        status: (r?['status'] as String?) ?? 'failed',
        results: ((r?['results'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => m.map((k, v) => MapEntry('$k', '$v')))
            .toList(),
        error: r?['error'] as String?,
      );
    } on MissingPluginException {
      return (
        status: 'unsupported',
        results: const <Map<String, String>>[],
        error: null,
      );
    } on PlatformException catch (e) {
      return (
        status: 'failed',
        results: const <Map<String, String>>[],
        error: e.code,
      );
    }
  }

  /// Re-checks that the enforcement for [version] is still in place (e.g.
  /// suspended packages are still suspended, shields still set).
  Future<bool> verify(int version) async {
    try {
      return await _ch.invokeMethod<bool>('verify', {'version': version}) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Whether this phone currently enforces rules at the OS level (used to
  /// decide whether a child may sign out alone).
  Future<bool> enforcementActive() async {
    try {
      return await _ch.invokeMethod<bool>('enforcementActive') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Removes every restriction Mamily applied. Only called when the backend
  /// revoked this install (unpaired) — never by a child action.
  Future<void> clear() async {
    try {
      await _ch.invokeMethod<void>('clear');
    } catch (_) {}
  }

  /// Android: launchable apps (package, label, category) so a parent can
  /// choose apps from their own phone.
  Future<List<Map<String, String>>> installedApps() async {
    try {
      final l = await _ch.invokeListMethod<Map>('installedApps');
      return (l ?? const [])
          .map((m) => m.map((k, v) => MapEntry('$k', '$v')))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Android: foreground usage per app between [from] and now, as usage
  /// events ready for `/child/usage`.
  Future<List<Map<String, Object?>>> usageSince(DateTime from) async {
    try {
      final l = await _ch.invokeListMethod<Map>('usageSince', {
        'from': from.millisecondsSinceEpoch,
      });
      return (l ?? const [])
          .map((m) => m.map((k, v) => MapEntry('$k', v)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Opens the system screen for a missing permission/setup step:
  /// usage_access | family_controls | location.
  Future<bool> openSetup(String what) async {
    try {
      return await _ch.invokeMethod<bool>('openSetup', {'what': what}) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// iOS: show Apple's app picker on this (child's) device, with a parent
  /// present. Returns opaque token data — names can't be read by apps.
  Future<List<Map<String, String>>?> pickApps({
    String? currentSelection,
  }) async {
    try {
      final l = await _ch.invokeListMethod<Map>('pickApps', {
        'selection': currentSelection,
      });
      return l?.map((m) => m.map((k, v) => MapEntry('$k', '$v'))).toList();
    } catch (_) {
      return null;
    }
  }
}
