import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import 'models/child_summary.dart';
import 'models/development_report.dart';
import 'models/parent_dashboard.dart';

/// HTTP for the read-only dashboard / development-report endpoints
/// (`App\Http\Controllers\Api\V1\DashboardController`).
///
/// * `GET /families/{family}/dashboard` — any active member.
/// * `GET /families/{family}/children/{child}/summary` — `view_reports`
///   (owner/parent always; a caregiver needs the grant → 403 otherwise).
/// * `GET /families/{family}/children/{child}/reports/{weekly|monthly}` —
///   `view_reports`; optional `date=YYYY-MM-DD` anchors the period.
///
/// Every response is a plain object under `data` — no pagination.
class DashboardRepository {
  DashboardRepository(this._client);

  final ApiClient _client;

  Future<ParentDashboard> parentDashboard(String familyId) async {
    final envelope = await _client.get('/families/$familyId/dashboard');
    return ParentDashboard.fromJson(envelope.dataMap);
  }

  Future<ChildSummary> childSummary(String familyId, String childId) async {
    final envelope = await _client.get(
      '/families/$familyId/children/$childId/summary',
    );
    return ChildSummary.fromJson(envelope.dataMap);
  }

  /// [period] is `weekly` or `monthly`. [date] (optional) anchors which
  /// week/month the backend reports on; it is sent as `YYYY-MM-DD`.
  Future<DevelopmentReport> report({
    required String familyId,
    required String childId,
    required String period,
    DateTime? date,
  }) async {
    final envelope = await _client.get(
      '/families/$familyId/children/$childId/reports/$period',
      query: {if (date != null) 'date': DateFormat('yyyy-MM-dd').format(date)},
    );
    return DevelopmentReport.fromJson(envelope.dataMap);
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(ref.watch(apiClientProvider)),
);
