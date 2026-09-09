import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_envelope.dart';
import '../../../core/providers.dart';
import 'learning_goal_requests.dart';
import 'models/learning_goal.dart';

/// Result of recording progress: the backend returns both the new entry and the
/// (possibly auto-achieved) goal.
typedef RecordedProgress = ({
  LearningGoalProgressEntry progress,
  LearningGoal goal,
});

/// HTTP for `/families/{family}/children/{child}/learning-goals`.
///
/// Read = any active member; create / update / archive / record-progress require
/// the `manage_learning_goals` permission (owner/parent implicitly; caregiver
/// → 403).
class LearningGoalsRepository {
  LearningGoalsRepository(this._client);

  final ApiClient _client;

  String _base(String familyId, String childId) =>
      '/families/$familyId/children/$childId/learning-goals';

  Future<Paginated<LearningGoal>> list({
    required String familyId,
    required String childId,
    int page = 1,
    int perPage = 20,
    String? status,
  }) async {
    final envelope = await _client.get(
      _base(familyId, childId),
      query: {
        'page': page,
        'per_page': perPage,
        if (status != null && status != 'all') 'status': status,
      },
    );
    return Paginated.from<LearningGoal>(envelope, LearningGoal.fromJson);
  }

  Future<LearningGoal> show(
    String familyId,
    String childId,
    String goalId,
  ) async {
    final envelope = await _client.get('${_base(familyId, childId)}/$goalId');
    return LearningGoal.fromJson(envelope.dataMap);
  }

  Future<LearningGoal> create(
    String familyId,
    String childId,
    LearningGoalCreateInput input,
  ) async {
    final envelope = await _client.post(
      _base(familyId, childId),
      body: input.toJson(),
    );
    return LearningGoal.fromJson(envelope.dataMap);
  }

  Future<LearningGoal> update(
    String familyId,
    String childId,
    String goalId,
    LearningGoalUpdateInput input,
  ) async {
    final envelope = await _client.patch(
      '${_base(familyId, childId)}/$goalId',
      body: input.toJson(),
    );
    return LearningGoal.fromJson(envelope.dataMap);
  }

  Future<LearningGoal> archive(
    String familyId,
    String childId,
    String goalId,
  ) async {
    final envelope = await _client.post(
      '${_base(familyId, childId)}/$goalId/archive',
    );
    return LearningGoal.fromJson(envelope.dataMap);
  }

  Future<Paginated<LearningGoalProgressEntry>> progressHistory({
    required String familyId,
    required String childId,
    required String goalId,
    int page = 1,
    int perPage = 25,
  }) async {
    final envelope = await _client.get(
      '${_base(familyId, childId)}/$goalId/progress',
      query: {'page': page, 'per_page': perPage},
    );
    return Paginated.from<LearningGoalProgressEntry>(
      envelope,
      LearningGoalProgressEntry.fromJson,
    );
  }

  Future<RecordedProgress> recordProgress(
    String familyId,
    String childId,
    String goalId,
    LearningGoalProgressInput input,
  ) async {
    final envelope = await _client.post(
      '${_base(familyId, childId)}/$goalId/progress',
      body: input.toJson(),
    );
    final data = envelope.dataMap;
    return (
      progress: LearningGoalProgressEntry.fromJson(
        (data['progress'] as Map).cast<String, dynamic>(),
      ),
      goal: LearningGoal.fromJson(
        (data['goal'] as Map).cast<String, dynamic>(),
      ),
    );
  }
}

final learningGoalsRepositoryProvider = Provider<LearningGoalsRepository>(
  (ref) => LearningGoalsRepository(ref.watch(apiClientProvider)),
);
