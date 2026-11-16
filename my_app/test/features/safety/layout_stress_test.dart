// The new safety / phone-rules screens in English, Arabic and Hebrew, at
// normal and 200 % text, on a small phone and a tablet. Any overflow or
// layout exception fails the test.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/cache/offline_cache.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/features/device_rules/data/device_rules_models.dart';
import 'package:my_app/features/device_rules/data/device_rules_repository.dart';
import 'package:my_app/features/device_rules/presentation/device_rules_screen.dart';
import 'package:my_app/features/kid/data/kid_models.dart';
import 'package:my_app/features/safety/application/kid_safety_providers.dart';
import 'package:my_app/features/safety/application/parent_safety_providers.dart';
import 'package:my_app/features/safety/data/safety_models.dart';
import 'package:my_app/features/safety/presentation/access_history_screen.dart';
import 'package:my_app/features/safety/presentation/kid_help_screen.dart';
import 'package:my_app/features/safety/presentation/parent_safety_screen.dart';
import 'package:my_app/features/safety/presentation/safety_centre_screen.dart';
import 'package:my_app/l10n/app_localizations.dart';

import '../../support/memory_offline_cache.dart';
import '../../support/test_api.dart';

final _now = DateTime.now();

final _rules = DeviceRulesState.fromJson({
  'child_id': 'child-1',
  'version': 7,
  'timezone': 'Asia/Hebron',
  'rules': {
    'blocked_apps': [
      {
        'platform': 'android',
        'id': 'com.google.android.youtube',
        'name': 'YouTube',
      },
      {'platform': 'android', 'id': 'com.google.android.gm', 'name': 'Gmail'},
    ],
    'schedules': [
      {
        'id': 's1',
        'preset': 'bedtime',
        'name': 'Bedtime',
        'days': [1, 2, 3, 4, 5, 6, 7],
        'start': '21:00',
        'end': '07:00',
        'restriction': 'allow_only',
      },
    ],
    'web': {
      'mode': 'block_listed',
      'blocked_domains': ['example.com'],
    },
  },
  'status': {
    'summary': 'partially_active',
    'has_rules': true,
    'devices': [
      {
        'device_id': 'd1',
        'device_name': 'Samsung Galaxy Tab A9+ (family)',
        'platform': 'android',
        'state': 'active',
        'applied_version': 7,
        'applied_at': _now.toUtc().toIso8601String(),
        'capabilities': {
          'app_blocking': 'available',
          'web_filter': 'available',
          'exact_alarms': 'permission_needed',
        },
      },
      {
        'device_id': 'd2',
        'device_name': 'iPhone',
        'platform': 'ios',
        'state': 'permission_needed',
        'capabilities': {
          'app_blocking': 'permission_needed',
          'app_limits': 'unsupported',
        },
      },
    ],
    'current': {'kind': 'schedule', 'name': 'Bedtime', 'preset': 'bedtime'},
  },
});

final _help = HelpAlert.fromJson({
  'id': 'h1',
  'child_id': 'child-1',
  'child_name': 'Alexandria-Rose',
  'status': 'open',
  'message': 'Please come, I am at the bus stop near the big park',
  'location': {'latitude': 31.9, 'longitude': 35.2, 'accuracy_m': 30},
  'battery_pct': 7,
  'recipients': [
    {'id': 'u1', 'name': 'Dana'},
  ],
  'push_queued': 0,
  'created_at': _now.toUtc().toIso8601String(),
});

final _checkins = [
  for (final k in ['pick_me_up', 'call_me', 'arrived', 'okay'])
    SafetyCheckin.fromJson({
      'id': k,
      'child_id': 'child-1',
      'child_name': 'Alexandria-Rose',
      'kind': k,
      'created_at': _now.toUtc().toIso8601String(),
    }),
];

final _log = [
  for (final a in [
    'remote.started',
    'remote.ended',
    'location.viewed',
    'rules.changed',
  ])
    AccessLogEntry.fromJson({
      'id': a,
      'action': a,
      'actor_type': 'user',
      'actor_name': 'Christopher-Alexander',
      'child_name': 'Alexandria-Rose',
      'created_at': _now.toUtc().toIso8601String(),
    }),
];

