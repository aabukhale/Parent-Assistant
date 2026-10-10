import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/deep_links.dart';
import '../../../core/config/device_label.dart';
import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/child_auth_repository.dart';
import '../../devices/data/devices_repository.dart';
import '../../devices/data/models/device.dart';
import '../application/notifications_controller.dart';

/// Whether this build can receive pushes and what the user decided.
enum PushAvailability {
  /// Firebase isn't configured in this build (no google-services.json /
  /// GoogleService-Info.plist). The in-app inbox still works.
  notConfigured,

  /// Configured, permission not asked yet.
  notDetermined,
  granted,
  denied,
}

/// Android channels, one per category, so people can tune them in Settings.
const _channels = <String, String>{
  'tasks': 'Tasks',
  'approvals': 'Requests & approvals',
  'rewards': 'Rewards',
  'routines': 'Routines',
  'challenges': 'Family challenges',
  'encouragement': 'Encouragement',
  'checkins': 'Check-ins',
  'screen_time': 'Screen time',
  'planner': 'Family planner',
  'devices': 'Devices',
};

/// Push notifications via FCM (Android + iOS/APNs through Firebase), with
/// local notifications for foreground display.
///
/// * Never asks for permission at launch — [requestPermission] is called from
///   an explained onboarding step.
/// * Tokens are tied to the signed-in session on this install and sent to the
///   backend; logout deletes the FCM token locally and the backend clears it.
/// * Tapping a notification goes through the role-checked [DeepLinks] router
///   (foreground, background and terminated launches).
class PushService {
  PushService(this._ref);

  final Ref _ref;
  final _local = FlutterLocalNotificationsPlugin();
  bool _firebaseReady = false;
  StreamSubscription<String>? _tokenSub;

  final availability = ValueNotifier<PushAvailability>(
    PushAvailability.notConfigured,
  );

  bool get isConfigured => _firebaseReady;

  Future<void> initialize() async {
    await _initLocal();
    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
    } catch (e) {
      // Missing platform config: push stays off, everything else works.
      debugPrint('Push disabled: Firebase not configured (${e.runtimeType}).');
      availability.value = PushAvailability.notConfigured;
      return;
    }

    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    availability.value = _map(settings.authorizationStatus);

    // iOS: show banners while the app is open too (we also keep the inbox).
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(
      (m) => _openRoute(m.data['route'] as String?),
    );
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _stashRoute(initial.data['route'] as String?);

    _tokenSub = FirebaseMessaging.instance.onTokenRefresh.listen(
      (t) => _sendTokenToBackend(t),
    );
  }

  Future<void> _initLocal() async {
    try {
      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (r) => _openRoute(r.payload),
      );
      final launch = await _local.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _stashRoute(launch!.notificationResponse?.payload);
      }

      final android = _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      for (final e in _channels.entries) {
        await android?.createNotificationChannel(
          AndroidNotificationChannel(
            'mamily_${e.key}',
            e.value,
            importance: Importance.high,
          ),
        );
      }
    } catch (e) {
      debugPrint('Local notifications unavailable: ${e.runtimeType}');
    }
  }

  /// Ask the OS for permission. Call only after explaining why.
  Future<PushAvailability> requestPermission() async {
    if (!_firebaseReady) return PushAvailability.notConfigured;
    final s = await FirebaseMessaging.instance.requestPermission();
    availability.value = _map(s.authorizationStatus);
    if (availability.value == PushAvailability.granted) {
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      await registerCurrentSession();
    }
    return availability.value;
  }

  /// Bind this install's FCM token to whoever is signed in now.
  Future<void> registerCurrentSession() async {
    if (!_firebaseReady || availability.value != PushAvailability.granted) {
      return;
    }
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _sendTokenToBackend(token);
    } catch (e) {
      debugPrint('Push token unavailable: ${e.runtimeType}');
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    final auth = _ref.read(authControllerProvider);
    try {
      if (auth.isChild) {
        await _ref.read(childAuthRepositoryProvider).updatePushToken(token);
      } else if (auth.isAuthenticated && auth.activeMembership != null) {
        final installId = await _ref
            .read(secureStorageProvider)
            .readOrCreateInstallId();
        await _ref
            .read(devicesRepositoryProvider)
            .register(
              auth.activeMembership!.familyId,
              DeviceRegisterInput(
                name: currentDeviceLabel(),
                platform: defaultTargetPlatform == TargetPlatform.iOS
                    ? DevicePlatform.ios
                    : DevicePlatform.android,
                deviceMode: DeviceMode.familyShared,
                deviceIdentifierHash: installId,
                pushToken: token,
              ),
            );
      }
    } catch (e) {
      debugPrint('Push token registration failed: ${e.runtimeType}');
    }
  }

  /// Logout / revoke: stop pushes to this install immediately (the backend
  /// also clears its copy) and remove anything already shown.
  Future<void> onSessionEnded() async {
    try {
      await _local.cancelAll();
      if (_firebaseReady) await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  Future<void> _onForegroundMessage(RemoteMessage m) async {
    _ref.invalidate(unreadCountProvider);
    final n = m.notification;
    if (n == null) return;
    // On iOS the system already presents it (setForegroundNotificationPresentationOptions).
    if (defaultTargetPlatform == TargetPlatform.iOS) return;
    final category = (m.data['category'] as String?) ?? 'tasks';
    await _local.show(
      id: m.messageId.hashCode,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'mamily_$category',
          _channels[category] ?? 'Mamily',
          importance: Importance.high,
          priority: Priority.high,
          visibility: NotificationVisibility.private,
        ),
      ),
      payload: m.data['route'] as String?,
    );
  }

  void _stashRoute(String? route) {
    if (route == null || route.isEmpty) return;
    _ref.read(pendingDeepLinkProvider.notifier).state = route;
  }

  void _openRoute(String? route) {
    if (route == null || route.isEmpty) return;
    DeepLinks.openWith(_ref.read, route);
  }

  static PushAvailability _map(AuthorizationStatus s) => switch (s) {
    AuthorizationStatus.authorized ||
    AuthorizationStatus.provisional => PushAvailability.granted,
    AuthorizationStatus.denied => PushAvailability.denied,
    _ => PushAvailability.notDetermined,
  };

  void dispose() {
    _tokenSub?.cancel();
  }
}

final pushServiceProvider = Provider<PushService>((ref) {
  final s = PushService(ref);
  ref.onDispose(s.dispose);
  return s;
});
