import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/cache/offline_cache.dart';
import '../../../core/util/client_id.dart';
import '../../auth/application/auth_controller.dart';
import '../data/safety_models.dart';
import '../data/safety_repository.dart';

/// Location on the child's device, battery-conscious and visible:
///
/// * Nothing is read or sent unless a parent turned sharing on (server says
///   so) — and the child sees that it is on (Family tab badge, explanation
///   sheet, Android's location notification during a journey).
/// * Routine updates happen when Mamily opens / comes to the foreground and
///   every few minutes while it stays open. During a journey a low-power
///   position stream runs (Android: foreground-service notification; iOS:
///   the blue location indicator).
/// * Safe-place arrivals/departures are evaluated here whenever a fix
///   arrives (no hidden background tracking). They are therefore only as
///   timely as the last update, and the UI never promises instant alerts.
class LocationReporter {
  LocationReporter(this._repo, this._cache, this._scope);

  final KidSafetyRepository _repo;
  final OfflineCache _cache;

  /// Cache namespace of this child session (wiped on sign-out).
  final String _scope;

  StreamSubscription<Position>? _journeyStream;
  Timer? _foregroundTimer;
  bool _sharing = false;
  List<SafePlace> _places = const [];

  bool get sharing => _sharing;

  /// Called on start/resume. Refreshes whether sharing is on, reports device
  /// status (permission, battery) and, if allowed, one fix.
  Future<void> refresh() async {
    try {
      final s = await _repo.locationSettings();
      _sharing = s.sharing;
    } catch (_) {
      // Offline: keep the last known setting.
    }
    await reportStatus();
    if (!_sharing) {
      stopForegroundUpdates();
      return;
    }
    try {
      _places = await _repo.safePlaces();
    } catch (_) {}
    await reportNow(source: 'app');
    startForegroundUpdates();
  }

