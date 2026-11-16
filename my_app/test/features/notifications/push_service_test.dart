import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:my_app/features/auth/application/auth_controller.dart';
import 'package:my_app/features/notifications/push/push_service.dart';

import '../../support/fixtures.dart';
import '../../support/test_api.dart';

/// Scripted stand-in for Firebase Messaging.
class FakePushMessaging implements PushMessaging {
  AuthorizationStatus status = AuthorizationStatus.notDetermined;
  AuthorizationStatus statusAfterPrompt = AuthorizationStatus.authorized;

  /// Values returned by successive [apnsToken] calls (last one repeats).
  List<String?> apnsSequence = ['apns-device-token'];
  String? fcmToken = 'fcm-token-1';

  final calls = <String>[];
  final refresh = StreamController<String>.broadcast();
  int _apnsIndex = 0;

  @override
  Future<AuthorizationStatus> authorizationStatus() async {
    calls.add('status');
    return status;
  }

  @override
  Future<AuthorizationStatus> requestPermission() async {
    calls.add('prompt');
    status = statusAfterPrompt;
    return status;
  }

  @override
  Future<String?> apnsToken() async {
    calls.add('apns');
    final v =
        apnsSequence[_apnsIndex.clamp(0, apnsSequence.length - 1).toInt()];
    _apnsIndex++;
    return v;
  }

  @override
  Future<String?> token() async {
    calls.add('token');
    return fcmToken;
  }

  @override
  Future<void> deleteToken() async {
    calls.add('delete');
  }

  @override
  Stream<String> get onTokenRefresh => refresh.stream;
}

