import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_envelope.dart';
import '../../../core/providers.dart';
import 'models/game.dart';

/// `POST …/game-sessions` body. `clientSessionId` is the **per-child idempotency
/// key** for session-start retries — reuse it on retry so the backend returns
/// the existing session (200) instead of creating a duplicate (201).
class StartGameSessionInput {
  const StartGameSessionInput({
    required this.gameId,
    required this.clientSessionId,
    this.deviceId,
  });

  final String gameId;
  final String clientSessionId;
  final String? deviceId;

  Map<String, dynamic> toJson() => {
    'game_id': gameId,
    'client_session_id': clientSessionId,
    if (deviceId != null) 'device_id': deviceId,
  };
}

class SubmitGameSessionInput {
  const SubmitGameSessionInput({
    this.status,
    this.score,
    this.progress,
    this.endedAt,
  });

  /// `completed` | `abandoned`.
  final String? status;
  final int? score;
  final Map<String, dynamic>? progress;
  final DateTime? endedAt;

  Map<String, dynamic> toJson() => {
    if (status != null) 'status': status,
    if (score != null) 'score': score,
    if (progress != null) 'progress': progress,
    if (endedAt != null) 'ended_at': endedAt!.toUtc().toIso8601String(),
  };
}

/// HTTP for the game catalog + per-child sessions/progress (`GameController`).
///
/// Catalog reads = any authenticated user; sessions + progress = any active
/// member. The app has **no game engine** — [startSession] / [submitSession]
/// exist for a future native/web game runtime and are never called with
/// fabricated scores.
class GamesRepository {
  GamesRepository(this._client);

  final ApiClient _client;

  String _child(String familyId, String childId) =>
      '/families/$familyId/children/$childId';

  Future<Paginated<Game>> listGames({
    int? age,
    int page = 1,
    int perPage = 20,
  }) async {
    final envelope = await _client.get(
      '/games',
      query: {'page': page, 'per_page': perPage, 'age': ?age},
    );
    return Paginated.from<Game>(envelope, Game.fromJson);
  }

  /// `GET /games/{game}` — the route binds by **slug** (`Game::getRouteKeyName`
  /// returns `'slug'`), not by id.
  Future<Game> showGame(String slug) async {
    final envelope = await _client.get('/games/$slug');
    return Game.fromJson(envelope.dataMap);
  }

  /// Plain array — one row per game the child has played.
  Future<List<GameProgress>> progress(String familyId, String childId) async {
    final envelope = await _client.get(
      '${_child(familyId, childId)}/game-progress',
    );
    return envelope.dataList
        .whereType<Map<String, dynamic>>()
        .map(GameProgress.fromJson)
        .toList(growable: false);
  }

  Future<GameSession> startSession(
    String familyId,
    String childId,
    StartGameSessionInput input,
  ) async {
    final envelope = await _client.post(
      '${_child(familyId, childId)}/game-sessions',
      body: input.toJson(),
    );
    return GameSession.fromJson(envelope.dataMap);
  }

  Future<GameSession> submitSession(
    String familyId,
    String childId,
    String sessionId,
    SubmitGameSessionInput input,
  ) async {
    final envelope = await _client.post(
      '${_child(familyId, childId)}/game-sessions/$sessionId/submit',
      body: input.toJson(),
    );
    return GameSession.fromJson(envelope.dataMap);
  }
}

final gamesRepositoryProvider = Provider<GamesRepository>(
  (ref) => GamesRepository(ref.watch(apiClientProvider)),
);
