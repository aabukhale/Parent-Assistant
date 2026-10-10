import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../surfaces/surface_sync.dart';
import '../data/hub_models.dart';
import '../data/hub_repository.dart';
import 'hub_providers.dart';

/// Parent decisions on inbox items. The server enforces permissions and
/// state (a second approval is a 409, never a second award); after each
/// decision the overview, dashboards and out-of-app surfaces refresh.
class HubActions {
  HubActions(this._ref);

  final Ref _ref;

  HubRepository get _repo => _ref.read(hubRepositoryProvider);

  /// Approve. Returns an undo callback when the action can be reversed
  /// (task approval → reverse; reward approval → cancel with refund).
  Future<Future<void> Function()?> approve(
    InboxItem item, {
    String? note,
    int? points,
    String? title,
    String? type,
    int? minutes,
  }) async {
    Future<void> Function()? undo;
    switch (item.kind) {
      case 'task_completion':
        final taskId = item.detail['task_id'] as String;
        await _repo.approveTask(item.childId, taskId, item.id, note: note);
        undo = () async {
          await _repo.reverseTask(item.childId, taskId, item.id);
          _after();
        };
      case 'activity_completion':
        await _repo.approveActivity(
          item.childId,
          item.detail['assignment_id'] as String,
          item.id,
          note: note,
        );
      case 'reward_redemption':
        await _repo.approveRedemption(item.childId, item.id, note: note);
        undo = () async {
          await _repo.cancelRedemption(item.childId, item.id);
          _after();
        };
      case 'reward_wish':
        await _repo.approveWish(
          item.id,
          pointsCost: points ?? 50,
          title: title,
          type: type,
          minutes: minutes,
          note: note,
        );
      case 'screen_time_request':
        await _repo.approveScreenTime(item.id, minutes: minutes, note: note);
      case 'routine_run':
        await _repo.approveRoutine(item.childId, item.id, note: note);
    }
    _after();
    return undo;
  }

  Future<void> decline(InboxItem item, {String? note}) async {
    switch (item.kind) {
      case 'task_completion':
        await _repo.rejectTask(
          item.childId,
          item.detail['task_id'] as String,
          item.id,
          note: note,
        );
      case 'activity_completion':
        await _repo.rejectActivity(
          item.childId,
          item.detail['assignment_id'] as String,
          item.id,
          note: note,
        );
      case 'reward_redemption':
        await _repo.rejectRedemption(item.childId, item.id, note: note);
      case 'reward_wish':
        await _repo.declineWish(item.id, note: note);
      case 'screen_time_request':
        await _repo.declineScreenTime(item.id, note: note);
      case 'routine_run':
        await _repo.rejectRoutine(item.childId, item.id, note: note);
    }
    _after();
  }

  Future<void> replyCheckin(
    String checkinId, {
    String? reply,
    String? sticker,
  }) async {
    await _repo.replyCheckin(checkinId, reply: reply, sticker: sticker);
    _ref.invalidate(childCheckinsProvider);
    _after();
  }

  Future<void> sendPraise(
    String childId, {
    required String message,
    String? badgeKey,
    String? subjectType,
    String? subjectId,
  }) async {
    await _repo.sendEncouragement(
      childId,
      message: message,
      badgeKey: badgeKey,
      subjectType: subjectType,
      subjectId: subjectId,
    );
    _ref.invalidate(childEncouragementsProvider(childId));
  }

  void _after() {
    _ref
      ..invalidate(pulseProvider)
      ..invalidate(familyInboxProvider)
      ..invalidate(challengesProvider);
    bumpDashboardRefresh(_ref);
    _ref.read(surfaceSyncProvider).refresh();
  }
}

final hubActionsProvider = Provider<HubActions>(HubActions.new);