Future<void> _settle(TestApi api, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// A child phone (paired) with [messaging] standing in for Firebase.
Future<TestApi> _childPhone(
  FakePushMessaging messaging, {
  TargetPlatform platform = TargetPlatform.iOS,
}) async {
  final api = TestApi.create(
    token: 'child-tok',
    locale: 'en',
    overrides: [
      pushServiceProvider.overrideWith(
        (ref) => PushService.withMessaging(ref, messaging, platform: platform),
      ),
    ],
  );
  await api.storage.writeSessionKind('child');
  final me = jsonDecode(File('test/fixtures/kid/me.json').readAsStringSync());
  api.adapter
    ..onGet('/child/me', (s) => s.reply(200, me))
    ..onPut(
      '/child/device',
      (s) => s.reply(200, {'success': true, 'data': {}}),
      data: Matchers.any,
    );
  api.container.read(authControllerProvider);
  await _settle(api, () => api.container.read(authControllerProvider).isChild);
  return api;
}

List<Object?> _sentTokens(TestApi api) => api.requests
    .where((r) => r.path.endsWith('/child/device'))
    .map((r) => (r.data as Map)['push_token'])
    .toList();

void main() {
  test('iOS waits for the APNs token before asking FCM for one', () async {
    final fake = FakePushMessaging()
      ..status = AuthorizationStatus.authorized
      ..apnsSequence = [null, null, 'apns-device-token'];
    final api = await _childPhone(fake);
    addTearDown(api.dispose);

    await api.container.read(pushServiceProvider).registerCurrentSession();

    expect(fake.calls.where((c) => c == 'apns'), hasLength(3));
    expect(
      fake.calls.indexOf('token'),
      greaterThan(fake.calls.lastIndexOf('apns')),
    );
    expect(_sentTokens(api), ['fcm-token-1']);
    final push = api.container.read(pushServiceProvider);
    expect(push.tokenRegistered.value, isTrue);
    // A stored token doesn't prove pushes arrive (APNs key / provider
    // credentials can be missing): the polled banners stay on until one does.
    expect(push.delivering.value, isFalse);
  });

  test('without an APNs token (no push entitlement) nothing is sent', () async {
    final fake = FakePushMessaging()
      ..status = AuthorizationStatus.authorized
      ..apnsSequence = [null];
    final api = await _childPhone(fake);
    addTearDown(api.dispose);

    await api.container.read(pushServiceProvider).registerCurrentSession();

    expect(fake.calls, isNot(contains('token')));
    expect(_sentTokens(api), isEmpty);
    expect(
      api.container.read(pushServiceProvider).tokenRegistered.value,
      isFalse,
    );
  });

  test(
    'a permission granted elsewhere is picked up before registering',
    () async {
      // Regression: availability was read once at launch, so a later grant
      // (another prompt, Settings) never registered the token.
      final fake = FakePushMessaging()
        ..status = AuthorizationStatus.notDetermined;
      final api = await _childPhone(fake);
      addTearDown(api.dispose);
      final push = api.container.read(pushServiceProvider);
      await push.refreshAvailability();
      expect(push.availability.value, PushAvailability.notDetermined);

      fake.status = AuthorizationStatus.authorized;
      await push.registerCurrentSession();

      expect(_sentTokens(api), ['fcm-token-1']);
    },
  );

  test('denied permission never sends a token', () async {
    final fake = FakePushMessaging()..status = AuthorizationStatus.denied;
    final api = await _childPhone(fake);
    addTearDown(api.dispose);

    await api.container.read(pushServiceProvider).registerCurrentSession();

    expect(fake.calls, isNot(contains('token')));
    expect(_sentTokens(api), isEmpty);
  });

  test('asking permission once registers the token when granted', () async {
    final fake = FakePushMessaging();
    final api = await _childPhone(fake);
    addTearDown(api.dispose);

    final result = await api.container
        .read(pushServiceProvider)
        .requestPermission();

    expect(result, PushAvailability.granted);
    expect(fake.calls.where((c) => c == 'prompt'), hasLength(1));
    expect(_sentTokens(api), ['fcm-token-1']);
  });

  test('a refreshed token replaces the old one on the backend', () async {
    final fake = FakePushMessaging()..status = AuthorizationStatus.authorized;
    final api = await _childPhone(fake);
    addTearDown(api.dispose);
    final push = api.container.read(pushServiceProvider)
      ..listenForTokenRefresh();
    await push.registerCurrentSession();

    fake.refresh.add('fcm-token-2');
    await _settle(api, () => _sentTokens(api).length == 2);

    expect(_sentTokens(api), ['fcm-token-1', 'fcm-token-2']);
  });

  test('concurrent registrations send the token once', () async {
    final fake = FakePushMessaging()..status = AuthorizationStatus.authorized;
    final api = await _childPhone(fake);
    addTearDown(api.dispose);
    final push = api.container.read(pushServiceProvider);

    await Future.wait([
      push.registerCurrentSession(),
      push.registerCurrentSession(),
    ]);

    expect(_sentTokens(api), ['fcm-token-1']);
  });

  test(
    'ending the session deletes the token so the next person gets a new one',
    () async {
      final fake = FakePushMessaging()..status = AuthorizationStatus.authorized;
      final api = await _childPhone(fake);
      addTearDown(api.dispose);
      final push = api.container.read(pushServiceProvider);
      await push.registerCurrentSession();
      expect(push.tokenRegistered.value, isTrue);

      await push.onSessionEnded();

      expect(fake.calls.last, 'delete');
      expect(push.tokenRegistered.value, isFalse);
      expect(push.delivering.value, isFalse);
    },
  );

  test('a parent registers this install with its token', () async {
    final fake = FakePushMessaging()..status = AuthorizationStatus.authorized;
    final api = TestApi.create(
      token: 'parent-tok',
      locale: 'en',
      overrides: [
        pushServiceProvider.overrideWith(
          (ref) => PushService.withMessaging(
            ref,
            fake,
            platform: TargetPlatform.android,
          ),
        ),
      ],
    );
    addTearDown(api.dispose);
    api.adapter
      ..onGet('/auth/me', (s) => s.reply(200, Fixtures.meEnvelope()))
      ..onPost(
        '/families/family-1/devices',
        (s) => s.reply(201, {
          'success': true,
          'data': {
            'id': 'device-1',
            'name': 'Phone',
            'platform': 'android',
            'device_mode': 'family_shared',
            'is_active': true,
          },
        }),
        data: Matchers.any,
      );
    api.container.read(authControllerProvider);
    await _settle(
      api,
      () => api.container.read(authControllerProvider).isAuthenticated,
    );

    await api.container.read(pushServiceProvider).registerCurrentSession();

    final body =
        api.requests
                .singleWhere(
                  (r) => r.path.endsWith('/families/family-1/devices'),
                )
                .data
            as Map;
    expect(body['push_token'], 'fcm-token-1');
    expect(body['platform'], 'android');
    // Android needs no APNs token.
    expect(fake.calls, isNot(contains('apns')));
  });
}