final _centre = SafetyCentre.fromJson({
  'people': [
    {'id': 'u1', 'name': 'Dana', 'phone': '+970599000000'},
    {'id': 'u2', 'name': 'Christopher-Alexander', 'phone': null},
  ],
  'contacts': [
    {
      'id': 'c1',
      'name': 'Grandma',
      'phone': '+970598000000',
      'can_pick_up': true,
    },
  ],
  'emergency_number': '100',
  'pickup_instructions':
      'Wait inside the school office until a grown-up from the list arrives.',
  'caregivers': [
    {
      'member_id': 'm1',
      'user_id': 'u1',
      'name': 'Dana',
      'role': 'owner',
      'contact_phone': '+970599000000',
      'is_me': true,
    },
    {
      'member_id': 'm2',
      'user_id': 'u2',
      'name': 'Christopher-Alexander',
      'role': 'caregiver',
      'receives_urgent_alerts': false,
      'child_scope': 'selected',
      'child_ids': ['child-1'],
    },
  ],
});

class _Screen {
  const _Screen(this.name, this.build, {this.kid = false});
  final String name;
  final Widget Function() build;
  final bool kid;
}

final _screens = [
  _Screen(
    'phone rules',
    () => const DeviceRulesScreen(
      childId: 'child-1',
      childName: 'Alexandria-Rose',
    ),
  ),
  _Screen('parent safety', () => const ParentSafetyScreen()),
  _Screen('access history', () => const AccessHistoryScreen()),
  _Screen('safety centre', () => const SafetyCentreScreen()),
  _Screen('kid help', () => const KidHelpScreen(), kid: true),
];

void main() {
  // The help alert's map snippet caches tiles under the app cache dir.
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => Directory.systemTemp.path,
        );
  });

  const sizes = {'phone': Size(360, 740), 'tablet': Size(1024, 1366)};

  for (final screen in _screens) {
    for (final locale in const ['en', 'ar', 'he']) {
      for (final scale in const [1.0, 2.0]) {
        for (final size in sizes.entries) {
          testWidgets('${screen.name} · $locale · ${scale}x · ${size.key}', (
            tester,
          ) async {
            tester.view.physicalSize = size.value;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);

            final api = TestApi.create(
              token: 'tok',
              locale: locale,
              activeFamilyId: 'family-1',
              overrides: [
                offlineCacheProvider.overrideWithValue(MemoryOfflineCache()),
                deviceRulesProvider.overrideWith((ref, _) async => _rules),
                openHelpAlertsProvider.overrideWith((ref) async => [_help]),
                safetyCheckinsProvider.overrideWith((ref) async => _checkins),
                accessLogProvider.overrideWith((ref, _) async => _log),
                kidSafetyCentreProvider.overrideWith(
                  (ref) async => Fresh(_centre, fetchedAt: _now),
                ),
              ],
            );
            addTearDown(api.dispose);

            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: api.container,
                child: MaterialApp(
                  theme: screen.kid ? AppTheme.kid : AppTheme.light,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  locale: Locale(locale),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: screen.build(),
                ),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 500));

            expect(tester.takeException(), isNull);
            if (locale == 'en' && scale == 1.0 && size.key == 'phone') {
              final handle = tester.ensureSemantics();
              await expectLater(
                tester,
                meetsGuideline(labeledTapTargetGuideline),
              );
              await expectLater(
                tester,
                meetsGuideline(androidTapTargetGuideline),
              );
              await expectLater(tester, meetsGuideline(textContrastGuideline));
              handle.dispose();
            }
            // Scroll through the whole page so lower sections lay out too.
            final scrollables = find.byType(Scrollable);
            if (scrollables.evaluate().isNotEmpty) {
              for (var i = 0; i < 6; i++) {
                await tester.drag(scrollables.first, const Offset(0, -600));
                await tester.pump(const Duration(milliseconds: 200));
                expect(tester.takeException(), isNull);
              }
            }
            // Stop periodic timers (rules auto-refresh, help polling).
            await tester.pumpWidget(const SizedBox());
          });
        }
      }
    }
  }
}
