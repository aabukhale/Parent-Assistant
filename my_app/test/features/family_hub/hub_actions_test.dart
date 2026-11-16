import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:my_app/features/family_hub/application/hub_actions.dart';
import 'package:my_app/features/family_hub/data/hub_models.dart';

import '../../support/test_api.dart';

InboxItem _item(String kind, {Map<String, dynamic> detail = const {}}) =>
    InboxItem.fromJson({
      'kind': kind,
      'id': 'req-1',
      'child_id': 'c1',
      'child_name': 'Sara',
      'title': 'Brush teeth',
      'detail': detail,
      'can_act': true,
    });

void main() {
  late TestApi api;

  setUp(() {
    api = TestApi.create(
      token: 'tok',
      locale: 'en',
      activeFamilyId: 'family-1',
    );
    api.adapter.onPost(
      RegExp(r'.*'),
      (s) => s.reply(200, {'success': true, 'data': null}),
      data: Matchers.any,
    );
  });
  tearDown(() async {
    // Let the follow-up refreshes (auth restore, pulse…) finish first.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    api.dispose();
  });

  List<String> posted() => api.requests
      .where((r) => r.method == 'POST')
      .map((r) => r.path.replaceFirst(RegExp(r'^.*/api/v1'), ''))
      .toList();

  test('approving a task completion can be undone by reversing it', () async {
    final actions = api.container.read(hubActionsProvider);
    final undo = await actions.approve(
      _item('task_completion', detail: {'task_id': 't1'}),
    );

    expect(posted(), [
      '/families/family-1/children/c1/tasks/t1/completions/req-1/approve',
    ]);
    expect(undo, isNotNull);

    await undo!();
    expect(
      posted().last,
      '/families/family-1/children/c1/tasks/t1/completions/req-1/reverse',
    );
  });

  test('a reward approval undoes by cancelling (refund)', () async {
    final undo = await api.container
        .read(hubActionsProvider)
        .approve(_item('reward_redemption'));
    await undo!();

    expect(posted().first, endsWith('/reward-redemptions/req-1/approve'));
    expect(posted().last, endsWith('/reward-redemptions/req-1/cancel'));
  });

  test('screen-time and routine approvals offer no fake undo', () async {
    final actions = api.container.read(hubActionsProvider);
    expect(await actions.approve(_item('screen_time_request')), isNull);
    expect(await actions.approve(_item('routine_run')), isNull);
    expect(posted(), [
      '/families/family-1/screen-time-requests/req-1/approve',
      '/families/family-1/children/c1/routine-runs/req-1/approve',
    ]);
  });

  test('declining a wish goes to the wish endpoint', () async {
    await api.container.read(hubActionsProvider).decline(_item('reward_wish'));
    expect(posted(), ['/families/family-1/reward-wishes/req-1/decline']);
  });
}
