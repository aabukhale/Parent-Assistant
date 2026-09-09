import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:my_app/core/errors/api_exception.dart';
import 'package:my_app/features/games/data/games_repository.dart';
import 'package:my_app/features/games/data/models/game.dart';
import 'package:my_app/features/games/presentation/games_screen.dart';
import 'package:my_app/l10n/app_localizations.dart';

import '../../support/fixtures.dart';
import '../../support/test_api.dart';

void main() {
  const c = '/families/family-1/children/child-1';

  group('models', () {
    test('Game: unknown type → other; config kept opaque', () {
      final g = Game.fromJson(Fixtures.gameJson(gameType: 'rhythm'));
      expect(g.gameType, GameType.other);
      expect(g.config, isNotNull);
    });

    test('GameProgress: aggregates parse; null best_score tolerated', () {
      final p = GameProgress.fromJson(
        Fixtures.gameProgressJson2(bestScore: null, totalAttempts: 2),
      );
      expect(p.bestScore, isNull);
      expect(p.totalAttempts, 2);
      expect(p.totalPlaySeconds, 900);
    });

    test('GameSession: unknown status tolerated; score nullable', () {
      final s = GameSession.fromJson(
        Fixtures.gameSessionEnvelope(status: 'paused')['data']
            as Map<String, dynamic>,
      );
      expect(s.status, GameSessionStatus.unknown);
      expect(s.score, isNull);
    });

    test('StartGameSessionInput keeps client_session_id (idempotency)', () {
      expect(
        const StartGameSessionInput(
          gameId: 'g',
          clientSessionId: 'sess-1',
        ).toJson()['client_session_id'],
        'sess-1',
      );
    });
  });

  group('repository', () {
    late TestApi api;
    late GamesRepository repo;
    setUp(() {
      api = TestApi.create(
        token: 'tok',
        activeFamilyId: 'family-1',
        selectedChildId: 'child-1',
      );
      repo = api.container.read(gamesRepositoryProvider);
    });
    tearDown(() => api.dispose());

    test('listGames: GET /games with age', () async {
      api.adapter.onGet(
        '/games',
        (s) => s.reply(200, Fixtures.gamesPage([Fixtures.gameJson()])),
      );
      await repo.listGames(age: 5);
      expect(api.lastRequest.uri.queryParameters['age'], '5');
    });

    test('progress: GET child-scoped array', () async {
      api.adapter.onGet(
        '$c/game-progress',
        (s) => s.reply(200, Fixtures.gameProgressEnvelope()),
      );
      final rows = await repo.progress('family-1', 'child-1');
      expect(rows.single.gameId, 'game-1');
    });

    test('startSession: idempotent retry returns existing (200)', () async {
      api.adapter.onPost(
        '$c/game-sessions',
        (s) => s.reply(200, Fixtures.gameSessionEnvelope()),
        data: Matchers.any,
      );
      final session = await repo.startSession(
        'family-1',
        'child-1',
        const StartGameSessionInput(gameId: 'game-1', clientSessionId: 's1'),
      );
      expect(session.status, GameSessionStatus.inProgress);
      expect((api.lastRequest.data as Map)['client_session_id'], 's1');
    });

    test('submitSession: POST .../submit', () async {
      api.adapter.onPost(
        '$c/game-sessions/gs1/submit',
        (s) => s.reply(
          200,
          Fixtures.gameSessionEnvelope(status: 'completed', score: 200),
        ),
        data: Matchers.any,
      );
      final s = await repo.submitSession(
        'family-1',
        'child-1',
        'gs1',
        const SubmitGameSessionInput(status: 'completed', score: 200),
      );
      expect(s.score, 200);
    });

    test('showGame: GET /games/{slug} — binds by slug, not id', () async {
      api.adapter.onGet(
        '/games/memory-cards',
        (s) => s.reply(
          200,
          Fixtures.gameEnvelope(
            game: Fixtures.gameJson(id: 'game-uuid-1', slug: 'memory-cards'),
          ),
        ),
      );
      final game = await repo.showGame('memory-cards');
      expect(game.id, 'game-uuid-1');
      expect(game.slug, 'memory-cards');
      expect(api.lastRequest.uri.path, endsWith('/games/memory-cards'));
    });

    test('game detail 404 for an inactive game', () async {
      api.adapter.onGet(
        '/games/x',
        (s) => s.reply(404, {'success': false, 'message': 'Not found.'}),
      );
      try {
        await repo.showGame('x');
        fail('expected');
      } on ApiException catch (e) {
        expect(e.kind, ApiErrorKind.notFound);
      }
    });
  });

  group('widget', () {
    testWidgets('catalog renders games + the honest preview note', (
      tester,
    ) async {
      final l = lookupAppLocalizations(const Locale('en'));
      final api = TestApi.create(
        token: 'tok',
        locale: 'en',
        activeFamilyId: 'family-1',
      );
      addTearDown(api.dispose);
      api.adapter.onGet(
        '/games',
        (s) => s.reply(
          200,
          Fixtures.gamesPage([Fixtures.gameJson(title: 'Shape sorter')]),
        ),
      );
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: api.container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: GamesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Shape sorter'), findsOneWidget);
      expect(find.text(l.gamesPreviewNote), findsOneWidget);
    });
  });
}
