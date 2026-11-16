import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:my_app/core/errors/api_exception.dart';
import 'package:my_app/features/auth/application/auth_controller.dart';
import 'package:my_app/features/auth/application/auth_state.dart';
import 'package:my_app/features/auth/data/auth_requests.dart';

import '../../support/fixtures.dart';
import '../../support/test_api.dart';

Future<AuthState> _settle(TestApi api, bool Function(AuthState) test) async {
  for (var i = 0; i < 50; i++) {
    final state = api.container.read(authControllerProvider);
    if (test(state)) return state;
    await Future<void>.delayed(Duration.zero);
  }
  return api.container.read(authControllerProvider);
}

const _parentLogin = LoginInput(
  login: 'parent@example.com',
  password: 'secret-password',
  deviceName: 'Shared phone',
);

/// A phone paired to a child, where a parent signs in for a moment.
Future<TestApi> _childPhone() async {
  final api = TestApi.create(token: 'child-tok', locale: 'en');
  await api.storage.writeSessionKind('child');
  final me = jsonDecode(File('test/fixtures/kid/me.json').readAsStringSync());
  api.adapter.onGet('/child/me', (s) => s.reply(200, me));
  api.container.read(authControllerProvider);
  final state = await _settle(api, (s) => s.isChild);
  expect(state.isChild, isTrue);
  return api;
}

void main() {
  test('a mistyped parent password leaves the child signed in', () async {
    final api = await _childPhone();
    addTearDown(api.dispose);
    api.adapter.onPost(
      '/auth/login',
      (s) =>
          s.reply(401, {'success': false, 'message': 'Invalid credentials.'}),
      data: Matchers.any,
    );

    await expectLater(
      api.container.read(authControllerProvider.notifier).login(_parentLogin),
      throwsA(
        isA<ApiException>().having(
          (e) => e.kind,
          'kind',
          ApiErrorKind.invalidCredentials,
        ),
      ),
    );

    expect(api.container.read(authControllerProvider).isChild, isTrue);
    expect(await api.storage.readToken(), 'child-tok');
    expect(await api.storage.readSessionKind(), 'child');
    expect(await api.storage.readParkedChildToken(), isNull);
  });

  test('a successful parent sign-in parks the child session', () async {
    final api = await _childPhone();
    addTearDown(api.dispose);
    api.adapter
      ..onPost(
        '/auth/login',
        (s) => s.reply(200, Fixtures.loginEnvelope(token: 'parent-tok')),
        data: Matchers.any,
      )
      ..onGet('/auth/me', (s) => s.reply(200, Fixtures.meEnvelope()));

    await api.container
        .read(authControllerProvider.notifier)
        .login(_parentLogin);

    final state = api.container.read(authControllerProvider);
    expect(state.isAuthenticated && !state.isChild, isTrue);
    expect(state.hasParkedChild, isTrue);
    expect(await api.storage.readToken(), 'parent-tok');
    expect(await api.storage.readParkedChildToken(), 'child-tok');
  });
}
