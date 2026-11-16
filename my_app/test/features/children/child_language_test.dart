import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:my_app/features/children/data/children_repository.dart';
import 'package:my_app/features/children/data/models/child.dart';
import 'package:my_app/features/children/presentation/child_language.dart';
import 'package:my_app/l10n/app_localizations.dart';

import '../../support/test_api.dart';

Map<String, dynamic> _childJson({
  String id = 'child-1',
  String name = 'Sara',
  String? preferred,
  String? effective,
}) => {
  'id': id,
  'family_id': 'family-1',
  'name': name,
  'birth_date': '2017-05-01',
  'age': 9,
  'status': 'active',
  'preferred_language': preferred,
  'effective_language': effective,
  'interests': [],
};

void main() {
  final l = lookupAppLocalizations(const Locale('en'));
  late TestApi api;

  setUp(() {
    api = TestApi.create(
      token: 'parent-tok',
      locale: 'en',
      activeFamilyId: 'family-1',
    );
    api.adapter.onGet(
      '/families/family-1/children',
      (s) => s.reply(200, {
        'success': true,
        'data': [_childJson()],
        'meta': {'current_page': 1, 'last_page': 1, 'total': 1},
      }),
    );
  });
  tearDown(() => api.dispose());

  test('setting one child\'s language sends only that field', () async {
    api.adapter.onPatch(
      '/families/family-1/children/child-1',
      (s) => s.reply(200, {
        'success': true,
        'data': _childJson(preferred: 'he', effective: 'he'),
      }),
      data: Matchers.any,
    );

    final child = await api.container
        .read(childrenRepositoryProvider)
        .setLanguage('family-1', 'child-1', 'he');

    final body = api.lastRequest.data as Map;
    expect(body, {'preferred_language': 'he'});
    expect(api.lastRequest.path, endsWith('/children/child-1'));
    expect(child.effectiveLanguage, 'he');
  });

  test('family default clears the setting with an explicit null', () async {
    api.adapter.onPatch(
      '/families/family-1/children/child-1',
      (s) => s.reply(200, {
        'success': true,
        'data': _childJson(preferred: null, effective: 'ar'),
      }),
      data: Matchers.any,
    );

    await api.container
        .read(childrenRepositoryProvider)
        .setLanguage('family-1', 'child-1', null);

    final body = api.lastRequest.data as Map;
    expect(body.containsKey('preferred_language'), isTrue);
    expect(body['preferred_language'], isNull);
  });

  test('summary marks the family default', () {
    final own = Child.fromJson(_childJson(preferred: 'he', effective: 'he'));
    final inherited = Child.fromJson(_childJson(effective: 'ar'));
    expect(childLanguageSummary(l, own), l.languageHebrew);
    expect(
      childLanguageSummary(l, inherited),
      l.childLanguageFamilyDefault(l.languageArabic),
    );
  });

  testWidgets('the parent picks a language in its own script and it saves', (
    tester,
  ) async {
    api.adapter.onPatch(
      '/families/family-1/children/child-1',
      (s) => s.reply(200, {
        'success': true,
        'data': _childJson(preferred: 'he', effective: 'he'),
      }),
      data: Matchers.any,
    );
    final child = Child.fromJson(_childJson(effective: 'ar'));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: api.container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => showChildLanguagePicker(context, ref, child),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text(l.childLanguageHint('Sara')), findsOneWidget);
    // Each language in its own script; Hebrew is laid out right-to-left.
    expect(find.text('العربية'), findsOneWidget);
    expect(find.text('English'), findsWidgets); // endonym + English name
    final hebrew = tester.widget<Text>(find.text('עברית'));
    expect(hebrew.textDirection, TextDirection.rtl);

    await tester.tap(find.text('עברית'));
    await tester.pumpAndSettle();

    final patch = api.requests.singleWhere((r) => r.method == 'PATCH');
    expect(patch.data, {'preferred_language': 'he'});
    expect(find.text(l.childLanguageSaved('Sara')), findsOneWidget);
  });
}
