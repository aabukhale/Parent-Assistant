// End-to-end: a parent issues a pairing code, the child pairs this install,
// sends "I did it!" for the next task, and the request reaches the parent's
// inbox. Runs against a LOCAL backend seeded with synthetic demo data:
//
//   cd ../mamily && php artisan mamily:demo-seed --fresh && php artisan serve
//   flutter test integration_test -d <simulator> \
//     --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_app/core/config/app_config.dart';
import 'package:my_app/core/storage/secure_token_storage.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/main.dart' as app;

/// Synthetic credentials from `php artisan mamily:demo-seed` (local only).
const _demoEmail = 'demo.parent@mamily.test';
const _demoPassword = 'DemoFamily2026!';

/// Talks to the backend as the demo parent, outside the app under test.
class _Parent {
  _Parent._(this._dio, this.familyId);

  final Dio _dio;
  final String familyId;

  static Future<_Parent> signIn() async {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.fromEnvironment().apiBaseUrl,
        headers: {'Accept': 'application/json'},
      ),
    );
    final login = await dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {
        'login': _demoEmail,
        'password': _demoPassword,
        'device_name': 'integration-test',
      },
    );
    dio.options.headers['Authorization'] =
        'Bearer ${login.data!['data']['token']}';
    final me = await dio.get<Map<String, dynamic>>('/auth/me');
    final memberships = me.data!['data']['memberships'] as List;
    final family = (memberships.first as Map)['family'] as Map;
    return _Parent._(dio, family['id'] as String);
  }

  Future<String> childId(String name) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/families/$familyId/children',
    );
    final child = (res.data!['data'] as List).cast<Map>().firstWhere(
      (c) => c['name'] == name,
    );
    return child['id'] as String;
  }

  Future<String> pairingCode(String childId) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/families/$familyId/children/$childId/pairing-codes',
    );
    return res.data!['data']['code'] as String;
  }

  Future<List<Map>> inbox() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/families/$familyId/inbox',
    );
    return (res.data!['data']['items'] as List).cast<Map>();
  }

  Future<void> signOut() => _dio.post<void>('/auth/logout');
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final l = lookupAppLocalizations(const Locale('en'));

  testWidgets('a paired child sends a task for approval', (tester) async {
    // Start from a clean install.
    final storage = SecureTokenStorage();
    await storage.clearEverything();
    await storage.writeLocale('en');

    final parent = await _Parent.signIn();
    addTearDown(parent.signOut);
    final omar = await parent.childId('Omar');
    final code = await parent.pairingCode(omar);
    final pendingBefore = (await parent.inbox())
        .where((i) => i['kind'] == 'task_completion' && i['child_id'] == omar)
        .length;

    await app.main();
    await _pumpUntil(tester, find.text(l.roleChild));

    await tester.tap(find.text(l.roleChild));
    await _pumpUntil(tester, find.text(l.pairButton));
    await tester.enterText(find.byType(TextField).first, code);
    await tester.tap(find.text(l.pairButton));

    // My Day for Omar, with a next step to finish.
    await _pumpUntil(tester, find.text(l.kidIDidIt));
    expect(find.textContaining('Omar'), findsWidgets);

    await tester.tap(find.text(l.kidIDidIt));
    await _pumpUntil(tester, find.text(l.kidYesDone));
    await tester.tap(find.text(l.kidYesDone));
    await tester.pump(const Duration(seconds: 3));

    final pendingAfter = (await parent.inbox())
        .where((i) => i['kind'] == 'task_completion' && i['child_id'] == omar)
        .length;
    expect(pendingAfter, pendingBefore + 1);

    // Leave the simulator signed out for the next run.
    await storage.clearEverything();
  });
}
