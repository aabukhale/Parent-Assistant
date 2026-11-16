// Real-backend journeys for screen time, phone rules and remote help.
//
// Run against an ISOLATED backend (throwaway SQLite), never the normal dev DB:
//
//   cd ../mamily
//   touch /tmp/mamily_it.sqlite
//   DB_DATABASE=/tmp/mamily_it.sqlite php artisan migrate --force
//   DB_DATABASE=/tmp/mamily_it.sqlite php artisan mamily:demo-seed
//   DB_DATABASE=/tmp/mamily_it.sqlite php artisan serve --port=8101
//   flutter test integration_test/safety_flows_test.dart -d <simulator> \
//     --dart-define=API_BASE_URL=http://127.0.0.1:8101/api/v1
//
// The child app runs on the simulator, which has no Screen Time enforcement:
// these journeys check delivery and honest reporting, not native blocking
// (that is verified on an Android device-owner emulator; see docs/PROGRESS.md).
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_app/core/storage/secure_token_storage.dart';

import 'support/backend.dart';
import 'support/ui.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late ParentApi parent;
  late String omar;

  setUpAll(() async {
    parent = await ParentApi.signIn();
    omar = await parent.childId('Omar');
    await SecureTokenStorage().clearEverything();
  });
  tearDownAll(() async {
    await SecureTokenStorage().clearEverything();
    await parent.signOut();
  });

  testWidgets(
    'extra time: child asks for 20, parent gives 10, limit grows by 10',
    (tester) async {
      await parent.setDailyLimit(omar, 60);
      addTearDown(() => parent.setDailyLimit(omar, null));
      final before =
          (await parent.screenTimeSummary(omar))['effective_limit_minutes']
              as int;

      await launchAsChild(tester, parent, omar);
      await pumpUntil(tester, find.text(l.kidAskMoreTime));
      await tester.tap(find.text(l.kidAskMoreTime));
      await pumpUntil(tester, find.text(l.kidMinutes(20)));
      await tester.tap(find.text(l.kidMinutes(20)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(l.kidMoreTimeSend));
      await pumpUntil(tester, find.textContaining(l.kidWaitingParent));

      // Nothing changes until the parent decides.
      expect(
        (await parent.screenTimeSummary(omar))['effective_limit_minutes'],
        before,
      );
      final pending = await eventually(
        parent.pendingScreenTimeRequests,
        (r) => r.any((x) => x['child_id'] == omar && x['minutes'] == 20),
      );
      final req = pending.firstWhere((x) => x['child_id'] == omar);
      expect(
        await parent.approveScreenTime(req['id'] as String, minutes: 10),
        200,
      );
      // Approving twice must not add time twice.
      expect(
        await parent.approveScreenTime(req['id'] as String, minutes: 10),
        409,
      );

      final after = await parent.screenTimeSummary(omar);
      expect(after['effective_limit_minutes'], before + 10);
    },
  );

  testWidgets('pause now: the phone receives it and is never reported "on" '
      'when it cannot enforce', (tester) async {
    final state = await parent.restrictNow(omar);
    addTearDown(() => parent.release(omar));
    final version = state['version'] as int;

    // The app fetches the policy when it opens.
    await launchAsChild(tester, parent, omar);
    await pumpUntil(tester, find.text(l.kidPausedNow));

    final rules = await eventually(
      () => parent.deviceRules(omar),
      (r) => ((r['status'] as Map)['devices'] as List).any(
        (d) => (d as Map)['received_version'] == version,
      ),
      timeout: const Duration(seconds: 20),
    );
    final device = ((rules['status'] as Map)['devices'] as List)
        .cast<Map>()
        .firstWhere((d) => d['received_version'] == version);
    // The simulator has no Screen Time authorization: the phone processed
    // the version and said why it can't enforce it — never "on".
    expect(device['state'], 'permission_needed');
    expect(device['state'], isNot('active'));
  });

  testWidgets('remote help: nothing until the child accepts; parent ending '
      'it clears the banner and is logged', (tester) async {
    await launchAsChild(tester, parent, omar);
    final s = await parent.requestRemote(omar, 'in_app_help');
    final id = s['id'] as String;
    addTearDown(() => parent.endRemote(id));
    expect(s['status'], 'requested');

    await pumpUntil(
      tester,
      find.text(l.kidRemoteAccept),
      timeout: const Duration(seconds: 25),
    );
    expect((await parent.remoteSession(id))['status'], 'requested');

    // Let the consent sheet finish sliding in before tapping.
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text(l.kidRemoteAccept).last);
    await pumpUntil(tester, find.text(l.kidRemoteStop));
    expect(
      (await eventually(
        () => parent.remoteSession(id),
        (r) => r['status'] == 'active',
      ))['status'],
      'active',
    );

    final ended = await parent.endRemote(id);
    expect(ended['end_reason'], 'parent_ended');
    final end = DateTime.now().add(const Duration(seconds: 25));
    while (found(find.text(l.kidRemoteStop)) && DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(found(find.text(l.kidRemoteStop)), isFalse);

    final log = await parent.accessLog();
    expect(
      log.map((e) => e['action']),
      containsAll(['remote.started', 'remote.ended']),
    );
  });
}
