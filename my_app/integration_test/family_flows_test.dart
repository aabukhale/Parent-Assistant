// End-to-end family flows against the LOCAL backend (synthetic demo data):
//
//   cd ../mamily && php artisan mamily:demo-seed --fresh && php artisan serve
//   flutter test integration_test -d <simulator> \
//     --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
//
// Child actions go through the real app UI; parent decisions and every
// assertion go through the API, so each test checks what the server
// actually recorded. Every test creates its own uniquely named task, reward
// or routine and removes it afterwards.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_app/core/storage/secure_token_storage.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/main.dart' as app;

import 'support/backend.dart';

final l = lookupAppLocalizations(const Locale('en'));

/// `finder.first`/`.last` throw while nothing matches yet; treat that as
/// "not there yet".
bool found(Finder finder) {
  try {
    return finder.evaluate().isNotEmpty;
  } on StateError {
    return false;
  }
}

Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (found(finder)) return;
  }
  throw TestFailure(
    'Timed out waiting for ${finder.describeMatch(Plurality.zero)}',
  );
}

Future<T> eventually<T>(
  Future<T> Function() read,
  bool Function(T) ok, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final end = DateTime.now().add(timeout);
  late T last;
  while (DateTime.now().isBefore(end)) {
    last = await read();
    if (ok(last)) return last;
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  return last;
}

/// The child app, paired to Omar. The first test pairs a fresh install
/// through the real pairing screen; later tests relaunch the app and reuse
/// that session (as a real phone would), which also keeps a full run under
/// the backend's pairing rate limit (5/min, 30/h per IP).
Future<void> launchAsChild(
  WidgetTester tester,
  ParentApi parent,
  String childId,
) async {
  final storage = SecureTokenStorage();
  final paired =
      await storage.readSessionKind() == 'child' &&
      await storage.readToken() != null;
  if (!paired) {
    await storage.clearEverything();
    await storage.writeLocale('en');
  }
  await app.main();
  if (paired) {
    await pumpUntil(tester, find.text(l.kidTabMyDay));
    return;
  }
  final code = await parent.pairingCode(childId);
  await pumpUntil(tester, find.text(l.roleChild));
  await tester.tap(find.text(l.roleChild));
  await pumpUntil(tester, find.text(l.pairButton));
  await tester.enterText(find.byType(TextField).first, code);
  await tester.tap(find.text(l.pairButton));
  await pumpUntil(tester, find.text(l.kidTabMyDay));
}

/// Scrolls the page's main list until [text] is on screen; returns its last
/// match (a title can also appear in the "next step" hero).
Future<Finder> scrollTo(WidgetTester tester, String text) async {
  await pumpUntil(tester, find.byType(Scrollable));
  final target = find.text(text);
  for (var i = 0; i < 40 && !found(target); i++) {
    await tester.drag(
      find.byType(Scrollable).hitTestable().first,
      const Offset(0, -300),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }
  await pumpUntil(tester, target);
  await tester.ensureVisible(target.last);
  await tester.pump(const Duration(milliseconds: 300));
  return target.last;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late ParentApi parent;
  late String omar;

  setUpAll(() async {
    parent = await ParentApi.signIn();
    omar = await parent.childId('Omar');
    // Start from a clean install; the first test pairs it.
    await SecureTokenStorage().clearEverything();
  });
  tearDownAll(() async {
    await SecureTokenStorage().clearEverything();
    await parent.signOut();
  });

  testWidgets('task: child sends it, parent approves, points land once', (
    tester,
  ) async {
    final title = uniqueName('IT feed fish');
    final taskId = await parent.createDailyTask(omar, title, points: 7);
    addTearDown(() => parent.archiveTask(omar, taskId));
    final before = await parent.balance(omar);

    await launchAsChild(tester, parent, omar);
    await tester.tap(await scrollTo(tester, title));
    await pumpUntil(tester, find.text(l.kidIDidIt).last);
    await tester.tap(find.text(l.kidIDidIt).last);
    await pumpUntil(tester, find.text(l.kidYesDone));
    await tester.tap(find.text(l.kidYesDone));
    await tester.pump(const Duration(seconds: 2));

    // The request reached the parent's inbox…
    final items = await eventually(
      parent.inbox,
      (list) => list.any((i) => i['detail']?['task_id'] == taskId),
    );
    final item = items.firstWhere((i) => i['detail']?['task_id'] == taskId);
    expect(item['kind'], 'task_completion');
    expect(await parent.balance(omar), before, reason: 'not before approval');

    // …approving awards the points exactly once, even if approved twice.
    expect(await parent.approveCompletion(omar, taskId, item['id']), 200);
    expect(await parent.approveCompletion(omar, taskId, item['id']), 409);
    expect(await parent.balance(omar), before + 7);
    expect(
      (await parent.inbox()).where((i) => i['detail']?['task_id'] == taskId),
      isEmpty,
    );
  });

  testWidgets('reward: child asks, parent approves, points spent once', (
    tester,
  ) async {
    final title = uniqueName('IT ice cream');
    final rewardId = await parent.createReward(title, cost: 5);
    addTearDown(() => parent.deleteReward(rewardId));
    final before = await parent.balance(omar);
    expect(before, greaterThanOrEqualTo(5), reason: 'seed gives Omar points');

    await launchAsChild(tester, parent, omar);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.kidTabRewards));
    await pumpUntil(tester, find.text(l.kidAskForReward).first);
    await scrollTo(tester, title);
    final card = find.ancestor(
      of: find.text(title),
      matching: find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'KidCard',
      ),
    );
    await tester.tap(
      find.descendant(of: card.first, matching: find.text(l.kidAskForReward)),
    );
    // Wait for the sheet itself, then confirm on its primary button.
    await pumpUntil(tester, find.text(l.kidRewardAskTitle(title)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.kidAskForReward).last);
    await tester.pump(const Duration(seconds: 2));

    final mine = await eventually(
      () => parent.redemptions(omar),
      (list) => list.any(
        (r) => r['reward_id'] == rewardId && r['status'] == 'pending',
      ),
    );
    final redemption = mine.firstWhere((r) => r['reward_id'] == rewardId);
    expect(redemption['requested_by_child'], isTrue);
    expect(await parent.balance(omar), before, reason: 'held, not spent');

    expect(await parent.approveRedemption(omar, redemption['id']), 200);
    expect(await parent.approveRedemption(omar, redemption['id']), 409);
    expect(await parent.balance(omar), before - 5);
  });

  testWidgets('routine: child ticks every step, bonus paid once on approval', (
    tester,
  ) async {
    final title = uniqueName('IT bedtime');
    final steps = ['IT brush', 'IT pyjamas'];
    final routineId = await parent.createRoutine(
      omar,
      title,
      bonus: 4,
      steps: steps,
    );
    addTearDown(() => parent.deleteRoutine(omar, routineId));
    final before = await parent.balance(omar);

    await launchAsChild(tester, parent, omar);
    await tester.tap(await scrollTo(tester, title));
    for (final step in steps) {
      await pumpUntil(tester, find.bySemanticsLabel(step));
      await tester.tap(find.bySemanticsLabel(step));
      await tester.pump(const Duration(milliseconds: 800));
    }
    await pumpUntil(tester, find.text(l.kidRoutineDone));

    final runs = await eventually(
      () => parent.routineRuns(omar),
      (list) => list.any(
        (r) => r['routine_id'] == routineId && r['status'] == 'pending_review',
      ),
    );
    final run = runs.firstWhere((r) => r['routine_id'] == routineId);
    expect(run['steps_done'], steps.length);
    expect(await parent.balance(omar), before, reason: 'bonus needs approval');

    expect(await parent.approveRoutineRun(omar, run['id']), 200);
    expect(await parent.approveRoutineRun(omar, run['id']), 409);
    expect(await parent.balance(omar), before + 4);
  });

  testWidgets('roles stay isolated; unpairing ends the child session', (
    tester,
  ) async {
    final sara = await parent.childId('Sara');
    final saraTask = await parent.createDailyTask(
      sara,
      uniqueName('IT Sara only'),
      points: 1,
    );
    addTearDown(() => parent.archiveTask(sara, saraTask));

    final child = await ChildApi.pair(
      await parent.pairingCode(omar),
      installId:
          'integration-isolation-${DateTime.now().millisecondsSinceEpoch}',
    );
    final f = '/families/${parent.familyId}';

    // A child token can't use parent endpoints…
    expect(await child.status('GET', '$f/inbox'), 403);
    expect(await child.status('GET', '$f/children'), 403);
    expect(await child.status('GET', '/auth/me'), 403);
    expect(await child.status('POST', '$f/rewards'), 403);
    // …nor see another child's data, even by id.
    expect(await child.status('GET', '/child/tasks/$saraTask'), 404);
    expect(await child.status('POST', '/child/tasks/$saraTask/complete'), 404);
    // A parent token can't act as a child.
    expect((await parent.dio.get<dynamic>('/child/my-day')).statusCode, 403);

    // Unpairing revokes that install's session at once.
    final deviceId = await child.deviceId();
    expect(deviceId, isNotNull);
    expect(await child.status('GET', '/child/my-day'), 200);
    expect(await parent.unpair(omar, deviceId!), 200);
    expect(await child.status('GET', '/child/my-day'), 401);

    // In the app: a paired child whose device is unpaired falls back to the
    // role chooser with nothing of the old session left.
    await launchAsChild(tester, parent, omar);
    final appDevices = await parent.devices(omar);
    // Newest first: the install the app just paired.
    final appDevice = appDevices.firstWhere(
      (d) => d['has_child_session'] == true,
    );
    expect(await parent.unpair(omar, appDevice['id'] as String), 200);
    // The app learns on its next fetch (pull to refresh, or app resume).
    await tester.pumpAndSettle();
    await tester.fling(
      find.byType(Scrollable).hitTestable().first,
      const Offset(0, 400),
      1500,
    );
    await pumpUntil(tester, find.text(l.roleChild));
    expect(await SecureTokenStorage().readToken(), isNull);
  });
}
