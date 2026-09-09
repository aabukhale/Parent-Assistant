import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_envelope.dart';
import '../../../core/providers.dart';
import 'models/child_task.dart';
import 'models/point_transaction.dart';
import 'models/task_completion.dart';
import 'task_requests.dart';

/// HTTP for `/families/{family}/children/{child}` — tasks, completions and the
/// points ledger.
///
/// Read (list / show / completions / balance / transactions) = any active
/// member. `manage_tasks` for task CRUD; `approve_task_completions` for
/// approve/reject; `reverse_points` for reversal. Domain conflicts come back as
/// **409**; invalid occurrences / archived task as **422**.
class TasksRepository {
  TasksRepository(this._client);

  final ApiClient _client;

  String _child(String familyId, String childId) =>
      '/families/$familyId/children/$childId';

  // --- Tasks ---

  Future<Paginated<ChildTask>> listTasks({
    required String familyId,
    required String childId,
    int page = 1,
    int perPage = 20,
    String? status,
  }) async {
    final envelope = await _client.get(
      '${_child(familyId, childId)}/tasks',
      query: {
        'page': page,
        'per_page': perPage,
        if (status != null && status != 'all') 'status': status,
      },
    );
    return Paginated.from<ChildTask>(envelope, ChildTask.fromJson);
  }

  Future<ChildTask> showTask(
    String familyId,
    String childId,
    String taskId,
  ) async {
    final envelope = await _client.get(
      '${_child(familyId, childId)}/tasks/$taskId',
    );
    return ChildTask.fromJson(envelope.dataMap);
  }

  Future<ChildTask> createTask(
    String familyId,
    String childId,
    TaskCreateInput input,
  ) async {
    final envelope = await _client.post(
      '${_child(familyId, childId)}/tasks',
      body: input.toJson(),
    );
    return ChildTask.fromJson(envelope.dataMap);
  }

  Future<ChildTask> updateTask(
    String familyId,
    String childId,
    String taskId,
    TaskUpdateInput input,
  ) async {
    final envelope = await _client.patch(
      '${_child(familyId, childId)}/tasks/$taskId',
      body: input.toJson(),
    );
    return ChildTask.fromJson(envelope.dataMap);
  }

  /// `DELETE` archives (sets `status: archived`) and returns the task.
  Future<ChildTask> archiveTask(
    String familyId,
    String childId,
    String taskId,
  ) async {
    final envelope = await _client.delete(
      '${_child(familyId, childId)}/tasks/$taskId',
    );
    return ChildTask.fromJson(envelope.dataMap);
  }

  // --- Completions ---

  Future<Paginated<TaskCompletion>> listCompletions({
    required String familyId,
    required String childId,
    required String taskId,
    int page = 1,
    int perPage = 25,
  }) async {
    final envelope = await _client.get(
      '${_child(familyId, childId)}/tasks/$taskId/completions',
      query: {'page': page, 'per_page': perPage},
    );
    return Paginated.from<TaskCompletion>(envelope, TaskCompletion.fromJson);
  }

  Future<TaskCompletion> requestCompletion(
    String familyId,
    String childId,
    String taskId,
    CompletionRequestInput input,
  ) async {
    final envelope = await _client.post(
      '${_child(familyId, childId)}/tasks/$taskId/completions',
      body: input.toJson(),
    );
    return TaskCompletion.fromJson(envelope.dataMap);
  }

  Future<TaskCompletion> _review(
    String familyId,
    String childId,
    String taskId,
    String completionId,
    String action,
    ReviewInput input,
  ) async {
    final envelope = await _client.post(
      '${_child(familyId, childId)}/tasks/$taskId/completions/$completionId/$action',
      body: input.toJson(),
    );
    return TaskCompletion.fromJson(envelope.dataMap);
  }

  Future<TaskCompletion> approveCompletion(
    String familyId,
    String childId,
    String taskId,
    String completionId,
    ReviewInput input,
  ) => _review(familyId, childId, taskId, completionId, 'approve', input);

  Future<TaskCompletion> rejectCompletion(
    String familyId,
    String childId,
    String taskId,
    String completionId,
    ReviewInput input,
  ) => _review(familyId, childId, taskId, completionId, 'reject', input);

  Future<TaskCompletion> reverseCompletion(
    String familyId,
    String childId,
    String taskId,
    String completionId,
    ReviewInput input,
  ) => _review(familyId, childId, taskId, completionId, 'reverse', input);

  // --- Points ---

  Future<PointsBalance> pointsBalance(String familyId, String childId) async {
    final envelope = await _client.get(
      '${_child(familyId, childId)}/points-balance',
    );
    return PointsBalance.fromJson(envelope.dataMap);
  }

  Future<Paginated<PointTransaction>> pointTransactions({
    required String familyId,
    required String childId,
    int page = 1,
    int perPage = 25,
  }) async {
    final envelope = await _client.get(
      '${_child(familyId, childId)}/point-transactions',
      query: {'page': page, 'per_page': perPage},
    );
    return Paginated.from<PointTransaction>(
      envelope,
      PointTransaction.fromJson,
    );
  }
}

final tasksRepositoryProvider = Provider<TasksRepository>(
  (ref) => TasksRepository(ref.watch(apiClientProvider)),
);
