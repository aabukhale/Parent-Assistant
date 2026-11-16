import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/cache/offline_cache.dart';
import 'package:my_app/features/kid/presentation/my_day_screen.dart';
import 'package:my_app/l10n/app_localizations.dart';

import '../../support/memory_offline_cache.dart';
import '../../support/test_api.dart';

Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('test/fixtures/kid/$name.json').readAsStringSync())
        as Map<String, dynamic>;

Widget _host(TestApi api) => UncontrolledProviderScope(
  container: api.container,
  child: const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: Locale('en'),
    home: MyDayScreen(),
  ),
);

void main() {
  final l = lookupAppLocalizations(const Locale('en'));
  late TestApi api;

  setUp(() {
    api = TestApi.create(
      token: 'child-token',
      locale: 'en',
      overrides: [offlineCacheProvider.overrideWithValue(MemoryOfflineCache())],
    );
    api.adapter.onGet('/child/my-day', (s) => s.reply(200, _fixture('my_day')));
  });
  tearDown(() => api.dispose());

  testWidgets('shows the next step and today\'s timeline', (tester) async {
    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();

    expect(find.text('Help with the dishes'), findsWidgets);
    expect(find.text('After school'), findsWidgets);
    expect(find.text(l.kidIDidIt), findsOneWidget);
  });

  testWidgets('"I did it!" asks once, then sends it for a parent to check', (
    tester,
  ) async {
    api.adapter.onPost(
      RegExp(r'/child/tasks/[^/]+/complete'),
      (s) => s.reply(200, {'success': true, 'data': null}),
    );

    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l.kidIDidIt));
    await tester.pumpAndSettle();

    // Straight to the confirmation — no intermediate task sheet.
    expect(
      find.text(l.kidConfirmDoneTitle('Help with the dishes')),
      findsOneWidget,
    );
    expect(api.requests.where((r) => r.method == 'POST'), isEmpty);

    await tester.tap(find.text(l.kidYesDone));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final posts = api.requests.where((r) => r.method == 'POST').toList();
    expect(posts, hasLength(1));
    expect(posts.single.path, matches(RegExp(r'/child/tasks/[^/]+/complete$')));

    // Let the celebration finish so no timers outlive the test.
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('"Not yet" sends nothing', (tester) async {
    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l.kidIDidIt));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.kidNotYet));
    await tester.pumpAndSettle();

    expect(api.requests.where((r) => r.method == 'POST'), isEmpty);
  });
}
