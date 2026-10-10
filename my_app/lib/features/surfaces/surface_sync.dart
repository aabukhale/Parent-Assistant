import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';
import '../auth/application/auth_controller.dart';

/// Out-of-app surfaces for parents: the home-screen widget (Android + iOS
/// WidgetKit) and the optional Android floating Family Pulse card.
///
/// Data comes from `GET /families/{f}/pulse/surface`, which already drops
/// anything the parent didn't allow (names, mood, points are off by default).
/// Every write carries `generated_at` so the widget can show "updated X ago"
/// and a stale state instead of pretending to be live. Logout wipes it all.
class SurfaceSync {
  SurfaceSync(this._ref);

  final Ref _ref;

  static const appGroupId = 'group.com.mamily.app';
  static const androidWidget = 'FamilyPulseWidgetProvider';
  static const iosWidget = 'FamilyPulseWidget';
  static const _overlay = MethodChannel('mamily/overlay');
  static const dataKey = 'mamily_surface';

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Pull the latest surface payload for the active family and push it to
  /// the widget (and the overlay if it is running). Call on resume and after
  /// approvals — never on a timer.
  Future<void> refresh() async {
    if (!_supported) return;
    final auth = _ref.read(authControllerProvider);
    final familyId = auth.activeMembership?.familyId;
    if (!auth.isAuthenticated || familyId == null) return;
    try {
      final ApiClient client = _ref.read(apiClientProvider);
      final env = await client.get('/families/$familyId/pulse/surface');
      final payload = jsonEncode({
        ...env.dataMap,
        'family_id': familyId,
        'written_at': DateTime.now().toUtc().toIso8601String(),
      });
      await HomeWidget.setAppGroupId(appGroupId);
      await HomeWidget.saveWidgetData<String>(dataKey, payload);
      await HomeWidget.updateWidget(
        androidName: androidWidget,
        iOSName: iosWidget,
      );
      await _invokeOverlay('update', {'payload': payload});
    } catch (e) {
      // Keep the last data; the widget shows its age and goes "stale".
      debugPrint('Surface refresh skipped: ${e.runtimeType}');
    }
  }

  /// Wipe widget data and stop the overlay (logout, revoke, account switch).
  Future<void> clearAll() async {
    if (!_supported) return;
    try {
      await HomeWidget.setAppGroupId(appGroupId);
      await HomeWidget.saveWidgetData<String>(dataKey, null);
      await HomeWidget.updateWidget(
        androidName: androidWidget,
        iOSName: iosWidget,
      );
    } catch (_) {}
    await _invokeOverlay('stop', const {});
  }

  // ---- Android floating card -------------------------------------------------

  bool get overlaySupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> hasOverlayPermission() async =>
      (await _invokeOverlay<bool>('hasPermission', const {})) ?? false;

  /// Opens the system "Display over other apps" settings page for Mamily.
  Future<void> openOverlayPermissionSettings() =>
      _invokeOverlay('requestPermission', const {});

  Future<bool> isOverlayRunning() async =>
      (await _invokeOverlay<bool>('isRunning', const {})) ?? false;

  Future<bool> startOverlay() async {
    final started = (await _invokeOverlay<bool>('start', const {})) ?? false;
    if (started) await refresh();
    return started;
  }

  Future<void> stopOverlay() => _invokeOverlay('stop', const {});

  Future<T?> _invokeOverlay<T>(String method, Map<String, Object?> args) async {
    if (!overlaySupported) return null;
    try {
      return await _overlay.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('Overlay $method failed: ${e.code}');
      return null;
    }
  }
}

final surfaceSyncProvider = Provider<SurfaceSync>(SurfaceSync.new);
