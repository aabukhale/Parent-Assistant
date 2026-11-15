import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:my_app/core/localization/locale_controller.dart';
import 'package:my_app/features/auth/application/auth_controller.dart';
import 'package:my_app/features/auth/application/auth_state.dart';
import 'package:my_app/features/auth/data/auth_requests.dart';
import 'package:my_app/features/auth/data/models/child_session.dart';
import 'package:my_app/features/auth/presentation/role_entry_screen.dart';
import 'package:my_app/l10n/app_localizations.dart';

import '../../support/fixtures.dart';
import '../../support/test_api.dart';

Map<String, dynamic> _me({String? preferred, String? effective}) {
  final me =
      jsonDecode(File('test/fixtures/kid/me.json').readAsStringSync())
          as Map<String, dynamic>;
  final child = (me['data'] as Map<String, dynamic>)['child'] as Map;
  child['preferred_language'] = preferred;
  child['effective_language'] = effective;
  return me;
}

Future<void> _settle(TestApi api, bool Function(AuthState) done) async {
  for (var i = 0; i < 100; i++) {
    if (done(api.container.read(authControllerProvider))) return;
    await Future<void>.delayed(Duration.zero);
  }
}

/// A phone whose own (device/parent) language is English, paired to a child.
Future<TestApi> _childPhone(Map<String, dynamic> me) async {
  final api = TestApi.create(token: 'child-tok', locale: 'en');
  await api.storage.writeSessionKind('child');
  api.adapter.onGet('/child/me', (s) => s.reply(200, me));
  api.container.read(authControllerProvider);
  await _settle(api, (s) => s.isChild);
  return api;
}

String _locale(TestApi api) =>
    api.container.read(localeControllerProvider).languageCode;

void main() {
  test(
    "the child app follows the language the parent set for that child",
    () async {
      final api = await _childPhone(_me(preferred: 'he', effective: 'he'));
      addTearDown(api.dispose);

      expect(_locale(api), 'he');
      // Not written as the device's own language.
      expect(await api.storage.readLocale(), 'en');
    },
  );

  test('a child without a setting gets the family default', () async {
    final api = await _childPhone(_me(preferred: null, effective: 'ar'));
    addTearDown(api.dispose);

    expect(_locale(api), 'ar');
  });

  test(
    'a language changed by a parent applies on the next session read',
    () async {
      final api = await _childPhone(_me(preferred: 'he', effective: 'he'));
      addTearDown(api.dispose);
      expect(_locale(api), 'he');

      // What the sync_profile signal / app resume triggers.
      api.adapter.onGet(
        '/child/me',
        (s) => s.reply(200, _me(preferred: 'en', effective: 'en')),
      );
      await api.container
          .read(authControllerProvider.notifier)
          .refreshSession();

      expect(_locale(api), 'en');
      expect(
        api.container.read(authControllerProvider).childSession?.language,
        'en',
      );
    },
  );

  test('the cached session keeps the language for offline restarts', () {
    final session = ChildSession.fromJson(
      (_me(preferred: null, effective: 'he')['data'] as Map)
          .cast<String, dynamic>(),
    );
    final restored = ChildSession.fromJson(
      jsonDecode(jsonEncode(session.toJson())) as Map<String, dynamic>,
    );
    expect(restored.language, 'he');
    expect(restored.preferredLanguage, isNull);
  });

  test('when the child signs out the device language comes back', () async {
    final api = await _childPhone(_me(preferred: 'he', effective: 'he'));
    addTearDown(api.dispose);
    api.adapter.onPost(
      '/child/logout',
      (s) => s.reply(200, {'success': true, 'data': null}),
    );

    await api.container.read(authControllerProvider.notifier).logout();
    await Future<void>.delayed(Duration.zero);

    expect(_locale(api), 'en');
  });

  test(
    "a parent stepping in gets the parent's language, not the child's",
    () async {
      final api = await _childPhone(_me(preferred: 'he', effective: 'he'));
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
          .login(
            const LoginInput(
              login: 'parent@example.com',
              password: 'secret-password',
              deviceName: 'Shared phone',
            ),
          );
      await Future<void>.delayed(Duration.zero);

      // Fixtures' parent account is Arabic.
      expect(_locale(api), 'ar');
    },
  );

  group('a child session that ends on its own says why', () {
    Future<TestApi> restoreWith(String deviceState) async {
      final api = TestApi.create(token: 'child-tok', locale: 'en');
      await api.storage.writeSessionKind('child');
      await api.storage.writeChildDeviceId('device-1');
      api.adapter
        ..onGet(
          '/child/me',
          (s) =>
              s.reply(401, {'success': false, 'message': 'Unauthenticated.'}),
        )
        ..onPost(
          '/child-auth/device-status',
          (s) => s.reply(200, {
            'success': true,
            'data': {'state': deviceState},
          }),
          data: Matchers.any,
        );
      api.container.read(authControllerProvider);
      await _settle(api, (s) => s.phase == AuthPhase.unauthenticated);
      return api;
    }

    test('unpaired by a parent', () async {
      final api = await restoreWith('revoked');
      addTearDown(api.dispose);
      expect(
        api.container.read(authControllerProvider).childSessionEnd,
        ChildSessionEnd.revoked,
      );
      expect(await api.storage.readToken(), isNull);
    });

    test('expired (still paired): not reported as an unpair', () async {
      final api = await restoreWith('active');
      addTearDown(api.dispose);
      expect(
        api.container.read(authControllerProvider).childSessionEnd,
        ChildSessionEnd.expired,
      );
    });

    testWidgets('the role chooser tells the child to ask for a new code', (
      tester,
    ) async {
      final api = await tester.runAsync(() => restoreWith('revoked'));
      addTearDown(api!.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: api.container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: RoleEntryScreen(),
          ),
        ),
      );
      await tester.pump();
      final l = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l.childSessionEndedRevoked), findsOneWidget);
    });
  });
}
