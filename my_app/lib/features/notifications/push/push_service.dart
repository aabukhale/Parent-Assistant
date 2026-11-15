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
  'safety': 'Safety and help (urgent)',
  'location': 'Arrivals and check-ins',
  'remote': 'Help and call requests',
};

/// The parts of Firebase Messaging the app uses. A seam so the token
/// lifecycle (permission → APNs → FCM token → backend, logout cleanup) can be
/// tested without Firebase.
abstract class PushMessaging {
  Future<AuthorizationStatus> authorizationStatus();
  Future<AuthorizationStatus> requestPermission();

  /// iOS only: the APNs device token. FCM cannot issue a token before iOS
  /// has handed one to the app (needs the aps-environment entitlement and a
  /// provisioning profile with Push Notifications).
  Future<String?> apnsToken();
  Future<String?> token();
  Future<void> deleteToken();
  Stream<String> get onTokenRefresh;
}

class FirebasePushMessaging implements PushMessaging {
  const FirebasePushMessaging();

  FirebaseMessaging get _m => FirebaseMessaging.instance;

  @override
  Future<AuthorizationStatus> authorizationStatus() async =>
      (await _m.getNotificationSettings()).authorizationStatus;

  @override
  Future<AuthorizationStatus> requestPermission() async =>
      (await _m.requestPermission()).authorizationStatus;

  @override
  Future<String?> apnsToken() => _m.getAPNSToken();

  @override
  Future<String?> token() => _m.getToken();

  @override
  Future<void> deleteToken() => _m.deleteToken();