  /// Permission name as the backend expects it.
  static Future<String> permissionState() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return 'while_in_use';
      return switch (await Geolocator.checkPermission()) {
        LocationPermission.always => 'always',
        LocationPermission.whileInUse => 'while_in_use',
        LocationPermission.deniedForever => 'denied',
        LocationPermission.denied => 'not_determined',
        LocationPermission.unableToDetermine => 'not_determined',
      };
    } catch (_) {
      return 'not_determined';
    }
  }

  static Future<bool> servicesOn() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return false;
    }
  }

  /// Ask for "while using the app" permission (shown after the child saw the
  /// explanation). Returns true if granted.
  static Future<bool> requestPermission() async {
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      return p == LocationPermission.always ||
          p == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (_) {}
  }

  Future<({int? pct, bool? charging})> _battery() async {
    try {
      final b = Battery();
      final level = await b.batteryLevel;
      final state = await b.batteryState;
      return (pct: level, charging: state == BatteryState.charging);
    } catch (_) {
      return (pct: null, charging: null);
    }
  }

  Future<void> reportStatus() async {
    final battery = await _battery();
    try {
      await _repo.reportDeviceStatus({
        'location_permission': await permissionState(),
        'location_services_on': await servicesOn(),
        'battery_pct': ?battery.pct,
        'battery_charging': ?battery.charging,
      });
    } catch (_) {}
  }

  /// One fix with a short timeout; null when not allowed or unavailable.
  static Future<GeoPoint?> currentFix({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm != LocationPermission.always &&
          perm != LocationPermission.whileInUse) {
        return null;
      }
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      ).catchError((_) => Geolocator.getLastKnownPosition().then((p) => p!));
      return GeoPoint(
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracyM: pos.accuracy.round(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> reportNow({required String source}) async {
    if (!_sharing) return;
    final fix = await currentFix();
    if (fix == null) return;
    await _upload(fix, source: source);
  }

  Future<void> _upload(GeoPoint fix, {required String source}) async {
    final battery = await _battery();
    final now = DateTime.now();
    try {
      await _repo.uploadLocations([
        {
          'latitude': fix.latitude,
          'longitude': fix.longitude,
          'accuracy_m': ?fix.accuracyM,
          'recorded_at': now.toUtc().toIso8601String(),
          'battery_pct': ?battery.pct,
          'battery_charging': ?battery.charging,
          'source': source,
          'client_id': newClientId(),
        },
      ]);
    } catch (_) {
      // Best effort: the parent sees the age of the last fix instead.
    }
    await _evaluatePlaces(fix, now);
  }

  /// Compare a fix with the safe places and send arrive/leave transitions.
  /// Fixes less accurate than the place radius are ignored to avoid false
  /// "left home" alerts.
  Future<void> _evaluatePlaces(GeoPoint fix, DateTime at) async {
    if (_places.isEmpty) return;
    final inside = await _loadInside();
    final next = <String>{};
    for (final p in _places) {
      final pt = p.point;
      if (pt == null) continue;
      if ((fix.accuracyM ?? 0) > p.radiusM) {
        if (inside.contains(p.id)) next.add(p.id); // unsure → keep state
        continue;
      }
      final d = Geolocator.distanceBetween(
        fix.latitude,
        fix.longitude,
        pt.latitude,
        pt.longitude,
      );
      // Small hysteresis: enter inside r, leave beyond r + 50 m.
      final isInside = inside.contains(p.id)
          ? d <= p.radiusM + 50
          : d <= p.radiusM;
      if (isInside) next.add(p.id);
      if (isInside != inside.contains(p.id)) {
        try {
          await _repo.placeEvent(
            placeId: p.id,
            type: isInside ? 'arrive' : 'leave',
            occurredAt: at,
            clientEventId: newClientId(),
          );
        } catch (_) {}
      }
    }
    await _saveInside(next);
  }

  Future<Set<String>> _loadInside() async {
    final v = await _cache.read(_scope, 'inside_places');
    if (v?.data is List) return (v!.data as List).cast<String>().toSet();
    return const {};
  }

  Future<void> _saveInside(Set<String> ids) =>
      _cache.write(_scope, 'inside_places', ids.toList());

  void startForegroundUpdates() {
    _foregroundTimer ??= Timer.periodic(
      const Duration(minutes: 5),
      (_) => reportNow(source: 'app'),
    );
  }

  void stopForegroundUpdates() {
    _foregroundTimer?.cancel();
    _foregroundTimer = null;
  }

  /// Journey tracking: a low-power stream with a visible OS indicator.
  void startJourneyTracking() {
    if (_journeyStream != null || !_sharing) return;
    final settings = switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100,
        intervalDuration: const Duration(minutes: 2),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Mamily',
          notificationText:
              'Sharing your location with your family during your trip.',
          enableWakeLock: false,
        ),
      ),
      TargetPlatform.iOS => AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100,
        activityType: ActivityType.otherNavigation,
        pauseLocationUpdatesAutomatically: true,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      ),
      _ => const LocationSettings(distanceFilter: 100),
    };
    try {
      _journeyStream = Geolocator.getPositionStream(locationSettings: settings)
          .listen(
            (pos) => _upload(
              GeoPoint(
                latitude: pos.latitude,
                longitude: pos.longitude,
                accuracyM: pos.accuracy.round(),
              ),
              source: 'journey',
            ),
            onError: (_) => stopJourneyTracking(),
          );
    } catch (_) {
      _journeyStream = null;
    }
  }

  void stopJourneyTracking() {
    _journeyStream?.cancel();
    _journeyStream = null;
  }

  void dispose() {
    stopJourneyTracking();
    stopForegroundUpdates();
  }
}

final locationReporterProvider = Provider<LocationReporter>((ref) {
  final childId = ref.watch(childSessionProvider)?.childId ?? 'none';
  final reporter = LocationReporter(
    ref.watch(kidSafetyRepositoryProvider),
    ref.watch(offlineCacheProvider),
    'child_$childId',
  );
  ref.onDispose(reporter.dispose);
  return reporter;
});
