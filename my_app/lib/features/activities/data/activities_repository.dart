import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_envelope.dart';
import '../../../core/providers.dart';
import '../../tasks/data/task_requests.dart';
import 'activity_requests.dart';
import 'models/activity.dart';
import 'models/activity_assignment.dart';
import 'models/activity_completion.dart';

/// HTTP for the activity catalog + per-child assignments
/// (`ActivityController`, `ActivityAssignmentController`).
///
/// Catalog reads = any authenticated user (a `family_id` must be a family you
/// belong to, else 404). `manage_activities` for family-activity create/delete,
/// assignment create, and AI generation. `approve_task_completions` for
/// approve/reject; `reverse_points` for reverse. Completing an assignment is any
/// active member (parent-managed / on-behalf-of-child). Domain conflicts → 409;
/// AI generation → 503 while no provider is configured.
class ActivitiesRepository {
  ActivitiesRepository(this._client);

  final ApiClient _client;

  String _child(String familyId, String childId) =>
      '/families/$familyId/children/$childId';

  // --- Catalog ---

  Future<Paginated<Activity>> listActivities({
    String? familyId,
    String? source,
    int? age,
    String? interestId,
    int page = 1,
    int perPage = 20,
  }) async {
    final envelope = await _client.get(
      '/activities',
      query: {
        'page': page,
        'per_page': perPage,
        'family_id': ?familyId,
        'source': ?source,
        'age': ?age,
        'interest': ?interestId,
      },
    );
    return Paginated.from<Activity>(envelope, Activity.fromJson);
  }

  Future<Activity> showActivity(String activityId) async {
    final envelope = await _client.get('/activities/$activityId');
    return Activity.fromJson(envelope.dataMap);
  }

  /// Real AI generation. Returns the generated (not-yet-persisted) payloads.
  /// Throws an [ApiException] with `kind == unavailable` (503) until a provider
  /// is configured — callers must surface that honestly, never fabricate.
  Future<List<Map<String, dynamic>>> generate(
    String familyId,
    String childId,
    GenerateActivityInput input,
  ) async {
    final envelope = await _client.post(
      '${_child(familyId, childId)}/activities/generate',
      body: input.toJson(),
    );
    final data = envelope.dataMap['activities'];
    return data is List
        ? data.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList()
        : const [];
  }

  // --- Assignments ---

  Future<Paginated<ActivityAssignment>> listAssignments({
    required String familyId,
    required String childId,
    int page = 1,
    int perPage = 15,
  }) async {
    final envelope = await _client.get(
      '${_child(familyId, childId)}/activity-assignments',
      query: {'page': page, 'per_page': perPage},
    );
    return Paginated.from<ActivityAssignment>(
      envelope,
      ActivityAssignment.fromJson,
    );
  }

  Future<ActivityAssignment> createAssignment(
    String familyId,
    String childId,
    ActivityAssignInput input,
  ) async {
    final envelope = await _client.post(
      '${_child(familyId, childId)}/activity-assignments',
      body: input.toJson(),
    );
    return ActivityAssignment.fromJson(envelope.dataMap);
  }

  /// Parent-managed / on-behalf-of-child. `points_reward > 0` → the returned
  /// completion is `pending`; otherwise it is auto-`approved` server-side.
  Future<ActivityCompletion> complete(
    String familyId,
    String childId,
    String assignmentId,
    ReviewInput input,
  ) async {
    final envelope = await _client.post(
      '${_child(familyId, childId)}/activity-assignments/$assignmentId/complete',
      body: input.toJson(),
    );
    return ActivityCompletion.fromJson(envelope.dataMap);
  }

  Future<ActivityCompletion> approve(
    String familyId,
    String childId,
    String assignmentId,
    String completionId,
    ReviewInput input,
  ) => _review(familyId, childId, assignmentId, completionId, 'approve', input);

  Future<ActivityCompletion> reject(
    String familyId,
    String childId,
    String assignmentId,
    String completionId,
    ReviewInput input,
  ) => _review(familyId, childId, assignmentId, completionId, 'reject', input);

  Future<ActivityCompletion> reverse(
    String familyId,
    String childId,
    String assignmentId,
    String completionId,
    ReviewInput input,
  ) => _review(familyId, childId, assignmentId, completionId, 'reverse', input);

  Future<ActivityCompletion> _review(
    String familyId,
    String childId,
    String assignmentId,
    String completionId,
    String action,
    ReviewInput input,
  ) async {
    final envelope = await _client.post(
      '${_child(familyId, childId)}/activity-assignments/$assignmentId'
      '/completions/$completionId/$action',
      body: input.toJson(),
    );
    return ActivityCompletion.fromJson(envelope.dataMap);
  }
}

final activitiesRepositoryProvider = Provider<ActivitiesRepository>(
  (ref) => ActivitiesRepository(ref.watch(apiClientProvider)),
);
