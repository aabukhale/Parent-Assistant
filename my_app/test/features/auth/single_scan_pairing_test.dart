import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:my_app/features/auth/application/auth_controller.dart';
import 'package:my_app/features/auth/presentation/pairing_screen.dart';
import 'package:my_app/features/family_hub/presentation/pairing_sheet.dart';
import 'package:my_app/l10n/app_localizations.dart';

import '../../support/test_api.dart';

Widget _host(TestApi api, Widget home, {Locale locale = const Locale('en')}) =>
    UncontrolledProviderScope(
      container: api.container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: home,
      ),
    );

Map<String, dynamic> _pairResponse() {
  final me =
      (jsonDecode(File('test/fixtures/kid/me.json').readAsStringSync())
          as Map<String, dynamic>)['data'];
  return {
    'success': true,
    'data': {'token': 'child-tok', 'token_type': 'Bearer', 'session': me},
  };
}

void main() {
  final l = lookupAppLocalizations(const Locale('en'));

  group('child phone', () {
    late TestApi api;
    setUp(() => api = TestApi.create(token: null, locale: 'en'));
    tearDown(() => api.dispose());

    int pairCalls() =>
        api.requests.where((r) => r.path.endsWith('/child-auth/pair')).length;

    testWidgets('a scanned link pairs straight away — one scan, no tap', (
      tester,
    ) async {
      api.adapter.onPost(
        '/child-auth/pair',
        (s) => s.reply(201, _pairResponse()),
        data: Matchers.any,
      );

      await tester.pumpWidget(
        _host(
          api,
          const PairingScreen(initialCode: 'DZQN9N6K', autoSubmit: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(pairCalls(), 1);
      expect(api.container.read(authControllerProvider).isChild, isTrue);
      expect(
        api.container.read(authControllerProvider).childSession?.name,
        'Omar',
      );
    });

    testWidgets('a prefilled code without autoSubmit waits for the child', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(api, const PairingScreen(initialCode: 'DZQN9N6K')),
      );
      await tester.pumpAndSettle();
      expect(pairCalls(), 0);
    });

    testWidgets('an expired or already-used code says to ask for a new one', (
      tester,
    ) async {
      api.adapter.onPost(
        '/child-auth/pair',
        (s) => s.reply(422, {
          'success': false,
          'message': 'The given data was invalid.',
          'errors': {
            'code': [
              'This pairing code is invalid or has expired. Ask a parent for a new one.',
            ],
          },
        }),
        data: Matchers.any,
      );

      await tester.pumpWidget(
        _host(
          api,
          const PairingScreen(initialCode: 'DZQN9N6K', autoSubmit: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(l.pairInvalid), findsOneWidget);
      expect(api.container.read(authControllerProvider).isChild, isFalse);
      // Typing a new code and joining is still possible.
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    });

    testWidgets('a network failure can be retried without scanning again', (
      tester,
    ) async {
      api.adapter.onPost(
        '/child-auth/pair',
        (s) => s.throws(
          0,
          DioException.connectionError(
            requestOptions: RequestOptions(path: '/child-auth/pair'),
            reason: 'offline',
          ),
        ),
        data: Matchers.any,
      );

      await tester.pumpWidget(
        _host(
          api,
          const PairingScreen(initialCode: 'DZQN9N6K', autoSubmit: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(l.errorNetwork), findsOneWidget);

      api.adapter.onPost(
        '/child-auth/pair',
        (s) => s.reply(201, _pairResponse()),
        data: Matchers.any,
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(api.container.read(authControllerProvider).isChild, isTrue);
    });

    testWidgets('pairing screen is right-to-left in Arabic and Hebrew', (
      tester,
    ) async {
      for (final (code, dir) in [
        ('ar', TextDirection.rtl),
        ('he', TextDirection.rtl),
        ('en', TextDirection.ltr),
      ]) {
        await tester.pumpWidget(
          _host(api, const PairingScreen(), locale: Locale(code)),
        );
        await tester.pumpAndSettle();
        final ctx = tester.element(find.byType(TextField));
        expect(Directionality.of(ctx), dir, reason: code);
        expect(
          find.text(lookupAppLocalizations(Locale(code)).pairTitle),
          findsOneWidget,
        );
      }
    });
  });

  group('parent phone', () {
    late TestApi api;
    setUp(() {
      api = TestApi.create(
        token: 'parent-tok',
        locale: 'en',
        activeFamilyId: 'family-1',
      );
      pairingStatusPollInterval = const Duration(milliseconds: 500);
    });
    tearDown(() => api.dispose());

    testWidgets('the sheet says "Paired!" as soon as the child scans', (
      tester,
    ) async {
      const base = '/families/family-1/children/child-1';
      api.adapter
        ..onPost(
          '$base/pairing-codes',
          (s) => s.reply(201, {
            'success': true,
            'data': {
              'id': 'code-1',
              'child_id': 'child-1',
              'device_mode': 'child_dedicated',
              'state': 'active',
              'expires_at': DateTime.now()
                  .add(const Duration(minutes: 10))
                  .toUtc()
                  .toIso8601String(),
              'code': 'DZQN-9N6K',
              'qr_payload': 'mamily://pair?code=DZQN9N6K',
            },
          }),
          data: Matchers.any,
        )
        ..onGet(
          '$base/pairing-codes/code-1',
          (s) => s.reply(200, {
            'success': true,
            'data': {
              'id': 'code-1',
              'child_id': 'child-1',
              'device_mode': 'child_dedicated',
              'state': 'used',
              'used_device_name': 'Omar’s iPad',
              'expires_at': DateTime.now().toUtc().toIso8601String(),
            },
          }),
        )
        ..onGet(
          '$base/devices',
          (s) => s.reply(200, {'success': true, 'data': []}),
        );

      await tester.pumpWidget(
        _host(
          api,
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showPairingSheet(
                context,
                childId: 'child-1',
                childName: 'Omar',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('DZQN-9N6K'), findsOneWidget);
      expect(find.text(l.pairWaitingForChild('Omar')), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(l.pairSuccessTitle), findsOneWidget);
      expect(
        find.text(l.pairSuccessBody('Omar', 'Omar’s iPad')),
        findsOneWidget,
      );

      // Closing after success must not revoke the (already used) code.
      await tester.tap(find.text(l.commonDone));
      await tester.pumpAndSettle();
      expect(api.requests.where((r) => r.method == 'DELETE'), isEmpty);
    });
  });
}
