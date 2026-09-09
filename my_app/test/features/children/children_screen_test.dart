import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/children/presentation/children_screen.dart';
import 'package:my_app/l10n/app_localizations.dart';

import '../../support/fixtures.dart';
import '../../support/test_api.dart';

Widget _host(TestApi api) => UncontrolledProviderScope(
  container: api.container,
  child: const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: Locale('en'),
    home: ChildrenScreen(),
  ),
);

void main() {
  late TestApi api;
  final l = lookupAppLocalizations(const Locale('en'));

  setUp(
    () => api = TestApi.create(
      token: 'tok',
      locale: 'en',
      activeFamilyId: 'family-1',
    ),
  );
  tearDown(() => api.dispose());

  testWidgets('renders the empty state when the family has no children', (
    tester,
  ) async {
    api.adapter.onGet(
      '/families/family-1/children',
      (s) => s.reply(200, Fixtures.childrenPage(const [])),
    );

    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();

    expect(find.text(l.childrenEmpty), findsOneWidget);
    expect(find.text(l.childrenAdd), findsWidgets); // empty-state add button
  });

  testWidgets('renders the list with a localized age label', (tester) async {
    api.adapter.onGet(
      '/families/family-1/children',
      (s) => s.reply(
        200,
        Fixtures.childrenPage([
          Fixtures.childJson(id: 'c1', name: 'Layan', age: 8),
        ]),
      ),
    );

    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();

    expect(find.text('Layan'), findsOneWidget);
    expect(find.text(l.childAgeYears(8)), findsOneWidget);
  });

  testWidgets('shows an error + retry, then recovers', (tester) async {
    api.adapter.onGet(
      '/families/family-1/children',
      (s) => s.reply(500, {'success': false, 'message': 'boom'}),
    );

    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();

    expect(find.text(l.commonRetry), findsOneWidget);

    api.adapter.onGet(
      '/families/family-1/children',
      (s) => s.reply(
        200,
        Fixtures.childrenPage([
          Fixtures.childJson(id: 'c1', name: 'Recovered'),
        ]),
      ),
    );
    await tester.tap(find.text(l.commonRetry));
    await tester.pumpAndSettle();

    expect(find.text('Recovered'), findsOneWidget);
  });
}