  @override
  Stream<String> get onTokenRefresh => _m.onTokenRefresh;
}

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
  PushService(this._ref)
    : _messaging = const FirebasePushMessaging(),
      _platformOverride = null;

  /// Tests: Firebase is "ready" with [messaging] standing in for it.
  @visibleForTesting
  PushService.withMessaging(
    this._ref,
    PushMessaging messaging, {
    TargetPlatform? platform,
    this.apnsWait = const Duration(milliseconds: 1),
  }) : _messaging = messaging,
       _platformOverride = platform,
       _firebaseReady = true;

  final Ref _ref;
  final PushMessaging _messaging;
  final TargetPlatform? _platformOverride;
  final _local = FlutterLocalNotificationsPlugin();
  bool _firebaseReady = false;
  StreamSubscription<String>? _tokenSub;
  Future<void>? _registering;

  /// How long to wait between checks for the iOS APNs token (10 checks).
  @visibleForTesting
  Duration apnsWait = const Duration(seconds: 1);

  final availability = ValueNotifier<PushAvailability>(
    PushAvailability.notConfigured,
  );

  /// True once this install's token was accepted by the backend for the
  /// current session, i.e. the server can reach this phone by push. While
  /// false, the parent shell's inbox polling shows new items as local
  /// banners instead (foreground only).
  final delivering = ValueNotifier<bool>(false);

  bool get isConfigured => _firebaseReady;

  TargetPlatform get _platform => _platformOverride ?? defaultTargetPlatform;

  Future<void> initialize() async {
    await _initLocal();
    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
    } catch (e) {
      // Missing platform config (e.g. GoogleService-Info.plist not in the
      // app bundle): push stays off, everything else works.
      debugPrint('Push disabled: Firebase not configured (${e.runtimeType}).');
      availability.value = PushAvailability.notConfigured;
      return;
    }

    await refreshAvailability();

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

    listenForTokenRefresh();
  }

  /// FCM rotates tokens, and on iOS issues the first one only after APNs
  /// registration completes: every new token goes to the backend.
  @visibleForTesting
  void listenForTokenRefresh() {
    _tokenSub?.cancel();
    _tokenSub = _messaging.onTokenRefresh.listen((t) {
      if (availability.value == PushAvailability.granted) {
        _sendTokenToBackend(t);
      }
    });
  }

  /// Re-read the OS permission. It can change outside this service: in
  /// Settings, or through another permission prompt (local notifications).
  Future<PushAvailability> refreshAvailability() async {
    if (!_firebaseReady) return availability.value;
    try {
      availability.value = _map(await _messaging.authorizationStatus());
    } catch (e) {
      debugPrint('Push permission unknown: ${e.runtimeType}');
    }
    return availability.value;
  }

  Future<void> _initLocal() async {
    try {
      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_stat_mamily'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
            defaultPresentAlert: true,
            defaultPresentBanner: true,
            defaultPresentList: true,
            defaultPresentSound: true,
            defaultPresentBadge: true,
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
            // Urgent alerts use the highest importance; Do Not Disturb still
            // applies unless the person allows this channel to override it.
            importance: e.key == 'safety' ? Importance.max : Importance.high,
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
    availability.value = _map(await _messaging.requestPermission());
    if (availability.value == PushAvailability.granted) {
      if (_platform == TargetPlatform.android) {
        try {
          await _local
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission();
        } catch (_) {
          // Local notifications unavailable: remote pushes still work.
        }
      }
      await registerCurrentSession();
    }
    return availability.value;
  }

  /// The OS permission for notifications shown by the app itself (the
  /// floating card's persistent "turn off" notification on Android 13+).
  /// Works without Firebase. Returns true when allowed.
  Future<bool> requestLocalNotificationPermission() async {
    try {
      final android = _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }

      final ios = _local
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();

      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  /// Bind this install's FCM token to whoever is signed in now. Concurrent
  /// calls (shell start + permission grant) share one registration.
  Future<void> registerCurrentSession() =>
      _registering ??= _register().whenComplete(() => _registering = null);

  Future<void> _register() async {
    if (!_firebaseReady) return;
    if (await refreshAvailability() != PushAvailability.granted) return;
    try {
      if (_platform == TargetPlatform.iOS && !await _waitForApnsToken()) {
        // No APNs token yet: missing aps-environment entitlement / push
        // provisioning, or iOS is still registering. onTokenRefresh sends
        // the FCM token once it exists.
        debugPrint('Push: APNs token not available yet.');
        return;
      }
      final token = await _messaging.token();
      if (token != null) await _sendTokenToBackend(token);
    } catch (e) {
      debugPrint('Push token unavailable: ${e.runtimeType}');
    }
  }

  Future<bool> _waitForApnsToken() async {
    for (var i = 0; i < 10; i++) {
      final apns = await _messaging.apnsToken();
      if (apns != null && apns.isNotEmpty) return true;
      await Future<void>.delayed(apnsWait);
    }
    return false;
  }

  Future<void> _sendTokenToBackend(String token) async {
    final auth = _ref.read(authControllerProvider);
    try {
      if (auth.isChild) {
        await _ref.read(childAuthRepositoryProvider).updatePushToken(token);
        delivering.value = true;
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
                platform: _platform == TargetPlatform.iOS
                    ? DevicePlatform.ios
                    : DevicePlatform.android,
                deviceMode: DeviceMode.familyShared,
                deviceIdentifierHash: installId,
                pushToken: token,
              ),
            );
        delivering.value = true;
      }
    } catch (e) {
      debugPrint('Push token registration failed: ${e.runtimeType}');
    }
  }

  /// Logout / revoke: stop pushes to this install immediately (the backend
  /// also clears its copy) and remove anything already shown.
  /// The next session gets a fresh token, so nothing addressed to the
  /// previous person can arrive (the backend also drops a token as soon as
  /// another device row claims it).
  Future<void> onSessionEnded() async {
    delivering.value = false;
    try {
      await _local.cancelAll();
    } catch (_) {}
    try {
      if (_firebaseReady) await _messaging.deleteToken();
    } catch (_) {}
  }

  Future<void> _onForegroundMessage(RemoteMessage m) async {
    // Data-only "something changed" signals: re-read state from the API.
    // A push is only a hint — nothing is assumed applied until the phone
    // reports it.
    final signal = m.data['signal'] as String?;
    if (signal != null) {
      onSignal?.call(signal);
      return;
    }
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

  /// Display a newly received inbox item as a local iOS banner.
  Future<void> showLocalInboxNotification({
    required String id,
    required String title,
    required String body,
    String? route,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;

    await _local.show(
      id: id.hashCode & 0x7fffffff,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentSound: true,
        ),
      ),
      payload: route,
    );
  }

  /// Set by the child shell: 'sync_rules' → device rules sync,
  /// 'remote_session' → remote-session refresh, 'sync_profile' → re-read the
  /// child session (e.g. a parent changed the child's language).
  void Function(String signal)? onSignal;

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
    availability.dispose();
    delivering.dispose();
  }
}

final pushServiceProvider = Provider<PushService>((ref) {
  final s = PushService(ref);
  ref.onDispose(s.dispose);
  return s;
});
