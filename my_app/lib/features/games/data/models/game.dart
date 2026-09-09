import 'package:flutter/foundation.dart';

/// Backend `App\Enums\GameType`. Unknown wire values are preserved as [other].
enum GameType {
  memory,
  puzzle,
  quiz,
  matching,
  drawing,
  other;

  static GameType fromWire(String? v) => switch (v) {
    'memory' => GameType.memory,
    'puzzle' => GameType.puzzle,
    'quiz' => GameType.quiz,
    'matching' => GameType.matching,
    'drawing' => GameType.drawing,
    _ => GameType.other,
  };
}

/// Backend `App\Enums\GameSessionStatus`.
enum GameSessionStatus {
  inProgress('in_progress'),
  completed('completed'),
  abandoned('abandoned'),
  unknown('unknown');

  const GameSessionStatus(this.wire);
  final String wire;

  static GameSessionStatus fromWire(String? v) => switch (v) {
    'in_progress' => GameSessionStatus.inProgress,
    'completed' => GameSessionStatus.completed,
    'abandoned' => GameSessionStatus.abandoned,
    _ => GameSessionStatus.unknown,
  };
}

/// A catalog game (`GameResource`). `title` / `description` are API-localized.
/// `config` is opaque backend JSON — the app does not interpret it and does not
/// ship a game engine, so nothing about gameplay, levels or scoring is invented.
@immutable
class Game {
  const Game({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.gameType,
    required this.minAge,
    required this.maxAge,
    required this.isActive,
    this.config,
  });

  final String id;
  final String slug;
  final String title;
  final String? description;
  final GameType gameType;
  final int? minAge;
  final int? maxAge;
  final bool isActive;
  final Map<String, dynamic>? config;

  factory Game.fromJson(Map<String, dynamic> json) {
    final rawConfig = json['config'];
    return Game(
      id: '${json['id']}',
      slug: '${json['slug']}',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      gameType: GameType.fromWire(json['game_type'] as String?),
      minAge: (json['min_age'] as num?)?.round(),
      maxAge: (json['max_age'] as num?)?.round(),
      isActive: json['is_active'] as bool? ?? true,
      config: rawConfig is Map<String, dynamic> ? rawConfig : null,
    );
  }
}

/// Per-child aggregate progress for one game (`GameProgressResource`). All
/// values are backend aggregates — never computed on the client.
@immutable
class GameProgress {
  const GameProgress({
    required this.id,
    required this.childId,
    required this.gameId,
    required this.bestScore,
    required this.totalAttempts,
    required this.totalPlaySeconds,
    required this.lastPlayedAt,
  });

  final String id;
  final String childId;
  final String gameId;
  final int? bestScore;
  final int totalAttempts;
  final int totalPlaySeconds;
  final DateTime? lastPlayedAt;

  factory GameProgress.fromJson(Map<String, dynamic> json) => GameProgress(
    id: '${json['id']}',
    childId: '${json['child_id']}',
    gameId: '${json['game_id']}',
    bestScore: (json['best_score'] as num?)?.round(),
    totalAttempts: (json['total_attempts'] as num?)?.round() ?? 0,
    totalPlaySeconds: (json['total_play_seconds'] as num?)?.round() ?? 0,
    lastPlayedAt: DateTime.tryParse('${json['last_played_at']}')?.toLocal(),
  );
}

/// A game session (`GameSessionResource`). Created/updated only via the backend;
/// the app never invents `score`, `status`, or `progress`.
@immutable
class GameSession {
  const GameSession({
    required this.id,
    required this.gameId,
    required this.childId,
    required this.status,
    required this.startedAt,
    required this.endedAt,
    required this.score,
    this.progress,
  });

  final String id;
  final String gameId;
  final String childId;
  final GameSessionStatus status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? score;
  final Map<String, dynamic>? progress;

  factory GameSession.fromJson(Map<String, dynamic> json) {
    final rawProgress = json['progress'];
    return GameSession(
      id: '${json['id']}',
      gameId: '${json['game_id']}',
      childId: '${json['child_id']}',
      status: GameSessionStatus.fromWire(json['status'] as String?),
      startedAt: DateTime.tryParse('${json['started_at']}')?.toLocal(),
      endedAt: DateTime.tryParse('${json['ended_at']}')?.toLocal(),
      score: (json['score'] as num?)?.round(),
      progress: rawProgress is Map<String, dynamic> ? rawProgress : null,
    );
  }
}
