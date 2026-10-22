import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/features/device_rules/presentation/device_rules_screen.dart';
import 'package:my_app/l10n/app_localizations.dart';

import '../../support/test_api.dart';

const _base = '/families/family-1/children/child-1/device-rules';

Map<String, dynamic> _state(String deviceState, {int? applied}) => {
  'success': true,
  'data': {
    'child_id': 'child-1',
    'version': 4,
    'timezone': 'Asia/Hebron',
    'rules': {
      'blocked_apps': [
        {'platform': 'android', 'id': 'com.google.android.gm', 'name': 'Gmail'},
      ],
    },
    'status': {
      'summary': deviceState,
      'has_rules': true,
      'devices': [
        {
          'device_id': 'd1',
          'device_name': 'Omar’s Android',
          'platform': 'android',
          'state': deviceState,
          'received_version': applied,
          'applied_version': applied,
          'applied_at': applied == null ? null : '2026-10-22T19:00:00Z',
          'last_contact_at': '2026-10-22T19:00:00Z',
          'capabilities': {'app_blocking': 'available'},
        },
      ],
    },
  },
};

Widget _host(TestApi api) => UncontrolledProviderScope(
  container: api.container,
  child: MaterialApp(
    theme: AppTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: const DeviceRulesScreen(childId: 'child-1', childName: 'Omar'),
  ),
);

int _gets(TestApi api) => api.requests
    .where((r) => r.method == 'GET' && r.path.endsWith(_base))
    .length;

void main() {
  final l = lookupAppLocalizations(const Locale('en'));
  late TestApi api;

  setUp(() {
    api = TestApi.create(
      token: 'tok',
      locale: 'en',
      activeFamilyId: 'family-1',
    );
  });
  tearDown(() => api.dispose());

  testWidgets('a saved rule the phone has not applied says "waiting"', (
    tester,
  ) async {
    api.adapter.onGet(_base, (s) => s.reply(200, _state('waiting_for_device')));
    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();

    expect(find.text(l.rulesStateWaiting), findsWidgets);
    // Never "on" just because the server stored it.
    expect(find.text(l.rulesStateActive), findsNothing);
  });

  testWidgets('waiting re-checks every 10 s until the phone confirms', (
    tester,
  ) async {
    api.adapter.onGet(_base, (s) => s.reply(200, _state('waiting_for_device')));
    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();
    final before = _gets(api);

    api.adapter.onGet(_base, (s) => s.reply(200, _state('active', applied: 4)));
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();

    expect(_gets(api), before + 1);
    expect(find.text(l.rulesStateActive), findsWidgets);
    expect(find.text(l.rulesStateWaiting), findsNothing);

    // Once confirmed, no more polling.
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(_gets(api), before + 1);
  });

  testWidgets('an offline phone is named, never shown as on', (
    tester,
  ) async {
    api.adapter.onGet(_base, (s) => s.reply(200, _state('device_offline')));
    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();
    expect(find.text(l.rulesStateOffline), findsWidgets);
    expect(find.text(l.rulesStateActive), findsNothing);
  });
}
