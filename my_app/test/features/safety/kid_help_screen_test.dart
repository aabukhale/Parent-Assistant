import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:my_app/core/cache/offline_cache.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/features/safety/presentation/kid_help_screen.dart';
import 'package:my_app/l10n/app_localizations.dart';

import '../../support/memory_offline_cache.dart';
import '../../support/test_api.dart';

Map<String, dynamic> _ok(Object? data) => {'success': true, 'data': data};

Widget _host(TestApi api) => UncontrolledProviderScope(
  container: api.container,
  child: MaterialApp(
    theme: AppTheme.kid,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: const KidHelpScreen(),
  ),
);

Iterable<Object?> _helpPosts(TestApi api) => api.requests
    .where((r) => r.method == 'POST' && r.path.endsWith('/child/help-alerts'))
    .map((r) => r.data);

void main() {
  final l = lookupAppLocalizations(const Locale('en'));
  late TestApi api;

  setUp(() {
    // Answer the location and battery plugins inside the fake clock: no
    // location permission (the alert must still go out), battery 41 %.
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/geolocator'),
      (call) async => call.method == 'checkPermission' ? 0 : null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/battery'),
      (call) async => call.method == 'getBatteryLevel' ? 41 : null,
    );
    api = TestApi.create(
      token: 'child-token',
      locale: 'en',
      overrides: [offlineCacheProvider.overrideWithValue(MemoryOfflineCache())],
    );
    api.adapter
      ..onGet(
        '/child/safety-centre',
        (s) => s.reply(
          200,
          _ok({
            'people': [
              {'id': 'u1', 'name': 'Dana', 'phone': '+970599000000'},
            ],
            'contacts': [],
            'emergency_number': '100',
          }),
        ),
      )
      ..onGet(
        '/child/location-settings',
        (s) => s.reply(200, _ok({'sharing_enabled': false})),
      )
      ..onPost(
        '/child/help-alerts',
        (s) => s.reply(
          201,
          _ok({
            'id': 'h1',
            'status': 'open',
            'recipients': [
              {'id': 'u1', 'name': 'Dana'},
            ],
            'push_queued': 0,
          }),
        ),
        data: Matchers.any,
      );
  });
  tearDown(() => api.dispose());

  testWidgets('a quick tap never sends help', (tester) async {
    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l.kidHelpButton));
    await tester.pumpAndSettle();

    expect(_helpPosts(api), isEmpty);
  });

  testWidgets('holding sends once, names who got it, and offers a call', (
    tester,
  ) async {
    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text(l.kidHelpButton)),
    );
    for (var i = 0; i < 18; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(_helpPosts(api), hasLength(1));
    final body = _helpPosts(api).single as Map;
    expect(body['client_id'], isNotEmpty);
    expect(body['battery_pct'], 41);
    // No permission → no coordinates invented.
    expect(body.containsKey('latitude'), isFalse);
    expect(find.text(l.kidHelpSentTo('Dana')), findsOneWidget);
    // No device could be reached by push: say so, don't pretend.
    expect(find.text(l.kidHelpNoPush), findsOneWidget);

    // Stop the status poll timer before the test ends.
    await tester.pumpWidget(const SizedBox());
  });
}
