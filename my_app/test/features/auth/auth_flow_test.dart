import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:my_app/core/errors/api_exception.dart';
import 'package:my_app/core/providers.dart';
import 'package:my_app/features/auth/application/auth_controller.dart';
import 'package:my_app/features/auth/application/auth_state.dart';
import 'package:my_app/features/auth/data/auth_requests.dart';

import '../../support/fixtures.dart';
import '../../support/test_api.dart';

/// Pumps the microtask queue until [test] passes or we give up.
Future<AuthState> _settle(TestApi api, bool Function(AuthState) test) async {
  for (var i = 0; i < 50; i++) {
    final state = api.container.read(authControllerProvider);
    if (test(state)) return state;
    await Future<void>.delayed(Duration.zero);
  }
  return api.container.read(authControllerProvider);
}

void main() {
  test('no stored token → unauthenticated after restore', () async {
    final api = TestApi.create(token: null);
    addTearDown(api.dispose);
    api.container.read(authControllerProvider); // start restore

    final state = await _settle(api, (s) => s.phase != AuthPhase.restoring);
    expect(state.phase, AuthPhase.unauthenticated);
  });

  test(
    'valid stored token → authenticated with single family auto-selected',
    () async {
      final api = TestApi.create(token: 'tok_abc123');
      addTearDown(api.dispose);
      api.adapter.onGet('/auth/me', (s) => s.reply(200, Fixtures.meEnvelope()));

      api.container.read(authControllerProvider);
      final state = await _settle(
        api,
        (s) => s.phase == AuthPhase.authenticated,
      );

      expect(state.isAuthenticated, isTrue);
      expect(state.session!.user.firstName, 'Moaz');
      expect(state.activeMembership!.familyId, 'family-1');
      expect(await api.storage.readActiveFamilyId(), 'family-1');
    },
  );

  test(
    'stored token rejected with 401 → token wiped, unauthenticated',
    () async {
      final api = TestApi.create(token: 'stale');
      addTearDown(api.dispose);
      api.adapter.onGet(
        '/auth/me',
        (s) => s.reply(401, {'success': false, 'message': 'Unauthenticated.'}),
      );

      api.container.read(authControllerProvider);
      final state = await _settle(
        api,
        (s) => s.phase == AuthPhase.unauthenticated,
      );

      expect(state.phase, AuthPhase.unauthenticated);
      expect(await api.storage.readToken(), isNull);
    },
  );

  test(
    'offline during restore → restoreFailed, token kept for retry',
    () async {
      final api = TestApi.create(token: 'tok_abc123');
      addTearDown(api.dispose);
      api.adapter.onGet(
        '/auth/me',
        (s) => s.reply(503, {'success': false, 'message': 'down'}),
      );

      api.container.read(authControllerProvider);
      final state = await _settle(
        api,
        (s) => s.phase == AuthPhase.restoreFailed,
      );

      expect(state.phase, AuthPhase.restoreFailed);
      expect(await api.storage.readToken(), 'tok_abc123');
    },
  );

  test(
    'login success stores token and hydrates the session via /auth/me',
    () async {
      final api = TestApi.create(token: null);
      addTearDown(api.dispose);
      api.adapter
        ..onPost(
          '/auth/login',
          (s) => s.reply(200, Fixtures.loginEnvelope()),
          data: Matchers.any,
        )
        ..onGet('/auth/me', (s) => s.reply(200, Fixtures.meEnvelope()));

      await _settle(api, (s) => s.phase == AuthPhase.unauthenticated);
      await api.container
          .read(authControllerProvider.notifier)
          .login(
            const LoginInput(
              login: 'moaz@example.com',
              password: 'secret',
              deviceName: 'test',
            ),
          );

      expect(
        api.container.read(authControllerProvider).isAuthenticated,
        isTrue,
      );
      expect(await api.storage.readToken(), 'tok_abc123');
    },
  );

  test(
    'login failure surfaces a validation ApiException and stays logged out',
    () async {
      final api = TestApi.create(token: null);
      addTearDown(api.dispose);
      api.adapter.onPost(
        '/auth/login',
        (s) => s.reply(
          422,
          Fixtures.validationError(
            errors: {
              'login': ['These credentials do not match our records.'],
            },
          ),
        ),
        data: Matchers.any,
      );

      await _settle(api, (s) => s.phase == AuthPhase.unauthenticated);

      ApiException? caught;
      try {
        await api.container
            .read(authControllerProvider.notifier)
            .login(
              const LoginInput(
                login: 'x@y.com',
                password: 'bad',
                deviceName: 'test',
              ),
            );
      } on ApiException catch (e) {
        caught = e;
      }

      expect(caught, isNotNull);
      expect(caught!.isValidation, isTrue);
      expect(caught.fieldError('login'), contains('do not match'));
      expect(
        api.container.read(authControllerProvider).phase,
        AuthPhase.unauthenticated,
      );
      expect(await api.storage.readToken(), isNull);
    },
  );

  test('logout revokes server-side and clears local state', () async {
    final api = TestApi.create(token: 'tok_abc123');
    addTearDown(api.dispose);
    api.adapter
      ..onGet('/auth/me', (s) => s.reply(200, Fixtures.meEnvelope()))
      ..onPost(
        '/auth/logout',
        (s) => s.reply(200, Fixtures.messageEnvelope('Logged out.')),
        data: Matchers.any,
      );

    api.container.read(authControllerProvider);
    await _settle(api, (s) => s.phase == AuthPhase.authenticated);

    await api.container.read(authControllerProvider.notifier).logout();

    expect(
      api.container.read(authControllerProvider).phase,
      AuthPhase.unauthenticated,
    );
    expect(await api.storage.readToken(), isNull);
  });

  test(
    'a mid-session 401 signal drops an authenticated session to logged out',
    () async {
      final api = TestApi.create(token: 'tok_abc123');
      addTearDown(api.dispose);
      api.adapter
        ..onGet('/auth/me', (s) => s.reply(200, Fixtures.meEnvelope()))
        ..onGet(
          '/interests',
          (s) =>
              s.reply(401, {'success': false, 'message': 'Unauthenticated.'}),
        );

      api.container.read(authControllerProvider);
      await _settle(api, (s) => s.phase == AuthPhase.authenticated);

      // Any authenticated call returning 401 trips the interceptor.
      try {
        await api.container.read(apiClientProvider).get('/interests');
      } on ApiException {
        // expected
      }

      await _settle(api, (s) => s.phase == AuthPhase.unauthenticated);
      expect(
        api.container.read(authControllerProvider).phase,
        AuthPhase.unauthenticated,
      );
    },
  );
}
