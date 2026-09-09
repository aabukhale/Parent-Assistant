import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/errors/api_exception.dart';
import 'package:my_app/features/dashboard/data/dashboard_repository.dart';

import '../../support/fixtures.dart';
import '../../support/test_api.dart';

void main() {
  late TestApi api;
  late DashboardRepository repo;

  setUp(() {
    api = TestApi.create(
      token: 'tok',
      activeFamilyId: 'family-1',
      selectedChildId: 'child-1',
    );
    repo = api.container.read(dashboardRepositoryProvider);
  });
  tearDown(() => api.dispose());

  Future<ApiException> capture(Future<void> Function() f) async {
    try {
      await f();
      fail('expected ApiException');
    } on ApiException catch (e) {
      return e;
    }
  }

  test('parentDashboard: GET /families/{family}/dashboard, no query', () async {
    api.adapter.onGet(
      '/families/family-1/dashboard',
      (s) => s.reply(
        200,
        Fixtures.parentDashboardEnvelope(
          dashboard: Fixtures.parentDashboardJson(
            children: [
              Fixtures.childSummaryJson(childId: 'a', pointsBalance: 10),
              Fixtures.childSummaryJson(childId: 'b', pointsBalance: 20),
            ],
          ),
        ),
      ),
    );

    final d = await repo.parentDashboard('family-1');
    expect(d.children.map((c) => c.childId), ['a', 'b']);
    expect(api.lastRequest.uri.path, '/api/v1/families/family-1/dashboard');
    expect(api.lastRequest.uri.queryParameters, isEmpty);
  });

  test(
    'childSummary: GET /families/{family}/children/{child}/summary',
    () async {
      api.adapter.onGet(
        '/families/family-1/children/child-1/summary',
        (s) => s.reply(
          200,
          Fixtures.childSummaryEnvelope(
            summary: Fixtures.childSummaryJson(pointsBalance: 55),
          ),
        ),
      );

      final s = await repo.childSummary('family-1', 'child-1');
      expect(s.pointsBalance, 55);
    },
  );

  test('report: GET reports/{period} with no date query by default', () async {
    api.adapter.onGet(
      '/families/family-1/children/child-1/reports/weekly',
      (s) => s.reply(200, Fixtures.developmentReportEnvelope()),
    );

    await repo.report(
      familyId: 'family-1',
      childId: 'child-1',
      period: 'weekly',
    );
    expect(api.lastRequest.uri.path, endsWith('/reports/weekly'));
    expect(api.lastRequest.uri.queryParameters.containsKey('date'), isFalse);
  });

  test('report: forwards date as YYYY-MM-DD', () async {
    api.adapter.onGet(
      '/families/family-1/children/child-1/reports/monthly',
      (s) => s.reply(
        200,
        Fixtures.developmentReportEnvelope(
          report: Fixtures.developmentReportJson(
            period: 'monthly',
            periodStart: '2026-06-01',
            periodEnd: '2026-06-30',
          ),
        ),
      ),
    );

    final r = await repo.report(
      familyId: 'family-1',
      childId: 'child-1',
      period: 'monthly',
      date: DateTime(2026, 6, 15),
    );
    expect(api.lastRequest.uri.queryParameters['date'], '2026-06-15');
    expect(r.period, 'monthly');
  });

  test('childSummary without view_reports → 403 forbidden', () async {
    api.adapter.onGet(
      '/families/family-1/children/child-1/summary',
      (s) => s.reply(403, {
        'success': false,
        'message': 'This action is unauthorized.',
      }),
    );
    final e = await capture(() => repo.childSummary('family-1', 'child-1'));
    expect(e.kind, ApiErrorKind.forbidden);
  });

  test('report for an outsider / unknown family → 404', () async {
    api.adapter.onGet(
      '/families/family-1/children/child-1/reports/weekly',
      (s) => s.reply(404, {'success': false, 'message': 'Resource not found.'}),
    );
    final e = await capture(
      () => repo.report(
        familyId: 'family-1',
        childId: 'child-1',
        period: 'weekly',
      ),
    );
    expect(e.kind, ApiErrorKind.notFound);
  });

  test('dashboard 500 → server error', () async {
    api.adapter.onGet(
      '/families/family-1/dashboard',
      (s) => s.reply(500, {'success': false, 'message': 'boom'}),
    );
    final e = await capture(() => repo.parentDashboard('family-1'));
    expect(e.kind, ApiErrorKind.server);
  });

  test('dashboard 401 → unauthorized', () async {
    api.adapter.onGet(
      '/families/family-1/dashboard',
      (s) => s.reply(401, {'success': false, 'message': 'Unauthenticated.'}),
    );
    final e = await capture(() => repo.parentDashboard('family-1'));
    expect(e.kind, ApiErrorKind.unauthorized);
  });

  test(
    'one dashboard request returns every child — no per-child follow-up',
    () async {
      api.adapter.onGet(
        '/families/family-1/dashboard',
        (s) => s.reply(
          200,
          Fixtures.parentDashboardEnvelope(
            dashboard: Fixtures.parentDashboardJson(
              children: [
                Fixtures.childSummaryJson(childId: 'a'),
                Fixtures.childSummaryJson(childId: 'b'),
                Fixtures.childSummaryJson(childId: 'c'),
              ],
            ),
          ),
        ),
      );

      await repo.parentDashboard('family-1');
      expect(
        api.requests.where((r) => r.uri.path.contains('/summary')),
        isEmpty,
      );
      expect(
        api.requests.where((r) => r.uri.path.contains('/dashboard')),
        hasLength(1),
      );
    },
  );
}
