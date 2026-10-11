import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/cache/offline_cache.dart';
import 'package:my_app/features/kid/data/kid_repository.dart';

import '../../support/test_api.dart';

/// Responses captured from the real backend (`/api/v1/child/*`, synthetic demo
/// family), so model parsing is checked against the actual API contract.
Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('test/fixtures/kid/$name.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  late TestApi api;
  late Directory cacheDir;
  late KidRepository repo;

  setUp(() {
    cacheDir = Directory.systemTemp.createTempSync('kid_cache');
    api = TestApi.create(
      token: 'child-token',
      locale: 'en',
      overrides: [
        offlineCacheProvider.overrideWithValue(
          OfflineCache(baseDir: () async => cacheDir),
        ),
      ],
    );
    repo = api.container.read(kidRepositoryProvider);
  });
  tearDown(() {
    api.dispose();
    if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
  });

  void serve(String path, String fixture) =>
      api.adapter.onGet(path, (s) => s.reply(200, _fixture(fixture)));

  group('parses every real child endpoint', () {
    test('my day', () async {
      serve('/child/my-day', 'my_day');
      final day = (await repo.myDay()).value;
      expect(day.date, '2026-10-11');
      expect(day.timeline, isNotEmpty);
      expect(day.pointsBalance, greaterThanOrEqualTo(0));
    });

    test('tasks, routines, rewards, points', () async {
      serve('/child/tasks', 'tasks');
      serve('/child/routines', 'routines');
      serve('/child/rewards', 'rewards');
      serve('/child/points', 'points');

      final tasks = (await repo.tasks()).value;
      expect(tasks, isNotEmpty);
      expect(tasks.every((t) => t.title.isNotEmpty), isTrue);

      final routines = (await repo.routines()).value;
      expect(routines, isNotEmpty);
      expect(routines.first.steps, isNotEmpty);

      final catalog = (await repo.rewards()).value;
      expect(catalog.balance, 30);
      expect(catalog.rewards, isNotEmpty);
      expect(
        catalog.rewards.where((r) => r.isSavingFor).single.id,
        catalog.savingForRewardId,
      );

      await repo.points();
    });

    test('challenges show a shared total, never sibling rankings', () async {
      serve('/child/challenges', 'challenges');
      final challenges = (await repo.challenges()).value;
      expect(challenges, isNotEmpty);
      final raw = (_fixture('challenges')['data'] as List).first as Map;
      expect(raw.containsKey('contributions_by_child'), isFalse);
      expect(raw.containsKey('leaderboard'), isFalse);
    });

    test('wishes, check-ins, encouragements, requests, screen time', () async {
      serve('/child/wishes', 'wishes');
      serve('/child/checkins', 'checkins');
      serve('/child/encouragements', 'encouragements');
      serve('/child/requests', 'requests');
      serve('/child/screen-time', 'screen_time');

      expect((await repo.wishes()).value, isNotEmpty);
      expect((await repo.checkins()).value, isNotEmpty);
      expect((await repo.encouragements()).value, isEmpty);
      expect((await repo.requests()).value.pending, isNotEmpty);
      await repo.screenTime();
    });
  });

  test('completing a task posts to the child endpoint only', () async {
    api.adapter.onPost(
      '/child/tasks/t-1/complete',
      (s) => s.reply(200, {'success': true, 'data': null}),
    );

    await repo.completeTask('t-1');

    final sent = api.requests.where((r) => r.method == 'POST').single;
    expect(sent.path, endsWith('/child/tasks/t-1/complete'));
    expect(sent.headers['Authorization'], 'Bearer child-token');
  });

  test('offline: serves the last cached My Day, marked as cached', () async {
    serve('/child/my-day', 'my_day');
    final live = await repo.myDay();
    expect(live.fromCache, isFalse);

    api.adapter.onGet(
      '/child/my-day',
      (s) => s.throws(
        0,
        DioException(
          requestOptions: RequestOptions(path: '/child/my-day'),
          type: DioExceptionType.connectionError,
        ),
      ),
    );
    final cached = await repo.myDay();

    expect(cached.fromCache, isTrue);
    expect(cached.value.date, live.value.date);
    expect(cached.value.timeline.length, live.value.timeline.length);
  });

  test('a server error is not hidden behind the cache', () async {
    serve('/child/my-day', 'my_day');
    await repo.myDay();

    api.adapter.onGet(
      '/child/my-day',
      (s) => s.reply(500, {'success': false, 'message': 'boom'}),
    );

    expect(repo.myDay(), throwsA(anything));
  });
}
